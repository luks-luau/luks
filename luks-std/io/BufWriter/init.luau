--!strict
-- luks-std/IO/BufWriter/init.luau
-- Buffered writer implementation for efficient small writes

local Async = require("@self/../../async")
local types = require("@self/../types")

local DEFAULT_CAPACITY = 8192

type Self = {
    _inner: types.Writer,
    _buf: buffer,
    _pos: number,
}

type Writer = types.Writer
type IoError = types.IoError

local BufWriter = {}
local BufWriterMT = {}
BufWriterMT.__index = BufWriterMT

--[[
    Creates a new BufWriter wrapping an inner writer.
    @param inner The underlying Writer to buffer
    @param capacity Optional initial capacity for the internal buffer (default: 8192)
    @return A new Writer instance (buffered)
]]
function BufWriter.new(inner: types.Writer, capacity: number?): Writer
    local cap = capacity or DEFAULT_CAPACITY
    local self: Self = {
        _inner = inner,
        _buf = buffer.create(cap),
        _pos = 0,
    }
    return (setmetatable(self, BufWriterMT) :: any) :: Writer
end

--[[
    Flushes the internal buffer, writing all data to the underlying writer.
    @param self The buffered writer instance
    @return A future resolving when the flush is complete
]]
function BufWriterMT:flush(): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    if this._pos > 0 then
        this._inner:write_all(buffer.tostring(this._buf):sub(1, this._pos)):and_then(function(): any
            this._pos = 0
            return this._inner:flush()
        end):and_then(function(): any
            resolve(nil)
            return nil
        end):inspect_err(reject)
    else
        this._inner:flush():and_then(function(): any
            resolve(nil)
            return nil
        end):inspect_err(reject)
    end
    return future
end

--[[
    Attempts to write bytes into the buffered writer.
    @param self The buffered writer instance
    @param buf The data to write (buffer or string)
    @param offset Optional offset in the data to start reading
    @param len Optional number of bytes to write
    @return A future resolving to the number of bytes written
]]
function BufWriterMT:write(buf: buffer | string, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    local src = if type(buf) == "string" then buffer.fromstring(buf) else buf
    local off = offset or 0
    local l = len or buffer.len(src)
    local capacity = buffer.len(this._buf)
    
    if this._pos + l > capacity then
        (self :: Writer):flush():and_then(function(): any
            if l >= capacity then 
                return this._inner:write(src, off, l) 
            else
                buffer.copy(this._buf, this._pos, src, off, l)
                this._pos += l
                return Async.resolved(l)
            end
        end):and_then(function(n): any
            resolve(n :: number)
            return nil
        end):inspect_err(reject)
    else
        buffer.copy(this._buf, this._pos, src, off, l)
        this._pos += l
        resolve(l)
    end
    return future
end

--[[
    Attempts to write all bytes from the provided buffer or string.
    @param self The buffered writer instance
    @param buf The data to write
    @return A future resolving when all data is written
]]
function BufWriterMT:write_all(buf: buffer | string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        local len = if type(buf) == "string" then #buf else buffer.len(buf)
        while total < len do
            local n, ok = (self :: Writer):write(buf, total, len - total):Wait()
            if not ok then reject(n :: any); return end
            total += n :: number
        end
        resolve(nil)
    end)
    return future
end

return BufWriter
