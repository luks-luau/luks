# Process Module

The **Process** submodule implements a highly robust, multi-tier execution interface for the `luks-luau` environment. It enables native subprocess execution through both low-level explicit argument vectors and high-level platform shells, provides standard stream descriptor processing (`stdout`, `stderr`, `stdin`), inspects host processor telemetry, and controls runtime environmental variables synchronously and asynchronously.

## Features

- **Direct Subprocess Operations**: Invoke executable targets directly bypassing intermediate shell evaluation structures (`Process.spawn`).
- **Platform Shell Evaluation**: Wrap complex inline pipeline command logic automatically matching host operational kernels (`Process.exec`).
- **Standard Input Feeding**: Pass input payload buffers directly into child pipeline input channels via the `stdin` configuration parameter.
- **Environment Isolation**: Inherit host system context strings or enforce pure execution isolation layers using `env_clear`.
- **Hardware Telemetry**: Query active host hardware compilation architectures (`Process.arch`) and running OS kernels (`Process.os`).
- **Asynchronous Execution Loops**: Seamless background tasks powered by non-blocking event mechanisms (`Signal`) via `*Async` methods.

---

## Path Resolution Semantics

The `Process` module integrates context-aware caller-based path resolution for executable targets and working directory configurations, establishing complete parity with `FileSystem` and native `require()` mechanics.

### Spawning Resolution Rules

1. **System `PATH` Programs**: Pure/bare commands containing no directory separators (e.g., `"git"`, `"luks"`, `"cargo"`) are preserved exactly as provided. This ensures standard host operating system lookups traverse environmental `PATH` variables correctly.
2. **Context-Relative Targets**: Executable paths containing directory separators (`/` or `\`) or explicitly prefixed with `@self`, `./`, or `../` are automatically resolved relative to the physical file location of the script invoking the evaluation.
3. **Working Directory Overrides (`options.cwd`)**: If a custom working directory string is provided via `options.cwd`, it is fully resolved contextually relative to the invoking script directory prior to launch.

---

## API Reference

### Spawning Subprocesses

#### `Process.spawn(program: string, args: {string}?, options: ProcessOptions?): ProcessOutput`
Blocks the active Lua thread to execute the target application program binary directly.

```lua
local res = Process.spawn("git", { "--version" })
if res.ok then
    print("Installed version:", res.stdout)
end
```

#### `Process.exec(command: string, options: ProcessOptions?): ProcessOutput`
Evaluates string expressions using standard underlying system shells (`cmd.exe /C` on Windows, `/bin/sh -c` on Unix platforms).

```lua
-- Execute multi-part expressions
local res = Process.exec("echo Interactive Shell Binding && whoami")
print(res.status, res.stdout)
```

### Feeding Data into Standard Input

Inject pipeline structures programmatically via `stdin`:

```lua
local res = Process.spawn("cat", {}, {
    stdin = "Injected binary stream buffers matching pipe logic.",
})
print(res.stdout)
```

### Asynchronous Execution Variants

Non-blocking calls execute processes inside native thread spawn queues, firing asynchronous event handlers (`Signal`):

```lua
local signal = Process.spawnAsync("sleep", { "2" })
signal:Connect(function(out)
    print("Background execution finished with return code:", out.status)
end)
```

### Managing Environment & Telemetry

```lua
-- Inspect compilation environments
print("Host OS:", Process.os())
print("Host CPU Arch:", Process.arch())
print("Host PID:", Process.id())

-- Access runtime maps
Process.setEnv("LUKS_TARGET_MODE", "flexibility")
print(Process.getEnv("LUKS_TARGET_MODE"))

-- Extract complete state contexts
local maps = Process.getAllEnv()
for k, v in pairs(maps) do
    print(k, "->", v)
end
```
