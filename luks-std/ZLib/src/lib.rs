#![allow(unsafe_op_in_unsafe_fn)]

use flate2::write::{ZlibDecoder, ZlibEncoder};
use flate2::Compression;
use luks_module_sys::*;
use std::ffi::CString;
use std::io::Write;

/// Helper to convert a Rust string to CString, replacing null bytes with U+FFFD
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

/// Zlib compress function exported to Luau.
///
/// # Safety
/// This function is invoked by the Luau VM and assumes `l` is a valid `lua_State` pointer.
unsafe extern "C-unwind" fn lua_compress(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            lua_error_msg(l, "ZLib.compress error: expected at least 1 argument (data)");
        }

        let mut len: usize = 0;
        let data_ptr = lua_tolstring(l, 1, &mut len);
        if data_ptr.is_null() {
            lua_error_msg(l, "ZLib.compress error: argument 1 must be a string");
        }

        let data = std::slice::from_raw_parts(data_ptr as *const u8, len);

        // Optional compression level (argument 2)
        let level = if argc >= 2 && lua_type(l, 2) == LUA_TNUMBER {
            let n = lua_tonumber(l, 2);
            // clamp level between 0 and 9
            let lvl = n as u32;
            lvl.clamp(0, 9)
        } else {
            6 // default compression level
        };

        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::new(level));
        if let Err(e) = encoder.write_all(data) {
            lua_error_msg(l, &format!("ZLib.compress error: write failed: {}", e));
        }
        match encoder.finish() {
            Ok(compressed) => {
                lua_pushlstring(l, compressed.as_ptr() as *const i8, compressed.len());
                1
            }
            Err(e) => {
                lua_error_msg(l, &format!("ZLib.compress error: finish failed: {}", e));
            }
        }
    }
}

/// Zlib decompress function exported to Luau.
///
/// # Safety
/// This function is invoked by the Luau VM and assumes `l` is a valid `lua_State` pointer.
unsafe extern "C-unwind" fn lua_decompress(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            lua_error_msg(
                l,
                "ZLib.decompress error: expected at least 1 argument (compressed_data)",
            );
        }

        let mut len: usize = 0;
        let data_ptr = lua_tolstring(l, 1, &mut len);
        if data_ptr.is_null() {
            lua_error_msg(l, "ZLib.decompress error: argument 1 must be a string");
        }

        let data = std::slice::from_raw_parts(data_ptr as *const u8, len);

        let mut decoder = ZlibDecoder::new(Vec::new());
        if let Err(e) = decoder.write_all(data) {
            lua_error_msg(
                l,
                &format!("ZLib.decompress error: invalid or corrupted zlib data: {}", e),
            );
        }
        match decoder.finish() {
            Ok(decompressed) => {
                lua_pushlstring(l, decompressed.as_ptr() as *const i8, decompressed.len());
                1
            }
            Err(e) => {
                lua_error_msg(
                    l,
                    &format!(
                        "ZLib.decompress error: failed to complete decompression: {}",
                        e
                    ),
                );
            }
        }
    }
}

/// Entrypoint for the ZLib module.
///
/// # Safety
/// This function is called by the Luau VM and must only be invoked from a valid Lua state.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);
        lua_createtable(l, 0, 3);

        lua_pushcfunction(l, lua_compress);
        lua_setfield(l, -2, c"compress".as_ptr());

        lua_pushcfunction(l, lua_decompress);
        lua_setfield(l, -2, c"decompress".as_ptr());

        lua_pushstring(l, c"0.1.0".as_ptr());
        lua_setfield(l, -2, c"version".as_ptr());

        1
    }
}
