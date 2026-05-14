--!strict
--!native
--!optimize 2

--[[
    Process Module — Advanced Native Subprocess and Host Management Interface.
    Enables executing OS programs and inline shell commands synchronously or
    asynchronously via Signal event dispatchers. Manages global environment states,
    telemetry, CWD overrides, and pure string manipulation.
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

local nativeName = "process"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load Process native library")

-- ---------------------------------------------------------------------------
-- Public Types
-- ---------------------------------------------------------------------------

--[[
    Optional arguments controlling child process invocation properties.
]]
export type ProcessOptions = {
    --[[ Specific directory target where the command will evaluate. ]]
    cwd: string?,
    --[[ Map of custom environment variables to assign to the execution frame. ]]
    env: { [string]: string }?,
    --[[ If true, purges inherited host environment variables prior to running. ]]
    env_clear: boolean?,
    --[[ Payload fed directly into the child process standard input pipe. ]]
    stdin: string?,
}

--[[
    Output returned after terminating subprocess evaluations.
]]
export type ProcessOutput = {
    --[[ True if execution completed successfully yielding a zero exit code. ]]
    ok: boolean,
    --[[ Raw OS numerical termination status code. ]]
    status: number,
    --[[ Standard text stream buffers emitted from stdout. ]]
    stdout: string,
    --[[ Standard text stream buffers emitted from stderr. ]]
    stderr: string,
    --[[ Explanatory error details if child pipeline generation panics. ]]
    error: string?,
}

--[[
    Signal dispatcher yielding output records asynchronously.
]]
export type AsyncProcessOutput = Signal.Signal<ProcessOutput>

--[[
    Supported compile-time target CPU architectures configured by the OS kernel.
]]
export type CpuArchitecture = "x86_64" | "aarch64" | "x86" | "arm" | "riscv64" | "wasm32" | string

--[[
    Supported underlying target host kernel platform profiles.
]]
export type OperatingSystem = "windows" | "linux" | "macos" | "ios" | "android" | "freebsd" | string

-- ---------------------------------------------------------------------------
-- Module Interface
-- ---------------------------------------------------------------------------

local Process = {}

local function resolvePath(input: string, isProgram: boolean?): string
    if input:match("^/") or input:match("^\\") or input:match("^[A-Za-z]:") then
        return input
    end

    if isProgram and not input:find("/") and not input:find("\\") then
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
    Launches raw binary target directly passing explicit argument vectors.

    @param program  Binary executable string path.
    @param args     Optional array table of parameter arguments.
    @param options  Optional process mapping specifications.
    @return         `ProcessOutput` mapping status strings.
]]
function Process.spawn(program: string, args: {string}?, options: ProcessOptions?): ProcessOutput
    local resProgram = program
    if type(program) == "string" then
        resProgram = resolvePath(program, true)
    end
    local resOptions = options
    if options and type(options) == "table" and type(options.cwd) == "string" then
        local cloned = table.clone(options :: ProcessOptions)
        cloned.cwd = resolvePath((options :: ProcessOptions).cwd :: string, false)
        resOptions = cloned
    end
    return native.spawn(resProgram, args, resOptions)
end

--[[
    Launches commands encapsulated implicitly inside the OS native shell layer.

    @param command  Terminal string command expression.
    @param options  Optional process mapping specifications.
    @return         `ProcessOutput` mapping status strings.
]]
function Process.exec(command: string, options: ProcessOptions?): ProcessOutput
    local resOptions = options
    if options and type(options) == "table" and type(options.cwd) == "string" then
        local cloned = table.clone(options :: ProcessOptions)
        cloned.cwd = resolvePath((options :: ProcessOptions).cwd :: string, false)
        resOptions = cloned
    end
    return native.exec(command, resOptions)
end

-- ---------------------------------------------------------------------------
-- Asynchronous Handlers (Signal wraps running in background threads)
-- ---------------------------------------------------------------------------

--[[
    Non-blocking async variant of `Process.spawn`. Returns `Signal<ProcessOutput>`.
]]
function Process.spawnAsync(program: string, args: {string}?, options: ProcessOptions?): AsyncProcessOutput
    local resProgram = program
    if type(program) == "string" then
        resProgram = resolvePath(program, true)
    end
    local resOptions = options
    if options and type(options) == "table" and type(options.cwd) == "string" then
        local cloned = table.clone(options :: ProcessOptions)
        cloned.cwd = resolvePath((options :: ProcessOptions).cwd :: string, false)
        resOptions = cloned
    end

    local signal = Signal.new() :: Signal.SignalInternal<ProcessOutput>
    task.defer(function()
        local response = native.spawn(resProgram, args, resOptions)
        signal:Fire(response)
    end)
    return signal:Public()
end

--[[
    Non-blocking async variant of `Process.exec`. Returns `Signal<ProcessOutput>`.
]]
function Process.execAsync(command: string, options: ProcessOptions?): AsyncProcessOutput
    local resOptions = options
    if options and type(options) == "table" and type(options.cwd) == "string" then
        local cloned = table.clone(options :: ProcessOptions)
        cloned.cwd = resolvePath((options :: ProcessOptions).cwd :: string, false)
        resOptions = cloned
    end

    local signal = Signal.new() :: Signal.SignalInternal<ProcessOutput>
    task.defer(function()
        local response = native.exec(command, resOptions)
        signal:Fire(response)
    end)
    return signal:Public()
end

-- ---------------------------------------------------------------------------
-- Host & Environment Wrappers
-- ---------------------------------------------------------------------------

--[[ Returns current runtime Host OS process identifier. ]]
function Process.id(): number
    return native.id()
end

--[[ Returns primary compiled physical processor architecture string. ]]
function Process.arch(): CpuArchitecture
    return native.arch() :: any
end

--[[ Returns runtime active compilation host operating system platform. ]]
function Process.os(): OperatingSystem
    return native.os() :: any
end

--[[ Computes floating incremental delta execution frames in seconds. ]]
function Process.uptime(): number
    return native.uptime()
end

--[[ Resolves mapping configurations associated with specific target environment variables. ]]
function Process.getEnv(key: string): string?
    return native.getEnv(key)
end

--[[ Assigns or overrides contextual environmental map variable strings. ]]
function Process.setEnv(key: string, value: string)
    native.setEnv(key, value)
end

--[[ Purges specified context mapping targets from global engine bounds. ]]
function Process.removeEnv(key: string)
    native.removeEnv(key)
end

--[[ Returns global dictionary table capturing all initialized environment bindings. ]]
function Process.getAllEnv(): { [string]: string }
    return native.getAllEnv()
end

--[[ Explicit application termination procedure using custom code flags. ]]
function Process.exit(code: number?)
    native.exit(code or 0)
end

--[[ Submodule engine static target revision descriptor. ]]
Process.version = native.version :: string

return Process
