--!strict
-- luks-std/Process/ChildStdout/init.luau
local Async = require("../async")
local types = require("types")

local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return try_load("@self/../lib/luks_process")
        or try_load("@self/../../../target/release/luks_process")
        or try_load("@self/../../../target/debug/luks_process")
        or error("Could not load Process native library")
end)()

local ChildStdoutMT = {}
ChildStdoutMT.__index = ChildStdoutMT

--[[
    Attempts to read bytes from the child process's standard output.
    @param self The child stdout instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function ChildStdoutMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local ok, err = pcall(function()
            while true do
                if not self._handle then error("pipe closed") end
                local ok_, n = pcall(native.child_stdout_read, self._handle, buf, offset or 0, len or buffer.len(buf))
                if ok_ then
                    if n then return n end
                    task.wait()
                else
                    error(tostring(n))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
    end)
    return future
end

local ChildStdout = {}

--[[
    Internal: Creates a new ChildStdout instance.
    @param handle The native process handle
    @return A new ChildStdout instance
]]
function ChildStdout.new(handle: any): types.ChildStdout
    return setmetatable({ _handle = handle }, ChildStdoutMT) :: any
end

return ChildStdout
