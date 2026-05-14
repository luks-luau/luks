--!strict
--!native
--!optimize 2

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
        local fallback: string = ((getfenv(0)) :: any).__script_dir__ or "."
        if fallback:sub(1, 4) == "\\\\?\\" then
            fallback = fallback:sub(5)
        end
        scriptDir = fallback
        moduleFolder = fallback
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
    Reads the complete contents of a target path into a UTF-8 string buffer.
    Raises a runtime error if the path does not resolve or prevents reads.

    @param path Target location identifier string.
    @return File content text payload.

    @example
        local text = FileSystem.readFile("data.json")
]]
function FileSystem.readFile(path: string): string
    return native.readFile(resolvePath(path))
end

--[[
    Overwrites or instantiates a designated file target saving given string payload.
    Raises a runtime error if parent folders are missing or access is restricted.

    @param path Target file absolute or relative location.
    @param contents Text payload bytes to persist.
]]
function FileSystem.writeFile(path: string, contents: string)
    native.writeFile(resolvePath(path), contents)
end

--[[
    Collects string identifiers mapped to individual entries inside a specific directory.
    Raises a runtime error if the path references a non-directory entity.

    @param path Target folder descriptor.
    @return Array table populated with child entry names.
]]
function FileSystem.readDir(path: string): { string }
    return native.readDir(resolvePath(path))
end

--[[
    Instantiates an empty folder path target directly.
    Raises a runtime error if intermediate structural frames do not exist.

    @param path Designated location path.
]]
function FileSystem.createDir(path: string)
    native.createDir(resolvePath(path))
end

--[[
    Recursively instantiates a folder path along with all absent parent prefixes.

    @param path Entire structural hierarchy target string.
]]
function FileSystem.createDirAll(path: string)
    native.createDirAll(resolvePath(path))
end

--[[
    Destroys a designated host storage file node directly.

    @param path Path target pointing to a regular file.
]]
function FileSystem.removeFile(path: string)
    native.removeFile(resolvePath(path))
end

--[[
    Removes an isolated folder target provided it contains no child nodes.

    @param path Path target pointing to an empty directory.
]]
function FileSystem.removeDir(path: string)
    native.removeDir(resolvePath(path))
end

--[[
    Recursively deletes a folder target completely scrubbing all child subdirectories.

    @param path Target root hierarchy to remove.
]]
function FileSystem.removeDirAll(path: string)
    native.removeDirAll(resolvePath(path))
end

--[[
    Replicates the absolute content bytes of a source file entity into a target file path.

    @param from Origin storage target location.
    @param to Duplicate target destination location.
    @return Sum total allocated payload octets successfully transferred.
]]
function FileSystem.copy(from: string, to: string): number
    return native.copy(resolvePath(from), resolvePath(to))
end

--[[
    Modifies the structural identification mapping of an existing host node.

    @param from Active origin location pointer.
    @param to Desired output identity mapping target.
]]
function FileSystem.rename(from: string, to: string)
    native.rename(resolvePath(from), resolvePath(to))
end

--[[
    Inspects host kernel attributes and temporal bounds of a given storage frame.

    @param path Target entity location string.
    @return `FileMetadata` mapping detailed structural records.
]]
function FileSystem.metadata(path: string): FileMetadata
    return native.metadata(resolvePath(path))
end

--[[
    Verifies if a designated target path exists in the physical host storage.
    Does not raise exceptions on missing entities.

    @param path Target file or folder location string.
    @return True if the host confirms storage allocation.
]]
function FileSystem.exists(path: string): boolean
    return native.exists(resolvePath(path))
end

--[[ Confirms if the referenced target path points specifically to a regular file. ]]
function FileSystem.isFile(path: string): boolean
    return native.isFile(resolvePath(path))
end

--[[ Confirms if the referenced target path points specifically to a directory. ]]
function FileSystem.isDir(path: string): boolean
    return native.isDir(resolvePath(path))
end

-- ---------------------------------------------------------------------------
-- Asynchronous Interface (Signal event loops evaluating inside task.spawn)
-- ---------------------------------------------------------------------------

local function createAsyncResultSignal<T>(fn: (...any) -> T, ...: any): Signal.Signal<AsyncFsResult<T>>
    local args = { ... }
    local signal = Signal.new() :: Signal.SignalInternal<AsyncFsResult<T>>
    task.defer(function()
        local success, res = pcall(fn, table.unpack(args))
        if success then
            signal:Fire({ ok = true, result = res })
        else
            signal:Fire({ ok = false, error = tostring(res) })
        end
    end)
    return signal:Public()
end

local function createAsyncVoidSignal(fn: (...any) -> (), ...: any): Signal.Signal<AsyncFsResult<boolean>>
    local args = { ... }
    local signal = Signal.new() :: Signal.SignalInternal<AsyncFsResult<boolean>>
    task.defer(function()
        local success, res = pcall(fn :: (...any) -> any, table.unpack(args))
        if success then
            signal:Fire({ ok = true, result = true })
        else
            signal:Fire({ ok = false, error = tostring(res) })
        end
    end)
    return signal:Public()
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.readFile`. ]]
function FileSystem.readFileAsync(path: string): Signal.Signal<AsyncFsResult<string>>
    return createAsyncResultSignal(native.readFile, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.writeFile`. ]]
function FileSystem.writeFileAsync(path: string, contents: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.writeFile, resolvePath(path), contents)
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.readDir`. ]]
function FileSystem.readDirAsync(path: string): Signal.Signal<AsyncFsResult<{ string }>>
    return createAsyncResultSignal(native.readDir, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.createDir`. ]]
function FileSystem.createDirAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.createDir, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.createDirAll`. ]]
function FileSystem.createDirAllAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.createDirAll, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.removeFile`. ]]
function FileSystem.removeFileAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.removeFile, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.removeDir`. ]]
function FileSystem.removeDirAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.removeDir, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.removeDirAll`. ]]
function FileSystem.removeDirAllAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.removeDirAll, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.copy`. ]]
function FileSystem.copyAsync(from: string, to: string): Signal.Signal<AsyncFsResult<number>>
    return createAsyncResultSignal(native.copy, resolvePath(from), resolvePath(to))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.rename`. ]]
function FileSystem.renameAsync(from: string, to: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncVoidSignal(native.rename, resolvePath(from), resolvePath(to))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.metadata`. ]]
function FileSystem.metadataAsync(path: string): Signal.Signal<AsyncFsResult<FileMetadata>>
    return createAsyncResultSignal(native.metadata, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.exists`. ]]
function FileSystem.existsAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncResultSignal(native.exists, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.isFile`. ]]
function FileSystem.isFileAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncResultSignal(native.isFile, resolvePath(path))
end

--[[ Non-blocking background evaluation equivalent of `FileSystem.isDir`. ]]
function FileSystem.isDirAsync(path: string): Signal.Signal<AsyncFsResult<boolean>>
    return createAsyncResultSignal(native.isDir, resolvePath(path))
end

--[[ Module native structural binary target revision version. ]]
FileSystem.version = native.version :: string

return FileSystem
