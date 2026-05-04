# std-template

A template for creating Luau native standard libraries using Rust. This template provides the basic structure for building native modules that can be loaded dynamically via `dlopen` in Luau.

## Overview

This template demonstrates how to create a native library that exports functionality to Luau. The key component is the `luau_export` function, which serves as the entry point when the library is loaded.

## How It Works

### The `luau_export` Function

When creating a native module for Luau, you must export a function named `luau_export`. This function:

- Receives a `*mut lua_State` pointer (the Luau VM state) when loaded via `dlopen`
- Returns an integer indicating the number of values pushed onto the Lua stack
- Typically returns a table containing the module's functions and values

```rust
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State) -> i32 {
    unsafe {
        // Create and return a table with module functions
        lua_createtable(l, 0, 2);
        // ... push functions and values
        1 // Return 1 to indicate one value (the table) was pushed
    }
}
```

### Native Module Structure

The Rust library must be compiled as a `cdylib` (dynamic library) so it can be loaded at runtime:

```toml
[lib]
crate-type = ["cdylib"]
```

### Loading in Luau

The `init.luau` file demonstrates how to load and use the native module:

```lua
local native = dlopen("@self/lib/native") -- Load the native library
local version = native.version -- Access exported values
local result = native.hello() -- Call exported functions
```

## Luau Module Wrapper (`init.luau`)

The `init.luau` file is the entry point for Luau when the module is required. It is not just a simple wrapper for the native library, but also provides intellisense support and reexports all native functionality with proper typing:

### Safe Native Loading
It includes a `SafeLoadNative` helper to load the native `cdylib` with fallback paths (release build, debug build, local lib directory) to ensure compatibility across different development and production environments.

### Intellisense & LSP Support
`init.luau` acts as the intellisense provider for the module, compatible with Luau LSP tools like HoverLSP. It achieves this by:
- Adding explicit type annotations (e.g., `:: string` type casts, function return types) for all exported members
- Including JSDoc-style documentation comments (e.g., `@return`, descriptions) that LSP tools use to display hover information and context

### Full API Reexport with Typing
All functionality exported by the native `luau_export` function is reexported via a typed `Module` table, ensuring the full API surface is exposed with proper Luau types. Example from the template:
```lua
--[[
    @return A native version in string
]]
Module.version = native.version :: string

--[[
    receiving hello from native
    @return A string
]]
function Module.hello() : string
    return native.hello()
end
```

## Getting Started

1. Rename the library in `Cargo.toml` to your desired module name
2. Implement your functionality in `src/lib.rs`
3. Export functions using the `luau_export` entry point
4. Build with `cargo build --release`
5. Load and use in your Luau scripts via `dlopen`

## Dependencies

- `mlua-sys` with the `luau` feature enabled for Luau VM FFI bindings
