--!strict
-- luks-std/Process/ChildStdin/init.luau
local Async = require("../async")
local types = require("types")

local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return try_load("@self/lib/luks_process")
        or try_load("@self/../../../target/release/luks_process")
        or try_load("@self/../../../target/debug/luks_process")
        or error("Could not load Process native library")
end)()

local ChildStdinMT = {}
ChildStdinMT.__index = ChildStdinMT

--[[
    Attempts to write bytes into the child process's standard input.
    @param self The child stdin instance
    @param buf The data to write (buffer or string)
    @param offset Optional offset in the data to start reading
    @param len Optional number of bytes to write
    @return A future resolving to the number of bytes written
]]
function ChildStdinMT:write(buf: buffer | string, offset: number?, len: number?): Async.TaskFuture<number>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not self._handle then reject({ kind = "IoError", message = "pipe closed" }); break end
            local n, err = native.child_stdin_write(self._handle, buf, offset or 0, len or (if type(buf) == "string" then #buf else buffer.len(buf)))
            if n then resolve(n); break
            elseif err == "WouldBlock" then task.wait()
            else reject({ kind = "IoError", message = err or "write failed" }); break end
        end
    end)
    return future
end

--[[
    Closes the child process's standard input stream.
    @param self The child stdin instance
]]
function ChildStdinMT:close()
    if self._handle then
        native.child_stdin_close(self._handle)
        self._handle = nil
    end
end

local ChildStdin = {}

--[[
    Internal: Creates a new ChildStdin instance.
    @param handle The native process handle
    @return A new ChildStdin instance
]]
function ChildStdin.new(handle: any): types.ChildStdin
    return setmetatable({ _handle = handle }, ChildStdinMT) :: any
end

return ChildStdin
