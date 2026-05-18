--!strict
-- luks-std/Process/Stdio/init.luau
local types = require("types")

local Stdio = {}

--[[
    Returns a configuration that creates a pipe for the standard stream.
    @return The "piped" StdioConfig
]]
function Stdio.piped(): types.StdioConfig return "piped" end

--[[
    Returns a configuration that inherits the standard stream from the parent process.
    @return The "inherit" StdioConfig
]]
function Stdio.inherit(): types.StdioConfig return "inherit" end

--[[
    Returns a configuration that redirects the standard stream to null.
    @return The "null" StdioConfig
]]
function Stdio.null(): types.StdioConfig return "null" end

return Stdio
