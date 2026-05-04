local SafeLoadNative = function(path: string)
    local sucess, native = pcall(dlopen, path)
    if sucess then
        return native
    else
        return nil
    end
end
local nativeName = "native"
local native = SafeLoadNative("@self/lib/".. nativeName) or SafeLoadNative("@self/../../target/release/".. nativeName) or SafeLoadNative("@self/../../target/debug/".. nativeName) or error("Could not load native library")

--[[
    Native Module Example
]]
local Module = {}

--[[
    @return A native version in string
]]
Module.version = native.version :: string

--[[
    receiving hello from native
    @return A string
]]
function Module.hello() : string
    return native.hello()
end

return Module