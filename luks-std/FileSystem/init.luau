--!strict

--[[
    FileSystem Module — Native file system access for Luau.
    Provides direct access to host storage manipulation, re-exporting
    standard `std::fs` functionality robustly.

    Synchronous APIs propagate internal operating system or runtime errors
    directly as catchable Lua runtime errors via `pcall`:
        local ok, data = pcall(FileSystem.readFile, "path/to/file")
]]

local Signal = require("@self/../Signal")

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local nativeName = "fs"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load FileSystem native library")

-- ---------------------------------------------------------------------------
-- Public Types
-- ---------------------------------------------------------------------------

--[[
    Metadata associated with a host file system entity.
]]
export type FileMetadata = {
    --[[ True if the entity is a regular file. ]]
    is_file: boolean,
    --[[ True if the entity is a directory. ]]
    is_dir: boolean,
    --[[ True if the entity is a symbolic link. ]]
    is_symlink: boolean,
    --[[ Physical payload storage allocation length in bytes. ]]
    size: number,
    --[[ Epoch creation timestamp computed in floating seconds. ]]
    created: number,
    --[[ Epoch modification timestamp computed in floating seconds. ]]
    modified: number,
    --[[ Epoch recent reference access timestamp computed in floating seconds. ]]
    accessed: number,
    --[[ True if the entity prevents write operations. ]]
    readonly: boolean,
}

--[[
    Container encapsulating the resulting states of non-blocking background tasks.
]]
export type AsyncFsResult<T> = {
    --[[ True if the execution finished without encountering runtime errors. ]]
    ok: boolean,
    --[[ Successful typed output emitted from the evaluation. ]]
    result: T?,
    --[[ Textual diagnostic OS exception message if execution failed. ]]
    error: string?,
}

-- ---------------------------------------------------------------------------
-- Module Interface
-- ---------------------------------------------------------------------------

local FileSystem = {}

--[[
    Reads the complete contents of a target path into a UTF-8 string buffer.
    Raises a runtime error if the path does not resolve or prevents reads.

    @param path Target location identifier string.
    @return File content text payload.

    @example
        local text = FileSystem.readFile("data.json")
]]
function FileSystem.readFile(path: string): string
    return native.readFile(path)
end

--[[
    Overwrites or instantiates a designated file target saving given string payload.
    Raises a runtime error if parent folders are missing or access is restricted.

    @param path Target file absolute or relative location.
    @param contents Text payload bytes to persist.
]]
function FileSystem.writeFile(path: string, contents: string)
    native.writeFile(path, contents)
end

--[[
    Collects string identifiers mapped to individual entries inside a specific directory.
    Raises a runtime error if the path references a non-directory entity.

    @param path Target folder descriptor.
    @return Array table populated with child entry names.
]]
function FileSystem.readDir(path: string): { string }
    return native.readDir(path)
end

--[[
    Instantiates an empty folder path target directly.
    Raises a runtime error if intermediate structural frames do not exist.

    @param path Designated location path.
]]
function FileSystem.createDir(path: string)
    native.createDir(path)
end

--[[
    Recursively instantiates a folder path path along with all absent parent prefixes.

    @param path Entire structural hierarchy target string.
]]
function FileSystem.createDirAll(path: string)
    native.createDirAll(path)
end

--[[
    Destroys a designated host storage file node directly.

    @param path Path target pointing to a regular file.
]]
function FileSystem.removeFile(path: string)
    native.removeFile(path)
end

--[[
    Removes an isolated folder target provided it contains no child nodes.

    @param path Path target pointing to an empty directory.
]]
function FileSystem.removeDir(path: string)
    native.removeDir(path)
end

--[[
    Recursively deletes a folder target completely scrubbing all child subdirectories.

    @param path Target root hierarchy to remove.
]]
function FileSystem.removeDirAll(path: string)
    native.removeDirAll(path)
end

--[[
    Replicates the absolute content bytes of a source file entity into a target file path.

    @param from Origin storage target location.
    @param to Duplicate target destination location.
    @return Sum total allocated payload octets successfully transferred.
]]
function FileSystem.copy(from: string, to: string): number
    return native.copy(from, to)
end

--[[
    Modifies the structural identification mapping of an existing host node.

    @param from Active origin location pointer.
    @param to Desired output identity mapping target.
]]
function FileSystem.rename(from: string, to: string)
    native.rename(from, to)
end

--[[
    Inspects host kernel attributes and temporal bounds of a given storage frame.

    @param path Target entity location string.
    @return `FileMetadata` mapping detailed structural records.
]]
function FileSystem.metadata(path: string): FileMetadata
    return native.metadata(path)
