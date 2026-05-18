# IO Module

High-performance, strictly-typed asynchronous I/O primitives for Luau inspired by the Rust `std::io` ecosystem. This module provides a robust suite of tools for stream manipulation, buffering, and system-level I/O integration with full Rust authenticity.

## Features

- **Rust-Authentic Primitives** — Implements core `std::io` components including `stdin`, `stdout`, `stderr`, `Cursor`, and `BufReader/Writer`.
- **Trait-Based Architecture** — Strict interface contracts for `Reader`, `Writer`, `Seeker`, and `BufRead` ensuring modular and predictable behavior.
- **Asynchronous Design** — Every I/O operation is integrated with the `TaskFuture` system for non-blocking execution.
- **Fluent Combinators** — Functional stream transformation via `.take(limit)` and `.chain(other)` available on all readers.
- **Strict Type Safety** — Comprehensive Luau type definitions eliminate `any` and provide premium Intellisense support.
- **Memory Efficiency** — Leverages native `buffer` primitives for low-overhead data transfers and zero-copy potential.

---

## API Reference

### Core Traits

The module revolves around four primary interfaces that define stream capabilities.

#### `Reader`
```luau
export type Reader = {
    read: (self: Reader, buf: buffer, offset: number?, len: number?) -> TaskFuture<number>,
    read_to_end: (self: Reader) -> TaskFuture<buffer>,
    read_to_string: (self: Reader) -> TaskFuture<string>,
    read_exact: (self: Reader, buf: buffer, len: number) -> TaskFuture<()>,
    take: (self: Reader, limit: number) -> Reader,
    chain: (self: Reader, other: Reader) -> Reader,
}
```

#### `Writer`
```luau
export type Writer = {
    write: (self: Writer, buf: buffer | string, offset: number?, len: number?) -> TaskFuture<number>,
    write_all: (self: Writer, buf: buffer | string) -> TaskFuture<()>,
    flush: (self: Writer) -> TaskFuture<()>,
}
```

#### `Seeker`
```luau
export type Seeker = {
    seek: (self: Seeker, pos: SeekFrom) -> TaskFuture<number>,
    position: (self: Seeker) -> number,
}
```

#### `BufRead`
```luau
export type BufRead = Reader & {
    read_line: (self: BufRead) -> TaskFuture<string?>,
    read_until: (self: BufRead, byte: number) -> TaskFuture<buffer?>,
    lines: (self: BufRead) -> () -> string?,
}
```

---

## Usage Examples

### Reading from Stdin to Stdout
Standard streams are fully asynchronous and support native piping.

```luau
local IO = require("path/to/io")

local stdin = IO.stdin()
local stdout = IO.stdout()

-- Asynchronously copy everything from stdin to stdout
IO.copy(stdin, stdout)
    :inspect(function(total) print(`Copied {total} bytes`) end)
    :expect("Failed to copy stream")
```

### Buffered File Reading
Using `BufReader` to efficiently read lines from a memory cursor or file stream.

```luau
local IO = require("@luks/io")

local cursor = IO.Cursor.new("First Line\nSecond Line\nThird Line")
local reader = IO.BufReader.new(cursor)

for line in reader:lines() do
    print("Read:", line)
end
```

### Fluent Combinators and Take
Chaining readers and limiting input using the fluent API.

```luau
local IO = require("@luks/io")

local hello = IO.Cursor.new("Hello ")
local world = IO.repeat_byte(string.byte("!"))

-- Chain readers and limit the infinite "!" stream to 5 bytes
local combined = hello:chain(world:take(5))

local result = combined:read_to_string():unwrap()
print(result) -- "Hello !!!!!"
```

---

## Implementation Details

The `IO` module is split between a high-performance Rust backend for system streams and a pure, optimized Luau layer for memory-based operations. All error objects follow the standardized `IoError` format `{ kind: string, message: string }`, ensuring compatibility with the `FileSystem` and `Process` modules.

---

## License

MIT License — see [LICENSE](LICENSE) file for details.
