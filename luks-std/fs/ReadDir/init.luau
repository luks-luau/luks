--!strict
-- luks-std/FS/ReadDir/init.luau
local Async = require("@self/../../async")
local types = require("types")
local Metadata = require("Metadata")

type Self = {
    _handle: any, -- Native handle (internally any is okay)
}

local ReadDirMT = {}
ReadDirMT.__index = ReadDirMT

local EntryMT = {}
EntryMT.__index = EntryMT

-- Native layer link
local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    return (try_load("@self/../lib/luks_fs")
        or try_load("@self/../../../target/release/luks_fs")
        or try_load("@self/../../../target/debug/luks_fs")
        or error("Could not load FS native library")) :: any
end)()

--[[
    Returns the next entry in the directory.
    @param self The readdir instance
    @return A future resolving to the next DirEntry or nil if reached EOF
]]
function ReadDirMT:next(): Async.TaskFuture<types.DirEntry?>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        if not this._handle then
            reject({ kind = "IoError", message = "readdir handle is closed" } :: types.FsError)
            return
        end
        local ok, result = pcall(native.readdir_next, this._handle)
        if not ok then
            reject({ kind = "IoError", message = tostring(result) } :: types.FsError)
        elseif result then
            resolve(setmetatable(result, EntryMT) :: any)
        else
            resolve(nil)
        end
    end)
    return future
end

--[[
    Closes the readdir handle.
    @param self The readdir instance
]]
function ReadDirMT:close()
    (self :: any)._handle = nil
end

--[[
    Fetches metadata for the entry.
    @param self The directory entry instance
    @return A future resolving to the metadata
]]
function EntryMT:metadata(): Async.TaskFuture<types.Metadata>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.metadata, self.path, true)
        if ok then resolve(Metadata.new(result)) else reject({ kind = "IoError", message = tostring(result) } :: types.FsError) end
    end)
    return future
end

--[[
    Fetches the file type for the entry.
    @param self The directory entry instance
    @return A future resolving to the file type
]]
function EntryMT:file_type(): Async.TaskFuture<types.FileType>
    return self:metadata():map(function(m) return m:file_type() end)
end

local ReadDirObj = {}

--[[
    Internal: Creates a new ReadDir instance from a native handle.
    @param handle The native readdir handle
    @return A new ReadDir instance
]]
function ReadDirObj.new(handle: any): types.ReadDir
    local self: Self = { _handle = handle }
    return setmetatable(self, ReadDirMT) :: any
end

return ReadDirObj
