#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::CString;
use std::fs::{File, Metadata, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::PathBuf;
use std::time::UNIX_EPOCH;

// Structure to hold our file handle in userdata
struct LuauFile {
    file: File,
}

// Structure for directory iterator
struct LuauReadDir {
    iter: std::fs::ReadDir,
}

/// Helper to convert a Rust string to CString
fn str_to_cstring(s: &str) -> CString {
    let sanitized = s.replace('\0', "\u{FFFD}");
    CString::new(sanitized).expect("Failed to create CString")
}

unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    unsafe {
        let cstr = str_to_cstring(msg);
        lua_pushstring(l, cstr.as_ptr());
        lua_error(l);
    }
}

unsafe fn get_path_arg(l: *mut lua_State, idx: i32) -> PathBuf {
    unsafe {
        let mut len = 0;
        let ptr = lua_tolstring(l, idx, &mut len);
        if ptr.is_null() {
            lua_error_msg(l, "expected path string");
        }
        let bytes = std::slice::from_raw_parts(ptr as *const u8, len);
        let s = std::str::from_utf8(bytes).unwrap_or("");
        PathBuf::from(s)
    }
}

unsafe fn get_buffer_mut(l: *mut lua_State, idx: i32) -> Option<&'static mut [u8]> {
    let mut len = 0;
    let ptr = lua_tobuffer(l, idx, &mut len);
    if ptr.is_null() {
        None
    } else {
        Some(std::slice::from_raw_parts_mut(ptr as *mut u8, len))
    }
}

unsafe fn get_file_handle(l: *mut lua_State, idx: i32) -> *mut LuauFile {
    let ud_ptr = lua_touserdata(l, idx) as *mut *mut LuauFile;
    if ud_ptr.is_null() {
        lua_error_msg(l, "expected file handle, got nil");
    }
    let ud = *ud_ptr;
    if ud.is_null() {
        lua_error_msg(l, "file handle is closed");
    }
    ud
}

unsafe fn get_readdir_handle(l: *mut lua_State, idx: i32) -> *mut LuauReadDir {
    let ud_ptr = lua_touserdata(l, idx) as *mut *mut LuauReadDir;
    if ud_ptr.is_null() {
        lua_error_msg(l, "expected readdir handle, got nil");
    }
    let ud = *ud_ptr;
    if ud.is_null() {
        lua_error_msg(l, "readdir handle is closed");
    }
    ud
}

unsafe fn push_metadata(l: *mut lua_State, meta: &Metadata) {
    lua_createtable(l, 0, 8);

    lua_pushboolean(l, if meta.is_file() { 1 } else { 0 });
    lua_setfield(l, -2, c"is_file".as_ptr());

    lua_pushboolean(l, if meta.is_dir() { 1 } else { 0 });
    lua_setfield(l, -2, c"is_dir".as_ptr());

    lua_pushboolean(l, if meta.file_type().is_symlink() { 1 } else { 0 });
    lua_setfield(l, -2, c"is_symlink".as_ptr());

    lua_pushnumber(l, meta.len() as f64);
    lua_setfield(l, -2, c"len".as_ptr());

    let to_secs = |t: std::io::Result<std::time::SystemTime>| {
        t.ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs_f64())
            .unwrap_or(0.0)
    };

    lua_pushnumber(l, to_secs(meta.modified()));
    lua_setfield(l, -2, c"modified".as_ptr());

    lua_pushnumber(l, to_secs(meta.accessed()));
    lua_setfield(l, -2, c"accessed".as_ptr());

    lua_pushnumber(l, to_secs(meta.created()));
    lua_setfield(l, -2, c"created".as_ptr());

    lua_pushboolean(l, if meta.permissions().readonly() { 1 } else { 0 });
    lua_setfield(l, -2, c"readonly".as_ptr());
}

// --- FILE OPERATIONS ---

