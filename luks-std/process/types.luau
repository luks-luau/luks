--!strict
-- luks-std/Process/types.luau
local Async = require("../async")
local IO = require("../io")

--[[ Configuration for standard streams in a child process. ]]
export type StdioConfig = 
    --[[ Pipes the stream to the parent process. ]]
    "piped" | 
    --[[ Inherits the stream from the parent process. ]]
    "inherit" | 
    --[[ Discards the stream. ]]
    "null"

--[[ Represents the exit status of a process. ]]
export type ExitStatus = {
    --[[
        Returns true if the process exited successfully (code 0).
        @param self The exit status instance
        @return Boolean indicating success
    ]]
    success: (self: ExitStatus) -> boolean,
    --[[
        Returns the exit code of the process, if available.
        @param self The exit status instance
        @return The numeric exit code
    ]]
    code: (self: ExitStatus) -> number?,
}

--[[ Represents the standard input stream of a child process. ]]
export type ChildStdin = IO.Writer & {
    -- Any child-specific stdin methods
}

--[[ Represents the standard output stream of a child process. ]]
export type ChildStdout = IO.Reader & {
    -- Any child-specific stdout methods
}

--[[ Represents the standard error stream of a child process. ]]
export type ChildStderr = IO.Reader & {
    -- Any child-specific stderr methods
}

--[[ Represents a spawned child process. ]]
export type Child = {
    --[[ The process ID (PID) of the child process. ]]
    id: number,
    --[[ The standard input stream, if piped. ]]
    stdin: ChildStdin?,
    --[[ The standard output stream, if piped. ]]
    stdout: ChildStdout?,
    --[[ The standard error stream, if piped. ]]
    stderr: ChildStderr?,
    
    --[[
        Forces the child process to exit.
        @param self The child process instance
        @return A future resolving when the process is killed
    ]]
    kill: (self: Child) -> Async.TaskFuture<any>,
    
    --[[
        Attempts to collect the exit status without blocking.
        @param self The child process instance
        @return A future resolving to the ExitStatus if finished, or nil
    ]]
    try_wait: (self: Child) -> Async.TaskFuture<ExitStatus?>,
    
    --[[
        Waits for the child process to finish and returns its exit status.
        @param self The child process instance
        @return A future resolving to the ExitStatus
    ]]
    wait: (self: Child) -> Async.TaskFuture<ExitStatus>,
    
    --[[
        Closes the child process handles.
        @param self The child process instance
    ]]
    close: (self: Child) -> (),
}

--[[ Builder for configuring and spawning a child process. ]]
export type Command = {
    --[[
        Adds a single argument to the command.
        @param self The command instance
        @param arg The argument string
        @return The command instance for chaining
    ]]
    arg: (self: Command, arg: string) -> Command,
    
    --[[
        Adds multiple arguments to the command.
        @param self The command instance
        @param args Array of argument strings
        @return The command instance for chaining
    ]]
    args: (self: Command, args: {string}) -> Command,
    
    --[[
        Sets the working directory for the child process.
        @param self The command instance
        @param path The directory path
        @return The command instance for chaining
    ]]
    cwd: (self: Command, path: string) -> Command,
    
    --[[
        Adds or updates an environment variable for the child process.
        @param self The command instance
        @param key The environment variable name
        @param value The environment variable value
        @return The command instance for chaining
    ]]
    env: (self: Command, key: string, value: string) -> Command,
    
    --[[
        Clears all environment variables for the child process.
        @param self The command instance
        @return The command instance for chaining
    ]]
    env_clear: (self: Command) -> Command,
    
    --[[
        Configures the standard input stream.
        @param self The command instance
        @param cfg The stream configuration
        @return The command instance for chaining
    ]]
    stdin: (self: Command, cfg: StdioConfig) -> Command,
    
    --[[
        Configures the standard output stream.
        @param self The command instance
        @param cfg The stream configuration
        @return The command instance for chaining
    ]]
    stdout: (self: Command, cfg: StdioConfig) -> Command,
    
    --[[
        Configures the standard error stream.
        @param self The command instance
        @param cfg The stream configuration
        @return The command instance for chaining
    ]]
    stderr: (self: Command, cfg: StdioConfig) -> Command,
    
    --[[
        Spawns the child process with the current configuration.
        @param self The command instance
        @return A future resolving to the Child process instance
    ]]
    spawn: (self: Command) -> Async.TaskFuture<Child>,
}

return {}
