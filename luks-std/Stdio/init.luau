--!strict

--[[
    Stdio Module — Advanced standard input, output, and error streaming interface.
    Enables chainable console output formatting, synchronous standard host reads,
    non-blocking asynchronous user prompts, and highly interactive event-driven child process
    pipelining via Signal event dispatchers.
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

local nativeName = "stdio"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load Stdio native library")

-- ---------------------------------------------------------------------------
-- Public Types (Single-Source of LSP Documentation Truth)
-- ---------------------------------------------------------------------------

--[[
    Supported ANSI formatting styles and text coloring tokens.
]]
export type ConsoleColor = "red" | "green" | "yellow" | "blue" | "magenta" | "cyan" | "reset" | "bold"

--[[
    Standard output stream writer interface enabling chainable text manipulations.
]]
export type StdoutHandle = {
    --[[
        Writes raw text directly to the standard output buffer.
        
        @param self The active output stream handle
        @param text Payload content string to output
        @return Chainable reference returning the active handle
    ]]
    write: (self: StdoutHandle, text: string) -> StdoutHandle,
    
    --[[
        Writes text followed by a standard line termination character sequence.
        
        @param self The active output stream handle
        @param text Payload content string to output
        @return Chainable reference returning the active handle
    ]]
    writeLine: (self: StdoutHandle, text: string) -> StdoutHandle,
    
    --[[
        Applies standard string template interpolation output formatting.
        
        @param self The active output stream handle
        @param template Format specification string pattern
        @param ... Variadic argument vector mapping format values
        @return Chainable reference returning the active handle
    ]]
    fmt: (self: StdoutHandle, template: string, ...any) -> StdoutHandle,
    
    --[[
        Applies visual terminal rendering color mappings directly to the output sequence.
        
        @param self The active output stream handle
        @param color Semantic visual color string identifier
        @return Chainable reference returning the active handle
    ]]
    color: (self: StdoutHandle, color: ConsoleColor) -> StdoutHandle,
    
    --[[
        Forces the standard output stream to flush pending memory buffers to the operating system kernel.
        
        @param self The active output stream handle
    ]]
    flush: (self: StdoutHandle) -> (),
}

--[[
    Standard diagnostic error output stream interface.
]]
export type StderrHandle = {
    --[[
        Writes raw text directly to the standard diagnostic error stream.
        
        @param self The active error stream handle
        @param text Payload content string to output
        @return Chainable reference returning the active handle
    ]]
    write: (self: StderrHandle, text: string) -> StderrHandle,
    
    --[[
        Writes text followed by a standard line termination sequence to the diagnostic stream.
        
        @param self The active error stream handle
        @param text Payload content string to output
        @return Chainable reference returning the active handle
    ]]
    writeLine: (self: StderrHandle, text: string) -> StderrHandle,
    
    --[[
        Applies visual rendering color flags directly to the error stream output sequence.
        
        @param self The active error stream handle
        @param color Semantic visual color string identifier
        @return Chainable reference returning the active handle
    ]]
    color: (self: StderrHandle, color: ConsoleColor) -> StderrHandle,
    
    --[[
        Forces the diagnostic error stream to synchronize pending memory buffers.
        
        @param self The active error stream handle
    ]]
    flush: (self: StderrHandle) -> (),
}

--[[ Type alias for the Signal event dispatcher class. ]]
type SignalString = Signal.Signal<string>
--[[ Type alias for the Signal event dispatcher class. ]]
type SignalNumber = Signal.Signal<number>

--[[
    Standard input stream boundary reader interface.
]]
export type StdinHandle = {
    --[[
        Reads a single line of standard input synchronously, blocking the host execution thread until submitted.
        
        @param self The active input stream handle
        @return The payload content string submitted by the user
    ]]
    read: (self: StdinHandle) -> string,
    
    --[[
        Activates a background asynchronous reader process polling console submissions non-blockingly.
        
        @param self The active input stream handle
        @return Signal event dispatcher fired immediately upon reading console submission entries
    ]]
    readAsync: (self: StdinHandle) -> SignalString,
    
    --[[ Gracefully stops the active asynchronous standard input listener loop. ]]
    close: (self: StdinHandle) -> (),
}

--[[
    Subprocess interaction frame containing active event listeners and stream handlers.
]]
export type StreamedChild = {
    --[[ Signal event dispatcher yielding text blocks emitted from stdout. ]]
    onStdout: SignalString,
    --[[ Signal event dispatcher yielding text blocks emitted from stderr. ]]
    onStderr: SignalString,
    --[[ Signal event dispatcher capturing native termination return codes. ]]
    onExit: SignalNumber,
    
    --[[
        Pushes string data streams securely into the active sub-process input pipe.
        
        @param self The active child interaction object
        @param data String payload content to assign
    ]]
    writeStdin: (self: StreamedChild, data: string) -> (),
    
    --[[
        Signals standard End-Of-File (EOF) flags gracefully terminating the input pipe.
        
        @param self The active child interaction object
    ]]
    closeStdin: (self: StreamedChild) -> (),
    
    --[[
        Forces immediate kernel-level termination of the target subprocess.
        
        @param self The active child interaction object
    ]]
    terminate: (self: StreamedChild) -> (),
}

-- ---------------------------------------------------------------------------
-- Module Interface Implementation
-- ---------------------------------------------------------------------------

local Stdio = {}

Stdio.version = native.version :: string

local ANSI_MAP = {
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    reset = "\27[0m",
    bold = "\27[1m"
}

function Stdio.stdout(): StdoutHandle
    local handle = {} :: StdoutHandle
    function handle:write(text)
        native.write(text)
        return self
    end
    function handle:writeLine(text)
        native.writeLine(text)
        return self
    end
    function handle:fmt(template, ...)
        native.write(string.format(template, ...))
        return self
    end
    function handle:color(c)
        native.write(ANSI_MAP[c] or "")
        return self
    end
    function handle:flush()
        native.flushStdout()
    end
    return handle
end

function Stdio.stderr(): StderrHandle
    local handle = {} :: StderrHandle
    function handle:write(text)
        native.writeError(text)
        return self
    end
    function handle:writeLine(text)
        native.writeErrorLine(text)
        return self
    end
    function handle:color(c)
        native.writeError(ANSI_MAP[c] or "")
        return self
    end
    function handle:flush()
        native.flushStderr()
    end
    return handle
end

function Stdio.stdin(): StdinHandle
    local handle = {} :: StdinHandle
    local closed = false
    function handle:read()
        return native.readLine() or ""
    end
    function handle:readAsync()
        local sig = Signal.new()
        task.spawn(function()
            native.startReaderThread()
            while not closed do
                local line = native.tryReadLine()
                if line then
                    sig:Fire(line)
                end
                task.wait()
            end
        end)
        return sig
    end
    function handle:close()
        closed = true
    end
    return handle
end

function Stdio.prompt(prefix: string): string
    Stdio.stdout():color("bold"):color("cyan"):write(prefix):color("reset"):flush()
    return Stdio.stdin():read()
end

function Stdio.promptAsync(prefix: string): SignalString
    Stdio.stdout():color("bold"):color("cyan"):write(prefix):color("reset"):flush()
    return Stdio.stdin():readAsync()
end

function Stdio.spawnStream(program: string, args: {string}?, options: any?): StreamedChild
    local childId = native.spawnStreamChild(program, args or {}, options or {})
    local internalSignals = {
         onStdout = Signal.new(),
        onStderr = Signal.new(),
        onExit = Signal.new(),
    }

    local child = {
       onStdout = internalSignals.onStdout:Public(),
       onStderr = internalSignals.onStderr:Public(),
       onExit = internalSignals.onExit:Public(),
        writeStdin = function(_, data)
            native.writeChildStdin(childId, data)
        end,
        closeStdin = function(_)
            native.closeChildStdin(childId)
        end,
        terminate = function(_)
            native.terminateChild(childId)
        end,
    } :: StreamedChild

    task.spawn(function()
        while true do
            local outChunk = native.pollChildStdout(childId)
            if outChunk and #outChunk > 0 then
                internalSignals.onStdout:Fire(outChunk)
            end

            local errChunk = native.pollChildStderr(childId)
            if errChunk and #errChunk > 0 then
                internalSignals.onStderr:Fire(errChunk)
            end

            local exitCode = native.pollChildExit(childId)
            if exitCode then
                internalSignals.onExit:Fire(exitCode)
                break
            end

            task.wait(0.01)
        end
    end)

    return child
end

return Stdio
