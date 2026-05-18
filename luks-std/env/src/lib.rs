#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::{CStr, CString};

/// Helper to push a string to the Lua stack
unsafe fn push_string(l: *mut lua_State, s: &str) {
    let c_str = CString::new(s).unwrap_or_default();
    lua_pushstring(l, c_str.as_ptr());
}

/// Helper to push an OsString/Path as a string
unsafe fn push_os_str(l: *mut lua_State, s: &std::ffi::OsStr) {
    push_string(l, &s.to_string_lossy());
}

/// std::env::args()
unsafe extern "C-unwind" fn lua_args(l: *mut lua_State) -> i32 {
    let args: Vec<String> = std::env::args().collect();
    lua_createtable(l, args.len() as i32, 0);
    for (i, arg) in args.iter().enumerate() {
        push_string(l, arg);
        lua_rawseti(l, -2, (i + 1) as i64);
    }
    1
}

/// std::env::var(key)
unsafe extern "C-unwind" fn lua_var(l: *mut lua_State) -> i32 {
    if lua_gettop(l) < 1 {
        return 0;
    }
    let key_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
    if key_ptr.is_null() {
        return 0;
    }
    let key = CStr::from_ptr(key_ptr).to_string_lossy();

    match std::env::var(key.as_ref()) {
        Ok(val) => {
            push_string(l, &val);
            1
        }
        Err(_) => 0,
    }
}

/// std::env::vars()
unsafe extern "C-unwind" fn lua_vars(l: *mut lua_State) -> i32 {
    lua_createtable(l, 0, 16);
    for (k, v) in std::env::vars() {
        let k_cstr = CString::new(k).unwrap_or_default();
        push_string(l, &v);
        lua_setfield(l, -2, k_cstr.as_ptr());
    }
    1
}

/// std::env::set_var(key, value)
unsafe extern "C-unwind" fn lua_set_var(l: *mut lua_State) -> i32 {
    if lua_gettop(l) < 2 {
        return 0;
    }
    let k_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
    let v_ptr = lua_tolstring(l, 2, std::ptr::null_mut());
    if !k_ptr.is_null() && !v_ptr.is_null() {
        let k = CStr::from_ptr(k_ptr).to_string_lossy();
        let v = CStr::from_ptr(v_ptr).to_string_lossy();
        std::env::set_var(k.as_ref(), v.as_ref());
    }
    0
}

/// std::env::remove_var(key)
unsafe extern "C-unwind" fn lua_remove_var(l: *mut lua_State) -> i32 {
    if lua_gettop(l) < 1 {
        return 0;
    }
    let k_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
    if !k_ptr.is_null() {
        let k = CStr::from_ptr(k_ptr).to_string_lossy();
        std::env::remove_var(k.as_ref());
    }
    0
}

/// std::env::current_dir()
unsafe extern "C-unwind" fn lua_current_dir(l: *mut lua_State) -> i32 {
    match std::env::current_dir() {
        Ok(p) => {
            push_os_str(l, p.as_os_str());
            1
        }
        Err(_) => 0,
    }
}

/// std::env::set_current_dir(path)
unsafe extern "C-unwind" fn lua_set_current_dir(l: *mut lua_State) -> i32 {
    if lua_gettop(l) < 1 {
        return 0;
    }
    let p_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
    if !p_ptr.is_null() {
        let p = CStr::from_ptr(p_ptr).to_string_lossy();
        let res = std::env::set_current_dir(p.as_ref()).is_ok();
        lua_pushboolean(l, if res { 1 } else { 0 });
        return 1;
    }
    0
}

/// std::env::current_exe()
unsafe extern "C-unwind" fn lua_current_exe(l: *mut lua_State) -> i32 {
    match std::env::current_exe() {
        Ok(p) => {
            push_os_str(l, p.as_os_str());
            1
        }
        Err(_) => 0,
    }
}

/// std::env::temp_dir()
unsafe extern "C-unwind" fn lua_temp_dir(l: *mut lua_State) -> i32 {
    let p = std::env::temp_dir();
    push_os_str(l, p.as_os_str());
    1
}

