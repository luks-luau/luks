# Stdio Module

Native Standard I/O module for Luau. Provides real-time interactive streaming interfaces allowing scripts to perform robust console formatting, synchronous blocking host inputs, non-blocking asynchronous user polling, and advanced bidirectional sub-process execution management.

The module bridges low-level system kernels natively to Luau via safe background threads and un-polled queues, ensuring smooth runtime execution alongside thread-safe multi-platform console access.

## Features

- **Chainable Text Formatting** — Output streams support direct method chaining to apply text coloring, visual ANSI flags, and dynamic template interpolation seamlessly
- **Dual-Mode Console Reads** — Choose between instantaneous host-blocking synchronous evaluation (`read()`) or event-driven asynchronous polling (`readAsync()`) mapped via native `Signal` pipelines
- **Piped Sub-Process Management** — Instantiate executables with non-blocking standard output, standard error, and exit status monitoring loops alongside secure standard input writing (`spawnStream`)
- **Diagnostic Error Filtering** — Dedicated standard error streaming outputs enabling clear diagnostics separated from primary operational channels
- **LSP Single-Source of Truth** — Complete statically checked API definitions driving built-in Hover Intellisense directly in developer editors

---

## API Reference

### Global Interfaces

#### `Stdio.stdout() → StdoutHandle`
Instantiates a handle mapping to the host operating system's standard output stream buffer.

#### `Stdio.stderr() → StderrHandle`
Instantiates a handle mapping to the host operating system's diagnostic error output stream.

#### `Stdio.stdin() → StdinHandle`
Instantiates an input interface reader monitoring standard console submissions.

#### `Stdio.prompt(prefix: string) → string`
Synchronously prints a bold, colored text prefix followed by an immediate blocking read of the user's string console submission.

#### `Stdio.promptAsync(prefix: string) → Signal<string>`
Prints a prefix non-blockingly and returns an asynchronous event dispatcher firing upon console submission.

#### `Stdio.spawnStream(program: string, args: {string}?, options: any?) → StreamedChild`
Spawns a target external program background process complete with active input/output event frame listeners.

---

### Handle Structures

#### `StdoutHandle`
Standard output writing frame equipped with chainable manipulation methods:
- **`write(text: string) → StdoutHandle`**: Writes raw text directly to standard output.
- **`writeLine(text: string) → StdoutHandle`**: Writes text appended with line termination.
- **`fmt(template: string, ...any) → StdoutHandle`**: Applies string template interpolation mapping.
- **`color(color: string) → StdoutHandle`**: Applies terminal rendering color tokens (`red`, `green`, `cyan`, `bold`, `reset`, etc.).
- **`flush() → ()`**: Forces native memory buffers to synchronize immediately to the operating system kernel.

#### `StderrHandle`
Diagnostic output writing frame supporting isolated logging:
- **`write(text: string) → StderrHandle`**: Writes raw string payload blocks to stderr.
- **`writeLine(text: string) → StderrHandle`**: Writes payload strings with line terminations.
- **`color(color: string) → StderrHandle`**: Applies visual formatting colors to error diagnostics.
- **`flush() → ()`**: Forces immediate synchronization of host diagnostic memory buffers.

#### `StdinHandle`
Console submission reading interface supporting dual paradigms:
- **`read() → string`**: Synchronously blocks the execution frame waiting for physical keyboard input, returning the submitted content buffer stripped of trailing carriage returns.
- **`readAsync() → Signal<string>`**: Activates a background listener queue non-blockingly, returning a pure Luau `Signal` that triggers upon submission.
- **`close() → ()`**: Gracefully stops asynchronous background standard input reader threads.

#### `StreamedChild`
Sub-process controller yielding real-time streams and security operations:
- **`onStdout: Signal<string>`**: Fires data blocks captured from the child's standard output stream.
- **`onStderr: Signal<string>`**: Fires diagnostic errors captured from the child's standard error stream.
- **`onExit: Signal<number>`**: Fires the exit status return code generated upon subprocess termination.
- **`writeStdin(data: string) → ()`**: Safely injects character string sequences into the active child input pipe.
- **`closeStdin() → ()`**: Emits an end-of-file (EOF) token closing the child's stdin stream.
- **`terminate() → ()`**: Sends immediate kernel termination signals to halt the child process.

---

### Properties

#### `Stdio.version: string`
The module's compiled dynamic library build version identifier.

---

## Usage Examples

### Synchronous Prompting and Chainable Output

```lua
local Stdio = require("path/to/Stdio")

-- Use direct method chaining to render complex visual console outputs
Stdio.stdout()
    :color("bold")
    :color("green")
    :write("Luks Console Initialized. ")
    :color("reset")
    :writeLine("Awaiting interactive operational flags.")
    :flush()

-- Synchronous blocking interface prompts naturally for inline assignment
local username = Stdio.prompt("Enter Operator Name: ")

Stdio.stdout()
    :fmt("Welcome back, %s!\n", username)
    :flush()
```

### Event-Driven Non-Blocking Interactive Capture

```lua
local Stdio = require("path/to/Stdio")

local input = Stdio.stdin()
local listener = input:readAsync()

print("Non-blocking background stream activated. Type 'exit' to quit.")

listener:Connect(function(line)
    if line == "exit" then
        print("Closing background listener loop gracefully.")
        input:close()
    else
        print("Captured asynchronous input entry:", line)
    end
end)
```

### Real-Time Subprocess Streaming

```lua
local Stdio = require("path/to/Stdio")

-- Spawn a multi-platform shell process capturing outputs non-blockingly
local child = Stdio.spawnStream("rustc", { "--version" })

child.onStdout:Connect(function(chunk)
    Stdio.stdout():color("cyan"):write("[Child Out] "):color("reset"):writeLine(chunk):flush()
end)

child.onStderr:Connect(function(chunk)
    Stdio.stderr():color("red"):write("[Child Err] "):color("reset"):writeLine(chunk):flush()
end)

child.onExit:Connect(function(code)
    print("Target compilation child exited with code:", code)
end)
```

---

## Building

```bash
cd luks-std/Stdio
cargo build --release
```

Output dynamic libraries paths:
- **Windows**: `target/release/stdio.dll`
- **Linux**: `target/release/libstdio.so`
- **macOS**: `target/release/libstdio.dylib`

---

## Dependencies

- **Rust standard structures**: `std::io::{self, BufRead, Write}`, `std::process::{Command, Stdio}`
- **Luau Interface**: Direct FFI mapping interface wrapped securely via `luks-module-sys`

## License

MIT License — see [LICENSE](../../LICENSE) file for comprehensive legal details.
