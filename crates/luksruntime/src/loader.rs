// src/loader.rs
use mlua::ffi as ffi;
use std::ffi::{CStr, CString};
use std::path::{Path, PathBuf};

type LuauExport = unsafe extern "C-unwind" fn(*mut ffi::lua_State) -> i32;

// API única
fn load_export(path: &Path) -> Result<LuauExport, String> {
    platform::open(path)
}

// --- Windows ---
#[cfg(windows)]
mod platform {
    use super::*;
    use std::os::raw::c_void;

    extern "system" {
        fn LoadLibraryA(lpLibFileName: *const i8) -> isize;
        fn GetProcAddress(hModule: isize, lpProcName: *const i8) -> *const c_void;
    }

    pub fn open(path: &Path) -> Result<LuauExport, String> {
        let c_path = CString::new(path.to_string_lossy().as_bytes())
            .map_err(|_| "caminho inválido".to_string())?;
        let handle = unsafe { LoadLibraryA(c_path.as_ptr()) };
        if handle == 0 {
            return Err(format!("LoadLibrary falhou: {}", path.display()));
        }
        let sym = CString::new("luau_export").unwrap();
        let addr = unsafe { GetProcAddress(handle, sym.as_ptr()) };
        if addr.is_null() {
            return Err("luau_export não encontrado".into());
        }
        Ok(unsafe { std::mem::transmute(addr) })
    }
}

// --- Unix (Linux, macOS, Android/Termux) ---
#[cfg(unix)]
mod platform {
    use super::*;
    use std::os::raw::{c_char, c_int, c_void};

    const RTLD_NOW: c_int = 2;

    extern "C" {
        fn dlopen(filename: *const c_char, flags: c_int) -> *mut c_void;
        fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
        fn dlerror() -> *const c_char;
    }

    pub fn open(path: &Path) -> Result<LuauExport, String> {
        let c_path = CString::new(path.to_string_lossy().as_bytes())
            .map_err(|_| "caminho inválido".to_string())?;
        let handle = unsafe { dlopen(c_path.as_ptr(), RTLD_NOW) };
        if handle.is_null() {
            let err = unsafe { dlerror() };
            let msg = if err.is_null() {
                "desconhecido".into()
            } else {
                unsafe { CStr::from_ptr(err).to_string_lossy().into_owned() }
            };
            return Err(format!("dlopen: {}", msg));
        }
        let sym = CString::new("luau_export").unwrap();
        let addr = unsafe { dlsym(handle, sym.as_ptr()) };
        if addr.is_null() {
            return Err("luau_export não encontrado".into());
        }
        Ok(unsafe { std::mem::transmute(addr) })
    }
}

// --- função exposta pro Lua ---
#[no_mangle]
pub unsafe extern "C-unwind" fn lua_dlopen(l: *mut ffi::lua_State) -> i32 {
    let arg = CStr::from_ptr(ffi::luaL_checkstring(l, 1)).to_string_lossy();
    let base = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    
    let mut path = if let Some(rest) = arg.strip_prefix("@self/") {
        base.join(rest)
    } else {
        PathBuf::from(arg.as_ref())
    };

    // adiciona extensão correta automaticamente
    if path.extension().is_none() {
        path.set_extension(std::env::consts::DLL_EXTENSION);
    }

    match load_export(&path) {
        Ok(export) => export(l),
        Err(e) => {
            ffi::lua_pushboolean(l, 0);
            ffi::lua_pushstring(l, CString::new(e).unwrap_or_default().as_ptr());
            2
        }
    }
}