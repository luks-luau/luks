use luks_module_sys::*;

/// Entrypoint for native module loading.
///
/// # Safety
/// - `l` must be a valid Luau `lua_State*`.
/// - `api` must be a valid pointer to the host's `LuauAPI`.
#[no_mangle]
pub unsafe extern "C-unwind" fn luau_export(
    l: *mut lua_State,
    api: *const LuauAPI,
) -> std::os::raw::c_int {
    // Initializes the global VTable for this native module.
    init_api(api);

    // The wrapper code is now clean and transparent.
    lua_createtable(l, 0, 2);

    lua_pushcclosure(l, lua_hello, c"lua_hello".as_ptr(), 0);
    lua_setfield(l, -2, c"hello".as_ptr());

    lua_pushstring(l, c"1.0.0".as_ptr());
    lua_setfield(l, -2, c"version".as_ptr());

    1
}

unsafe extern "C-unwind" fn lua_hello(l: *mut lua_State) -> std::os::raw::c_int {
    lua_pushstring(l, c"Greetings from Rust!".as_ptr());
    1
}
