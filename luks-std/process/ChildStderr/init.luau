--!strict
-- luks-std/Process/ChildStderr/init.luau
local Async = require("../async")
local types = require("types")

local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return try_load("@self/lib/luks_process")
        or try_load("@self/../../../target/release/luks_process")
        or try_load("@self/../../../target/debug/luks_process")
        or error("Could not load Process native library")
end)()

local ChildStderrMT = {}
ChildStderrMT.__index = ChildStderrMT

--[[
    Attempts to read bytes from the child process's standard error.
    @param self The child stderr instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function ChildStderrMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not self._handle then reject({ kind = "IoError", message = "pipe closed" }); break end
            local n, err = native.child_stderr_read(self._handle, buf, offset or 0, len or buffer.len(buf))
            if n then resolve(n); break
            elseif err == "WouldBlock" then task.wait()
            else reject({ kind = "IoError", message = err or "read failed" }); break end
        end
    end)
    return future
end

local ChildStderr = {}

--[[
    Internal: Creates a new ChildStderr instance.
    @param handle The native process handle
    @return A new ChildStderr instance
]]
function ChildStderr.new(handle: any): types.ChildStderr
    return setmetatable({ _handle = handle }, ChildStderrMT) :: any
end

return ChildStderr
