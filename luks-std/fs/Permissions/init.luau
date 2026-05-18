--!strict
-- luks-std/FS/Permissions/init.luau
local types = require("types")

type Self = {
    _readonly: boolean,
}

local Permissions = {}
local PermissionsMT = {}
PermissionsMT.__index = PermissionsMT

--[[
    Returns whether these permissions represent a read-only state.
    @param self The permissions instance
    @return True if read-only
]]
function PermissionsMT:readonly(): boolean
    return self._readonly
end

--[[
    Sets whether these permissions represent a read-only state.
    @param self The permissions instance
    @param readonly Whether it should be read-only
]]
function PermissionsMT:set_readonly(readonly: boolean)
    self._readonly = readonly
end

--[[
    Internal: Creates a new Permissions instance.
    @param readonly Initial read-only state
    @return A new Permissions instance
]]
function Permissions.new(readonly: boolean): types.Permissions
    local self: Self = {
        _readonly = readonly,
    }
    return setmetatable(self, PermissionsMT) :: any
end

return Permissions
