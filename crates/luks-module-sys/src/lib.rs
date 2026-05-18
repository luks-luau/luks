pub use mlua_sys::luau::*;
use std::os::raw::{c_char, c_int};

/// Function pointer table for the Luau C API.
#[repr(C)]
pub struct LuauAPI {
    pub lua_createtable: unsafe extern "C-unwind" fn(*mut lua_State, c_int, c_int),
    pub lua_pushstring: unsafe extern "C-unwind" fn(*mut lua_State, *const c_char),
    pub lua_pushcfunction:
        unsafe extern "C-unwind" fn(*mut lua_State, lua_CFunction, *const c_char),
    pub lua_pushcclosurek: unsafe extern "C-unwind" fn(
        *mut lua_State,
        lua_CFunction,
        *const c_char,
        c_int,
        Option<unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int>,
    ),
    pub lua_setfield: unsafe extern "C-unwind" fn(*mut lua_State, c_int, *const c_char),
    pub lua_getfield: unsafe extern "C-unwind" fn(*mut lua_State, c_int, *const c_char) -> c_int,
    pub lua_getglobal: unsafe extern "C-unwind" fn(*mut lua_State, *const c_char) -> c_int,
    pub lua_pushvalue: unsafe extern "C-unwind" fn(*mut lua_State, c_int),
    pub lua_pushnil: unsafe extern "C-unwind" fn(*mut lua_State),
    pub lua_pushinteger: unsafe extern "C-unwind" fn(*mut lua_State, lua_Integer),
    pub lua_pushnumber: unsafe extern "C-unwind" fn(*mut lua_State, f64),
    pub lua_pushboolean: unsafe extern "C-unwind" fn(*mut lua_State, c_int),
    pub lua_type: unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int,
    pub lua_tostring: unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> *const c_char,
    pub lua_call: unsafe extern "C-unwind" fn(*mut lua_State, c_int, c_int),

    pub lua_pushlstring: unsafe fn(*mut lua_State, *const c_char, usize) -> *const c_char,
    pub lua_tolstring:
        unsafe extern "C-unwind" fn(*mut lua_State, c_int, *mut usize) -> *const c_char,
    pub lua_gettop: unsafe extern "C-unwind" fn(*mut lua_State) -> c_int,
    pub lua_settop: unsafe extern "C-unwind" fn(*mut lua_State, c_int),
    pub lua_remove: unsafe extern "C-unwind" fn(*mut lua_State, c_int),
    pub lua_insert: unsafe extern "C-unwind" fn(*mut lua_State, c_int),
    pub lua_absindex: unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int,
    pub lua_gettable: unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int,
    pub lua_settable: unsafe extern "C-unwind" fn(*mut lua_State, c_int),
    pub lua_rawgeti: unsafe fn(*mut lua_State, c_int, i64) -> c_int,
    pub lua_rawseti: unsafe fn(*mut lua_State, c_int, i64),
    pub lua_next: unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int,
    pub lua_error: unsafe extern "C-unwind" fn(*mut lua_State) -> !,
    pub lua_tonumberx: unsafe extern "C-unwind" fn(*mut lua_State, c_int, *mut c_int) -> f64,
    pub lua_tointegerx: unsafe fn(*mut lua_State, c_int, *mut c_int) -> i64,
    pub lua_toboolean: unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int,
    pub lua_topointer:
        unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> *const std::ffi::c_void,
    pub lua_newuserdata:
        unsafe extern "C-unwind" fn(*mut lua_State, usize) -> *mut std::ffi::c_void,
    pub lua_tobuffer:
        unsafe extern "C-unwind" fn(*mut lua_State, c_int, *mut usize) -> *mut std::ffi::c_void,
    pub lua_newbuffer: unsafe extern "C-unwind" fn(*mut lua_State, usize) -> *mut std::ffi::c_void,
    pub lua_pushlightuserdata: unsafe extern "C-unwind" fn(*mut lua_State, *mut std::ffi::c_void),
}

static mut API: *const LuauAPI = std::ptr::null();

/// Initializes the global VTable for this native module.
/// The entrypoint must call this before using the API.
///
/// # Safety
/// The provided `api` pointer must be a valid reference to a `LuauAPI` structure
/// outliving the execution of this module.
pub unsafe fn init_api(api: *const LuauAPI) {
    API = api;
}

