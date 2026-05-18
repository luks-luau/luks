# Events Module

Centralized Event Loop and Polling Service for the `luks-luau` runtime. This module provides a unified tick system, allowing native modules and user scripts to register non-blocking periodic tasks and respond to the global execution cycle.

## Features

- **Global Tick Signal** — High-performance `OnTick` signal fired once per Luau scheduler cycle.
- **Provider Registration** — Managed polling system for registering and unregistering named tasks.
- **Periodic Tasks** — Built-in `onEvery` helper for running logic at fixed time intervals.
- **Single-Shot Tasks** — `once` helper for executing code on the immediate next tick.
- **Self-Starting Loop** — The event loop automatically starts when the first provider is registered and stops when empty to save resources.
- **Robust Error Handling** — Individual pollers are wrapped in `pcall` to ensure one failing task doesn't crash the entire loop.

---

## API Reference

### Signals

#### `Events.OnTick: Signal<()>`
Fired at the beginning of every event loop cycle.

---

### Core Methods

#### `Events.registerPoll(name: string, callback: () -> ())`
Registers a function to be executed every tick.
- **name**: A unique identifier for the poller.
- **callback**: The function to execute.

#### `Events.unregisterPoll(name: string)`
Removes a previously registered poll provider.

#### `Events.onEvery(seconds: number, callback: () -> ()) -> (() -> ())`
Runs the callback at a specified interval. Returns a function that, when called, stops the interval.

#### `Events.once(callback: () -> ())`
Registers a callback to run exactly once on the next tick.

#### `Events.start()`
Manually starts the event loop. Usually called automatically by `registerPoll`.

#### `Events.stop()`
Stops the event loop and clears all registered pollers.

#### `Events.isActive() -> boolean`
Returns `true` if the event loop is currently running.

#### `Events.getProviders() -> {string}`
Returns an array containing the names of all currently registered poll providers.

---

## Usage Examples

### Registering a Poller

```lua
local Events = require("path/to/Events")

Events.registerPoll("MyService", function()
    -- This runs every tick
    -- Keep it non-blocking!
end)
```

### Running Periodic Tasks

```lua
local Events = require("path/to/Events")

local stop = Events.onEvery(1.5, function()
    print("This runs every 1.5 seconds")
end)

-- Stop it later
task.delay(10, stop)
```

### Next-Tick Execution

```lua
local Events = require("path/to/Events")

print("Now")
Events.once(function()
    print("Next Tick")
end)
```

### Subscribing to the Tick Signal

```lua
local Events = require("path/to/Events")

Events.OnTick:Connect(function()
    -- Global logic for every tick
end)
```

---

## Performance Considerations

The `Events` module uses a single `task.wait(0)` loop to manage all registered pollers. To maintain high performance:
1. Ensure all poll callbacks are **non-blocking**.
2. Avoid heavy computations inside the tick loop.
3. Use `onEvery` for tasks that don't need to run at maximum frequency.

## License

MIT License — see [LICENSE](LICENSE) file for details.
