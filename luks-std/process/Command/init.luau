--!strict
-- luks-std/Process/Command/init.luau
local Async = require("../async")
local types = require("types")
local Child = require("Child")

local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return try_load("@self/lib/luks_process")
        or try_load("@self/../../../target/release/luks_process")
        or try_load("@self/../../../target/debug/luks_process")
        or error("Could not load Process native library")
end)()

local CommandMT = {}
CommandMT.__index = CommandMT

--[[
    Adds an argument to the command.
    @param self The command instance
    @param arg The argument string
    @return The command instance (for chaining)
]]
function CommandMT:arg(arg: string) table.insert(self._args, arg); return self end

--[[
    Adds multiple arguments to the command.
    @param self The command instance
    @param args A list of argument strings
    @return The command instance (for chaining)
]]
function CommandMT:args(args: {string})
    for _, a in args do table.insert(self._args, a) end
    return self
end

--[[
    Sets the working directory for the child process.
    @param self The command instance
    @param path The path to the directory
    @return The command instance (for chaining)
]]
function CommandMT:cwd(path: string) self._opts.cwd = path; return self end

--[[
    Sets an environment variable for the child process.
    @param self The command instance
    @param key The environment variable name
    @param value The environment variable value
    @return The command instance (for chaining)
]]
function CommandMT:env(key: string, value: string)
    if not self._opts.env then self._opts.env = {} end
    (self._opts.env :: any)[key] = value
    return self
end

--[[
    Clears the environment for the child process.
    @param self The command instance
    @return The command instance (for chaining)
]]
function CommandMT:env_clear() self._opts.env_clear = true; return self end

--[[
    Sets the stdin configuration for the child process.
    @param self The command instance
    @param cfg The configuration (inherit, piped, or null)
    @return The command instance (for chaining)
]]
function CommandMT:stdin(cfg: types.StdioConfig) self._opts.stdin = cfg; return self end

--[[
    Sets the stdout configuration for the child process.
    @param self The command instance
    @param cfg The configuration (inherit, piped, or null)
    @return The command instance (for chaining)
]]
function CommandMT:stdout(cfg: types.StdioConfig) self._opts.stdout = cfg; return self end

--[[
    Sets the stderr configuration for the child process.
    @param self The command instance
    @param cfg The configuration (inherit, piped, or null)
    @return The command instance (for chaining)
]]
function CommandMT:stderr(cfg: types.StdioConfig) self._opts.stderr = cfg; return self end

--[[
    Spawns the command as a child process.
    @param self The command instance
    @return A future resolving to the child process handle
]]
function CommandMT:spawn(): Async.TaskFuture<types.Child>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, handle = pcall(native.spawn, self._program, self._args, self._opts)
        if ok then resolve(Child.new(handle)) else reject({ kind = "IoError", message = tostring(handle) }) end
    end)
    return future
end

local Command = {}

--[[
    Creates a new Command builder for the specified program.
    @param program The name or path of the program to run
    @return A new Command builder instance
]]
function Command.new(program: string): types.Command
    local self = setmetatable({
        _program = program,
        _args = {},
        _opts = {},
    }, CommandMT)
    return self :: any
end

return Command
