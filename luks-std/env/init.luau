--!strict
-- luks-std/env/init.luau
-- Complete Rust-style Environment API for luks-luau

local consts = require("@self/consts")

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local native = SafeLoadNative("@self/lib/env")
    or SafeLoadNative("@self/../../target/release/env")
    or SafeLoadNative("@self/../../target/debug/env")
    or error("Could not load Env native library")

--[[
    The Env module provides functions to inspect and manipulate the process environment,
    command-line arguments, and system paths.
]]
local Env = {}

--[[ 
    Submodule containing native system constants.
    Includes ARCH, OS, FAMILY, and file extensions.
]]
Env.consts = consts

--[[
    Returns the arguments that the program was started with.
    The first element is usually the path to the executable.
    
    @return An array of strings containing the command-line arguments.
]]
function Env.args(): { string }
    return native.args()
end

--[[
    Fetches the value of an environment variable.
    Returns nil if the variable is not set in the host environment.
    
    @param key The name of the environment variable.
    @return The value of the variable as a string, or nil if not found.
]]
function Env.var(key: string): string?
    return native.var(key)
end

--[[
    Returns a dictionary of all current environment variables.
    Captures a snapshot of the process environment at the moment of call.
    
    @return A table where keys are variable names and values are their contents.
]]
function Env.vars(): { [string]: string }
    return native.vars()
end

--[[
    Sets an environment variable to a new value for the current process.
    This change will be inherited by any child processes spawned hereafter.
    
    @param key The name of the environment variable to set.
    @param value The value to assign to the variable.
]]
function Env.setVar(key: string, value: string): ()
    native.set_var(key, value)
end

--[[
    Removes an environment variable from the current process.
    
    @param key The name of the environment variable to delete.
]]
function Env.removeVar(key: string): ()
    native.remove_var(key)
end

--[[
    Returns the current working directory of the process.
    
    @return The absolute path to the current directory, or nil if an error occurs.
]]
function Env.currentDir(): string?
    return native.current_dir()
end

--[[
    Changes the current working directory of the process.
    
    @param path The target directory path to switch to.
    @return A boolean indicating whether the operation succeeded.
]]
function Env.setCurrentDir(path: string): boolean
    return native.set_current_dir(path)
end

--[[
    Returns the full path of the current running executable.
    
    @return The absolute path to the executable, or nil if resolution fails.
]]
function Env.currentExe(): string?
    return native.current_exe()
end

--[[
    Returns the path of the system's temporary directory.
    
    @return The absolute path to the OS-designated temp folder.
]]
function Env.tempDir(): string
    return native.temp_dir()
end

--[[
    Joins multiple path segments into a single string using the OS-specific separator.
    Handles platform differences (e.g., ';' on Windows, ':' on Unix).
    
    @param paths An array of path segments to join.
    @return The combined path string, or nil if the paths could not be joined.
]]
function Env.joinPaths(paths: { string }): string?
    return native.join_paths(paths)
end

--[[
    Splits a path string into an array of individual paths using the OS-specific separator.
    Useful for parsing variables like $PATH or %PATH%.
    
    @param unparsed The raw string containing multiple paths separated by the OS delimiter.
    @return An array of strings, each representing a single path.
]]
function Env.splitPaths(unparsed: string): { string }
    return native.split_paths(unparsed)
end

return Env