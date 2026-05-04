#![allow(unsafe_op_in_unsafe_fn)]

use mlua_sys::luau::*;
use std::ffi::{CStr, CString};
use std::ptr;

/// Helper to convert a Rust string to CString, replacing null bytes with U+FFFD
fn str_to_cstring(s: &str) -> CString {
    let sanitized = s.replace('\0', "\u{FFFD}");
    CString::new(sanitized).expect("Failed to create CString after sanitization")
}

/// Raise a Lua error with the given message. This will be catchable with pcall.
unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    unsafe {
        let cstr = str_to_cstring(msg);
        lua_pushstring(l, cstr.as_ptr());
        lua_error(l);
    }
}

/// Convert Lua value at index `idx` to serde_json::Value
unsafe fn lua_value_to_json(
    l: *mut lua_State,
    idx: i32,
    stack: &mut Vec<usize>,
) -> serde_json::Value {
    unsafe {
        let t = lua_type(l, idx);

        match t {
            LUA_TNIL => serde_json::Value::Null,
            LUA_TBOOLEAN => {
                let b = lua_toboolean(l, idx);
                serde_json::Value::Bool(b != 0)
            }
            LUA_TNUMBER => {
                let n = lua_tonumber(l, idx);
                // Handle NaN and Infinity - raise Lua error
                if n.is_nan() || n.is_infinite() {
                    lua_error_msg(l, "JSON encode error: cannot encode NaN or Infinity");
                }
                // Try to convert to i64 first, then f64
                if n.fract() == 0.0 && n >= i64::MIN as f64 && n <= i64::MAX as f64 {
                    serde_json::Value::Number(serde_json::Number::from(n as i64))
                } else {
                    serde_json::Value::Number(
                        serde_json::Number::from_f64(n).unwrap_or(serde_json::Number::from(0)),
                    )
                }
            }
            LUA_TSTRING => {
                let s = lua_tolstring(l, idx, ptr::null_mut());
                if s.is_null() {
                    serde_json::Value::Null
                } else {
                    let rust_str = CStr::from_ptr(s).to_string_lossy().into_owned();
                    serde_json::Value::String(rust_str)
                }
            }
            LUA_TTABLE => {
                let idx = lua_absindex(l, idx);
                // Get table pointer for cycle detection
                let table_ptr = lua_topointer(l, idx) as usize;
                // Check if we're already processing this table (cycle)
                if stack.contains(&table_ptr) {
                    lua_error_msg(l, "JSON encode error: circular reference detected");
                }
                // Add to stack
                stack.push(table_ptr);

                // Determine if array or object by checking keys
                let mut is_array = true;
                let mut max_index = 0;

                lua_pushnil(l);
                while lua_next(l, idx) != 0 {
                    let key_type = lua_type(l, -2);
                    if key_type == LUA_TNUMBER {
                        let key_num = lua_tonumber(l, -2);
                        if key_num.fract() == 0.0 && key_num >= 1.0 {
                            max_index = max_index.max(key_num as i32);
                        } else {
                            is_array = false;
                            lua_pop(l, 2); // pop value and key
                            break;
                        }
                    } else {
                        is_array = false;
                        lua_pop(l, 2); // pop value and key
                        break;
                    }
                    lua_pop(l, 1);
                }

                let result = if is_array && max_index > 0 {
                    // Array
                    let mut arr = Vec::new();
                    for i in 1..=max_index {
                        lua_rawgeti(l, idx, i as i64);
                        arr.push(lua_value_to_json(l, -1, stack));
                        lua_pop(l, 1);
                    }
                    serde_json::Value::Array(arr)
                } else {
                    // Object - handle both string and numeric keys
                    let mut obj = serde_json::Map::new();
                    lua_pushnil(l);
                    while lua_next(l, idx) != 0 {
                        let key_type = lua_type(l, -2);
                        let key = if key_type == LUA_TSTRING {
                            let key_str = lua_tolstring(l, -2, ptr::null_mut());
                            if key_str.is_null() {
                                lua_pop(l, 1);
                                continue;
                            }
                            CStr::from_ptr(key_str).to_string_lossy().into_owned()
                        } else if key_type == LUA_TNUMBER {
                            let key_num = lua_tonumber(l, -2);
                            format!("{}", key_num)
                        } else {
                            // Unsupported key type, skip
                            lua_pop(l, 1);
                            continue;
                        };
                        let value = lua_value_to_json(l, -1, stack);
                        obj.insert(key, value);
                        lua_pop(l, 1);
                    }
                    serde_json::Value::Object(obj)
                };

                // Remove from stack after processing
                stack.pop();
                result
            }
            _ => {
                lua_error_msg(l, &format!("JSON encode error: unsupported type {:?}", t));
            }
        }
    }
}

