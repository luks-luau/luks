--!strict
-- luks-std/IO/init.luau
-- Standalone Rust-style I/O library for luks-luau

local Async = require("@self/../async")
local types = require("@self/types")

--[[ ---------------------------------------------------------------------------
    GLOBAL TYPES (Re-exports from types.luau)
---------------------------------------------------------------------------- ]]

export type IoError = types.IoError
export type SeekFrom = types.SeekFrom
export type Reader = types.Reader
export type Writer = types.Writer
export type Seeker = types.Seeker
export type BufRead = types.BufRead

--[[ ---------------------------------------------------------------------------
    NATIVE INTERFACE TYPE
---------------------------------------------------------------------------- ]]
type NativeAPI = {
    stdin_read: (buf: buffer, offset: number, len: number) -> (number?, string?),
    stdout_write: (buf: buffer | string, offset: number, len: number) -> (number?, string?),
    stdout_flush: () -> (),
    stderr_write: (buf: buffer | string, offset: number, len: number) -> (number?, string?),
    stderr_flush: () -> (),
}

--[[ ---------------------------------------------------------------------------
    MODULE DEFINITION
---------------------------------------------------------------------------- ]]
local IO = {}

-- Forward declarations of submodules
--[[ A Reader that buffers data to reduce system calls and provide line reading. ]]
IO.BufReader = require("@self/BufReader")
--[[ A Writer that buffers data before flushing to the destination. ]]
IO.BufWriter = require("@self/BufWriter")
--[[ An in-memory stream that implements Reader, Writer, and Seeker. ]]
IO.Cursor = require("@self/Cursor")
--[[ A Reader that infinitely repeats a single byte. ]]
IO.Repeat = require("@self/Repeat")
--[[ A Reader that is limited to a specific number of bytes. ]]
IO.Take = require("@self/Take")
--[[ A Reader that chains multiple readers together. ]]
IO.Chain = require("@self/Chain")

--[[ ---------------------------------------------------------------------------
    CENTRAL AUGMENTATION
---------------------------------------------------------------------------- ]]
local function augment_reader(mt: any)
    mt.take = function(self: Reader, limit: number)
        return IO.Take.new(self, limit)
    end
    mt.chain = function(self: Reader, other: Reader)
        return IO.Chain.new(self, other)
    end
end

augment_reader((IO.BufReader :: any)._MT)
augment_reader((IO.Cursor :: any)._MT)
augment_reader((IO.Repeat :: any)._MT)
augment_reader((IO.Take :: any)._MT)
augment_reader((IO.Chain :: any)._MT)

--[[ ---------------------------------------------------------------------------
    NATIVE LAYER
---------------------------------------------------------------------------- ]]
local native: NativeAPI = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    local lib = try_load("@self/lib/io")
        or try_load("@self/../../target/release/io")
        or try_load("@self/../../target/debug/io")
        or error("Could not load IO native library")
    return lib :: any
end)()

--[[ ---------------------------------------------------------------------------
    STANDARD STREAMS
---------------------------------------------------------------------------- ]]

