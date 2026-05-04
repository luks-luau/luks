--!strict

--[[
    WebSocket Module — Native WebSocket client for Luau.
    Supports ws:// and wss:// (TLS), custom headers, multiple concurrent connections,
    and a Signal-based event API compatible with the luks-std ecosystem.

    Errors are raised as Lua runtime errors and can be caught with pcall:
        local ok, err = pcall(WebSocket.connect, "wss://...")
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

local nativeName = "websocket"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load WebSocket native library")

-- ---------------------------------------------------------------------------
-- Public Types
-- ---------------------------------------------------------------------------

--[[
    Options accepted by WebSocket.connect().
]]
export type WebSocketConnectOptions = {
    --[[ HTTP headers to include in the WebSocket handshake (e.g. Authorization). ]]
    headers: { [string]: string }?,
    --[[ Connection timeout in seconds. Default: 30. ]]
    timeout: number?,
}

--[[
    A message received from the WebSocket server.
]]
export type WebSocketMessage = {
    --[[ Message type: "text" | "binary" | "ping" | "pong" | "close" | "frame" ]]
    type: string,
    --[[ Raw message payload. nil for "frame" type. ]]
    data: string?,
    --[[ Close code — only present when type == "close". ]]
    code: number?,
    --[[ Close reason — only present when type == "close". ]]
    reason: string?,
}

--[[
    Information about a WebSocket close event.
]]
export type WebSocketCloseInfo = {
    code: number,
    reason: string,
}

--[[
    A live WebSocket connection object returned by WebSocket.connect().
    Use :startListening() to begin receiving messages via Signals.
]]
export type WebSocketConnection = {
    --[[ Fires when a text or binary message is received. ]]
    onMessage: Signal.Signal<WebSocketMessage>,
    --[[ Fires when the connection is closed (cleanly or by server). ]]
    onClose: Signal.Signal<WebSocketCloseInfo>,
    --[[ Fires when a protocol or I/O error occurs during receive. ]]
    onError: Signal.Signal<string>,

    --[[
        Sends a text message.
        Raises a Lua error on failure — wrap with pcall if needed.
        @return true on success
    ]]
    send: (self: WebSocketConnection, message: string) -> boolean,

    --[[
        Sends a binary message.
        Raises a Lua error on failure — wrap with pcall if needed.
        @return true on success
    ]]
    sendBinary: (self: WebSocketConnection, data: string) -> boolean,

    --[[
        Closes the connection with an optional close code and reason.
        Default code: 1000 (Normal Closure).
    ]]
    close: (self: WebSocketConnection, code: number?, reason: string?) -> (),

    --[[
        Returns true if the connection is still open and writable.
    ]]
    isOpen: (self: WebSocketConnection) -> boolean,

    --[[
        Returns the URL this connection was opened against.
        Raises a Lua error if the handle is invalid.
    ]]
    url: (self: WebSocketConnection) -> string,

    --[[
        Starts the internal receive loop (runs inside task.spawn).
        Fires onMessage, onClose, and onError Signals automatically.
        Call once after connect. The loop stops when the connection closes.
    ]]
    startListening: (self: WebSocketConnection) -> (),
}

-- ---------------------------------------------------------------------------
-- Connection object constructor (internal)
-- ---------------------------------------------------------------------------

local function newConnection(handleId: number): WebSocketConnection
    local onMessage = Signal.new() :: Signal.SignalInternal<WebSocketMessage>
    local onClose = Signal.new() :: Signal.SignalInternal<WebSocketCloseInfo>
    local onError = Signal.new() :: Signal.SignalInternal<string>

    local conn = {} :: WebSocketConnection

    conn.onMessage = onMessage:Public()
    conn.onClose = onClose:Public()
    conn.onError = onError:Public()

    function conn:send(message: string): boolean
        return native.send(handleId, message)
    end

    function conn:sendBinary(data: string): boolean
        return native.send_binary(handleId, data)
    end

    function conn:close(code: number?, reason: string?): ()
        native.close(handleId, code or 1000, reason or "")
    end

    function conn:isOpen(): boolean
        return native.is_open(handleId)
    end

    function conn:url(): string
        return native.url(handleId)
    end

    function conn:startListening(): ()
        task.spawn(function()
            while native.is_open(handleId) do
                -- receive returns: msg on success, nil + "timeout" on no data,
                -- or raises a Lua error for real protocol failures.
                local ok, msgOrErr = pcall(native.receive, handleId)

                if not ok then
                    -- Real error raised by native.receive
                    onError:Fire(msgOrErr :: string)
                    break
                end

                if msgOrErr == nil then
                    -- nil + "timeout": no message yet, yield and retry
                    task.wait(0)
                    continue
                end

                local wsMsg = msgOrErr :: WebSocketMessage

                if wsMsg.type == "close" then
                    onClose:Fire({
                        code = wsMsg.code or 1000,
                        reason = wsMsg.reason or "",
                    })
                    break
                else
                    onMessage:Fire(wsMsg)
                end

                task.wait(0)
            end

            -- Guarantee onClose fires when the loop exits
            onClose:Fire({ code = 1000, reason = "connection ended" })
        end)
    end

    return conn
end

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

--[[
    WebSocket Module — provides WebSocket client functionality.
]]
local WebSocket = {}

--[[
    Opens a WebSocket connection to the given URL.

    Raises a Lua runtime error on failure (use pcall to catch):
        local ok, result = pcall(WebSocket.connect, "wss://...")
        if not ok then print("Error:", result) end

    @param url       The WebSocket URL (ws:// or wss://).
    @param options   Optional: { headers, timeout }.
    @return          A WebSocketConnection object.

    @example
        local conn = WebSocket.connect("wss://echo.websocket.org")
        conn.onMessage:Connect(function(msg)
            print("Received:", msg.data)
        end)
        conn:startListening()
        conn:send("Hello!")
]]
function WebSocket.connect(url: string, options: WebSocketConnectOptions?): WebSocketConnection
    local handleId = native.connect(url, options)
    return newConnection(handleId)
end

--[[ Native library version. ]]
WebSocket.version = native.version :: string

return WebSocket
