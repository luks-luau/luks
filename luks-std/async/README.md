# Async Module

Innovative Asynchronous API for Luau inspired by the Rust `futures` and `tokio` ecosystem. This module provides a high-level, signal-driven Future interface for managing non-blocking operations, composition, and parallel task synchronization with full Rust authenticity.

## Features

- **Signal-Driven Futures** — Leverages the high-performance `Signal` system for event-driven resolution and error handling.
- **Rust-Authentic Combinators** — Functional composition via `.and_then()` (chaining), `.map()` (transforming), and `.or_else()` (recovery).
- **Error Handling** — Dedicated `.map_err()` and `.inspect_err()` methods for fine-grained error management.
- **Side-Effect Inspection** — Use `.inspect()` to look at values without consuming or transforming the future chain.
- **Yielding & Panics** — Support for `.unwrap()` and `.expect()` to yield the current thread and automatically panic on failure, matching Rust's robustness.
- **Parallel Task Synchronization** — First-class support for awaiting multiple tasks via `Async.join` (similar to `tokio::join!`).
- **Racing Patterns** — Built-in support for "racing" multiple futures with `Async.select` (similar to `tokio::select!`).
- **Strict Type Safety** — Advanced Luau type definitions ensure full Intellisense support even through complex generic chains.

---

## API Reference

### `TaskFuture<T>`

The core interface representing a value that will be available in the future.

```lua
export type TaskFuture<T> = {
    OnData: Signal<T>,
    OnError: Signal<FsError>,
    OnComplete: Signal<()>,

    and_then: <U>(self: TaskFuture<T>, callback: (T) -> TaskFuture<U> | U) -> TaskFuture<U>,
    map: <U>(self: TaskFuture<T>, callback: (T) -> U) -> TaskFuture<U>,
    or_else: (self: TaskFuture<T>, callback: (FsError) -> TaskFuture<T> | T) -> TaskFuture<T>,
    map_err: (self: TaskFuture<T>, callback: (FsError) -> FsError) -> TaskFuture<T>,
    inspect: (self: TaskFuture<T>, callback: (T) -> ()) -> TaskFuture<T>,
    inspect_err: (self: TaskFuture<T>, callback: (FsError) -> ()) -> TaskFuture<T>,
    
    Wait: (self: TaskFuture<T>) -> (T, boolean),
    unwrap: (self: TaskFuture<T>) -> T,
    expect: (self: TaskFuture<T>, message: string) -> T,
}
```

#### Combinators (Chaining)

- **`future:and_then<U>(callback: (T) -> TaskFuture<U> | U) -> TaskFuture<U>`**
  Chains a new future to the result. If the first future succeeds, the callback runs.

- **`future:map<U>(callback: (T) -> U) -> TaskFuture<U>`**
  Transforms the resolved value into a new value.

- **`future:or_else(callback: (FsError) -> TaskFuture<T> | T) -> TaskFuture<T>`**
  Recovers from an error. If the future fails, the callback can return a fallback value or a new future.

- **`future:map_err(callback: (FsError) -> FsError) -> TaskFuture<T>`**
  Transforms the error object if the future fails.

#### Side-Effects

- **`future:inspect(callback: (T) -> ()) -> TaskFuture<T>`**
  Runs a callback on success without modifying the future. Great for logging.

- **`future:inspect_err(callback: (FsError) -> ()) -> TaskFuture<T>`**
  Runs a callback on error without modifying the future.

#### Yielding (Blocking)

- **`future:Wait() -> (T | FsError, boolean)`**
  Yields the thread. Returns the result and a success boolean.

- **`future:unwrap() -> T`**
  Yields the thread. Returns the value or panics if the future failed.

- **`future:expect(message: string) -> T`**
  Yields the thread. Returns the value or panics with a custom message if the future failed.

---

## Usage Examples

### Full Rust-Style Chaining

```lua
local Async = require("path/to/Async")

local function get_data()
    -- Imagine this returns a TaskFuture
end

get_data()
    :inspect(function(data) print("Fetched:", data) end)
    :map(function(data) return data.value end)
    :or_else(function(err)
        warn("Fetch failed, using default")
        return "Default Value"
    end)
    :inspect_err(function(err) warn("Critical fail:", err.message) end)
    .OnData:Connect(function(final)
        print("Final:", final)
    end)
```

### Yielding with `unwrap`

```lua
local Async = require("path/to/Async")

-- Synchronous-looking code that yields under the hood
local result = get_data():expect("Failed to get critical data")
print("Got result:", result)
```

### Parallel Synchronization with `join`

```lua
local Async = require("path/to/Async")

local f1 = delay_msg("Task A", 1)
local f2 = delay_msg("Task B", 0.5)

Async.join({f1, f2}).OnData:Connect(function(results)
    print("All finished:", results) -- {"Task A", "Task B"}
end)
```

---

## License

MIT License — see [LICENSE](LICENSE) file for details.
