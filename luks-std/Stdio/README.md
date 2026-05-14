# Stdio Standard Module (`luks-std/Stdio`)

The `Stdio` standard library package provides real-time evented standard streaming abstraction interfaces for the Luks Luau runtime.

## Core Capabilities

- **Isolated Handler Factories**: Exports standard global constructors (`Stdio.stdout()`, `Stdio.stderr()`, `Stdio.stdin()`) yielding single-source documented objects mapped seamlessly for LSP static typecheck resolution.
- **Chainable Text Formatting**: Stream interfaces support native method chaining for visual coloring and string template interpolation.
- **Event-Driven Non-Blocking Console Interception**: Input streams expose asynchronous polling boundaries yielding standard `Signal` dispatchers managed entirely within script coroutine contexts.
- **Piped Sub-Process Controls**: Supports spawning executables with active real-time communication pipes via `Stdio.spawnStream`.
