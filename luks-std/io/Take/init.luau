--!strict
-- luks-std/IO/Take/init.luau
-- Reader wrapper that limits the number of bytes read

local Async = require("@self/../../async")
local types = require("@self/../types")

type Self = {
    _inner: types.Reader,
    _limit: number,
}

type Reader = types.Reader
type IoError = types.IoError

local Take = {}
local TakeMT = {}
TakeMT.__index = TakeMT

--[[
    Creates a new Take reader that limits the inner reader to 'limit' bytes.
    @param inner The underlying Reader to wrap
    @param limit The maximum number of bytes that can be read
    @return A new Reader instance (Take)
]]
function Take.new(inner: types.Reader, limit: number): Reader
    local self: Self = {
        _inner = inner,
        _limit = limit,
    }
    return (setmetatable(self, TakeMT) :: any) :: Reader
end

--[[
    Returns the remaining number of bytes that can be read.
    @param self The take reader instance
    @return The remaining limit in bytes
]]
function TakeMT:limit(): number
    return (self :: any)._limit
end

--[[
    Sets a new limit for the reader.
    @param self The take reader instance
    @param limit The new limit in bytes
]]
function TakeMT:set_limit(limit: number)
    (self :: any)._limit = limit
end

--[[
    Attempts to read bytes from the limited reader into the provided buffer.
    @param self The take reader instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function TakeMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    if this._limit <= 0 then return Async.resolved(0) end
    
    local off = offset or 0
    local l = len or buffer.len(buf)
    local max_to_read = math.min(l, this._limit)
    
    return this._inner:read(buf, off, max_to_read):and_then(function(n): any
        this._limit -= n
        return n
    end)
end

--[[
    Reads up to the remaining limit bytes from the reader and returns them in a buffer.
    @param self The take reader instance
    @return A future resolving to the buffer of bytes
]]
function TakeMT:read_to_end(): Async.TaskFuture<buffer>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local res = buffer.create(0)
        while this._limit > 0 do
            local tmp = buffer.create(math.min(8192, this._limit))
            local n, ok = (self :: Reader):read(tmp):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then break end
            local new_res = buffer.create(buffer.len(res) + n)
            buffer.copy(new_res, 0, res)
            buffer.copy(new_res, buffer.len(res), tmp, 0, n)
            res = new_res
        end
        resolve(res)
    end)
    return future
end

--[[
    Reads up to the remaining limit bytes from the reader and returns them as a string.
    @param self The take reader instance
    @return A future resolving to the full string
]]
function TakeMT:read_to_string(): Async.TaskFuture<string>
    return (self :: Reader):read_to_end():map(buffer.tostring)
end

--[[
    Attempts to read the exact number of bytes needed to fill the buffer, up to the limit.
    @param self The take reader instance
    @param buf The buffer to fill
    @param len The number of bytes to read
    @return A future resolving when complete
]]
function TakeMT:read_exact(buf: buffer, len: number): Async.TaskFuture<any>
    local this: Self = self :: any
    if len > this._limit then
        return Async.rejected({ kind = "UnexpectedEof", message = "take limit reached before filling buffer" } :: IoError)
    end
    return this._inner:read_exact(buf, len):and_then(function(): any
        this._limit -= len
        return nil
    end)
end

-- Export metatable
(Take :: any)._MT = TakeMT

return Take
