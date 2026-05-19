--!strict
-- luks-std/IO/Cursor/init.luau
-- In-memory stream implementation for buffers and strings

local Async = require("@self/../../async")
local types = require("@self/../types")

type Self = {
    _data: buffer,
    _pos: number,
}

type Reader = types.Reader
type Writer = types.Writer
type Seeker = types.Seeker
type IoError = types.IoError

local Cursor = {}
local CursorMT = {}
CursorMT.__index = CursorMT

--[[
    Creates a new Cursor wrapping a buffer or string.
    The Cursor provides Seek, Read, and Write capabilities on in-memory data.
    @param data The initial data to wrap in the cursor
    @return A new Reader & Writer & Seeker instance (Cursor)
]]
function Cursor.new(data: buffer | string): Reader & Writer & Seeker
    local self: Self = {
        _data = if type(data) == "string" then buffer.fromstring(data) else data,
        _pos = 0,
    }
    return (setmetatable(self, CursorMT) :: any) :: Reader & Writer & Seeker
end

--[[
    Attempts to read bytes from the cursor into the provided buffer.
    @param self The cursor instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function CursorMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, _ = Async.new_future()
    local off = offset or 0
    local l = len or buffer.len(buf)
    local data_len = buffer.len(this._data)
    local remaining = data_len - this._pos
    local to_read = math.min(l, remaining)
    
    if to_read > 0 then
        buffer.copy(buf, off, this._data, this._pos, to_read)
        this._pos += to_read
    end
    resolve(to_read)
    return future
end

--[[
    Reads all remaining bytes from the cursor until EOF and returns them in a buffer.
    @param self The cursor instance
    @return A future resolving to the full buffer of bytes
]]
function CursorMT:read_to_end(): Async.TaskFuture<buffer>
    local this: Self = self :: any
    local future, resolve, _ = Async.new_future()
    local data_len = buffer.len(this._data)
    local remaining = data_len - this._pos
    local res = buffer.create(remaining)
    buffer.copy(res, 0, this._data, this._pos, remaining)
    this._pos = data_len
    resolve(res)
    return future
end

--[[
    Reads all remaining bytes from the cursor until EOF and returns them as a string.
    @param self The cursor instance
    @return A future resolving to the full string
]]
function CursorMT:read_to_string(): Async.TaskFuture<string>
    return (self :: Reader):read_to_end():map(buffer.tostring)
end

--[[
    Attempts to read the exact number of bytes needed to fill the buffer.
    @param self The cursor instance
    @param buf The buffer to fill
    @param len The number of bytes to read
    @return A future resolving when the buffer is filled
]]
function CursorMT:read_exact(buf: buffer, len: number): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future();
    (self :: Reader):read(buf, 0, len):and_then(function(n): any
        if n < len then
            reject({ kind = "UnexpectedEof", message = "failed to fill whole buffer" } :: IoError)
        else
            resolve(nil)
        end
        return nil
    end):inspect_err(reject)
    return future
end

--[[
    Attempts to write bytes from the provided buffer or string into the cursor.
    @param self The cursor instance
    @param buf The data to write
    @param offset Optional offset in the data to start reading
    @param len Optional number of bytes to write
    @return A future resolving to the number of bytes written
]]
function CursorMT:write(buf: buffer | string, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, _ = Async.new_future()
    local src = if type(buf) == "string" then buffer.fromstring(buf) else buf
    local off = offset or 0
    local l = len or buffer.len(src)
    
    if this._pos + l > buffer.len(this._data) then
        local new_data = buffer.create(this._pos + l)
        buffer.copy(new_data, 0, this._data)
        this._data = new_data
    end
    
    buffer.copy(this._data, this._pos, src, off, l)
    this._pos += l
    resolve(l)
    return future
end

--[[
    Attempts to write all bytes from the provided buffer or string.
    @param self The cursor instance
    @param buf The data to write
    @return A future resolving when all data is written
]]
function CursorMT:write_all(buf: buffer | string): Async.TaskFuture<any>
    return (self :: Writer):write(buf):and_then(function(): any
        return nil
    end)
end

--[[
    Flushes the cursor (no-op for in-memory stream).
    @param self The cursor instance
    @return A future resolving when the flush is complete
]]
function CursorMT:flush(): Async.TaskFuture<any>
    return Async.resolved(nil)
end

--[[
    Changes the current position in the cursor stream.
    @param self The cursor instance
    @param pos The position to seek to
    @return A future resolving to the new position
]]
function CursorMT:seek(pos: types.SeekFrom): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    local new_pos = this._pos
    if pos.kind == "Start" then
        new_pos = pos.pos
    elseif pos.kind == "End" then
        new_pos = buffer.len(this._data) + pos.pos
    elseif pos.kind == "Current" then
        new_pos = this._pos + pos.pos
    end
    
    if new_pos < 0 then
        reject({ kind = "InvalidInput", message = "Attempted to seek to a negative position" } :: IoError)
    else
        this._pos = new_pos
        resolve(this._pos)
    end
    return future
end

--[[
    Returns a reference to the underlying buffer.
    @param self The cursor instance
    @return The internal data buffer
]]
function CursorMT:get_ref(): buffer
    return (self :: any)._data
end

--[[
    Returns the current position in the cursor stream.
    @param self The cursor instance
    @return The numeric position
]]
function CursorMT:position(): Async.TaskFuture<number>
    return Async.resolved((self :: any)._pos)
end

-- Export metatable
(Cursor :: any)._MT = CursorMT

return Cursor
