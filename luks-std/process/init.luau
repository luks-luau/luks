--!strict
-- luks-std/Process/init.luau
local types = require("@self/types")
local Command = require("@self/Command")
local Child = require("@self/Child")
local ExitStatus = require("@self/ExitStatus")
local Stdio = require("@self/Stdio")

local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return try_load("@self/lib/luks_process")
        or try_load("@self/../../target/release/luks_process")
        or try_load("@self/../../target/debug/luks_process")
        or error("Could not load Process native library")
end)()
export type Command = types.Command
export type Child = types.Child
export type ExitStatus = types.ExitStatus
export type StdioConfig = types.StdioConfig

local Process = {}

--[[ Builder for configuring and spawning a child process. ]]
Process.Command = Command
--[[ Represents a spawned child process. ]]
Process.Child = Child
--[[ Represents the exit status of a finished process. ]]
Process.ExitStatus = ExitStatus
--[[ Configuration helpers for standard streams (piped, inherit, null). ]]
Process.Stdio = Stdio

--[[
    Returns the process ID of the current process.
    @return The numeric PID
]]
function Process.id(): number return native.id() end

--[[
    Terminates the current process with the specified exit code.
    @param code The numeric exit code (0 for success)
]]
function Process.exit(code: number): () native.exit(code) end

--[[
    Terminates the process abnormally.
]]
function Process.abort(): () native.abort() end

--[[
    Returns the process ID of the parent process.
    @return The numeric parent PID
]]
function Process.ppid(): number return native.ppid() end

return Process
