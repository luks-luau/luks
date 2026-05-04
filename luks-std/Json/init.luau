--!strict

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local nativeName = "json"
local native = SafeLoadNative("@self/lib/".. nativeName) 
    or SafeLoadNative("@self/../../target/release/".. nativeName) 
    or SafeLoadNative("@self/../../target/debug/".. nativeName) 
    or error("Could not load JSON native library")

-- Types
export type JsonValue = any

export type Json = {
    --[[ 
        Encodes a Lua value to JSON string.
        Supports: nil (null), boolean, number, string, table (object/array)
        @param value The value to encode
        @return JSON string or error message
    ]]
    encode: (value: JsonValue) -> string,
    
    --[[ 
        Decodes a JSON string to Lua value.
        @param json_str The JSON string to decode
        @return Decoded Lua value or error message
    ]]
    decode: (json_str: string) -> JsonValue,
}

local Module = {} :: Json

function Module.encode(value: JsonValue): string
    return native.encode(value)
end

function Module.decode(json_str: string): JsonValue
    return native.decode(json_str)
end

return Module