/// Push serde_json::Value to Lua stack
unsafe fn json_value_to_lua(l: *mut lua_State, value: &serde_json::Value) {
    unsafe {
        match value {
            serde_json::Value::Null => {
                lua_pushnil(l);
            }
            serde_json::Value::Bool(b) => {
                lua_pushboolean(l, if *b { 1 } else { 0 });
            }
            serde_json::Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    lua_pushnumber(l, i as f64);
                } else if let Some(f) = n.as_f64() {
                    lua_pushnumber(l, f);
                } else {
                    lua_pushnumber(l, 0.0);
                }
            }
            serde_json::Value::String(s) => {
                let cstr = str_to_cstring(s.as_str());
                lua_pushstring(l, cstr.as_ptr());
            }
            serde_json::Value::Array(arr) => {
                lua_createtable(l, 0, arr.len().max(1) as i32);
                let table_idx = lua_absindex(l, -1);
                for (i, v) in arr.iter().enumerate() {
                    lua_pushnumber(l, (i + 1) as f64);
                    json_value_to_lua(l, v);
                    lua_settable(l, table_idx);
                }
            }
            serde_json::Value::Object(obj) => {
                lua_createtable(l, 0, obj.len().max(1) as i32);
                let table_idx = lua_absindex(l, -1);
                for (k, v) in obj {
                    let key_cstr = str_to_cstring(k.as_str());
                    lua_pushstring(l, key_cstr.as_ptr());
                    json_value_to_lua(l, v);
                    lua_settable(l, table_idx);
                }
            }
        }
    }
}

/// Encode Lua value to JSON string
unsafe extern "C-unwind" fn lua_encode(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            lua_error_msg(l, "JSON encode error: expected at least 1 argument");
        }

        let mut stack = Vec::new();
        let value = lua_value_to_json(l, 1, &mut stack);
        match serde_json::to_string(&value) {
            Ok(json_str) => {
                let cstr = str_to_cstring(&json_str);
                lua_pushstring(l, cstr.as_ptr());
                1
            }
            Err(e) => {
                lua_error_msg(l, &format!("JSON encode error: {}", e));
            }
        }
    }
}

/// Decode JSON string to Lua value
unsafe extern "C-unwind" fn lua_decode(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            lua_error_msg(l, "JSON decode error: expected at least 1 argument");
        }

        let json_str = lua_tolstring(l, 1, ptr::null_mut());
        if json_str.is_null() {
            lua_error_msg(l, "JSON decode error: expected string argument");
        }

        let json_str = CStr::from_ptr(json_str).to_string_lossy().into_owned();
        match serde_json::from_str::<serde_json::Value>(&json_str) {
            Ok(value) => {
                json_value_to_lua(l, &value);
                1
            }
            Err(e) => {
                lua_error_msg(l, &format!("JSON decode error: {}", e));
            }
        }
    }
}

/// Entrypoint for the Json module.
///
/// # Safety
///
/// This function is called by the Luau VM and must only be invoked from a valid Lua state.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State) -> i32 {
    unsafe {
        lua_createtable(l, 0, 2);

        lua_pushcfunction(l, lua_encode);
        lua_setfield(l, -2, c"encode".as_ptr());

        lua_pushcfunction(l, lua_decode);
        lua_setfield(l, -2, c"decode".as_ptr());

        1
    }
}
