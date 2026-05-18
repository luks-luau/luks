--!strict
-- luks-std/FS/File/init.luau
-- File object implementing IO traits

local Async = require("@self/../../async")
local IO = require("@self/../../io")
local types = require("types")
local OpenOptions = require("OpenOptions")

type Self = {
    _handle: any, -- Native userdata (internally any is okay)
}

type File = types.File
type IoError = IO.IoError

local FileObj = {}
local FileMT = {}
FileMT.__index = FileMT

--[[ Native layer for FS ]]
local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    local lib = try_load("@self/../lib/luks_fs")
        or try_load("@self/../../../target/release/luks_fs")
        or try_load("@self/../../../target/debug/luks_fs")
        or error("Could not load FS native library")
    return lib :: any
end)()

--[[
    Internal: Opens a file with specific options.
]]
function FileObj.open_with_options(path: string, options: any): Async.TaskFuture<File>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local handle, err = native.open(path, options)
        if handle then
            local self: Self = { _handle = handle }
            resolve(setmetatable(self, FileMT) :: any)
        else
            reject({ kind = "IoError", message = err or "failed to open file" } :: IoError)
        end
    end)
    return future
end

-- Inject the opener into OpenOptions to break circular dependency
OpenOptions._opener = FileObj.open_with_options

--[[
    Opens a file in read-only mode.
    @param path The path to the file to open
    @return A future resolving to the open File instance
]]
function FileObj.open(path: string): Async.TaskFuture<File>
    return OpenOptions.new():read(true):open(path)
end

--[[
    Opens a file in write-only mode, creating it if it doesn't exist and truncating it.
    @param path The path to the file to create
    @return A future resolving to the open File instance
]]
function FileObj.create(path: string): Async.TaskFuture<File>
    return OpenOptions.new():write(true):create(true):truncate(true):open(path)
end

--[[
    Attempts to read bytes from the file into the provided buffer.
    @param self The file instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function FileMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "file handle is closed" } :: IoError)
            return
        end
        local n, err = native.read(this._handle, buf, offset or 0, len or buffer.len(buf))
        if n then resolve(n) else reject({ kind = "IoError", message = err or "read failed" } :: IoError) end
    end)
    return future
end

--[[
    Reads all bytes from the file until EOF and returns them in a buffer.
    @param self The file instance
    @return A future resolving to the full buffer of bytes
]]
function FileMT:read_to_end(): Async.TaskFuture<buffer>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local res = buffer.create(0)
        local tmp = buffer.create(8192)
        while true do
            local n, ok = (self :: IO.Reader):read(tmp):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then break end
            local num: number = n :: number
            local new_res = buffer.create(buffer.len(res) + num)
            buffer.copy(new_res, 0, res)
            buffer.copy(new_res, buffer.len(res), tmp, 0, num)
            res = new_res
        end
        resolve(res)
    end)
    return future
end

--[[
    Reads all bytes from the file until EOF and returns them as a string.
    @param self The file instance
    @return A future resolving to the full string
]]
function FileMT:read_to_string(): Async.TaskFuture<string>
    return (self :: IO.Reader):read_to_end():map(buffer.tostring)
end

--[[
    Attempts to read the exact number of bytes needed to fill the buffer.
    @param self The file instance
    @param buf The buffer to fill
    @param len The number of bytes to read
    @return A future resolving when the buffer is filled
]]
function FileMT:read_exact(buf: buffer, len: number): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        while total < len do
            local n, ok = (self :: IO.Reader):read(buf, total, len - total):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then
                reject({ kind = "UnexpectedEof", message = "failed to fill whole buffer" } :: IoError)
                return
            end
            total += n :: number
        end
        resolve(nil)
    end)
    return future
end

