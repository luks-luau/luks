#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::CString;
use std::io::{Read, Write};

/// Convert a Rust string to CString, replacing null bytes with U+FFFD
fn str_to_cstring(s: &str) -> CString {
    let sanitized = s.replace('\0', "\u{FFFD}");
    CString::new(sanitized).expect("Failed to create CString after sanitization")
}

/// Raise a Lua error with the given message. This function does not return.
///
/// # Safety
/// Assumes `l` is a valid `lua_State` pointer.
unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    unsafe {
        let cstr = str_to_cstring(msg);
        lua_pushstring(l, cstr.as_ptr());
        lua_error(l);
    }
}

/// Helper to get a buffer from a Lua pointer/index
unsafe fn get_buffer(l: *mut lua_State, idx: i32) -> Option<&'static mut [u8]> {
    let mut len = 0;
    let ptr = lua_tobuffer(l, idx, &mut len);
    if ptr.is_null() {
        None
    } else {
        Some(std::slice::from_raw_parts_mut(ptr as *mut u8, len))
    }
}

// ---------------------------------------------------------------------------
// STDIN (Rust std::io::stdin)
// ---------------------------------------------------------------------------

/// Reads bytes from stdin into a Luau buffer.
/// Lua: stdin_read(buf: buffer, offset: number, len: number) -> bytes_read: number
///      On error, raises a Lua error (caught by pcall).
unsafe extern "C-unwind" fn lua_stdin_read(l: *mut lua_State) -> i32 {
    let buf_idx = 1;
    let offset = lua_tointeger(l, 2) as usize;
    let len = lua_tointeger(l, 3) as usize;

    let Some(buf) = get_buffer(l, buf_idx) else {
        lua_pushinteger(l, 0);
        return 1;
    };

    let max_len = buf.len().saturating_sub(offset);
    let read_len = if len == 0 { max_len } else { len.min(max_len) };

    let mut stdin = std::io::stdin().lock();
    match stdin.read(&mut buf[offset..offset + read_len]) {
        Ok(n) => {
            lua_pushinteger(l, n as i64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("stdin read error: {}", e));
        }
    }
}

// ---------------------------------------------------------------------------
// STDOUT (Rust std::io::stdout)
// ---------------------------------------------------------------------------

/// Writes bytes to stdout from a Luau buffer or string.
/// Lua: stdout_write(buf: buffer | string, offset: number, len: number) -> bytes_written: number
///      On error, raises a Lua error (caught by pcall).
unsafe extern "C-unwind" fn lua_stdout_write(l: *mut lua_State) -> i32 {
    let buf_idx = 1;
    let offset = lua_tointeger(l, 2) as usize;
    let len = lua_tointeger(l, 3) as usize;

    let data = if lua_isstring(l, buf_idx) != 0 {
        let mut slen = 0;
        let ptr = lua_tolstring(l, buf_idx, &mut slen);
        std::slice::from_raw_parts(ptr as *const u8, slen)
    } else if let Some(buf) = get_buffer(l, buf_idx) {
        buf
    } else {
        lua_pushinteger(l, 0);
        return 1;
    };

    let max_len = data.len().saturating_sub(offset);
    let write_len = if len == 0 { max_len } else { len.min(max_len) };

    let mut stdout = std::io::stdout().lock();
    match stdout.write(&data[offset..offset + write_len]) {
        Ok(n) => {
            lua_pushinteger(l, n as i64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("stdout write error: {}", e));
        }
    }
}

unsafe extern "C-unwind" fn lua_stdout_flush(l: *mut lua_State) -> i32 {
    let mut stdout = std::io::stdout().lock();
    match stdout.flush() {
        Ok(()) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("stdout flush error: {}", e));
        }
    }
}

// ---------------------------------------------------------------------------
// STDERR (Rust std::io::stderr)
// ---------------------------------------------------------------------------

unsafe extern "C-unwind" fn lua_stderr_write(l: *mut lua_State) -> i32 {
    let buf_idx = 1;
    let offset = lua_tointeger(l, 2) as usize;
    let len = lua_tointeger(l, 3) as usize;

    let data = if lua_isstring(l, buf_idx) != 0 {
        let mut slen = 0;
        let ptr = lua_tolstring(l, buf_idx, &mut slen);
        std::slice::from_raw_parts(ptr as *const u8, slen)
    } else if let Some(buf) = get_buffer(l, buf_idx) {
        buf
    } else {
        lua_pushinteger(l, 0);
        return 1;
    };

    let max_len = data.len().saturating_sub(offset);
    let write_len = if len == 0 { max_len } else { len.min(max_len) };

    let mut stderr = std::io::stderr().lock();
    match stderr.write(&data[offset..offset + write_len]) {
        Ok(n) => {
            lua_pushinteger(l, n as i64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("stderr write error: {}", e));
        }
    }
}

unsafe extern "C-unwind" fn lua_stderr_flush(l: *mut lua_State) -> i32 {
    let mut stderr = std::io::stderr().lock();
    match stderr.flush() {
        Ok(()) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("stderr flush error: {}", e));
        }
    }
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `api` must be a valid pointer to a `LuauAPI` struct.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);

        lua_createtable(l, 0, 5);

        lua_pushcfunction(l, lua_stdin_read);
        lua_setfield(l, -2, c"stdin_read".as_ptr());

        lua_pushcfunction(l, lua_stdout_write);
        lua_setfield(l, -2, c"stdout_write".as_ptr());

        lua_pushcfunction(l, lua_stdout_flush);
        lua_setfield(l, -2, c"stdout_flush".as_ptr());

        lua_pushcfunction(l, lua_stderr_write);
        lua_setfield(l, -2, c"stderr_write".as_ptr());

        lua_pushcfunction(l, lua_stderr_flush);
        lua_setfield(l, -2, c"stderr_flush".as_ptr());

        1
    }
}
