# Json Module

Native JSON encoding and decoding module for Luau, implemented in Rust using `serde_json`.

## Features

- **JSON Encoding**: Convert Luau values (nil, boolean, number, string, table) to JSON strings
- **JSON Decoding**: Parse JSON strings into Luau values
- **Type Support**: Handles nested objects, arrays, strings, numbers, booleans, and null
- **Native Performance**: Fast JSON processing via Rust's `serde_json` crate

## API Reference

### Types

```lua
export type JsonValue = any

export type Json = {
    -- Encodes a Lua value to JSON string
    encode: (value: JsonValue) -> string,
    
    -- Decodes a JSON string to Lua value
    decode: (json_str: string) -> JsonValue,
}
```

### Functions

#### `Json.encode(value: JsonValue): string`
Converts a Luau value to a JSON string.

- `nil` → `null`
- `boolean` → `true/false`
- `number` → JSON number
- `string` → JSON string
- `table` → JSON object (string keys) or array (integer keys starting at 1)

#### `Json.decode(json_str: string): JsonValue`
Parses a JSON string and returns the corresponding Luau value.

- `null` → `nil`
- `true/false` → boolean
- JSON number → number
- JSON string → string
- JSON object → table (key-value pairs)
- JSON array → table (integer-indexed)

## Usage

```lua
local Json = require("@std/Json")

-- Encoding
local data = {
    name = "John",
    age = 30,
    is_active = true,
    tags = {"lua", "rust", "json"}
}
local json_str = Json.encode(data)
print(json_str)
-- Output: {"name":"John","age":30,"is_active":true,"tags":["lua","rust","json"]}

-- Decoding
local decoded = Json.decode('{"status":"ok","code":200}')
print(decoded.status)  -- "ok"
print(decoded.code)     -- 200
```

## Building the Native Library

1. Navigate to the `Json` directory:
   ```bash
   cd luks-std/Json
   ```

2. Build the release version:
   ```bash
   cargo build --release
   ```

3. Copy the library to the `lib/` directory:
   ```bash
   # Windows
   copy target\release\json.dll lib\
   ```

## Dependencies

- **Rust Crate**: `serde_json` for fast JSON processing
- **Luau VM**: Requires `dlopen` function for loading native modules

## License

MIT License - see [LICENSE](LICENSE) file for details.
