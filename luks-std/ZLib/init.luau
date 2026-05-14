--!strict
--!native
--!optimize 2

--[[
    ZLib Module — Native Zlib compression/decompression for Luau.
    Compresses and decompresses strings or raw byte sequences.

    Errors are raised as Lua runtime errors and can be caught with pcall:
        local ok, err = pcall(ZLib.compress, data)
        local ok, err = pcall(ZLib.decompress, compressedData)
]]

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local nativeName = "zlib"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load ZLib native library")

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

--[[
    ZLib Module — provides Zlib compression and decompression.
]]
local ZLib = {}

--[[
    Compresses a raw string or byte sequence into Zlib format.

    @param data   The raw string/buffer to compress.
    @param level  Optional compression level (0 to 9, defaults to 6).
    @return       The Zlib-compressed string.

    @example
        local compressed = ZLib.compress("hello world", 9)
]]
function ZLib.compress(data: string, level: number?): string
    return native.compress(data, level)
end

--[[
    Decompresses a Zlib-compressed string back to the original raw buffer.

    Raises a runtime error if the payload is invalid or corrupted (catchable with pcall).

    @param compressed_data  The Zlib-compressed string.
    @return                 The original uncompressed string.

    @example
        local original = ZLib.decompress(compressed)
]]
function ZLib.decompress(compressed_data: string): string
    return native.decompress(compressed_data)
end

--[[ Native library version. ]]
ZLib.version = native.version :: string

return ZLib
