# luks-luau

A lightweight Luau runtime written in Rust with native module loading and async task scheduling capabilities.

![CI](https://github.com/luks-luau/luks/actions/workflows/ci.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Rust](https://img.shields.io/badge/rust-1.70%2B-orange.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS%20%7C%20Android-blue.svg)

## Overview

luks-luau is a high-performance Luau runtime designed for general-purpose scripting. It allows you to execute Luau scripts, load native modules dynamically, and write async code using the built-in task scheduler.

### Key Features

- **Script Execution**: Run Luau scripts via CLI (`lukscli run script.luau`)
- **Custom `require()`**: Module system with caching and `@self/` path resolution
- **Native Module Loading**: Load dynamic libraries (`.dll`, `.so`, `.dylib`) that export `luau_export`
- **Async Task Scheduling**: Built-in `task` module with `spawn`, `defer`, `delay`, `cancel`, and `wait`
- **Permission System**: Granular control over file access, native loading, and module imports

## Quick Examples

### Running a Script

```bash
# Build the project
cargo build --release

# Run a Luau script
./target/release/lukscli run myscript.luau
```

### Using require()

```lua
-- main.luau
local mymodule = require("./mymodule")
print(mymodule.hello())
```

### Loading Native Modules

luks-luau can load native modules that export a `luau_export` function. These modules receive direct access to the Luau VM:

```lua
-- Load a native module (only modules with luau_export entrypoint)
local mylib = dlopen("./mylib")
print(mylib.hello())  -- "Greetings from Rust!"
print(mylib.version)    -- "1.0.0"
```

Creating a native module in Rust:

```rust
use mlua_sys::luau::*;

#[no_mangle]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State) -> i32 {
    // Create a new table to return
    lua_createtable(l, 0, 2);

    // Add a function
    lua_pushcfunction(l, lua_hello);
    lua_setfield(l, -2, c"hello".as_ptr());

    // Add a version string
    lua_pushstring(l, c"1.0.0".as_ptr());
    lua_setfield(l, -2, c"version".as_ptr());

    // Return the table (already on stack)
    1
}

unsafe extern "C-unwind" fn lua_hello(l: *mut lua_State) -> i32 {
    lua_pushstring(l, c"Greetings from Rust!".as_ptr());
    1
}
```

### Using the task Module

The `task` module provides async/await-like functionality:

```lua
-- Spawn a new task
task.spawn(function()
    print("Hello from async task!")
    task.wait(1)  -- Wait 1 second
    print("Done after 1 second")
end)

-- Defer execution (runs after current thread yields)
task.defer(function()
    print("This runs after yield")
end)

-- Delay a function call
task.delay(2, function()
    print("This runs after 2 seconds")
end)

-- task.wait() works in main thread too!
print("Main thread waiting...")
task.wait(0.5)
print("Done waiting in main thread")
```

## Building

```bash
# Clone the repository
git clone https://github.com/luks-luau/luks.git
cd luks

# Build in debug mode
cargo build

# Build in release mode (optimized)
cargo build --release
```

## CLI Usage

```bash
# Run a script
lukscli run script.luau

# Evaluate a string
lukscli eval "print('Hello from Luau!')"

# Start interactive REPL
lukscli repl

# With permission flags
lukscli --no-native run script.luau      # Deny native module loading
lukscli --no-read run script.luau       # Deny file reading
lukscli --strict run script.luau        # Deny-by-default mode
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Acknowledgments

- [mlua](https://github.com/mlua-rs/mlua) - Lua/Luau bindings for Rust
- [Luau](https://luau.org/) - Fast, small, safe, gradually typed embeddable scripting language
- [mlua-luau-scheduler](https://github.com/lune-org/mlua-luau-scheduler) - Async scheduler for Luau