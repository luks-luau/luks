--!strict
-- luks-std/IO/Chain/init.luau
-- Reader wrapper that chains two readers sequentially

local Async = require("@self/../../async")
local types = require("@self/../types")

type Self = {
    _first: types.Reader,
    _second: types.Reader,
    _done_first: boolean,
}

type Reader = types.Reader
type IoError = types.IoError

local Chain = {}
local ChainMT = {}
ChainMT.__index = ChainMT

--[[
    Creates a new Chain reader that reads from 'first' until EOF, then 'second'.
    @param first The first reader to consume
    @param second The second reader to consume after the first reaches EOF
    @return A new Reader instance (Chain)
]]
function Chain.new(first: types.Reader, second: types.Reader): Reader
    local self: Self = {
        _first = first,
        _second = second,
        _done_first = false,
    }
    return (setmetatable(self, ChainMT) :: any) :: Reader
end

--[[
    Attempts to read bytes from the chained readers into the provided buffer.
    @param self The chain reader instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function ChainMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    if not this._done_first then
        return this._first:read(buf, offset, len):and_then(function(n): any
            if n == 0 then
                this._done_first = true
                return (self :: Reader):read(buf, offset, len)
            end
            return n
        end)
    else
        return this._second:read(buf, offset, len)
    end
end

--[[
    Reads all bytes from both readers sequentially and returns them in a buffer.
    @param self The chain reader instance
    @return A future resolving to the full buffer of bytes
]]
function ChainMT:read_to_end(): Async.TaskFuture<buffer>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local res1, ok1 = (if this._done_first then Async.resolved(buffer.create(0)) else this._first:read_to_end()):Wait()
        if not ok1 then reject(res1 :: any); return end
        this._done_first = true
        
        local res2, ok2 = this._second:read_to_end():Wait()
        if not ok2 then reject(res2 :: any); return end
        
        local final = buffer.create(buffer.len(res1) + buffer.len(res2))
        buffer.copy(final, 0, res1)
        buffer.copy(final, buffer.len(res1), res2)
        resolve(final)
    end)
    return future
end

--[[
    Reads all bytes from both readers sequentially and returns them as a string.
    @param self The chain reader instance
    @return A future resolving to the full string
]]
function ChainMT:read_to_string(): Async.TaskFuture<string>
    return (self :: Reader):read_to_end():map(buffer.tostring)
end

--[[
    Attempts to read the exact number of bytes needed to fill the buffer from the chained readers.
    @param self The chain reader instance
    @param buf The buffer to fill
    @param len The number of bytes to read
    @return A future resolving when complete
]]
function ChainMT:read_exact(buf: buffer, len: number): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        while total < len do
            local n, ok = (self :: Reader):read(buf, total, len - total):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then reject({ kind = "UnexpectedEof", message = "chain EOF reached before filling buffer" } :: IoError); return end
            total += n :: number
        end
        resolve(nil)
    end)
    return future
end

-- Export metatable
(Chain :: any)._MT = ChainMT

return Chain