// Clean and direct wrappers for use in plugins:

/// Creates a new table and pushes it onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_createtable(l: *mut lua_State, narray: c_int, nrec: c_int) {
    ((*API).lua_createtable)(l, narray, nrec)
}

/// Pushes a null-terminated string onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `s` must be a valid pointer to a null-terminated C string.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushstring(l: *mut lua_State, s: *const c_char) {
    ((*API).lua_pushstring)(l, s)
}

/// Pushes a C function onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushcfunction(l: *mut lua_State, f: lua_CFunction) {
    ((*API).lua_pushcfunction)(l, f, std::ptr::null())
}

/// Pushes a C closure onto the stack with upvalues.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `debugname` must be null or a valid pointer to a null-terminated C string.
/// - The caller must have pushed exactly `nup` upvalues onto the stack.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushcclosure(
    l: *mut lua_State,
    f: lua_CFunction,
    debugname: *const c_char,
    nup: c_int,
) {
    ((*API).lua_pushcclosurek)(l, f, debugname, nup, None)
}

/// Pushes a C closure onto the stack with upvalues and a continuation function.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `debugname` must be null or a valid pointer to a null-terminated C string.
/// - The caller must have pushed exactly `nup` upvalues onto the stack.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushcclosurek(
    l: *mut lua_State,
    f: lua_CFunction,
    debugname: *const c_char,
    nup: c_int,
    cont: Option<unsafe extern "C-unwind" fn(*mut lua_State, c_int) -> c_int>,
) {
    ((*API).lua_pushcclosurek)(l, f, debugname, nup, cont)
}

/// Sets the field `k` of the table at index `idx` to the value at the top of the stack, popping the value.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `k` must be a valid pointer to a null-terminated C string.
/// - The value at `idx` must be a valid table.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_setfield(l: *mut lua_State, idx: c_int, k: *const c_char) {
    ((*API).lua_setfield)(l, idx, k)
}

/// Pushes onto the stack the value of the field `k` of the table at index `idx`.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `k` must be a valid pointer to a null-terminated C string.
/// - The value at `idx` must be a valid table.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_getfield(l: *mut lua_State, idx: c_int, k: *const c_char) -> c_int {
    ((*API).lua_getfield)(l, idx, k)
}

/// Pushes onto the stack the value of the global `name`.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `name` must be a valid pointer to a null-terminated C string.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_getglobal(l: *mut lua_State, name: *const c_char) -> c_int {
    ((*API).lua_getglobal)(l, name)
}

/// Pushes a copy of the element at the given valid index onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `idx` must be a valid stack index.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushvalue(l: *mut lua_State, idx: c_int) {
    ((*API).lua_pushvalue)(l, idx)
}

/// Pushes a nil value onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushnil(l: *mut lua_State) {
    ((*API).lua_pushnil)(l)
}

/// Pushes an integer onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushinteger(l: *mut lua_State, n: lua_Integer) {
    ((*API).lua_pushinteger)(l, n)
}

/// Pushes a float/double number onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushnumber(l: *mut lua_State, n: f64) {
    ((*API).lua_pushnumber)(l, n)
}

/// Pushes a boolean value onto the stack.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushboolean(l: *mut lua_State, b: c_int) {
    ((*API).lua_pushboolean)(l, b)
}

/// Returns the type of the value in the given acceptable index.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_type(l: *mut lua_State, idx: c_int) -> c_int {
    ((*API).lua_type)(l, idx)
}

/// Converts the Lua value at the given index to a C string.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `idx` must be a valid stack index containing a string or number.
/// - The returned pointer remains valid only as long as the corresponding string value remains on the stack and is not modified.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tostring(l: *mut lua_State, idx: c_int) -> *const c_char {
    ((*API).lua_tostring)(l, idx)
}

