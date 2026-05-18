# luks-module-sys

Low-level bindings and VM FFI bridge utilities for creating native modules for the [Luks](https://github.com/luks-luau/luks) modular runtime.

`luks-module-sys` provides raw access to the Luau VM VTable and C API function pointers exposed dynamically by the Luks host during runtime module loading (`dlopen`).

---

## Features

- **Luau VM Re-exports**: Directly re-exports `mlua-sys` under `luau` for low-level VM structures and types.
- **Dynamic VTable (API)**: Employs a global, thread-safe dynamic VTable `API: *const LuauAPI` dynamically injected when the module is loaded.
- **Low-level Luau wrappers**: Safe inline proxies (`lua_isnumber`, `lua_tointeger`, `lua_newuserdata`, `lua_newbuffer`, etc.) mapped to the injected VTable.

---

## How to Build a Native Luks Module

To write a dynamic library (`.dll` / `.so` / `.dylib`) that can be loaded in Luks via `dlopen`, you simply expose an `extern "C"` initialization function that takes the `LuauAPI` VTable and returns your module interface.

### 1. `Cargo.toml` Setup

Configure your library crate to produce a dynamic library:

```toml
[package]
name = "my-luks-module"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
luks-module-sys = { version = "0.1.0" }
```

### 2. Rust Implementation (`src/lib.rs`)

```rust
use luks_module_sys::{lua_State, LuauAPI, init_api, lua_createtable, lua_pushstring, lua_setfield};

/// The entrypoint that Luks calls via dlopen.
#[no_mangle]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    // 1. Initialize the global Luau C API VTable
    init_api(api);

    // 2. Create the module return table
    lua_createtable(l, 0, 1);

    // 3. Add functions or constants to the module table
    lua_pushstring(l, c"Hello from Luks Native Module!".as_ptr());
    lua_setfield(l, -2, c"greeting".as_ptr());

    // 4. Return 1 telling the VM we returned a single table on the stack
    1
}
```

---

## Official Links

- **Luks Main Repository**: [github.com/luks-luau/luks](https://github.com/luks-luau/luks)
- **Modular Runtime Crates**: [github.com/luks-luau/luks/tree/main/crates](https://github.com/luks-luau/luks/tree/main/crates)
