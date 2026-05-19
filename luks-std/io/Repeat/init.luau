--!strict
-- luks-std/IO/Repeat/init.luau
-- Infinite reader that repeats a single byte

local Async = require("@self/../../async")
local types = require("@self/../types")

type Self = {
    _byte: number,
}

type Reader = types.Reader

local Repeat = {}
local RepeatMT = {}
RepeatMT.__index = RepeatMT

--[[
    Creates a new reader that infinitely repeats the specified byte.
    @param byte The byte value to repeat (0-255)
    @return A new Reader instance (Repeat)
]]
function Repeat.new(byte: number): Reader
    local self: Self = {
        _byte = byte % 256,
    }
    return (setmetatable(self, RepeatMT) :: any) :: Reader
end

--[[
    Fills the provided buffer with the repeating byte.
    @param self The repeat reader instance
    @param buf The buffer to fill
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to fill
    @return A future resolving to the number of bytes filled
]]
function RepeatMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local off = offset or 0
    local l = len or buffer.len(buf)
    buffer.fill(buf, off, this._byte, l)
    return Async.resolved(l)
end

--[[
    Always errors, as Repeat is an infinite source.
]]
function RepeatMT:read_to_end(): Async.TaskFuture<buffer>
    return Async.rejected({ kind = "InfiniteSource", message = "Attempted to read_to_end on an infinite IO.Repeat source" })
end

--[[
    Always errors, as Repeat is an infinite source.
]]
function RepeatMT:read_to_string(): Async.TaskFuture<string>
    return Async.rejected({ kind = "InfiniteSource", message = "Attempted to read_to_string on an infinite IO.Repeat source" })
end

--[[
    Fills the buffer with the exact number of repeating bytes requested.
    @param self The repeat reader instance
    @param buf The buffer to fill
    @param len The number of bytes to fill
    @return A future resolving when complete
]]
function RepeatMT:read_exact(buf: buffer, len: number): Async.TaskFuture<any>
    local this: Self = self :: any
    buffer.fill(buf, 0, this._byte, len)
    return Async.resolved(nil)
end

-- Export metatable
(Repeat :: any)._MT = RepeatMT

return Repeat
