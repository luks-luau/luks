# FileSystem Module

Native FileSystem standard module for Luau. Provides direct, low-level access to host storage manipulation, allowing Luau scripts to read, write, inspect, and manage files and directory structures robustly.

The module re-exports Rust's highly optimized `std::fs` operations, guaranteeing that internal host operating system faults cross safely over FFI boundaries as explicit, catchable Luau runtime errors.

## Features

- **Direct Storage Manipulation** — Synchronous and asynchronous reading/writing of complete string buffer contents
- **Directory Operations** — Retrieve child file names, instantiate deep hierarchical paths (`createDirAll`), and cleanly prune entities
- **Entity Management** — Rename physical host storage allocations and replicate payload contents (`copy`) across paths
- **Granular Metadata Inspection** — Access kernel byte size allocations, read-only permissions, structural classifications, and precision epoch floating timestamps
- **Non-Blocking Background Interfaces** — Comprehensive suite of non-blocking `*Async` methods mapping operations to background queues via `task.defer` paired with event-driven `Signal` pipelines
- **Type Safety** — Exhaustive static Luau API typing bindings complete with inline LSP Hover Intellisense integration

---

## Path Resolution Semantics

The `FileSystem` module integrates a sophisticated context-aware path resolution engine providing complete architectural parity with the native `require()` and `dlopen()` mechanisms. Rather than operating relative to the terminal's arbitrary Current Working Directory (CWD), path arguments are autonomously resolved relative to the physical location of the script file invoking the operation.

### Resolution Rules