--[[
    Attempts to write bytes from the provided buffer or string into the file.
    @param self The file instance
    @param buf The data to write
    @param offset Optional offset in the data to start reading
    @param len Optional number of bytes to write
    @return A future resolving to the number of bytes written
]]
function FileMT:write(buf: buffer | string, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "file handle is closed" } :: IoError)
            return
        end
        local n, err = native.write(this._handle, buf, offset or 0, len or (if type(buf) == "string" then #buf else buffer.len(buf)))
        if n then resolve(n) else reject({ kind = "IoError", message = err or "write failed" } :: IoError) end
    end)
    return future
end

--[[
    Attempts to write all bytes from the provided buffer or string.
    @param self The file instance
    @param buf The data to write
    @return A future resolving when all data is written
]]
function FileMT:write_all(buf: buffer | string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        local len = if type(buf) == "string" then #buf else buffer.len(buf)
        while total < len do
            local n, ok = (self :: IO.Writer):write(buf, total, len - total):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then
                reject({ kind = "WriteZero", message = "failed to write whole buffer" } :: IoError)
                return
            end
            total += n :: number
        end
        resolve(nil)
    end)
    return future
end

--[[
    Synchronizes all OS-internal metadata and data to disk.
    @param self The file instance
    @return A future resolving when the sync is complete
]]
function FileMT:sync_all(): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "file handle is closed" } :: IoError)
            return
        end
        local ok, err = native.sync(this._handle, false)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "sync_all failed" } :: IoError) end
    end)
    return future
end

--[[
    Synchronizes the data of the file to disk (metadata might be skipped).
    @param self The file instance
    @return A future resolving when the sync is complete
]]
function FileMT:sync_data(): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "file handle is closed" } :: IoError)
            return
        end
        local ok, err = native.sync(this._handle, true)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "sync_data failed" } :: IoError) end
    end)
    return future
end

--[[
    Truncates or extends the file to the specified size.
    @param self The file instance
    @param size The new size in bytes
    @return A future resolving when the operation is complete
]]
function FileMT:set_len(size: number): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "file handle is closed" } :: IoError)
            return
        end
        local ok, err = native.set_len(this._handle, size)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "set_len failed" } :: IoError) end
    end)
    return future
end

--[[
    Alias for sync_all().
    @param self The file instance
    @return A future resolving when the flush is complete
]]
function FileMT:flush(): Async.TaskFuture<any>
    return self:sync_all()
end

--[[
    Fetches metadata for the open file.
    @param self The file instance
    @return A future resolving to the metadata
]]
function FileMT:metadata(): Async.TaskFuture<types.Metadata>
    error("File:metadata() not implemented in native layer yet (use FS.metadata(path))")
end

--[[
    Changes the current position in the file.
    @param self The file instance
    @param pos The position to seek to
    @return A future resolving to the new position
]]
function FileMT:seek(pos: IO.SeekFrom): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    local whence = 0
    local p = 0
    if pos.kind == "Start" then whence = 0; p = pos.pos
    elseif pos.kind == "Current" then whence = 1; p = pos.pos
    elseif pos.kind == "End" then whence = 2; p = pos.pos end
    
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "file handle is closed" } :: IoError)
            return
        end
        local n, err = native.seek(this._handle, whence, p)
        if n then resolve(n) else reject({ kind = "IoError", message = err or "seek failed" } :: IoError) end
    end)
    return future
end

--[[
    Returns the current position in the file.
    @param self The file instance
    @return The current position in bytes from the start
]]
function FileMT:position(): number
    local res, ok = (self :: IO.Seeker):seek({ kind = "Current", pos = 0 }):Wait()
    if not ok then error(tostring(res)) end
    return res :: number
end

--[[
    Creates a new reader that is limited to a certain number of bytes.
    @param self The file instance
    @param limit The maximum number of bytes to read
    @return A new Reader instance
]]
function FileMT:take(limit: number) return IO.Take.new(self, limit) end

--[[
    Chains two readers together.
    @param self The file instance
    @param other The second reader
    @return A new Reader instance
]]
function FileMT:chain(other: IO.Reader) return IO.Chain.new(self, other) end

--[[
    Closes the file handle.
    @param self The file instance
]]
function FileMT:close()
    (self :: any)._handle = nil
end

-- Export metatable for augmentation if needed
(FileObj :: any)._MT = FileMT

return FileObj
