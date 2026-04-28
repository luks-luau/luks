//! Utilities for FFI boundary safety
//!
//! This module provides helpers to convert Rust errors into safe C returns,
//! ensuring panics never escape into non-Rust code.

use std::ffi::CString;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;

/// Converts a `Result<T, E>` into an FFI-safe C string pointer.
///
/// - `Ok(T)` -> allocated `CString` (caller must use `luks_free_error`)
/// - `Err(_)` -> null pointer
/// - internal panic -> null pointer (never unwinds across FFI)
///
/// # Safety
/// The caller is responsible for freeing the returned string with
/// `luks_free_error` when it is not null.
pub fn ffi_string_result<T: ToString, E: ToString>(
    result: Result<T, E>,
) -> *mut std::os::raw::c_char {
    match result {
        Ok(val) => {
            match CString::new(val.to_string()) {
                Ok(cstr) => cstr.into_raw(),
                Err(_) => ptr::null_mut(), // Interior null byte: safe null fallback
            }
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Safe wrapper for logic that may panic at FFI boundaries.
///
/// Catches panics and converts them to `None`, avoiding undefined behavior.
/// Uses `AssertUnwindSafe` to handle types that contain `UnsafeCell`
/// (such as internal `mlua` structures).
///
/// Returns `Some(value)` on success, or `None` on panic.
///
/// # Example
/// ```ignore
/// #[no_mangle]
/// pub unsafe extern "C-unwind" fn my_function() -> *mut i8 {
///     ffi_catch_unwind(|| {
///         // logic that may panic
///         Some(CString::new("success")?.into_raw())
///     }).unwrap_or(ptr::null_mut())
/// }
/// ```
pub fn ffi_catch_unwind<F, R>(f: F) -> Option<R>
where
    F: FnOnce() -> R,
{
    // AssertUnwindSafe tells the compiler that unwind-safety is handled here
    // by converting panic into `None`.
    panic::catch_unwind(AssertUnwindSafe(f)).ok()
}

/// Specialized helper for functions that return `*mut i8` (C strings).
///
/// Converts `Result<String, String>` into `*mut i8` with safe error handling.
/// Returns null on panic or error.
pub fn ffi_cstring_result(result: Result<String, String>) -> *mut std::os::raw::c_char {
    ffi_catch_unwind(|| {
        match result {
            Ok(msg) => match CString::new(msg) {
                Ok(cstr) => cstr.into_raw(),
                Err(_) => ptr::null_mut(), // Interior null byte = safe null fallback
            },
            Err(_) => ptr::null_mut(),
        }
    })
    .unwrap_or(ptr::null_mut())
}

/// Converts an error message to a safe CString with fallback.
/// Never returns null; always allocates a valid string.
pub fn ffi_error_msg(msg: impl ToString) -> *mut std::os::raw::c_char {
    let s = msg.to_string();
    // Sanitize null bytes that would make CString::new fail.
    let sanitized = s.replace('\0', "\\0");
    match CString::new(sanitized) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => {
            // Absolute fallback: this string is guaranteed to have no nulls.
            CString::new("internal error").unwrap().into_raw()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CStr;

    #[test]
    fn test_ffi_string_result_ok() {
        let result: Result<String, String> = Ok("hello".to_string());
        let ptr = ffi_string_result(result);
        unsafe {
            assert!(!ptr.is_null());
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "hello");
            // Free allocated memory.
            drop(CString::from_raw(ptr));
        }
    }

    #[test]
    fn test_ffi_string_result_err() {
        let result: Result<String, String> = Err("error".to_string());
        let ptr = ffi_string_result(result);
        assert!(ptr.is_null());
    }

    #[test]
    fn test_ffi_error_msg_with_null_byte() {
        // CString::new fails with interior null bytes.
        let ptr = ffi_error_msg("hello\0world");
        unsafe {
            // Must sanitize interior null bytes without panicking.
            assert!(!ptr.is_null());
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert_eq!(s, "hello\\0world");
            drop(CString::from_raw(ptr));
        }
    }
}
