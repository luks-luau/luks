--!strict
-- luks-std/FS/FileType/init.luau
local types = require("types")

type Self = {
    _is_file: boolean,
    _is_dir: boolean,
    _is_symlink: boolean,
}

local FileType = {}
local FileTypeMT = {}
FileTypeMT.__index = FileTypeMT

--[[
    Returns whether this file type represents a regular file.
    @param self The file type instance
    @return True if it's a file
]]
function FileTypeMT:is_file(): boolean
    return self._is_file
end

--[[
    Returns whether this file type represents a directory.
    @param self The file type instance
    @return True if it's a directory
]]
function FileTypeMT:is_dir(): boolean
    return self._is_dir
end

--[[
    Returns whether this file type represents a symbolic link.
    @param self The file type instance
    @return True if it's a symlink
]]
function FileTypeMT:is_symlink(): boolean
    return self._is_symlink
end

--[[
    Internal: Creates a new FileType instance.
    @param data Table containing is_file, is_dir, and is_symlink booleans
    @return A new FileType instance
]]
function FileType.new(data: { is_file: boolean, is_dir: boolean, is_symlink: boolean }): types.FileType
    local self: Self = {
        _is_file = data.is_file,
        _is_dir = data.is_dir,
        _is_symlink = data.is_symlink,
    }
    return setmetatable(self, FileTypeMT) :: any
end

return FileType
