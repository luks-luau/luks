export type table = { [string]: any }
export type DynamicLibrary = any? | unknown? | number? | boolean? | string? | buffer? | thread? | table? 

--[=[
 * Loads a dynamic library

 * A dynamic library must export a luau_export(lua_State* L) function and can also operate directly with this lua_State using the lua.h from luau
 * Suports dll/dylib/so formats by default and detects the format automatically based on the platform
---
# Native Example in [Rust lang](https://www.rust-lang.org/) using [crate mlua-sys](https://crates.io/crates/mlua-sys)

```rust
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
```
---
# Example in [Luau](https://luau.org/) using luks-luau runtime
```lua
  local lib = dlopen("path/to/library")
  
  print(lib.hello()) -- "Greetings from Rust!"
  print(lib.version) -- "1.0.0"
  ```
---
 * **param** `path` The path to the dynamic library
 * **return** The exports of the dynamic library
]=]
export type dlopen = (path: string) -> DynamicLibrary

declare dlopen: dlopen

