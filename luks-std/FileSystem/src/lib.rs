#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::CString;
use std::path::Path;
use std::time::UNIX_EPOCH;

/// Helper to convert a Rust string to CString securely, sanitizing null bytes
fn str_to_cstring(s: &str) -> CString {
    let sanitized = s.replace('\0', "\u{FFFD}");
    CString::new(sanitized).expect("Failed to create CString")
}

/// Raise a Lua runtime error with standard string OS messages.
/// This function does not return.
unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    unsafe {
        let cstr = str_to_cstring(msg);
        lua_pushstring(l, cstr.as_ptr());
        lua_error(l);
    }
}

/// Extract path parameter safely from string slice pointer at index `idx`
unsafe fn get_path_arg<'a>(l: *mut lua_State, idx: i32, func_name: &str) -> &'a Path {
    unsafe {
        let mut len = 0;
        let ptr = lua_tolstring(l, idx, &mut len);
        if ptr.is_null() {
            lua_error_msg(
                l,
                &format!(
                    "{} error: expected path string at argument {}",
                    func_name, idx
                ),
            );
        }
        let bytes = std::slice::from_raw_parts(ptr as *const u8, len);
        let s = match std::str::from_utf8(bytes) {
            Ok(s) => s,
            Err(_) => lua_error_msg(l, &format!("{} error: path must be valid UTF-8", func_name)),
        };
        Path::new(s)
    }
}

unsafe extern "C-unwind" fn lua_read_file(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.readFile");
        match std::fs::read_to_string(path) {
            Ok(content) => {
                lua_pushlstring(l, content.as_ptr() as *const i8, content.len());
                1
            }
            Err(e) => lua_error_msg(l, &format!("FileSystem.readFile error: {}", e)),
        }
    }
}