/// std::env::join_paths(iter)
unsafe extern "C-unwind" fn lua_join_paths(l: *mut lua_State) -> i32 {
    if lua_istable(l, 1) == 0 {
        return 0;
    }
    let mut paths = Vec::new();
    let len = lua_objlen(l, 1);
    for i in 1..=len {
        lua_rawgeti(l, 1, i as i64);
        if lua_isstring(l, -1) != 0 {
            let s_ptr = lua_tolstring(l, -1, std::ptr::null_mut());
            if !s_ptr.is_null() {
                let s = CStr::from_ptr(s_ptr).to_string_lossy().into_owned();
                paths.push(s);
            }
        }
        lua_pop(l, 1);
    }
    match std::env::join_paths(paths) {
        Ok(joined) => {
            push_os_str(l, &joined);
            1
        }
        Err(_) => 0,
    }
}

/// std::env::split_paths(string)
unsafe extern "C-unwind" fn lua_split_paths(l: *mut lua_State) -> i32 {
    if lua_isstring(l, 1) == 0 {
        return 0;
    }
    let s_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
    if s_ptr.is_null() {
        return 0;
    }
    let s = CStr::from_ptr(s_ptr).to_string_lossy();
    let paths: Vec<_> = std::env::split_paths(s.as_ref()).collect();

    lua_createtable(l, paths.len() as i32, 0);
    for (i, p) in paths.iter().enumerate() {
        push_os_str(l, p.as_os_str());
        lua_rawseti(l, -2, (i + 1) as i64);
    }
    1
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `api` must be a valid pointer to a `LuauAPI` struct.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);

        lua_createtable(l, 0, 15);

        // Functions
        lua_pushcfunction(l, lua_args);
        lua_setfield(l, -2, c"args".as_ptr());

        lua_pushcfunction(l, lua_var);
        lua_setfield(l, -2, c"var".as_ptr());

        lua_pushcfunction(l, lua_vars);
        lua_setfield(l, -2, c"vars".as_ptr());

        lua_pushcfunction(l, lua_set_var);
        lua_setfield(l, -2, c"set_var".as_ptr());

        lua_pushcfunction(l, lua_remove_var);
        lua_setfield(l, -2, c"remove_var".as_ptr());

        lua_pushcfunction(l, lua_current_dir);
        lua_setfield(l, -2, c"current_dir".as_ptr());

        lua_pushcfunction(l, lua_set_current_dir);
        lua_setfield(l, -2, c"set_current_dir".as_ptr());

        lua_pushcfunction(l, lua_current_exe);
        lua_setfield(l, -2, c"current_exe".as_ptr());

        lua_pushcfunction(l, lua_temp_dir);
        lua_setfield(l, -2, c"temp_dir".as_ptr());

        lua_pushcfunction(l, lua_join_paths);
        lua_setfield(l, -2, c"join_paths".as_ptr());

        lua_pushcfunction(l, lua_split_paths);
        lua_setfield(l, -2, c"split_paths".as_ptr());

        // Constants Subtable
        lua_createtable(l, 0, 7);

        push_string(l, std::env::consts::ARCH);
        lua_setfield(l, -2, c"ARCH".as_ptr());

        push_string(l, std::env::consts::OS);
        lua_setfield(l, -2, c"OS".as_ptr());

        push_string(l, std::env::consts::FAMILY);
        lua_setfield(l, -2, c"FAMILY".as_ptr());

        push_string(l, std::env::consts::EXE_EXTENSION);
        lua_setfield(l, -2, c"EXE_EXTENSION".as_ptr());

        push_string(l, std::env::consts::DLL_EXTENSION);
        lua_setfield(l, -2, c"DLL_EXTENSION".as_ptr());

        push_string(l, std::env::consts::DLL_PREFIX);
        lua_setfield(l, -2, c"DLL_PREFIX".as_ptr());

        push_string(l, std::env::consts::EXE_SUFFIX);
        lua_setfield(l, -2, c"EXE_SUFFIX".as_ptr());

        lua_setfield(l, -2, c"consts".as_ptr());

        1
    }
}