--[[
    Returns a handle to the standard input stream of the current process.
    @return A Reader instance for stdin
]]
function IO.stdin(): Reader
    local obj = {}
    
    function obj:read(buf: buffer, offset: number?, len: number?)
        local future, resolve, reject = Async.new_future()
        task.defer(function()
            local n, err = native.stdin_read(buf, offset or 0, len or 0)
            if n then resolve(n) else reject({ kind = "IoError", message = err or "unknown error" } :: IoError) end
        end)
        return future
    end
    
    function obj:read_to_end()
        local future, resolve, reject = Async.new_future()
        task.spawn(function()
            local res = buffer.create(0)
            local tmp = buffer.create(8192)
            while true do
                local n, ok = (self :: Reader):read(tmp):Wait()
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

    function obj:read_to_string()
        return (self :: Reader):read_to_end():map(buffer.tostring)
    end

    function obj:read_exact(buf: buffer, len: number)
        local future, resolve, reject = Async.new_future()
        task.spawn(function()
            local total = 0
            while total < len do
                local n, ok = (self :: Reader):read(buf, total, len - total):Wait()
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
    
    function obj:take(limit: number) return IO.Take.new(self, limit) end
    function obj:chain(other: Reader) return IO.Chain.new(self, other) end

    return (obj :: any) :: Reader
end

--[[
    Returns a handle to the standard output stream of the current process.
    @return A Writer instance for stdout
]]
function IO.stdout(): Writer
    local obj = {}
    
    function obj:write(buf: buffer | string, offset: number?, len: number?)
        local future, resolve, reject = Async.new_future()
        task.defer(function()
            local n, err = native.stdout_write(buf, offset or 0, len or 0)
            if n then resolve(n) else reject({ kind = "IoError", message = err or "unknown error" } :: IoError) end
        end)
        return future
    end
    
    function obj:write_all(buf: buffer | string)
        local future, resolve, reject = Async.new_future()
        task.spawn(function()
            local total = 0
            local len = if type(buf) == "string" then #buf else buffer.len(buf)
            while total < len do
                local n, ok = (self :: Writer):write(buf, total, len - total):Wait()
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
    
    function obj:flush()
        local future, resolve, _ = Async.new_future()
        native.stdout_flush()
        resolve(nil)
        return future
    end
    
    return (obj :: any) :: Writer
end

--[[
    Returns a handle to the standard error stream of the current process.
    @return A Writer instance for stderr
]]
function IO.stderr(): Writer
    local obj = {}
    
    function obj:write(buf: buffer | string, offset: number?, len: number?)
        local future, resolve, reject = Async.new_future()
        task.defer(function()
            local n, err = native.stderr_write(buf, offset or 0, len or 0)
            if n then resolve(n) else reject({ kind = "IoError", message = err or "unknown error" } :: IoError) end
        end)
        return future
    end
    
    function obj:write_all(buf: buffer | string)
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
    
    function obj:flush()
        local future, resolve, _ = Async.new_future()
        native.stderr_flush()
        resolve(nil)
        return future
    end
    
    return (obj :: any) :: Writer
end

--[[ ---------------------------------------------------------------------------
    GLOBAL UTILITIES
---------------------------------------------------------------------------- ]]

--[[
    Copies the entire contents of a reader into a writer.
    @param reader The source reader
    @param writer The destination writer
    @return A future resolving to the number of bytes copied
]]
function IO.copy(reader: Reader, writer: Writer): Async.TaskFuture<number>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        local buf = buffer.create(8192)
        while true do
            local n, ok = reader:read(buf):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then break end
            local num: number = n :: number
            local err, w_ok = writer:write_all(buffer.tostring(buf):sub(1, num)):Wait()
            if not w_ok then reject(err :: any); return end
            total += num
        end
        resolve(total)
    end)
    return future
end

--[[
    Returns a reader that is always at EOF.
    @return A Reader instance
]]
function IO.empty(): Reader
    local obj = {}
    function obj:read() return Async.resolved(0) end
    function obj:read_to_end() return Async.resolved(buffer.create(0)) end
    function obj:read_to_string() return Async.resolved("") end
    function obj:read_exact() return Async.resolved(nil) end
    function obj:take(limit) return IO.Take.new(self, limit) end
    function obj:chain(other) return IO.Chain.new(self, other) end
    return (obj :: any) :: Reader
end

--[[
    Returns a reader that infinitely repeats a single byte.
    @param byte The byte to repeat
    @return A Reader instance
]]
function IO.repeat_byte(byte: number): Reader
    return (IO.Repeat.new(byte) :: any) :: Reader
end

--[[
    Returns a writer that successfully consumes and discards all data.
    @return A Writer instance
]]
function IO.sink(): Writer
    local obj = {}
    function obj:write(buf, _, len) 
        local l = len or (if type(buf) == "string" then #buf else buffer.len(buf))
        return Async.resolved(l) 
    end
    function obj:write_all() return Async.resolved(nil) end
    function obj:flush() return Async.resolved(nil) end
    return (obj :: any) :: Writer
end

return IO
