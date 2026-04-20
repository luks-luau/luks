use mlua::{Lua, Compiler}; // <- tirei StdLib
use mlua::ffi as ffi;
use std::ffi::{CStr, CString};
use std::ptr;

pub mod require;
pub mod utils;
pub mod loader;

#[repr(C)]
pub struct LuksRuntime {
    lua: Lua,
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_new() -> *mut LuksRuntime {
    let lua = Lua::unsafe_new();

    if let Err(e) = require::init_require(&lua) {
        eprintln!("init_require falhou: {}", e);
        return ptr::null_mut();
    }

    // precisa dizer que o retorno é ()
    let _: mlua::Result<()> = lua.exec_raw((), |l| {
        ffi::lua_pushcfunction(l, loader::lua_dlopen);
        ffi::lua_setglobal(l, CString::new("dlopen").unwrap().as_ptr());
    });

    let compiler = Compiler::new()
        .set_optimization_level(1)
        .set_debug_level(1);
    let _ = lua.set_compiler(compiler);

    Box::into_raw(Box::new(LuksRuntime { lua }))
}
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_execute(
    rt: *mut LuksRuntime,
    source: *const i8,
    chunk_name: *const i8,
) -> *mut i8 {
    if rt.is_null() || source.is_null() {
        return CString::new("runtime ou source nulo").unwrap().into_raw();
    }
    let rt = &mut *rt;
    let src = CStr::from_ptr(source).to_str().unwrap_or("");
    let name = if chunk_name.is_null() {
        "luks_chunk"
    } else {
        CStr::from_ptr(chunk_name).to_str().unwrap_or("luks_chunk")
    };

    match rt.lua.load(src).set_name(name).exec() {
        Ok(_) => ptr::null_mut(),
        Err(e) => CString::new(format!("runtime error: {}", e))
            .unwrap_or_else(|_| CString::new("erro").unwrap())
            .into_raw(),
    }
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_free_error(err: *mut i8) {
    if !err.is_null() {
        drop(CString::from_raw(err));
    }
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_destroy(rt: *mut LuksRuntime) {
    if !rt.is_null() {
        drop(Box::from_raw(rt));
    }
}