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
- **Static Analysis**: Verify type safety and detect lint warnings via native `lukschecker` (`lukscli check .`)
- **Custom `require()`**: Module system with caching and `@self/` path resolution
- **Native Module Loading**: Load dynamic libraries (`.dll`, `.so`, `.dylib`) that export `luau_export`
- **Async Task Scheduling**: Built-in `task` module with `spawn`, `defer`, `delay`, `cancel`, and `wait`
- **Permission System**: Granular control over file access, native loading, and module imports
- **Granular VM Directives**: Real-time evaluation parsing of `--!native` and `--!optimize` module optimizations

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

luks-luau loads dynamically compiled native plugins (`.dll`, `.so`, `.dylib`) at runtime via `dlopen()`.

#### The VTable Architecture (`luks-module-sys`)

> [!IMPORTANT]  
> **Architectural Shift:** Previously, plugins linked directly against local static copies of the Luau VM internals via `mlua-sys`. On operating systems like Windows, this resulted in independent memory allocators and separate garbage collection heaps between the Host executable and loaded DLLs, causing severe **Segmentation Faults** during async execution cycles.
> 
> To guarantee stable cross-platform FFI boundaries, luks-luau implements a strict **VTable-based Proxy Pattern** via the `luks-module-sys` crate. Native libraries no longer compile their own VM state; instead, the runtime dynamically injects a function pointer table (`LuauAPI`) directly into the module handshake.

```lua
-- Load a native module
local mylib = dlopen("./mylib")
print(mylib.hello())    -- "Greetings from Rust!"
print(mylib.version)    -- "1.0.0"
```

Creating a safe, highly-performant native module in Rust using our centralized proxy:

```rust
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
    // 1. Handshake: Initializes the shared host VTable for this module instance.
    init_api(api);

    // 2. Transparent Execution: All subsequent Luau C-API calls seamlessly route
    // through inline wrappers targeting the injected host pointers.
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

### Static Analysis (`lukschecker`)

luks-luau integrates a highly performant native analysis engine via the `lukschecker` module. You can statically verify standard definitions, global types, and lint codebases for deprecated API usage directly from the command line:

```bash
# Check all files in the current workspace
lukscli check .

# Or verify a targeted module path
lukscli check ./src/module.luau
```

#### Intelligent Build Caching
To optimize developer workflows across large codebases, `lukschecker` implements an **Intelligent Build Cache Engine** persistent in the native host temporary directory.
- **Content Hashing**: Computes absolute execution tree hash fingerprints across target files and their recursive `require()` dependency networks. Unchanged files skip validation entirely, resulting in near-instantaneous successive checks.
- **Path Invariance**: Employs low-level kernel canonicalization (`std::fs::canonicalize`) to maintain storage keys securely across all platforms (Windows, Linux, macOS, and Android), ensuring consistent cache hits regardless of command-line syntax formats (slashes, verbatim strings, or relative variations).
- **Safety**: Modules producing active compiler warnings or static validation failures are intentionally omitted from caching, forcing live terminal outputs on every run until resolved.

## Standard Library (`luks-std`)

The workspace hosts a collection of highly-optimized native extensions implemented in Rust under the `luks-std/` directory. These submodules link seamlessly into the runtime to bridge OS capabilities directly to Luau logic:

- **[`async`](https://github.com/luks-luau/luks/blob/main/luks-std/async/README.md)**: Foundational asynchronous primitives, signals, and Rust-style futures.
- **[`env`](https://github.com/luks-luau/luks/blob/main/luks-std/env/README.md)**: Access to process environment, CLI arguments, and host system information.
- **[`fs`](https://github.com/luks-luau/luks/blob/main/luks-std/fs/README.md)**: Native filesystem operations following Rust `std::fs` with full async support.
- **[`io`](https://github.com/luks-luau/luks/blob/main/luks-std/io/README.md)**: Rust-style asynchronous I/O primitives including `Reader`, `Writer`, and `BufRead` traits.
- **[`process`](https://github.com/luks-luau/luks/blob/main/luks-std/process/README.md)**: High-performance subprocess execution, environment mapping, and system telemetry.
- **[`net`](https://github.com/luks-luau/luks/blob/main/luks-std/net/README.md)**: Non-blocking TCP/UDP networking and socket abstractions.
- **[`signal`](https://github.com/luks-luau/luks/blob/main/luks-std/signal/README.md)**: Robust asynchronous event systems and callback dispatchers.
- **[`Http`](https://github.com/luks-luau/luks/blob/main/luks-std/Http/README.md)**: Non-blocking client requests powered by dynamic TLS integrations.
- **[`WebSocket`](https://github.com/luks-luau/luks/blob/main/luks-std/WebSocket/README.md)**: Full-duplex asynchronous communication protocol.
- **[`Json`](https://github.com/luks-luau/luks/blob/main/luks-std/Json/README.md)**: Ultra-fast structural encoding and decoding for Luau values.
- **[`ZLib`](https://github.com/luks-luau/luks/blob/main/luks-std/ZLib/README.md)**: Native payload compression and decompression utilities.
- **[`Crypto`](https://github.com/luks-luau/luks/blob/main/luks-std/Crypto/README.md)**: Secure hash algorithms and CSPRNG random generators.
- **[`Discord`](https://github.com/luks-luau/luks/blob/main/luks-std/Discord/README.md)**: Native API wrapper and real-time gateway integrations.
- **[`std-template`](https://github.com/luks-luau/luks/blob/main/luks-std/std-template/README.md)**: Contributor boilerplate for crafting reliable Luau FFI submodules.

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

# Check codebase for type and lint errors
lukscli check .

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