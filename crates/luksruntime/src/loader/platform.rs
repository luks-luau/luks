use crate::path_resolution::canonicalize_or_absolute;
use libloading::{Library, Symbol};
use std::path::Path;
use std::sync::Mutex;

/// Type of the `luau_export` entrypoint from loaded libraries.
pub type LuauExport =
    unsafe extern "C-unwind" fn(*mut mlua::ffi::lua_State, *const luks_module_sys::LuauAPI) -> i32;

/// The global VTable instance with pointers to the actual functions from `mlua_sys`.
pub static HOST_LUAU_API: luks_module_sys::LuauAPI = luks_module_sys::LuauAPI {
    lua_createtable: mlua_sys::luau::lua_createtable,
    lua_pushstring: wrap_lua_pushstring,
    lua_pushcfunction: wrap_lua_pushcfunction,
    lua_pushcclosurek: wrap_lua_pushcclosurek,
    lua_setfield: mlua_sys::luau::lua_setfield,
    lua_getfield: mlua_sys::luau::lua_getfield,
    lua_getglobal: wrap_lua_getglobal,
    lua_pushvalue: mlua_sys::luau::lua_pushvalue,
    lua_pushnil: mlua_sys::luau::lua_pushnil,
    lua_pushinteger: wrap_lua_pushinteger,
    lua_pushnumber: mlua_sys::luau::lua_pushnumber,
    lua_pushboolean: mlua_sys::luau::lua_pushboolean,
    lua_type: mlua_sys::luau::lua_type,
    lua_tostring: wrap_lua_tostring,
    lua_call: mlua_sys::luau::lua_call,

    lua_pushlstring: mlua_sys::luau::lua_pushlstring,
    lua_tolstring: mlua_sys::luau::lua_tolstring,
    lua_gettop: mlua_sys::luau::lua_gettop,
    lua_settop: mlua_sys::luau::lua_settop,
    lua_remove: mlua_sys::luau::lua_remove,
    lua_insert: mlua_sys::luau::lua_insert,
    lua_absindex: mlua_sys::luau::lua_absindex,
    lua_gettable: mlua_sys::luau::lua_gettable,
    lua_settable: mlua_sys::luau::lua_settable,
    lua_rawgeti: mlua_sys::luau::lua_rawgeti,
    lua_rawseti: mlua_sys::luau::lua_rawseti,
    lua_next: mlua_sys::luau::lua_next,
    lua_error: mlua_sys::luau::lua_error,
    lua_tonumberx: mlua_sys::luau::lua_tonumberx,
    lua_tointegerx: mlua_sys::luau::lua_tointegerx,
    lua_toboolean: mlua_sys::luau::lua_toboolean,
    lua_topointer: mlua_sys::luau::lua_topointer,

};

unsafe extern "C-unwind" fn wrap_lua_pushstring(
    l: *mut mlua_sys::luau::lua_State,
    s: *const std::os::raw::c_char,
) {
    mlua_sys::luau::lua_pushstring(l, s);
}

unsafe extern "C-unwind" fn wrap_lua_pushcfunction(
    l: *mut mlua_sys::luau::lua_State,
    f: mlua_sys::luau::lua_CFunction,
    name: *const std::os::raw::c_char,
) {
    mlua_sys::luau::lua_pushcclosurek(l, f, name, 0, None);
}

unsafe extern "C-unwind" fn wrap_lua_pushcclosurek(
    l: *mut mlua_sys::luau::lua_State,
    f: mlua_sys::luau::lua_CFunction,
    name: *const std::os::raw::c_char,
    nup: std::os::raw::c_int,
    cont: Option<
        unsafe extern "C-unwind" fn(
            *mut mlua_sys::luau::lua_State,
            std::os::raw::c_int,
        ) -> std::os::raw::c_int,
    >,
) {
    mlua_sys::luau::lua_pushcclosurek(l, f, name, nup, cont);
}

unsafe extern "C-unwind" fn wrap_lua_getglobal(
    l: *mut mlua_sys::luau::lua_State,
    name: *const std::os::raw::c_char,
) -> std::os::raw::c_int {
    mlua_sys::luau::lua_getglobal(l, name)
}

unsafe extern "C-unwind" fn wrap_lua_pushinteger(
    l: *mut mlua_sys::luau::lua_State,
    n: mlua_sys::luau::lua_Integer,
) {
    mlua_sys::luau::lua_pushinteger(l, n);
}

unsafe extern "C-unwind" fn wrap_lua_tostring(
    l: *mut mlua_sys::luau::lua_State,
    idx: std::os::raw::c_int,
) -> *const std::os::raw::c_char {
    mlua_sys::luau::lua_tostring(l, idx)
}

// Keep libraries alive for the process lifetime.
// The `luau_export` symbol must remain valid after lookup.
use std::sync::LazyLock;
static LOADED_LIBS: LazyLock<Mutex<Vec<(std::path::PathBuf, Library)>>> =
    LazyLock::new(|| Mutex::new(Vec::new()));

/// Loads a library and returns its `luau_export` symbol.
pub fn load_export(path: &Path) -> Result<LuauExport, String> {
    let key = canonicalize_or_absolute(path);

    let libs = LOADED_LIBS
        .lock()
        .map_err(|_| "failed to acquire lock on LOADED_LIBS".to_string())?;

    if let Some((_, lib)) = libs.iter().find(|(p, _)| *p == key) {
        let symbol: Symbol<LuauExport> = unsafe {
            lib.get(b"luau_export\0")
                .map_err(|e| format!("symbol 'luau_export' not found: {}", e))?
        };
        return Ok(*symbol);
    }
    drop(libs);

    let library = unsafe {
        Library::new(&key)
            .map_err(|e| format!("failed to load library '{}': {}", key.display(), e))?
    };

    let symbol: Symbol<LuauExport> = unsafe {
        library
            .get(b"luau_export\0")
            .map_err(|e| format!("symbol 'luau_export' not found: {}", e))?
    };

    let func: LuauExport = *symbol;

    let mut libs = LOADED_LIBS
        .lock()
        .map_err(|_| "failed to acquire lock on LOADED_LIBS".to_string())?;
    if let Some((_, lib)) = libs.iter().find(|(p, _)| *p == key) {
        let symbol: Symbol<LuauExport> = unsafe {
            lib.get(b"luau_export\0")
                .map_err(|e| format!("symbol 'luau_export' not found: {}", e))?
        };
        return Ok(*symbol);
    }

    libs.push((key, library));
    Ok(func)
}

pub fn clear_loaded_libs() -> Result<(), String> {
    let mut libs = LOADED_LIBS
        .lock()
        .map_err(|_| "failed to acquire lock on LOADED_LIBS".to_string())?;
    libs.clear();
    Ok(())
}
