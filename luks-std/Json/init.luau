--!strict

--[[
    Json Module — Native JSON encode/decode for Luau.
    Serializes Luau values to JSON strings and parses JSON strings back to Luau values.

    Errors are raised as Lua runtime errors and can be caught with pcall:
        local ok, err = pcall(Json.encode, someValue)
        local ok, err = pcall(Json.decode, someString)
]]

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local nativeName = "json"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load JSON native library")

-- ---------------------------------------------------------------------------
-- Public Types
-- ---------------------------------------------------------------------------

--[[
    Any value that can be represented in JSON:
    `nil` (null), `boolean`, `number`, `string`, or a `table` (object or array).
]]
export type JsonValue = any

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

--[[
    Json Module — provides JSON serialization and deserialization.
]]
local Json = {}

--[[
    Encodes a Luau value into a JSON string.

    Supported types:
    - `nil`     → `null`
    - `boolean` → `true` / `false`
    - `number`  → JSON number (raises on `NaN` or `Infinity`)
    - `string`  → JSON string (null bytes replaced with U+FFFD)
    - `table`   → JSON object or array (raises on circular references)

    Raises a Lua runtime error on failure (use pcall to catch):
        local ok, result = pcall(Json.encode, value)

    @param value  The Luau value to serialize.
    @return       A JSON-encoded string.

    @example
        local s = Json.encode({ name = "luks", level = 5, active = true })
        -- s == '{"name":"luks","level":5,"active":true}'
]]
function Json.encode(value: JsonValue): string
    return native.encode(value)
end

--[[
    Decodes a JSON string into a Luau value.

    JSON types map to Luau as follows:
    - `null`          → `nil`
    - `true`/`false`  → `boolean`
    - number          → `number`
    - string          → `string`
    - object / array  → `table`

    Raises a Lua runtime error on invalid JSON (use pcall to catch):
        local ok, result = pcall(Json.decode, jsonString)

    @param json_str  The JSON string to parse.
    @return          The decoded Luau value.

    @example
        local data = Json.decode('{"name":"luks","level":5}')
        print(data.name)  -- "luks"
        print(data.level) -- 5
]]
function Json.decode(json_str: string): JsonValue
    return native.decode(json_str)
end

--[[ Native library version. ]]
Json.version = native.version :: string

return Json
