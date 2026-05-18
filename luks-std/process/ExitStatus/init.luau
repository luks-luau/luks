--!strict
-- luks-std/Process/ExitStatus/init.luau
local types = require("types")

type Self = {
    _code: number,
}

local ExitStatusMT = {}
ExitStatusMT.__index = ExitStatusMT

--[[
    Returns whether the process finished successfully (exit code 0).
    @param self The exit status instance
    @return True if successful
]]
function ExitStatusMT:success() return self._code == 0 end

--[[
    Returns the exit code of the process.
    @param self The exit status instance
    @return The numeric exit code
]]
function ExitStatusMT:code() return self._code end

local ExitStatus = {}

--[[
    Internal: Creates a new ExitStatus instance.
    @param code The numeric exit code
    @return A new ExitStatus instance
]]
function ExitStatus.new(code: number): types.ExitStatus
    local self: Self = { _code = code }
    return setmetatable(self, ExitStatusMT) :: any
end

return ExitStatus
