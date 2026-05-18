# Env Module

Rust-inspired Environment and System Path management for Luau. This module provides a complete interface for interacting with process arguments, environment variables, and filesystem metadata with native performance.

## Features

- **Process Arguments** — Access CLI arguments via `Env.args()`.
- **Environment Management** — Get, set, and list environment variables with UTF-8 safety.
- **Directory Control** — Query and change the Current Working Directory (CWD).
- **System Metadata** — Retrieve paths to the current executable and system temporary folders.
- **Path Utilities** — Cross-platform path joining and splitting using native separators.
- **System Constants** — Access `Env.consts` for CPU architecture, OS family, and file extensions.

---

## API Reference

### Environment Variables

- **`Env.var(key: string) -> string?`**
  Fetches the value of an environment variable. Returns `nil` if not found.

- **`Env.vars() -> { [string]: string }`**
  Returns a dictionary containing all currently set environment variables.

- **`Env.setVar(key: string, value: string)`**
  Sets an environment variable for the current process and its children.

- **`Env.removeVar(key: string)`**
  Removes an environment variable from the current process.

### Process & System

- **`Env.args() -> { string }`**
  Returns an array of command-line arguments. Index 1 is typically the executable path.

- **`Env.currentDir() -> string?`**
  Returns the current working directory.

- **`Env.setCurrentDir(path: string) -> boolean`**
  Sets the current working directory. Returns `true` on success.

- **`Env.currentExe() -> string?`**
  Returns the full path to the currently running executable.

- **`Env.tempDir() -> string`**
  Returns the system's temporary directory path.

### Path Manipulation

- **`Env.joinPaths(paths: { string }) -> string?`**
  Joins an array of paths into a single string using the platform's path separator (`;` on Windows, `:` on Unix).

- **`Env.splitPaths(unparsed: string) -> { string }`**
  Splits a string (like `$PATH`) into an array of individual paths.

---

### `Env.consts` (Submodule)

Provides OS-level constants for platform-specific logic:

- `Env.consts.ARCH` — CPU Architecture (e.g., `"x86_64"`, `"aarch64"`)
- `Env.consts.OS` — Operating System (e.g., `"windows"`, `"linux"`)
- `Env.consts.FAMILY` — OS Family (`"windows"` or `"unix"`)
- `Env.consts.EXE_EXTENSION` — Extension for executables (`"exe"` or `""`)
- `Env.consts.DLL_EXTENSION` — Extension for dynamic libraries (`"dll"`, `"so"`, or `"dylib"`)

---

## Usage Example

```lua
local Env = require("path/to/env")

-- Get current OS
print("Running on:", Env.consts.OS)

-- Set and get an environment variable
Env.setVar("MY_APP_MODE", "development")
print("Mode:", Env.var("MY_APP_MODE"))

-- Iterate through all variables
for k, v in Env.vars() do
    if k:match("^LUKS_") then
        print(k, "=", v)
    end
end

-- Get temporary folder
print("Temp file path:", Env.joinPaths({Env.tempDir(), "log.txt"}))
```

## License

MIT License — see [LICENSE](LICENSE) file for details.