unsafe extern "C-unwind" fn fs_open(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    let mut opts = OpenOptions::new();
    if lua_istable(l, 2) != 0 {
        lua_getfield(l, 2, c"read".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            opts.read(true);
        }
        lua_pop(l, 1);
        lua_getfield(l, 2, c"write".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            opts.write(true);
        }
        lua_pop(l, 1);
        lua_getfield(l, 2, c"append".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            opts.append(true);
        }
        lua_pop(l, 1);
        lua_getfield(l, 2, c"truncate".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            opts.truncate(true);
        }
        lua_pop(l, 1);
        lua_getfield(l, 2, c"create".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            opts.create(true);
        }
        lua_pop(l, 1);
        lua_getfield(l, 2, c"create_new".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            opts.create_new(true);
        }
        lua_pop(l, 1);
    } else {
        opts.read(true);
    }

    match opts.open(&path) {
        Ok(file) => {
            let ud = lua_newuserdata(l, std::mem::size_of::<*mut LuauFile>());
            let boxed = Box::into_raw(Box::new(LuauFile { file }));
            *(ud as *mut *mut LuauFile) = boxed;

            lua_createtable(l, 0, 1);
            lua_pushcfunction(l, fs_file_gc);
            lua_setfield(l, -2, c"__gc".as_ptr());
            lua_setmetatable(l, -2);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_file_gc(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauFile;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn fs_read(l: *mut lua_State) -> i32 {
    let handle = &mut *get_file_handle(l, 1);
    let offset = lua_tointeger(l, 3) as usize;
    let len = lua_tointeger(l, 4) as usize;
    if let Some(buf) = get_buffer_mut(l, 2) {
        if offset + len > buf.len() {
            lua_error_msg(l, "buffer overflow");
        }
        match handle.file.read(&mut buf[offset..offset + len]) {
            Ok(n) => {
                lua_pushnumber(l, n as f64);
                1
            }
            Err(e) => {
                lua_error_msg(l, &format!("{}", e));
            }
        }
    } else {
        lua_error_msg(l, "expected buffer");
    }
}

unsafe extern "C-unwind" fn fs_write(l: *mut lua_State) -> i32 {
    let handle = &mut *get_file_handle(l, 1);
    let offset = lua_tointeger(l, 3) as usize;
    let write_len = lua_tointeger(l, 4) as usize;
    let data = if lua_isstring(l, 2) != 0 {
        let mut slen = 0;
        let ptr = lua_tolstring(l, 2, &mut slen);
        std::slice::from_raw_parts(ptr as *const u8, slen)
    } else if let Some(buf) = get_buffer_mut(l, 2) {
        buf
    } else {
        lua_error_msg(l, "expected buffer or string");
    };

    if offset + write_len > data.len() {
        lua_error_msg(l, "source overflow");
    }
    match handle.file.write(&data[offset..offset + write_len]) {
        Ok(n) => {
            lua_pushnumber(l, n as f64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_seek(l: *mut lua_State) -> i32 {
    let handle = &mut *get_file_handle(l, 1);
    let whence = lua_tonumber(l, 2) as i32;
    let pos = lua_tonumber(l, 3) as i64;
    let seek_from = match whence {
        0 => SeekFrom::Start(pos as u64),
        1 => SeekFrom::Current(pos),
        2 => SeekFrom::End(pos),
        _ => lua_error_msg(l, "invalid seek whence"),
    };
    match handle.file.seek(seek_from) {
        Ok(n) => {
            lua_pushnumber(l, n as f64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_sync(l: *mut lua_State) -> i32 {
    let handle = &mut *get_file_handle(l, 1);
    let data_only = if lua_gettop(l) >= 2 {
        lua_toboolean(l, 2) != 0
    } else {
        false
    };
    let res = if data_only {
        handle.file.sync_data()
    } else {
        handle.file.sync_all()
    };
    match res {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_set_len(l: *mut lua_State) -> i32 {
    let handle = &mut *get_file_handle(l, 1);
    let len = lua_tonumber(l, 2) as u64;
    match handle.file.set_len(len) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

// --- STATIC UTILITIES ---

unsafe extern "C-unwind" fn fs_remove_file(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    match std::fs::remove_file(path) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_rename(l: *mut lua_State) -> i32 {
    let from = get_path_arg(l, 1);
    let to = get_path_arg(l, 2);
    match std::fs::rename(from, to) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_copy(l: *mut lua_State) -> i32 {
    let from = get_path_arg(l, 1);
    let to = get_path_arg(l, 2);
    match std::fs::copy(from, to) {
        Ok(n) => {
            lua_pushnumber(l, n as f64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_metadata(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    let follow = if lua_gettop(l) >= 2 {
        lua_toboolean(l, 2) != 0
    } else {
        true
    };
    let res = if follow {
        std::fs::metadata(path)
    } else {
        std::fs::symlink_metadata(path)
    };
    match res {
        Ok(meta) => {
            push_metadata(l, &meta);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_canonicalize(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    match std::fs::canonicalize(path) {
        Ok(p) => {
            let s = p.to_string_lossy();
            lua_pushstring(l, str_to_cstring(&s).as_ptr());
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_read_dir(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    match std::fs::read_dir(path) {
        Ok(iter) => {
            let ud = lua_newuserdata(l, std::mem::size_of::<*mut LuauReadDir>());
            let boxed = Box::into_raw(Box::new(LuauReadDir { iter }));
            *(ud as *mut *mut LuauReadDir) = boxed;

            lua_createtable(l, 0, 1);
            lua_pushcfunction(l, fs_readdir_gc);
            lua_setfield(l, -2, c"__gc".as_ptr());
            lua_setmetatable(l, -2);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_readdir_gc(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauReadDir;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn fs_readdir_next(l: *mut lua_State) -> i32 {
    let handle = &mut *get_readdir_handle(l, 1);
    match handle.iter.next() {
        Some(Ok(entry)) => {
            lua_createtable(l, 0, 2);

            let name = entry.file_name().to_string_lossy().into_owned();
            lua_pushstring(l, str_to_cstring(&name).as_ptr());
            lua_setfield(l, -2, c"name".as_ptr());

            let path = entry.path().to_string_lossy().into_owned();
            lua_pushstring(l, str_to_cstring(&path).as_ptr());
            lua_setfield(l, -2, c"path".as_ptr());

            1
        }
        Some(Err(e)) => {
            lua_error_msg(l, &format!("{}", e));
        }
        None => {
            lua_pushnil(l);
            1
        }
    }
}

// --- DIRECTORY UTILS ---

unsafe extern "C-unwind" fn fs_create_dir(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    let all = if lua_gettop(l) >= 2 {
        lua_toboolean(l, 2) != 0
    } else {
        false
    };
    let res = if all {
        std::fs::create_dir_all(path)
    } else {
        std::fs::create_dir(path)
    };
    match res {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_remove_dir(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    let all = if lua_gettop(l) >= 2 {
        lua_toboolean(l, 2) != 0
    } else {
        false
    };
    let res = if all {
        std::fs::remove_dir_all(path)
    } else {
        std::fs::remove_dir(path)
    };
    match res {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

// --- LINKS ---

unsafe extern "C-unwind" fn fs_hard_link(l: *mut lua_State) -> i32 {
    let src = get_path_arg(l, 1);
    let dst = get_path_arg(l, 2);
    match std::fs::hard_link(src, dst) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
        }
    }
}

unsafe extern "C-unwind" fn fs_read_link(l: *mut lua_State) -> i32 {
    let path = get_path_arg(l, 1);
    match std::fs::read_link(path) {
        Ok(p) => {
            let s = p.to_string_lossy();
            lua_pushstring(l, str_to_cstring(&s).as_ptr());
            1
        }
        Err(e) => {
            lua_error_msg(l, &format!("{}", e));
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
        lua_createtable(l, 0, 15);

        lua_pushcfunction(l, fs_open);
        lua_setfield(l, -2, c"open".as_ptr());
        lua_pushcfunction(l, fs_read);
        lua_setfield(l, -2, c"read".as_ptr());
        lua_pushcfunction(l, fs_write);
        lua_setfield(l, -2, c"write".as_ptr());
        lua_pushcfunction(l, fs_seek);
        lua_setfield(l, -2, c"seek".as_ptr());
        lua_pushcfunction(l, fs_sync);
        lua_setfield(l, -2, c"sync".as_ptr());
        lua_pushcfunction(l, fs_set_len);
        lua_setfield(l, -2, c"set_len".as_ptr());

        lua_pushcfunction(l, fs_remove_file);
        lua_setfield(l, -2, c"remove_file".as_ptr());
        lua_pushcfunction(l, fs_rename);
        lua_setfield(l, -2, c"rename".as_ptr());
        lua_pushcfunction(l, fs_copy);
        lua_setfield(l, -2, c"copy".as_ptr());
        lua_pushcfunction(l, fs_metadata);
        lua_setfield(l, -2, c"metadata".as_ptr());
        lua_pushcfunction(l, fs_canonicalize);
        lua_setfield(l, -2, c"canonicalize".as_ptr());

        lua_pushcfunction(l, fs_read_dir);
        lua_setfield(l, -2, c"read_dir".as_ptr());
        lua_pushcfunction(l, fs_readdir_next);
        lua_setfield(l, -2, c"readdir_next".as_ptr());

        lua_pushcfunction(l, fs_create_dir);
        lua_setfield(l, -2, c"create_dir".as_ptr());
        lua_pushcfunction(l, fs_remove_dir);
        lua_setfield(l, -2, c"remove_dir".as_ptr());

        lua_pushcfunction(l, fs_hard_link);
        lua_setfield(l, -2, c"hard_link".as_ptr());
        lua_pushcfunction(l, fs_read_link);
        lua_setfield(l, -2, c"read_link".as_ptr());

        1
    }
}
