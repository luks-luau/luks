--!strict
-- luks-std/FS/types.luau
local Async = require("@self/../async")
local IO = require("@self/../io")

--[[ Re-export of IoError for consistency in FS operations. ]]
export type IoError = IO.IoError
--[[ Alias for IoError specifically for filesystem operations. ]]
export type FsError = IoError

--[[ Represents the type of a file (file, directory, or symlink). ]]
export type FileType = {
    --[[ Returns true if the file type represents a directory. ]]
    is_dir: (self: FileType) -> boolean,
    --[[ Returns true if the file type represents a regular file. ]]
    is_file: (self: FileType) -> boolean,
    --[[ Returns true if the file type represents a symbolic link. ]]
    is_symlink: (self: FileType) -> boolean,
}

--[[ Represents the permissions of a file. ]]
export type Permissions = {
    --[[ Returns true if the file is read-only. ]]
    readonly: (self: Permissions) -> boolean,
    --[[ Sets whether the file is read-only. ]]
    set_readonly: (self: Permissions, readonly: boolean) -> (),
}

--[[ Metadata about a file or directory. ]]
export type Metadata = {
    --[[ Returns the file type. ]]
    file_type: (self: Metadata) -> FileType,
    --[[ Returns the permissions. ]]
    permissions: (self: Metadata) -> Permissions,
    --[[ Shortcut to check if it's a directory. ]]
    is_dir: (self: Metadata) -> boolean,
    --[[ Shortcut to check if it's a regular file. ]]
    is_file: (self: Metadata) -> boolean,
    --[[ Shortcut to check if it's a symlink. ]]
    is_symlink: (self: Metadata) -> boolean,
    --[[ Returns the size of the file in bytes. ]]
    len: (self: Metadata) -> number,
    --[[ Returns the last modified time as a Unix timestamp. ]]
    modified: (self: Metadata) -> number,
    --[[ Returns the last accessed time as a Unix timestamp. ]]
    accessed: (self: Metadata) -> number,
    --[[ Returns the creation time as a Unix timestamp. ]]
    created: (self: Metadata) -> number,
}

--[[ An entry returned by the ReadDir iterator. ]]
export type DirEntry = {
    --[[ The name of the file or directory. ]]
    name: string,
    --[[ The full path to the file or directory. ]]
    path: string,
    --[[
        Fetches the metadata for this entry.
        @param self The directory entry
        @return A future resolving to the metadata
    ]]
    metadata: (self: DirEntry) -> Async.TaskFuture<Metadata>,
    --[[
        Fetances the file type for this entry.
        @param self The directory entry
        @return A future resolving to the file type
    ]]
    file_type: (self: DirEntry) -> Async.TaskFuture<FileType>,
}

--[[ Iterator over the entries in a directory. ]]
export type ReadDir = {
    --[[
        Advances the iterator and returns the next entry.
        @param self The ReadDir instance
        @return A future resolving to the next DirEntry, or nil if at the end
    ]]
    next: (self: ReadDir) -> Async.TaskFuture<DirEntry?>,
}

--[[ Represents an open file on the filesystem. ]]
export type File = IO.Reader & IO.Writer & IO.Seeker & {
    --[[
        Synchronizes all OS-internal metadata and data to disk.
        @param self The file instance
        @return A future resolving when the sync is complete
    ]]
    sync_all: (self: File) -> Async.TaskFuture<any>,
    
    --[[
        Synchronizes the data of the file to disk (metadata might be skipped).
        @param self The file instance
        @return A future resolving when the sync is complete
    ]]
    sync_data: (self: File) -> Async.TaskFuture<any>,
    
    --[[
        Truncates or extends the file to the specified size.
        @param self The file instance
        @param size The new size in bytes
        @return A future resolving when the operation is complete
    ]]
    set_len: (self: File, size: number) -> Async.TaskFuture<any>,
    
    --[[
        Fetches metadata for the open file.
        @param self The file instance
        @return A future resolving to the metadata
    ]]
    metadata: (self: File) -> Async.TaskFuture<Metadata>,
    
    --[[
        Attempts to create a new handle to the same underlying file.
        @param self The file instance
        @return A future resolving to the new File instance
    ]]
    try_clone: (self: File) -> Async.TaskFuture<File>,
    
    --[[
        Closes the file handle.
        @param self The file instance
    ]]
    close: (self: File) -> (),
}

return {}
