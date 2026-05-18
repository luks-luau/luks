# FS Module

High-performance, strictly-typed asynchronous filesystem primitives for Luau inspired by the Rust `std::fs` ecosystem. This module provides a robust suite of tools for file manipulation, metadata querying, and directory management with full Rust authenticity.

## Features

- **Rust-Authentic Primitives** — Implements core `std::fs` components including `File`, `OpenOptions`, and `Metadata`.
- **Stream Integration** — `FS.File` fully implements `IO.Reader`, `IO.Writer`, and `IO.Seeker` traits.
- **Asynchronous First** — All filesystem operations are integrated with the `TaskFuture` system for non-blocking execution.
- **Builder Pattern** — Configure file opening precisely using the `OpenOptions` builder.
- **Strict Type Safety** — Comprehensive Luau type definitions ensure zero `any` usage and premium LSP support.
- **System Parity** — Direct mapping to Rust's high-level filesystem system calls for maximum reliability.

---

## API Reference

### `File` Object
The primary handle for an open file on the filesystem.

```luau
export type File = Reader & Writer & Seeker & {
    sync_all: (self: File) -> TaskFuture<()>,
    set_len: (self: File, size: number) -> TaskFuture<()>,
    metadata: (self: File) -> TaskFuture<Metadata>,
    close: (self: File) -> (),
}
```

### `OpenOptions` Builder
Used to configure how a file is opened.

```luau
local options = FS.OpenOptions.new()
    :read(true)
    :write(true)
    :create(true)
    :append(false)
    :truncate(true)

local file = options:open("path/to/file"):unwrap()
```

### Static Utilities

- **`FS.read_to_string(path)`** — Reads the entire file into a string.
- **`FS.write(path, contents)`** — Writes a string or buffer to a file.
- **`FS.copy(from, to)`** — Copies a file to another location.
- **`FS.rename(from, to)`** — Renames a file or directory.
- **`FS.remove_file(path)`** — Deletes a file.
- **`FS.metadata(path)`** — Queries information about a path.
- **`FS.create_dir_all(path)`** — Recursively creates directories.
- **`FS.resolve(path?)`** — Resolves a path relative to the caller's script location, similar to `require()`. Supports `@self` and `./`.

---

## Usage Examples

### Basic File Writing and Reading
```luau
local FS = require("./path/to/FS")

-- Write content to a file
FS.write("hello.txt", "Hello from Luks!"):expect("Failed to write")

-- Read it back
local content = FS.read_to_string("hello.txt"):expect("Failed to read")
print(content) -- "Hello from Luks!"
```

### Advanced File Manipulation with Seek
```luau
local FS = require("./path/to/FS")

local file = FS.File.create("data.bin"):unwrap()
file:write_all("ABCDEF"):Wait()

-- Seek to the 3rd byte and overwrite
file:seek({ kind = "Start", pos = 2 }):Wait()
file:write_all("XX"):Wait()
file:close()

print(FS.read_to_string("data.bin"):unwrap()) -- "ABXXEF"
```

### Directory Management
```luau
local FS = require("./path/to/FS")

FS.create_dir_all("logs/2026/05"):expect("Failed to create path")

local meta = FS.metadata("logs"):expect("Failed to get meta")
if meta.is_dir then
    print("Logs directory exists and has size:", meta.len)
end
```

### Script-Relative Path Resolution
```luau
local FS = require("./path/to/FS")

-- Get the absolute path to a resource relative to this script
local configPath = FS.resolve("./config.json")

-- Get the directory of the current module folder
local moduleDir = FS.resolve("@self")

-- Get the current script's directory
local scriptDir = FS.resolve()
```

---

## Implementation Details

The `FS` module leverages a dedicated native Rust crate (`luks_fs`) to provide true file descriptor management via `userdata`. This allows for efficient, incremental I/O that respects system-level file locks and permissions, while maintaining the safety and ergonomics of the Luau `TaskFuture` system.

---

## License

MIT License — see [LICENSE](LICENSE) file for details.
