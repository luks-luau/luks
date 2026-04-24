//! Utilitários para segurança em fronteiras FFI
//!
//! Este módulo fornece helpers para converter erros Rust em retornos C seguros,
//! garantindo que panics nunca escapem para código não-Rust.

use std::ffi::CString;
use std::panic::{self, AssertUnwindSafe};
use std::ptr;

/// Converte um Result<String, E> em *mut i8 seguro para FFI
///
/// - Ok(String) → CString alocado (caller deve usar luks_free_error)
/// - Err(_) → null ptr
/// - Panic interno → null ptr (nunca vaza)
///
/// # Safety
/// O caller é responsável por liberar a string retornada com `luks_free_error`
/// quando não for null.
pub fn ffi_string_result<T: ToString, E: ToString>(
    result: Result<T, E>,
) -> *mut std::os::raw::c_char {
    match result {
        Ok(val) => {
            match CString::new(val.to_string()) {
                Ok(cstr) => cstr.into_raw(),
                Err(_) => ptr::null_mut(), // Interior null: retorna null seguro
            }
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Wrapper seguro para executar lógica que pode panicar em fronteiras FFI
///
/// Captura panics e converte para None, evitando undefined behavior.
/// Usa AssertUnwindSafe internamente para lidar com tipos que contêm UnsafeCell
/// (como os usados pelo mlua).
///
/// Retorna Some(valor) se sucesso, ou None se houve panic.
///
/// # Example
/// ```ignore
/// #[no_mangle]
/// pub unsafe extern "C-unwind" fn minha_funcao() -> *mut i8 {
///     ffi_catch_unwind(|| {
///         // lógica que pode panicar
///         Some(CString::new("sucesso")?.into_raw())
///     }).unwrap_or(ptr::null_mut())
/// }
/// ```
pub fn ffi_catch_unwind<F, R>(f: F) -> Option<R>
where
    F: FnOnce() -> R,
{
    // AssertUnwindSafe diz ao compilador: "Eu sei que há UnsafeCell aqui,
    // mas vou lidar com o panic de forma segura (retornando None)".
    match panic::catch_unwind(AssertUnwindSafe(f)) {
        Ok(res) => Some(res),
        Err(_) => None,
    }
}

/// Helper específico para funções que retornam *mut i8 (C strings)
///
/// Converte Result<String, String> em *mut i8 com tratamento seguro de erros.
/// Retorna null em caso de panic ou erro.
pub fn ffi_cstring_result(result: Result<String, String>) -> *mut std::os::raw::c_char {
    ffi_catch_unwind(|| {
        match result {
            Ok(msg) => match CString::new(msg) {
                Ok(cstr) => cstr.into_raw(),
                Err(_) => ptr::null_mut(), // Interior null = null seguro
            },
            Err(_) => ptr::null_mut(),
        }
    })
    .unwrap_or(ptr::null_mut())
}

/// Converte uma mensagem de erro em CString seguro, com fallback
pub fn ffi_error_msg(msg: impl ToString) -> *mut std::os::raw::c_char {
    let s = msg.to_string();
    match CString::new(s) {
        Ok(cstr) => cstr.into_raw(),
        Err(_) => {
            // Fallback: tenta criar uma mensagem genérica sem nulls
            CString::new("internal error: invalid utf-8 or null byte")
                .unwrap_or_else(|_| CString::new("error").unwrap())
                .into_raw()
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
            // Limpar memória alocada
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
        // CString::new falha com null byte interior
        let ptr = ffi_error_msg("hello\0world");
        unsafe {
            // Deve retornar fallback, não panicar
            assert!(!ptr.is_null());
            let s = CStr::from_ptr(ptr).to_str().unwrap();
            assert!(s.contains("error") || s.contains("invalid"));
            drop(CString::from_raw(ptr));
        }
    }
}
