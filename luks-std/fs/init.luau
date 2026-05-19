--!strict
-- luks-std/FS/init.luau
-- FileSystem module following Rust std::fs API

local Async = require("@self/../async")
local types = require("@self/types")

-- Sub-modules
local File = require("@self/File")
local OpenOptions = require("@self/OpenOptions")
local Metadata = require("@self/Metadata")
local FileType = require("@self/FileType")
local Permissions = require("@self/Permissions")
local ReadDir = require("@self/ReadDir")

--[[ ---------------------------------------------------------------------------
    GLOBAL TYPES (Re-exports)
---------------------------------------------------------------------------- ]]
export type FsError = types.FsError
export type Metadata = types.Metadata
export type FileType = types.FileType
export type Permissions = types.Permissions
export type DirEntry = types.DirEntry
export type ReadDir = types.ReadDir
export type File = types.File

--[[ ---------------------------------------------------------------------------
    MODULE DEFINITION
---------------------------------------------------------------------------- ]]
local FS = {}

--[[ Handle for an open file on the filesystem. ]]
FS.File = File
--[[ Builder for configuring how files are opened. ]]
FS.OpenOptions = OpenOptions
--[[ Metadata information for a file or directory. ]]
FS.Metadata = Metadata
--[[ Information about a file's type (file, directory, or symlink). ]]
FS.FileType = FileType
--[[ Cross-platform representation of file permissions. ]]
FS.Permissions = Permissions
--[[ Iterator for reading the contents of a directory. ]]
FS.ReadDir = ReadDir

--[[ Native layer for FS ]]
local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    local lib = try_load("@self/lib/luks_fs")
        or try_load("@self/../../target/release/luks_fs")
        or try_load("@self/../../target/debug/luks_fs")
        or error("Could not load FS native library")
    return lib :: any
end)()

--[[ ---------------------------------------------------------------------------
    STATIC UTILITIES
---------------------------------------------------------------------------- ]]

--[[
    Reads the entire contents of a file into a string.
    @param path The path to the file to read
    @return A future resolving to the file contents as a string
]]
function FS.read_to_string(path: string): Async.TaskFuture<string>
    return FS.File.open(path):and_then(function(file)
        return file:read_to_string()
    end)
end

--[[
    Reads the entire contents of a file into a buffer.
    @param path The path to the file to read
    @return A future resolving to the file contents in a buffer
]]
function FS.read(path: string): Async.TaskFuture<buffer>
    return FS.File.open(path):and_then(function(file)
        return file:read_to_end()
    end)
end

--[[
    Writes the provided contents to a file, creating it if it doesn't exist.
    Overwrites the file if it already exists.
    @param path The path to the file to write
    @param contents The data to write (string or buffer)
    @return A future resolving when the write is complete
]]
function FS.write(path: string, contents: string | buffer): Async.TaskFuture<any>
    return FS.File.create(path):and_then(function(file)
        return file:write_all(contents):inspect(function()
            file:close()
        end)
    end)
end

--[[
    Copies the contents of one file to another.
    @param from The source file path
    @param to The destination file path
    @return A future resolving to the number of bytes copied
]]
function FS.copy(from: string, to: string): Async.TaskFuture<number>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.copy, from, to)
        if ok then resolve(result) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.rename(from: string, to: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.rename, from, to)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.remove_file(path: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.remove_file, path)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.metadata(path: string): Async.TaskFuture<Metadata>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.metadata, path, true)
        if ok then resolve(Metadata.new(result)) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.symlink_metadata(path: string): Async.TaskFuture<Metadata>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.metadata, path, false)
        if ok then resolve(Metadata.new(result)) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.canonicalize(path: string): Async.TaskFuture<string>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.canonicalize, path)
        if ok then resolve(result) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.read_dir(path: string): Async.TaskFuture<ReadDir>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.read_dir, path)
        if ok then resolve(ReadDir.new(result)) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.create_dir(path: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.create_dir, path, false)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.create_dir_all(path: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.create_dir, path, true)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.remove_dir(path: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.remove_dir, path, false)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.remove_dir_all(path: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.remove_dir, path, true)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.hard_link(src: string, dst: string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.hard_link, src, dst)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

function FS.read_link(path: string): Async.TaskFuture<string>
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.read_link, path)
        if ok then resolve(result) else reject({ kind = "IoError", message = tostring(result) } :: FsError) end
    end)
    return future
end

local function resolvePath(input: string): string
    if input:match("^/") or input:match("^\\") or input:match("^[A-Za-z]:") then
        return input
    end

    local scriptDir = "."
    local moduleFolder = "."
    local found = false

    local level = 3
    while true do
        local rawSource = debug.info(level, "s")
        if not rawSource then
            break
        end
        local source: string = rawSource

        local filePath: string? = nil
        if source:sub(1, 1) == "@" then
            filePath = source:sub(2)
        else
            local inner = source:match("^%[string \"(.*)\"%]$")
            if inner then
                local innerStr: string = inner
                if innerStr:sub(1, 1) == "@" then
                    filePath = innerStr:sub(2)
                elseif innerStr:match("^/") or innerStr:match("^\\") or innerStr:match("^[A-Za-z]:") or innerStr:match("%.luau$") or innerStr:match("%.lua$") then
                    filePath = innerStr
                end
            elseif source:match("^/") or source:match("^\\") or source:match("^[A-Za-z]:") then
                filePath = source
            end
        end

        if filePath then
            local pathStr: string = filePath
            if pathStr:sub(1, 4) == "\\\\?\\" then
                pathStr = pathStr:sub(5)
            end

            local dir, filename = pathStr:match("^(.*)[/\\]([^/\\]*)$")
            if not dir then
                filename = pathStr
                dir = "."
            end
            local dirStr: string = dir :: string

            if filename == "init.luau" or filename == "init.lua" then
                moduleFolder = dirStr
                local parentDir = dirStr:match("^(.*)[/\\][^/\\]*$")
                if parentDir and parentDir ~= "" then
                    scriptDir = parentDir
                else
                    scriptDir = "."
                end
            else
                moduleFolder = dirStr
                scriptDir = dirStr
            end
            found = true
            break
        end
        level += 1
    end

    if not found then
        scriptDir = "."
        moduleFolder = "."
    end

    if input == "@self" then
        return moduleFolder
    end

    local selfSub = input:match("^@self[/\\](.*)$")
    if selfSub then
        return moduleFolder .. "/" .. selfSub
    end

    local cleanInput = input
    if cleanInput:sub(1, 2) == "./" or cleanInput:sub(1, 2) == ".\\" then
        cleanInput = cleanInput:sub(3)
    end
    return scriptDir .. "/" .. cleanInput
end

--[[
    Resolves a path relative to the caller's script location, similar to require().
    Supports '@self' for the current module folder and './' for the script's directory.
    If empty path provided, it will resolve to the current script's directory.
    @param path The path string to resolve
    @return The resolved absolute path
]]
function FS.resolve(path: string?): string
    return resolvePath(if path and path ~= "" then path else ".")
end

return FS