unsafe extern "C-unwind" fn lua_write_file(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.writeFile");
        let mut len = 0;
        let ptr = lua_tolstring(l, 2, &mut len);
        if ptr.is_null() {
            lua_error_msg(
                l,
                "FileSystem.writeFile error: expected content string at argument 2",
            );
        }
        let content = std::slice::from_raw_parts(ptr as *const u8, len);
        if let Err(e) = std::fs::write(path, content) {
            lua_error_msg(l, &format!("FileSystem.writeFile error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_read_dir(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.readDir");
        let entries = match std::fs::read_dir(path) {
            Ok(iter) => iter,
            Err(e) => lua_error_msg(l, &format!("FileSystem.readDir error: {}", e)),
        };

        let mut names = Vec::new();
        for entry in entries {
            match entry {
                Ok(entry) => {
                    names.push(entry.file_name().to_string_lossy().into_owned());
                }
                Err(e) => {
                    lua_error_msg(l, &format!("FileSystem.readDir error reading entry: {}", e))
                }
            }
        }

        lua_createtable(l, names.len() as i32, 0);
        let table_idx = lua_absindex(l, -1);
        for (i, name) in names.iter().enumerate() {
            let cstr = str_to_cstring(name);
            lua_pushstring(l, cstr.as_ptr());
            lua_rawseti(l, table_idx, (i + 1) as i64);
        }
        1
    }
}

unsafe extern "C-unwind" fn lua_create_dir(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.createDir");
        if let Err(e) = std::fs::create_dir(path) {
            lua_error_msg(l, &format!("FileSystem.createDir error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_create_dir_all(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.createDirAll");
        if let Err(e) = std::fs::create_dir_all(path) {
            lua_error_msg(l, &format!("FileSystem.createDirAll error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_remove_file(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.removeFile");
        if let Err(e) = std::fs::remove_file(path) {
            lua_error_msg(l, &format!("FileSystem.removeFile error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_remove_dir(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.removeDir");
        if let Err(e) = std::fs::remove_dir(path) {
            lua_error_msg(l, &format!("FileSystem.removeDir error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_remove_dir_all(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.removeDirAll");
        if let Err(e) = std::fs::remove_dir_all(path) {
            lua_error_msg(l, &format!("FileSystem.removeDirAll error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_copy(l: *mut lua_State) -> i32 {
    unsafe {
        let from = get_path_arg(l, 1, "FileSystem.copy (from)");
        let to = get_path_arg(l, 2, "FileSystem.copy (to)");
        match std::fs::copy(from, to) {
            Ok(bytes) => {
                lua_pushnumber(l, bytes as f64);
                1
            }
            Err(e) => lua_error_msg(l, &format!("FileSystem.copy error: {}", e)),
        }
    }
}

unsafe extern "C-unwind" fn lua_rename(l: *mut lua_State) -> i32 {
    unsafe {
        let from = get_path_arg(l, 1, "FileSystem.rename (from)");
        let to = get_path_arg(l, 2, "FileSystem.rename (to)");
        if let Err(e) = std::fs::rename(from, to) {
            lua_error_msg(l, &format!("FileSystem.rename error: {}", e));
        }
        0
    }
}

unsafe extern "C-unwind" fn lua_metadata(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.metadata");
        let meta = match std::fs::metadata(path) {
            Ok(m) => m,
            Err(e) => lua_error_msg(l, &format!("FileSystem.metadata error: {}", e)),
        };

        lua_createtable(l, 0, 8);

        lua_pushboolean(l, if meta.is_file() { 1 } else { 0 });
        lua_setfield(l, -2, c"is_file".as_ptr());

        lua_pushboolean(l, if meta.is_dir() { 1 } else { 0 });
        lua_setfield(l, -2, c"is_dir".as_ptr());

        lua_pushboolean(l, if meta.file_type().is_symlink() { 1 } else { 0 });
        lua_setfield(l, -2, c"is_symlink".as_ptr());

        lua_pushnumber(l, meta.len() as f64);
        lua_setfield(l, -2, c"size".as_ptr());

        let modified = meta
            .modified()
            .map(|t| {
                t.duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs_f64())
                    .unwrap_or(0.0)
            })
            .unwrap_or(0.0);
        lua_pushnumber(l, modified);
        lua_setfield(l, -2, c"modified".as_ptr());

        let created = meta
            .created()
            .map(|t| {
                t.duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs_f64())
                    .unwrap_or(0.0)
            })
            .unwrap_or(0.0);
        lua_pushnumber(l, created);
        lua_setfield(l, -2, c"created".as_ptr());

        let accessed = meta
            .accessed()
            .map(|t| {
                t.duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs_f64())
                    .unwrap_or(0.0)
            })
            .unwrap_or(0.0);
        lua_pushnumber(l, accessed);
        lua_setfield(l, -2, c"accessed".as_ptr());

        lua_pushboolean(l, if meta.permissions().readonly() { 1 } else { 0 });
        lua_setfield(l, -2, c"readonly".as_ptr());

        1
    }
}

unsafe extern "C-unwind" fn lua_exists(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.exists");
        lua_pushboolean(l, if path.exists() { 1 } else { 0 });
        1
    }
}

unsafe extern "C-unwind" fn lua_is_file(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.isFile");
        lua_pushboolean(l, if path.is_file() { 1 } else { 0 });
        1
    }
}

unsafe extern "C-unwind" fn lua_is_dir(l: *mut lua_State) -> i32 {
    unsafe {
        let path = get_path_arg(l, 1, "FileSystem.isDir");
        lua_pushboolean(l, if path.is_dir() { 1 } else { 0 });
        1
    }
}

/// Entrypoint for native library exported symbol loading.
///
/// # Safety
/// Assumes `l` is a valid `lua_State` pointer initialized by Luau VM.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);
        lua_createtable(l, 0, 15);

        lua_pushstring(l, c"0.1.0".as_ptr());
        lua_setfield(l, -2, c"version".as_ptr());

        lua_pushcfunction(l, lua_read_file);
        lua_setfield(l, -2, c"readFile".as_ptr());

        lua_pushcfunction(l, lua_write_file);
        lua_setfield(l, -2, c"writeFile".as_ptr());

        lua_pushcfunction(l, lua_read_dir);
        lua_setfield(l, -2, c"readDir".as_ptr());

        lua_pushcfunction(l, lua_create_dir);
        lua_setfield(l, -2, c"createDir".as_ptr());

        lua_pushcfunction(l, lua_create_dir_all);
        lua_setfield(l, -2, c"createDirAll".as_ptr());

        lua_pushcfunction(l, lua_remove_file);
        lua_setfield(l, -2, c"removeFile".as_ptr());

        lua_pushcfunction(l, lua_remove_dir);
        lua_setfield(l, -2, c"removeDir".as_ptr());

        lua_pushcfunction(l, lua_remove_dir_all);
        lua_setfield(l, -2, c"removeDirAll".as_ptr());

        lua_pushcfunction(l, lua_copy);
        lua_setfield(l, -2, c"copy".as_ptr());

        lua_pushcfunction(l, lua_rename);
        lua_setfield(l, -2, c"rename".as_ptr());

        lua_pushcfunction(l, lua_metadata);
        lua_setfield(l, -2, c"metadata".as_ptr());

        lua_pushcfunction(l, lua_exists);
        lua_setfield(l, -2, c"exists".as_ptr());

        lua_pushcfunction(l, lua_is_file);
        lua_setfield(l, -2, c"isFile".as_ptr());

        lua_pushcfunction(l, lua_is_dir);
        lua_setfield(l, -2, c"isDir".as_ptr());

        1
    }
}
