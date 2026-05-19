--!strict
-- luks-std/Process/Child/init.luau
local Async = require("../async")
local types = require("types")
local ExitStatus = require("ExitStatus")
local ChildStdin = require("ChildStdin")
local ChildStdout = require("ChildStdout")
local ChildStderr = require("ChildStderr")

local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return try_load("@self/../lib/luks_process")
        or try_load("@self/../../../target/release/luks_process")
        or try_load("@self/../../../target/debug/luks_process")
        or error("Could not load Process native library")
end)()

local ChildMT = {}
ChildMT.__index = ChildMT

--[[
    Forcibly terminates the child process.
    @param self The child process instance
    @return A future resolving when the process is killed
]]
function ChildMT:kill(): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not self._handle then reject({ kind = "IoError", message = "process already closed" }); return end
        local ok, err = pcall(native.child_kill, self._handle)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(err) }) end
    end)
    return future
end

--[[
    Attempts to collect the exit status of the child process without blocking.
    @param self The child process instance
    @return A future resolving to the ExitStatus if the process has finished, or nil otherwise
]]
function ChildMT:try_wait(): Async.TaskFuture<types.ExitStatus?>
    local future: Async.TaskFuture<types.ExitStatus?>, resolve: (types.ExitStatus?) -> (), reject: (Async.FsError) -> () = Async.new_future()
    task.defer(function()
        if not self._handle then reject({ kind = "IoError", message = "process already closed" }); return end
        local ok, result = pcall(native.child_try_wait, self._handle)
        if ok then
            if result then resolve(ExitStatus.new(result)) else resolve(nil) end
        else
            reject({ kind = "IoError", message = tostring(result) })
        end
    end)
    return future
end

--[[
    Waits for the child process to finish and returns its exit status.
    @param self The child process instance
    @return A future resolving to the ExitStatus
]]
function ChildMT:wait(): Async.TaskFuture<types.ExitStatus>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local ok, err = pcall(function()
            while true do
                if not self._handle then error("process already closed") end
                local ok_, result = pcall(native.child_try_wait, self._handle)
                if ok_ then
                    if result then return ExitStatus.new(result) end
                    task.wait()
                else
                    error(tostring(result))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
    end)
    return future
end

--[[
    Closes the child process handle and releases native resources.
    Also nullifies stdin/stdout/stderr sub-handles to prevent dangling pointers.
    @param self The child process instance
]]
function ChildMT:close()
    if self._handle then
        native.child_free(self._handle)
        self._handle = nil
        if self.stdin then (self.stdin :: any)._handle = nil end
        if self.stdout then (self.stdout :: any)._handle = nil end
        if self.stderr then (self.stderr :: any)._handle = nil end
    end
end

local Child = {}

--[[
    Internal: Creates a new Child instance from a native handle.
    @param handle The native process handle
    @return A new Child instance
]]
function Child.new(handle: any): types.Child
    local self = setmetatable({
        _handle = handle,
        id = native.child_id(handle),
        stdin = if native.child_has_stdin(handle) then ChildStdin.new(handle) else nil,
        stdout = if native.child_has_stdout(handle) then ChildStdout.new(handle) else nil,
        stderr = if native.child_has_stderr(handle) then ChildStderr.new(handle) else nil,
    }, ChildMT)
    return self :: any
end

return Child
