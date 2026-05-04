use mlua_sys::luau::*;
use std::ffi::{CStr, CString};
use std::ptr;

/// Convert Lua value at index `idx` to serde_json::Value
unsafe fn lua_value_to_json(l: *mut lua_State, idx: i32) -> serde_json::Value {
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
                // Try to convert to i64 first, then f64
                if n.fract() == 0.0 && n >= i64::MIN as f64 && n <= i64::MAX as f64 {
                    serde_json::Value::Number(serde_json::Number::from(n as i64))
                } else {
                    serde_json::Value::Number(serde_json::Number::from_f64(n).unwrap_or(serde_json::Number::from(0)))
                }
            }
            LUA_TSTRING => {
                let s = lua_tolstring(l, idx, ptr::null_mut()) as *const i8;
                if s.is_null() {
                    serde_json::Value::Null
                } else {
                    let rust_str = CStr::from_ptr(s).to_string_lossy().into_owned();
                    serde_json::Value::String(rust_str)
                }
            }
            LUA_TTABLE => {
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
                            lua_pop(l, 1);
                            break;
                        }
                    } else {
                        is_array = false;
                        lua_pop(l, 1);
                        break;
                    }
                    lua_pop(l, 1);
                }
                
                if is_array && max_index > 0 {
                    // Array
                    let mut arr = Vec::new();
                    for i in 1..=max_index {
                        lua_rawgeti(l, idx, i as i64);
                        arr.push(lua_value_to_json(l, -1));
                        lua_pop(l, 1);
                    }
                    serde_json::Value::Array(arr)
                } else {
                    // Object
                    let mut obj = serde_json::Map::new();
                    lua_pushnil(l);
                    while lua_next(l, idx) != 0 {
                        let key_type = lua_type(l, -2);
                        if key_type == LUA_TSTRING {
                            let key_str = lua_tolstring(l, -2, ptr::null_mut()) as *const i8;
                            if !key_str.is_null() {
                                let key = CStr::from_ptr(key_str).to_string_lossy().into_owned();
                                let value = lua_value_to_json(l, -1);
                                obj.insert(key, value);
                            }
                        }
                        lua_pop(l, 1);
                    }
                    serde_json::Value::Object(obj)
                }
            }
            _ => serde_json::Value::Null,
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
                let cstr = CString::new(s.as_str()).unwrap();
                lua_pushstring(l, cstr.as_ptr());
            }
            serde_json::Value::Array(arr) => {
                lua_createtable(l, arr.len() as i32, 0);
                for (i, v) in arr.iter().enumerate() {
                    json_value_to_lua(l, v);
                    lua_rawseti(l, -2, (i + 1) as i64);
                }
            }
            serde_json::Value::Object(obj) => {
                lua_createtable(l, 0, obj.len() as i32);
                for (k, v) in obj {
                    let key_cstr = CString::new(k.as_str()).unwrap();
                    lua_pushstring(l, key_cstr.as_ptr());
                    json_value_to_lua(l, v);
                    lua_settable(l, -3);
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
            lua_pushnil(l);
            return 1;
        }
        
        let value = lua_value_to_json(l, 1);
        match serde_json::to_string(&value) {
            Ok(json_str) => {
                let cstr = CString::new(json_str).unwrap();
                lua_pushstring(l, cstr.as_ptr());
            }
            Err(e) => {
                let err_cstr = CString::new(format!("JSON encode error: {}", e)).unwrap();
                lua_pushstring(l, err_cstr.as_ptr());
            }
        }
        1
    }
}

/// Decode JSON string to Lua value
unsafe extern "C-unwind" fn lua_decode(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            lua_pushnil(l);
            return 1;
        }
        
        let json_str = lua_tolstring(l, 1, ptr::null_mut()) as *const i8;
        if json_str.is_null() {
            lua_pushnil(l);
            return 1;
        }
        
        let json_str = CStr::from_ptr(json_str).to_string_lossy().into_owned();
        match serde_json::from_str::<serde_json::Value>(&json_str) {
            Ok(value) => {
                json_value_to_lua(l, &value);
                1
            }
            Err(e) => {
                let err_cstr = CString::new(format!("JSON decode error: {}", e)).unwrap();
                lua_pushstring(l, err_cstr.as_ptr());
                1
            }
        }
    }
}

/// Entrypoint
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
