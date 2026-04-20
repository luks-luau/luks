use mlua_sys::luau::*;

#[no_mangle]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State) -> i32 {
    lua_createtable(l, 0, 2);

    lua_pushcfunction(l, lua_hello);
    lua_setfield(l, -2, c"hello".as_ptr());

    lua_pushstring(l, c"1.0.0".as_ptr());
    lua_setfield(l, -2, c"version".as_ptr());

    1
}

unsafe extern "C-unwind" fn lua_hello(l: *mut lua_State) -> i32 {
    lua_pushstring(l, c"Greetings from Rust!".as_ptr());
    1
}