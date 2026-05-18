# @luks/process

Production-grade asynchronous process management module for Luau, mirroring Rust's `std::process`.

## Features

- **Asynchronous Execution**: Spawn and manage subprocesses without blocking the Luau thread.
- **Command Builder**: Fluent API for configuring program arguments, environment variables, and working directories.
- **Streaming I/O**: Non-blocking `stdin`, `stdout`, and `stderr` pipes compatible with `IO.Reader` and `IO.Writer`.
- **Lifecycle Management**: Explicit process killing, waiting, and exit status inspection.
- **Resource Safety**: Handle-based architecture with explicit cleanup.

## Installation

Add to your project via `luks` package manager (internal):
```bash
luks add luks-std/Process
```

## Basic Usage

### Spawning a Process
```luau
local Process = require("luks-std/Process")

local cmd = Process.Command.new("echo")
    :arg("Hello Luks!")

local child = cmd:spawn():expect("Failed to spawn")
local status = child:wait():expect("Wait failed")

print("Exit Code:", status:code())
child:close()
```

### Capturing Output (Piping)
```luau
local Process = require("luks-std/Process")

local child = Process.Command.new("cmd.exe")
    :args({"/C", "echo Line 1 && echo Line 2"})
    :stdout(Process.Stdio.piped())
    :spawn()
    :expect("Spawn failed")

local stdout = child.stdout
local buf = buffer.create(1024)

while true do
    local n, ok = stdout:read(buf):Wait()
    if not ok or n == 0 then break end
    print(buffer.readstring(buf, 0, n))
end

child:wait():Wait()
child:close()
```

### Piping Stdin
```luau
local Process = require("luks-std/Process")

local child = Process.Command.new("sort")
    :stdin(Process.Stdio.piped())
    :stdout(Process.Stdio.piped())
    :spawn()
    :expect("Spawn failed")

child.stdin:write("Zebra\nApple\nBanana"):Wait()
child.stdin:close() -- Signal EOF to sort

local result = ""
local buf = buffer.create(1024)
while true do
    local n, ok = child.stdout:read(buf):Wait()
    if not ok or n == 0 then break end
    result ..= buffer.readstring(buf, 0, n)
end

print("Sorted output:", result)
child:close()
```

## API Reference

### `Process`
- `Command`: The command builder module.
- `Child`: The child process module.
- `ExitStatus`: The exit status module.
- `Stdio`: Stdio configuration constants.
- `id() -> number`: Returns the current process ID.
- `exit(code: number?)`: Exits the current process.
- `abort()`: Aborts the current process immediately.

### `Command`
- `new(program: string) -> Command`: Creates a new command.
- `arg(arg: string) -> Command`: Adds an argument.
- `args(args: {string}) -> Command`: Adds multiple arguments.
- `cwd(path: string) -> Command`: Sets working directory.
- `env(key: string, value: string) -> Command`: Sets an environment variable.
- `env_clear() -> Command`: Clears all environment variables.
- `stdin(cfg: StdioConfig) -> Command`: Sets stdin configuration.
- `stdout(cfg: StdioConfig) -> Command`: Sets stdout configuration.
- `stderr(cfg: StdioConfig) -> Command`: Sets stderr configuration.
- `spawn() -> TaskFuture<Child>`: Spawns the process.

### `Child`
- `id: number`: Process ID.
- `stdin: ChildStdin?`: Stdin pipe.
- `stdout: ChildStdout?`: Stdout pipe.
- `stderr: ChildStderr?`: Stderr pipe.
- `wait() -> TaskFuture<ExitStatus>`: Waits for process to exit.
- `try_wait() -> TaskFuture<ExitStatus?>`: Non-blocking check for exit.
- `kill() -> TaskFuture<any>`: Kills the process.
- `close()`: Closes handles and cleans up.

## License
MIT