end

--[[
    Verifies if a designated target path exists in the physical host storage.
    Does not raise exceptions on missing entities.

    @param path Target file or folder location string.
    @return True if the host confirms storage allocation.
]]
function FileSystem.exists(path: string): boolean
    return native.exists(path)
end

--[[ Confirms if the referenced target path points specifically to a regular file. ]]
function FileSystem.isFile(path: string): boolean
    return native.isFile(path)
end

--[[ Confirms if the referenced target path points specifically to a directory. ]]
function FileSystem.isDir(path: string): boolean
    return native.isDir(path)
end

-- ---------------------------------------------------------------------------
-- Asynchronous Interface (Signal event loops evaluating inside task.spawn)
-- ---------------------------------------------------------------------------

local function createAsyncWrapper<T, Args...>(syncFn: (Args...) -> T): (Args...) -> Signal.Signal<AsyncFsResult<T>>
    return function(...: any)
        local args = { ... }
        local signal = Signal.new() :: Signal.SignalInternal<AsyncFsResult<T>>
        task.defer(function()
            local success, res = pcall(syncFn, table.unpack(args))
            if success then
                signal:Fire({ ok = true, result = res })
            else
                signal:Fire({ ok = false, error = tostring(res) })
            end
        end)
        return signal:Public()
    end
end

local function createAsyncVoidWrapper<Args...>(syncFn: (Args...) -> ()): (Args...) -> Signal.Signal<AsyncFsResult<boolean>>
    return function(...: any)
        local args = { ... }
        local signal = Signal.new() :: Signal.SignalInternal<AsyncFsResult<boolean>>
        task.defer(function()
            local success, err = pcall(syncFn, table.unpack(args))
            if success then
                signal:Fire({ ok = true, result = true })
            else
                signal:Fire({ ok = false, error = tostring(err) })
            end
        end)
        return signal:Public()
    end
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.readFile`. ]]
FileSystem.readFileAsync = createAsyncWrapper(FileSystem.readFile)

--[[ Non-blocking background evaluation equivalent of `FileSystem.writeFile`. ]]
FileSystem.writeFileAsync = createAsyncVoidWrapper(FileSystem.writeFile)

--[[ Non-blocking background evaluation equivalent of `FileSystem.readDir`. ]]
FileSystem.readDirAsync = createAsyncWrapper(FileSystem.readDir)

--[[ Non-blocking background evaluation equivalent of `FileSystem.createDir`. ]]
FileSystem.createDirAsync = createAsyncVoidWrapper(FileSystem.createDir)

--[[ Non-blocking background evaluation equivalent of `FileSystem.createDirAll`. ]]
FileSystem.createDirAllAsync = createAsyncVoidWrapper(FileSystem.createDirAll)

--[[ Non-blocking background evaluation equivalent of `FileSystem.removeFile`. ]]
FileSystem.removeFileAsync = createAsyncVoidWrapper(FileSystem.removeFile)

--[[ Non-blocking background evaluation equivalent of `FileSystem.removeDir`. ]]
FileSystem.removeDirAsync = createAsyncVoidWrapper(FileSystem.removeDir)

--[[ Non-blocking background evaluation equivalent of `FileSystem.removeDirAll`. ]]
FileSystem.removeDirAllAsync = createAsyncVoidWrapper(FileSystem.removeDirAll)

--[[ Non-blocking background evaluation equivalent of `FileSystem.copy`. ]]
FileSystem.copyAsync = createAsyncWrapper(FileSystem.copy)

--[[ Non-blocking background evaluation equivalent of `FileSystem.rename`. ]]
FileSystem.renameAsync = createAsyncVoidWrapper(FileSystem.rename)

--[[ Non-blocking background evaluation equivalent of `FileSystem.metadata`. ]]
FileSystem.metadataAsync = createAsyncWrapper(FileSystem.metadata)

--[[ Non-blocking background evaluation equivalent of `FileSystem.exists`. ]]
FileSystem.existsAsync = createAsyncWrapper(FileSystem.exists)

--[[ Non-blocking background evaluation equivalent of `FileSystem.isFile`. ]]
FileSystem.isFileAsync = createAsyncWrapper(FileSystem.isFile)

--[[ Non-blocking background evaluation equivalent of `FileSystem.isDir`. ]]
FileSystem.isDirAsync = createAsyncWrapper(FileSystem.isDir)

--[[ Module native structural binary target revision version. ]]
FileSystem.version = native.version :: string

return FileSystem
