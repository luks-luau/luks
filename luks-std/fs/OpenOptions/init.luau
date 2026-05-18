--!strict
-- luks-std/FS/OpenOptions/init.luau
-- Builder for opening files with specific configurations

local Async = require("@self/../../async")
local types = require("types")

type Self = {
    _read: boolean,
    _write: boolean,
    _append: boolean,
    _truncate: boolean,
    _create: boolean,
    _create_new: boolean,
}

local OpenOptions = {}
local OpenOptionsMT = {}
OpenOptionsMT.__index = OpenOptionsMT

-- Placeholder for the opener function to break circular dependency
OpenOptions._opener = nil :: ((path: string, options: any) -> Async.TaskFuture<types.File>)?

--[[
    Creates a new set of options. All options are initially false.
    @return A new OpenOptions builder instance
]]
function OpenOptions.new(): any -- Returns OpenOptions
    local self: Self = {
        _read = false,
        _write = false,
        _append = false,
        _truncate = false,
        _create = false,
        _create_new = false,
    }
    return setmetatable(self, OpenOptionsMT)
end

--[[
    Sets the option for read access.
    @param enable Whether to enable read access
    @return The OpenOptions instance (for chaining)
]]
function OpenOptionsMT:read(enable: boolean): any
    self._read = enable
    return self
end

--[[
    Sets the option for write access.
    @param enable Whether to enable write access
    @return The OpenOptions instance (for chaining)
]]
function OpenOptionsMT:write(enable: boolean): any
    self._write = enable
    return self
end

--[[
    Sets the option for append mode.
    @param enable Whether to enable append mode
    @return The OpenOptions instance (for chaining)
]]
function OpenOptionsMT:append(enable: boolean): any
    self._append = enable
    return self
end

--[[
    Sets the option for truncating the file to 0 length.
    @param enable Whether to enable truncation
    @return The OpenOptions instance (for chaining)
]]
function OpenOptionsMT:truncate(enable: boolean): any
    self._truncate = enable
    return self
end

--[[
    Sets the option to create a new file if it doesn't exist.
    @param enable Whether to enable creation
    @return The OpenOptions instance (for chaining)
]]
function OpenOptionsMT:create(enable: boolean): any
    self._create = enable
    return self
end

--[[
    Sets the option to create a new file and fail if it already exists.
    @param enable Whether to enable create-new mode
    @return The OpenOptions instance (for chaining)
]]
function OpenOptionsMT:create_new(enable: boolean): any
    self._create_new = enable
    return self
end

--[[ Converts builder to a plain table for the native backend ]]
function OpenOptionsMT:_to_native()
    return {
        read = self._read,
        write = self._write,
        append = self._append,
        truncate = self._truncate,
        create = self._create,
        create_new = self._create_new,
    }
end

-- This will be linked to FS.File.open_with_options by the File module
--[[
    Opens the file at the specified path with the configured options.
    @param path The path to the file to open
    @return A future resolving to the open File instance
]]
function OpenOptionsMT:open(path: string): Async.TaskFuture<types.File>
    local opener = OpenOptions._opener
    if not opener then
        error("FS system not fully initialized: OpenOptions opener missing")
    end
    return opener(path, self:_to_native())
end

return OpenOptions
