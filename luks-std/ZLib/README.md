# ZLib Module

Native Zlib compression and decompression module for Luau. Efficiently reduces payload sizes for strings and raw byte sequences using the high-performance Rust `flate2` crate under the hood.

## Features

- **Zlib Compression** — Full Deflate compression enveloped with standard Zlib headers
- **Configurable Levels** — Support for custom compression levels ranging from `0` (no compression) to `9` (maximum compression)
- **Robust Deserialization** — Safely restores uncompressed raw byte buffers with graceful Lua runtime errors on corrupted payloads
- **Type Safety** — Comprehensive Luau type annotations and JSDoc-style comments for seamless IDE intellisense support

## API Reference

### Methods

#### `ZLib.compress(data: string, level: number?) → string`
Compresses a raw string or byte sequence into Zlib format.
- `data`: The raw payload string or byte buffer to compress.
- `level`: Optional compression level from `0` to `9`. Defaults to `6` if omitted.

#### `ZLib.decompress(compressed_data: string) → string`
Decompresses a Zlib-compressed string back to its original raw buffer.
- `compressed_data`: The Zlib payload string.
- Raises a Lua runtime error if the payload is malformed or corrupted (catchable via `pcall`).

### Properties

#### `ZLib.version: string`
The native dynamic library version string.

---

## Usage

### Basic Compression and Decompression

```lua
local ZLib = require("path/to/ZLib")

local payload = string.rep("luks-luau Zlib module compression test string. ", 50)

-- Compress using the maximum optimization level
local compressed = ZLib.compress(payload, 9)
print("Original size:", #payload)
print("Compressed size:", #compressed)

-- Restore original string
local decompressed = ZLib.decompress(compressed)
assert(decompressed == payload, "Decompressed string perfectly matches the original payload!")
```

### Safe Error Handling

Because malformed or corrupted payloads cause native decompression failures, always wrap suspicious data decoding operations in a `pcall` block to prevent uncontrolled script termination:

```lua
local ZLib = require("path/to/ZLib")

local success, result = pcall(ZLib.decompress, "invalid non-zlib raw bytes junk")

if not success then
    print("Caught expected decompression error:", result)
end
```

---

## Building

To build the native dynamic library manually from source:

```bash
cd luks-std/ZLib
cargo build --release
```

Compiled dynamic libraries will be placed in the workspace target directory:
- **Windows**: `target/release/zlib.dll`
- **Linux**: `target/release/libzlib.so`
- **macOS**: `target/release/libzlib.dylib`

---

## Dependencies

- **Rust**: `flate2` (high-performance Deflate/Zlib streaming encoder and decoder)
- **Luau Interface**: `luks-module-sys` VTable bindings for pure VM FFI interaction

## License

MIT License — see [LICENSE](LICENSE) file for details.
