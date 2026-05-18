--!strict
-- luks-std/IO/BufReader/init.luau
-- Buffered reader implementation for efficient small reads

local Async = require("@self/../../async")
local types = require("@self/../types")

local DEFAULT_CAPACITY = 8192

type Self = {
    _inner: types.Reader,
    _buf: buffer,
    _pos: number,
    _cap: number,
}

type BufRead = types.BufRead
type IoError = types.IoError

local BufReader = {}
local BufReaderMT = {}
BufReaderMT.__index = BufReaderMT

--[[
    Creates a new BufReader wrapping an inner reader.
    @param inner The underlying Reader to buffer
    @param capacity Optional initial capacity for the internal buffer (default: 8192)
    @return A new BufRead instance
]]
function BufReader.new(inner: types.Reader, capacity: number?): BufRead
    local cap = capacity or DEFAULT_CAPACITY
    local self: Self = {
        _inner = inner,
        _buf = buffer.create(cap),
        _pos = 0,
        _cap = 0,
    }
    return (setmetatable(self, BufReaderMT) :: any) :: BufRead
end

--[[
    Ensures the internal buffer is filled, potentially reading from the underlying source.
    @param self The buffered reader instance
    @return A future resolving to the internal buffer
]]
function BufReaderMT:fill_buf(): Async.TaskFuture<buffer>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    if this._pos >= this._cap then
        this._inner:read(this._buf, 0, buffer.len(this._buf)):and_then(function(n): any
            this._pos = 0
            this._cap = n
            resolve(this._buf)
            return nil
        end):inspect_err(reject)
    else
        resolve(this._buf)
    end
    return future
end

--[[
    Marks a certain amount of bytes as consumed from the internal buffer.
    @param self The buffered reader instance
    @param amt The number of bytes to consume
]]
function BufReaderMT:consume(amt: number)
    local this: Self = self :: any
    this._pos = math.min(this._pos + amt, this._cap)
end

--[[
    Attempts to read bytes from the buffered reader into the provided buffer.
    @param self The buffered reader instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function BufReaderMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    local off = offset or 0
    local l = len or buffer.len(buf)
    
    if this._pos >= this._cap and l >= buffer.len(this._buf) then
        return this._inner:read(buf, off, l)
    end
    
    (self :: BufRead):fill_buf():and_then(function(): any
        local available = this._cap - this._pos
        local to_read = math.min(l, available)
        if to_read > 0 then
            buffer.copy(buf, off, this._buf, this._pos, to_read);
            (self :: BufRead):consume(to_read)
        end
        resolve(to_read)
        return nil
    end):inspect_err(reject)
    return future
end

--[[
    Reads all bytes from the buffered reader until EOF and returns them in a buffer.
    @param self The buffered reader instance
    @return A future resolving to the full buffer of bytes
]]
function BufReaderMT:read_to_end(): Async.TaskFuture<buffer>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local res = buffer.create(0)
        if this._cap > this._pos then
            local n = this._cap - this._pos;
            res = buffer.create(n);
            buffer.copy(res, 0, this._buf, this._pos, n);
            (self :: BufRead):consume(n)
        end
        local inner_res, ok = this._inner:read_to_end():Wait()
        if not ok then reject(inner_res :: any); return end
        local final = buffer.create(buffer.len(res) + buffer.len(inner_res))
        buffer.copy(final, 0, res)
        buffer.copy(final, buffer.len(res), inner_res)
        resolve(final)
    end)
    return future
end

--[[
    Reads all bytes from the buffered reader until EOF and returns them as a string.
    @param self The buffered reader instance
    @return A future resolving to the full string
]]
function BufReaderMT:read_to_string(): Async.TaskFuture<string>
    return (self :: BufRead):read_to_end():map(buffer.tostring)
end

--[[
    Attempts to read the exact number of bytes needed to fill the buffer.
    @param self The buffered reader instance
    @param buf The buffer to fill
    @param len The number of bytes to read
    @return A future resolving when the buffer is filled
]]
function BufReaderMT:read_exact(buf: buffer, len: number): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        while total < len do
            local n, ok = (self :: BufRead):read(buf, total, len - total):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then reject({ kind = "UnexpectedEof", message = "failed to fill whole buffer" } :: IoError); return end
            total += n :: number
        end
        resolve(nil)
    end)
    return future
end

--[[
    Reads from the buffered reader until the specified byte is found.
    @param self The buffered reader instance
    @param byte The byte to search for
    @return A future resolving to a buffer containing the data up to and including the byte
]]
function BufReaderMT:read_until(byte: number): Async.TaskFuture<buffer?>
    local this: Self = self :: any
    local target = byte % 256
    local future, resolve, reject = Async.new_future()
    local res_buf = buffer.create(0)
    
    local function process()
        (self :: BufRead):fill_buf():and_then(function(_): any
            local n = this._cap - this._pos
            if n == 0 then 
                resolve(if buffer.len(res_buf) == 0 then nil else res_buf)
                return nil
            end
            
            local found_idx = -1
            for i = this._pos, this._cap - 1 do
                if buffer.readu8(this._buf, i) == target then
                    found_idx = i
                    break
                end
            end
            
            if found_idx ~= -1 then
                local chunk_len = found_idx - this._pos + 1
                local new_res = buffer.create(buffer.len(res_buf) + chunk_len)
                buffer.copy(new_res, 0, res_buf)
                buffer.copy(new_res, buffer.len(res_buf), this._buf, this._pos, chunk_len)
                res_buf = new_res;
                (self :: BufRead):consume(chunk_len)
                resolve(res_buf)
                return nil
            else
                local chunk_len = this._cap - this._pos
                local new_res = buffer.create(buffer.len(res_buf) + chunk_len)
                buffer.copy(new_res, 0, res_buf)
                buffer.copy(new_res, buffer.len(res_buf), this._buf, this._pos, chunk_len)
                res_buf = new_res;
                (self :: BufRead):consume(chunk_len)
                process()
                return nil
            end
        end):inspect_err(reject)
    end
    process()
    return future
end

--[[
    Reads from the buffered reader until a newline character (LF) is found.
    @param self The buffered reader instance
    @return A future resolving to the line as a string
]]
function BufReaderMT:read_line(): Async.TaskFuture<string?>
    return (self :: BufRead):read_until(10):map(function(buf: buffer?)
        return if buf then buffer.tostring(buf :: buffer) else nil
    end)
end

--[[
    Returns an iterator over the lines of the buffered reader.
    @param self The buffered reader instance
    @return An iterator function returning strings
]]
function BufReaderMT:lines(): () -> string?
    return function()
        local line, ok = (self :: BufRead):read_line():Wait()
        if not ok then error(tostring(line)) end
        return line
    end
end

--[[
    Returns the current position within the internal buffer.
    @param self The buffered reader instance
    @return The numeric position
]]
function BufReaderMT:pos(): number
    return (self :: any)._pos
end

--[[
    Returns the total capacity of the internal buffer.
    @param self The buffered reader instance
    @return The numeric capacity
]]
function BufReaderMT:cap(): number
    return (self :: any)._cap
end

-- Export metatable
(BufReader :: any)._MT = BufReaderMT

return BufReader
