--!strict
-- luks-std/FS/Metadata/init.luau
local types = require("types")
local FileType = require("FileType")
local Permissions = require("Permissions")

type Self = {
    _type: types.FileType,
    _perms: types.Permissions,
    _len: number,
    _modified: number,
    _accessed: number,
    _created: number,
}

local Metadata = {}
local MetadataMT = {}
MetadataMT.__index = MetadataMT

--[[
    Returns the file type from this metadata.
    @param self The metadata instance
    @return The file type object
]]
function MetadataMT:file_type(): types.FileType
    return self._type
end

--[[
    Returns the permissions from this metadata.
    @param self The metadata instance
    @return The permissions object
]]
function MetadataMT:permissions(): types.Permissions
    return self._perms
end

--[[
    Returns whether the metadata is for a directory.
    @param self The metadata instance
    @return True if it's a directory
]]
function MetadataMT:is_dir(): boolean
    return self._type:is_dir()
end

--[[
    Returns whether the metadata is for a regular file.
    @param self The metadata instance
    @return True if it's a file
]]
function MetadataMT:is_file(): boolean
    return self._type:is_file()
end

--[[
    Returns whether the metadata is for a symbolic link.
    @param self The metadata instance
    @return True if it's a symlink
]]
function MetadataMT:is_symlink(): boolean
    return self._type:is_symlink()
end

--[[
    Returns the size of the file in bytes.
    @param self The metadata instance
    @return The size in bytes
]]
function MetadataMT:len(): number
    return self._len
end

--[[
    Returns the last modification time of the file.
    @param self The metadata instance
    @return The modification time (Unix timestamp)
]]
function MetadataMT:modified(): number
    return self._modified
end

--[[
    Returns the last access time of the file.
    @param self The metadata instance
    @return The access time (Unix timestamp)
]]
function MetadataMT:accessed(): number
    return self._accessed
end

--[[
    Returns the creation time of the file.
    @param self The metadata instance
    @return The creation time (Unix timestamp)
]]
function MetadataMT:created(): number
    return self._created
end

--[[
    Internal: Creates a new Metadata instance from native data.
    @param data The raw data from the native layer
    @return A new Metadata instance
]]
function Metadata.new(data: any): types.Metadata
    local self: Self = {
        _type = FileType.new({
            is_file = data.is_file,
            is_dir = data.is_dir,
            is_symlink = data.is_symlink,
        }),
        _perms = Permissions.new(data.readonly),
        _len = data.len,
        _modified = data.modified,
        _accessed = data.accessed,
        _created = data.created,
    }
    return setmetatable(self, MetadataMT) :: any
end

return Metadata
