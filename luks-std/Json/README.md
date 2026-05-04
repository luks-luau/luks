# Json Module

Native JSON encoding and decoding module for Luau, implemented in Rust using `serde_json`.

## Features

- **JSON Encoding** — Converts Luau values (`nil`, `boolean`, `number`, `string`, `table`) to JSON strings
- **JSON Decoding** — Parses JSON strings into Luau values
- **Nested Types** — Full support for nested objects, arrays, and all JSON primitives
- **Native Performance** — Fast JSON processing via Rust's `serde_json` crate
- **Error via pcall** — Failures raise Lua runtime errors, catchable with `pcall`

## API Reference

### Types

```lua
-- Any value representable in JSON (nil, boolean, number, string, or table)
export type JsonValue = any
```

### `Json.encode(value: JsonValue): string`

Encodes a Luau value into a JSON string.

| Luau type | JSON output |
|-----------|-------------|
| `nil`     | `null`      |
| `boolean` | `true` / `false` |
| `number`  | JSON number (raises on `NaN` / `Infinity`) |
| `string`  | JSON string (null bytes replaced with U+FFFD) |
| `table`   | JSON object or array (raises on circular references) |

Raises a Lua error on failure — use `pcall` to catch:

```lua
local ok, result = pcall(Json.encode, value)
if not ok then
    print("Encode error:", result)
end
```

### `Json.decode(json_str: string): JsonValue`

Parses a JSON string and returns the corresponding Luau value.

| JSON type      | Luau result  |
|----------------|--------------|
| `null`         | `nil`        |
| `true`/`false` | `boolean`    |
| number         | `number`     |
| string         | `string`     |
| object         | `table` (key→value) |
| array          | `table` (integer-indexed) |

Raises a Lua error on invalid JSON — use `pcall` to catch:

```lua
local ok, result = pcall(Json.decode, jsonString)
if not ok then
    print("Decode error:", result)
end
```

### `Json.version: string`

The native library version string.

---

## Usage

### Basic encode / decode

```lua
local Json = require("./path/to/Json")

-- Encoding
local data = {
    name     = "luks",
    level    = 5,
    active   = true,
    tags     = { "lua", "rust", "json" },
}
local json_str = Json.encode(data)
print(json_str)
-- {"name":"luks","level":5,"active":true,"tags":["lua","rust","json"]}

-- Decoding
local decoded = Json.decode('{"status":"ok","code":200}')
print(decoded.status) -- "ok"
print(decoded.code)   -- 200
```

### Error handling with pcall

```lua
-- Catch encode errors
local ok, result = pcall(Json.encode, function() end) -- functions are unsupported
if not ok then
    print("Encode failed:", result) -- "unsupported type: function"
end

-- Catch decode errors
local ok2, result2 = pcall(Json.decode, "{invalid json}")
if not ok2 then
    print("Decode failed:", result2) -- "JSON decode error: ..."
end
```

### Round-trip example

```lua
local original = { user = "luks", score = 42, verified = false }
local encoded  = Json.encode(original)
local decoded  = Json.decode(encoded)

assert(decoded.user     == original.user)
assert(decoded.score    == original.score)
assert(decoded.verified == original.verified)
```

---

## Building

```bash
cd luks-std/Json
cargo build --release
```

Output locations:
- **Windows**: `target/release/json.dll`
- **Linux**: `target/release/libjson.so`
- **macOS**: `target/release/libjson.dylib`

Copy to `lib/` for deployment:
```bash
# Windows
copy target\release\json.dll lib\
```

---

## Dependencies

- **Rust**: `serde_json` for fast JSON processing
- **Luau VM**: Built-in `dlopen` function for loading native modules

## License

MIT License — see [LICENSE](LICENSE) file for details.
