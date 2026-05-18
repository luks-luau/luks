# Signal System

A high-performance, pure Luau implementation of the Signal (Event) pattern utilizing a linked-list architecture. This system is designed to provide optimal memory management and execution speed, closely mirroring the native Roblox event API for use in external Luau environments.

## Overview

By avoiding standard table array operations (table.insert/table.remove), this implementation minimizes garbage collection overhead during frequent event connections and disconnections.

## Key Features

- **O(1) Performance**: Connecting and disconnecting nodes in the linked list operates in constant time, ensuring maximum efficiency even under heavy event loads.
- **Error Isolation**: Handlers are dispatched using a task scheduler (via `task.spawn`). If a connected function encounters an error, it will not interrupt the execution flow of other connected listeners.
- **Familiar API**: Implements the standard Roblox RBXScriptSignal interface, providing a seamless development experience for those accustomed to the Roblox engine.
- **Read-Only Proxy**: The `:Public()` method returns a proxy object frozen with `table.freeze()`, exposing only `Connect`, `Once`, and `Wait` methods. Internal methods like `Fire` and `DisconnectAll` remain accessible only to the signal creator.

## API Reference

### Signal<T...>

Public interface returned by `:Public()` method:

```lua
export type Signal<T...> = {
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
    Wait: (self: Signal<T...>) -> T...
}
```

### PrivateSignal<T...>

Returned by `Signal.new()`. Has all methods including `Fire` and `Public`:

```lua
type PrivateSignal<T...> = {
    Connect: (self: PrivateSignal<T...>, fn: (T...) -> ()) -> ConnectionInternal,
    Once: (self: PrivateSignal<T...>, fn: (T...) -> ()) -> ConnectionInternal,
    Wait: (self: PrivateSignal<T...>) -> T...,
    Fire: (self: PrivateSignal<T...>, T...) -> (),
    DisconnectAll: (self: PrivateSignal<T...>) -> (),
    Public: (self: PrivateSignal<T...>) -> Signal<T...>
}
```

### Connection

```lua
export type Connection = {
    Disconnect: (self: Connection) -> ()
}
```

## Usage

Import the module and instantiate a new Signal to get started:

```lua
local Signal = require("./path/to/Signal")

-- Create a new signal (returns PrivateSignal with Fire method)
local onPlayerHit = Signal.new()

-- Get read-only proxy to share with others
local publicSignal = onPlayerHit:Public()

-- Connect a listener using the public proxy
local connection = publicSignal:Connect(function(player, damage)
    print(player .. " took " .. damage .. " damage.")
end)

-- Fire the signal with arguments (using PrivateSignal)
onPlayerHit:Fire("PlayerOne", 50)

-- Wait for next signal (returns the fired arguments)
task.spawn(function()
    local player, damage = publicSignal:Wait()
    print("Waited: " .. player)
end)

-- Disconnect when no longer needed
connection:Disconnect()

-- Disconnect all connections (PrivateSignal only)
onPlayerHit:DisconnectAll()
```

## Security

This implementation uses a defensive proxy pattern to ensure security:

1. **Separation of Concerns**: `Signal.new()` returns `PrivateSignal` which has `Fire` and `DisconnectAll` methods. The `:Public()` method returns a read-only `Signal` proxy without these methods.

2. **Table Freezing**: The proxy object returned by `:Public()` is frozen using `table.freeze()` to prevent runtime modifications, injection of new methods, or alteration of metatables.

3. **Internal Separation**: The `PrivateSignal` type contains all methods but is not directly exported. Only the creator who calls `Signal.new()` has access to `Fire` and `DisconnectAll`.

This ensures that scripts receiving the public proxy cannot:
- Fire the signal arbitrarily
- Disconnect all connections at once
- Modify the proxy to inject malicious code

## Type Checking

This module uses Luau's strict mode (`--!strict`) with generic variadics (`T...`) to ensure type safety. The generic parameter `T...` represents the types of arguments that the signal will fire, ensuring type consistency between:

- Arguments passed to `PrivateSignal:Fire(T...)`
- Parameters received by connected callbacks `fn: (T...) -> ()`
- Values returned by `Signal:Wait(): T...`

## License

This project is licensed under the MIT License - see the LICENSE file for details.