1. **Absolute Paths**: Strings prefixed with absolute indicators (`/`, `\`, or Windows drive letters like `C:\`) bypass caller resolution and target host storage directly.
2. **Standard File Modules** (e.g., `tests/cases/script.luau`):
   - Relative paths, explicit prefixes (`./`, `../`), and **bare implicit names** (e.g., `"data.txt"`) resolve directly from the folder containing the invoking script file.
   - The `@self` directive points to the invoking script's directory.
3. **Package Initialization Modules** (`init.luau` or `init.lua`):
   - **`@self` Directive**: Maps directly to the **module folder** itself (the folder where `init.luau` resides). For example, within `luks-std/FileSystem/init.luau`, `@self` targets `luks-std/FileSystem`.
   - **Dual-Base Relative Parity**: Explicit relative paths (`./`, `../`) and **bare implicit names** (e.g., `"test"`) behave identically, targeting the **parent directory** of the module folder. For example, within `luks-std/FileSystem/init.luau`, both `"./Process"` and `"Process"` resolve contextually to `luks-std/Process`.

---

## API Reference

### Synchronous Operations

> **Note:** Error-prone synchronous operations trigger standard Luau exceptions upon failure. Wrap critical operations inside `pcall` structures to capture faults safely.

#### `FileSystem.readFile(path: string) → string`
Reads the complete contents of a target path into a UTF-8 string buffer. Raises an exception if the path does not resolve or blocks read permissions.

#### `FileSystem.writeFile(path: string, contents: string)`
Overwrites or instantiates a designated target file saving the provided string contents payload.

#### `FileSystem.readDir(path: string) → { string }`
Collects string identifiers corresponding to individual files and subdirectories located directly inside the designated folder path.

#### `FileSystem.createDir(path: string)`
Instantiates an empty folder path target directly. Fails if intermediate parent paths are absent.

#### `FileSystem.createDirAll(path: string)`
Recursively instantiates a directory structure along with all absent parent prefixes.

#### `FileSystem.removeFile(path: string)`
Destroys a designated host file node directly.

#### `FileSystem.removeDir(path: string)`
Removes an isolated folder target provided it contains absolutely no child entities.

#### `FileSystem.removeDirAll(path: string)`
Recursively deletes a folder hierarchy completely scrubbing all nested subdirectories and files.

#### `FileSystem.copy(from: string, to: string) → number`
Replicates the payload bytes of a source file entity into a destination path. Returns the total byte count successfully transferred.

#### `FileSystem.rename(from: string, to: string)`
Modifies the physical identification mapping path of an existing host node.

#### `FileSystem.metadata(path: string) → FileMetadata`
Inspects host kernel attributes of a given storage frame. Returns a typed table detailing attributes:
```lua
type FileMetadata = {
    is_file: boolean,
    is_dir: boolean,
    is_symlink: boolean,
    size: number,
    created: number,
    modified: number,
    accessed: number,
    readonly: boolean,
}
```

#### `FileSystem.exists(path: string) → boolean`
Verifies if a designated target path exists in the physical host storage. Safe evaluation without throwing exceptions.

#### `FileSystem.isFile(path: string) → boolean`
Confirms if the target location specifically maps to a regular file payload.

#### `FileSystem.isDir(path: string) → boolean`
Confirms if the target location specifically maps to a directory structure.

---

### Asynchronous Operations

Non-blocking calls evaluate filesystem requests in the background, firing results asynchronously over dedicated event interfaces.

All asynchronous equivalents return a `Signal` instance yielding an `AsyncFsResult<T>` structure:
```lua
type AsyncFsResult<T> = {
    ok: boolean,
    result: T?,
    error: string?,
}
```

#### `FileSystem.readFileAsync(path: string) → Signal<AsyncFsResult<string>>`
#### `FileSystem.writeFileAsync(path: string, contents: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.readDirAsync(path: string) → Signal<AsyncFsResult<{string}>>`
#### `FileSystem.createDirAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.createDirAllAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.removeFileAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.removeDirAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.removeDirAllAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.copyAsync(from: string, to: string) → Signal<AsyncFsResult<number>>`
#### `FileSystem.renameAsync(from: string, to: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.metadataAsync(path: string) → Signal<AsyncFsResult<FileMetadata>>`
#### `FileSystem.existsAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.isFileAsync(path: string) → Signal<AsyncFsResult<boolean>>`
#### `FileSystem.isDirAsync(path: string) → Signal<AsyncFsResult<boolean>>`

---

### Properties

#### `FileSystem.version: string`
The runtime dynamic module compilation version string.

---

## Usage Examples

### Synchronous Reading and Writing

```lua
local FileSystem = require("path/to/FileSystem")

local configPath = "settings.json"
local defaultPayload = '{"theme": "dark", "version": 2}'

-- Ensure configuration exists safely
if not FileSystem.exists(configPath) then
    FileSystem.writeFile(configPath, defaultPayload)
    print("Created standard configurations.")
end

-- Read contents wrapping inside pcall boundaries
local success, content = pcall(FileSystem.readFile, configPath)
if success then
    print("Configuration buffer restored:", content)
else
    print("Fault captured reading storage payload.")
end
```

### Navigating Hierarchies and Metadata Inspection

```lua
local FileSystem = require("path/to/FileSystem")

local folder = "logs/runtime"
FileSystem.createDirAll(folder)

-- Write temporary operational buffers
FileSystem.writeFile(folder .. "/trace.log", "Execution boundaries established.")

local meta = FileSystem.metadata(folder .. "/trace.log")
print("Payload bytes size:", meta.size)
print("Entity Readonly constraint:", meta.readonly)

-- Inspect subdirectories
local list = FileSystem.readDir(folder)
for index, name in ipairs(list) do
    print(index, "-> Entry discovered:", name)
end

-- Cleanup structures cleanly
FileSystem.removeDirAll("logs")
```

### Event-Driven Asynchronous Non-Blocking Stream

```lua
local FileSystem = require("path/to/FileSystem")

local path = "async_payload.txt"

-- Initiate non-blocking buffer persistence
local writeStream = FileSystem.writeFileAsync(path, "Background IO Operations executing cleanly.")

writeStream:Connect(function(res)
    if res.ok then
        print("Background storage write finished successfully.")
        
        -- Chain subsequent async reads safely
        local readStream = FileSystem.readFileAsync(path)
        readStream:Connect(function(out)
            print("Background state contents restored:", out.result)
            FileSystem.removeFile(path)
        end)
    else
        print("Background evaluation intercepted fault:", res.error)
    end
end)
```

---

## Building

```bash
cd luks-std/FileSystem
cargo build --release
```

Output execution binary paths:
- **Windows**: `target/release/fs.dll`
- **Linux**: `target/release/libfs.so`
- **macOS**: `target/release/libfs.dylib`

---

## Dependencies

- **Rust core standard library**: `std::fs`, `std::path::Path`, `std::ffi::CString`
- **Luau Interface**: Direct FFI unrolled structure mapping via `luks-module-sys`

## License

MIT License — see [LICENSE](../../LICENSE) file for details.