/// Calls a function on the stack with `nargs` arguments and expects `nresults` results.
///
/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The callable object and its `nargs` arguments must be pushed onto the stack in order.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_call(l: *mut lua_State, nargs: c_int, nresults: c_int) {
    ((*API).lua_call)(l, nargs, nresults)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushlstring(l: *mut lua_State, s: *const c_char, len: usize) -> *const c_char {
    ((*API).lua_pushlstring)(l, s, len)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tolstring(l: *mut lua_State, idx: c_int, len: *mut usize) -> *const c_char {
    ((*API).lua_tolstring)(l, idx, len)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_gettop(l: *mut lua_State) -> c_int {
    ((*API).lua_gettop)(l)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_settop(l: *mut lua_State, idx: c_int) {
    ((*API).lua_settop)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_remove(l: *mut lua_State, idx: c_int) {
    ((*API).lua_remove)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_insert(l: *mut lua_State, idx: c_int) {
    ((*API).lua_insert)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_absindex(l: *mut lua_State, idx: c_int) -> c_int {
    ((*API).lua_absindex)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_gettable(l: *mut lua_State, idx: c_int) -> c_int {
    ((*API).lua_gettable)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_settable(l: *mut lua_State, idx: c_int) {
    ((*API).lua_settable)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_rawgeti(l: *mut lua_State, idx: c_int, n: i64) -> c_int {
    ((*API).lua_rawgeti)(l, idx, n)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_rawseti(l: *mut lua_State, idx: c_int, n: i64) {
    ((*API).lua_rawseti)(l, idx, n)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_next(l: *mut lua_State, idx: c_int) -> c_int {
    ((*API).lua_next)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_error(l: *mut lua_State) -> ! {
    ((*API).lua_error)(l)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tonumberx(l: *mut lua_State, idx: c_int, isnum: *mut c_int) -> f64 {
    ((*API).lua_tonumberx)(l, idx, isnum)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tointegerx(l: *mut lua_State, idx: c_int, isnum: *mut c_int) -> i64 {
    ((*API).lua_tointegerx)(l, idx, isnum)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_toboolean(l: *mut lua_State, idx: c_int) -> c_int {
    ((*API).lua_toboolean)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_topointer(l: *mut lua_State, idx: c_int) -> *const std::ffi::c_void {
    ((*API).lua_topointer)(l, idx)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pop(l: *mut lua_State, n: c_int) {
    lua_settop(l, -(n) - 1)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_isnumber(l: *mut lua_State, idx: c_int) -> c_int {
    if lua_type(l, idx) == LUA_TNUMBER {
        1
    } else {
        0
    }
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_isstring(l: *mut lua_State, idx: c_int) -> c_int {
    if lua_type(l, idx) == LUA_TSTRING {
        1
    } else {
        0
    }
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_istable(l: *mut lua_State, idx: c_int) -> c_int {
    if lua_type(l, idx) == LUA_TTABLE {
        1
    } else {
        0
    }
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_isfunction(l: *mut lua_State, idx: c_int) -> c_int {
    if lua_type(l, idx) == LUA_TFUNCTION {
        1
    } else {
        0
    }
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_isnil(l: *mut lua_State, idx: c_int) -> c_int {
    if lua_type(l, idx) == LUA_TNIL {
        1
    } else {
        0
    }
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tonumber(l: *mut lua_State, idx: c_int) -> f64 {
    lua_tonumberx(l, idx, std::ptr::null_mut())
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tointeger(l: *mut lua_State, idx: c_int) -> i64 {
    lua_tointegerx(l, idx, std::ptr::null_mut())
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_newuserdata(l: *mut lua_State, size: usize) -> *mut std::ffi::c_void {
    ((*API).lua_newuserdata)(l, size)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_tobuffer(
    l: *mut lua_State,
    idx: c_int,
    len: *mut usize,
) -> *mut std::ffi::c_void {
    ((*API).lua_tobuffer)(l, idx, len)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_newbuffer(l: *mut lua_State, size: usize) -> *mut std::ffi::c_void {
    ((*API).lua_newbuffer)(l, size)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_pushlightuserdata(l: *mut lua_State, p: *mut std::ffi::c_void) {
    ((*API).lua_pushlightuserdata)(l, p)
}

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - The global `API` VTable must have been initialized via `init_api`.
#[inline(always)]
pub unsafe fn lua_touserdata(l: *mut lua_State, idx: c_int) -> *mut std::ffi::c_void {
    lua_topointer(l, idx) as *mut std::ffi::c_void
}
