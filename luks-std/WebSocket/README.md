# WebSocket Module

Native WebSocket client module for Luau. Supports `ws://` and `wss://` (TLS), custom handshake headers, multiple concurrent connections, and a `Signal`-based event API — making it the ideal foundation for a Discord API client.

## Features

- **ws:// and wss://** — Full TLS support via `native-tls` (SChannel on Windows, OpenSSL on Linux)
- **Custom Headers** — Inject any HTTP header during the WebSocket handshake (e.g. `Authorization`, `User-Agent`)
- **Signal-based Events** — `onMessage`, `onClose`, `onError` events via the `Signal` module
- **Multiple Connections** — Unlimited concurrent WebSocket connections, each identified by an opaque handle
- **Error via pcall** — Connect failures raise Lua runtime errors, catchable with `pcall`
- **Type Safety** — Full Luau type annotations with LSP/intellisense support
- **Async-friendly** — Non-blocking receive loop via `startListening()` + `task.spawn`

## API Reference

### Types

```lua
export type WebSocketConnectOptions = {
    headers: { [string]: string }?,  -- Headers for the WS handshake
    timeout: number?,                -- Read/write timeout in seconds (default: 30)
}

export type WebSocketMessage = {
    type:    string,   -- "text" | "binary" | "ping" | "pong" | "close" | "frame"
    data:    string?,  -- Message payload (nil for "frame")
    code:    number?,  -- Close code   (only when type == "close")
    reason:  string?,  -- Close reason (only when type == "close")
}

export type WebSocketCloseInfo = {
    code:   number,
    reason: string,
}

export type WebSocketConnection = {
    onMessage: Signal<WebSocketMessage>,
    onClose:   Signal<WebSocketCloseInfo>,
    onError:   Signal<string>,

    send:           (self, message: string) -> boolean,
    sendBinary:     (self, data: string)    -> boolean,
    close:          (self, code?: number, reason?: string) -> (),
    isOpen:         (self) -> boolean,
    url:            (self) -> string,
    startListening: (self) -> (),
}
```

### `WebSocket.connect(url, options?) → WebSocketConnection`

Opens a WebSocket connection and returns a `WebSocketConnection`.

Raises a Lua runtime error on failure — use `pcall` to catch:

```lua
-- Simple (error propagates naturally)
local conn = WebSocket.connect("wss://echo.websocket.org")

-- With error handling
local ok, result = pcall(WebSocket.connect, "wss://echo.websocket.org", {
    headers = { ["User-Agent"] = "MyBot/1.0" },
    timeout = 10,
})
if not ok then
    print("Connect failed:", result)
    return
end
local conn = result
```

### `conn:startListening()`

Starts the internal receive loop (via `task.spawn`). Fires `onMessage`, `onClose`, and `onError` Signals automatically. Call once after `connect`. The loop stops when the connection closes.

### `conn:send(message: string) → boolean`

Sends a UTF-8 text frame. Returns `true` on success. Raises a Lua error on failure.

### `conn:sendBinary(data: string) → boolean`

Sends a binary frame. Returns `true` on success. Raises a Lua error on failure.

### `conn:close(code?: number, reason?: string)`

Sends a WebSocket close frame and removes the connection from the registry. Default close code: `1000` (Normal Closure).

### `conn:isOpen() → boolean`

Returns `true` if the connection is still active and writable.

### `conn:url() → string`

Returns the URL this connection was opened against. Raises a Lua error if the handle is invalid.

---

## Usage Examples

### Echo test

```lua
local WebSocket = require("./path/to/WebSocket")

local conn = WebSocket.connect("wss://echo.websocket.org")

conn.onMessage:Connect(function(msg)
    print("Echo received:", msg.data)
    conn:close()
end)

conn.onClose:Connect(function(info)
    print("Closed:", info.code, info.reason)
end)

conn:startListening()
conn:send("Hello WebSocket!")
```

### Error handling with pcall

```lua
local WebSocket = require("./path/to/WebSocket")

local ok, result = pcall(WebSocket.connect, "wss://invalid.host.example", { timeout = 5 })
if not ok then
    print("Connect failed:", result)
    return
end

local conn = result

local ok2, err = pcall(function()
    conn:send("test message")
end)
if not ok2 then
    print("Send failed:", err)
end
```

### Discord Gateway (preview)

```lua
local WebSocket = require("./path/to/WebSocket")
local Json      = require("./path/to/Json")

local GATEWAY = "wss://gateway.discord.gg/?v=10&encoding=json"
local TOKEN   = "Bot YOUR_TOKEN_HERE"

local conn = WebSocket.connect(GATEWAY, {
    headers = {
        ["Authorization"] = TOKEN,
        ["User-Agent"]    = "DiscordBot (luks-luau, 0.1.0)",
    },
    timeout = 15,
})

conn.onMessage:Connect(function(msg)
    local ok, payload = pcall(Json.decode, msg.data)
    if not ok then return end

    local op = payload.op

    if op == 10 then
        -- Hello: start heartbeat loop
        local interval = payload.d.heartbeat_interval / 1000
        print("Gateway Hello — heartbeat every", interval, "s")

        task.spawn(function()
            while conn:isOpen() do
                conn:send(Json.encode({ op = 1, d = nil }))
                task.wait(interval)
            end
        end)

        -- Identify
        conn:send(Json.encode({
            op = 2,
            d  = {
                token      = TOKEN,
                intents    = 513,
                properties = {
                    os      = "linux",
                    browser = "luks-luau",
                    device  = "luks-luau",
                },
            },
        }))

    elseif op == 0 then
        print("Dispatch:", payload.t)
    elseif op == 11 then
        print("Heartbeat ACK")
    end
end)

conn.onClose:Connect(function(info)
    print("Gateway disconnected:", info.code, info.reason)
end)

conn.onError:Connect(function(errMsg)
    print("Gateway error:", errMsg)
end)

conn:startListening()
```

---

## Building

```bash
cd luks-std/WebSocket
cargo build --release
```

Output locations:
- **Windows**: `target/release/websocket.dll`
- **Linux**: `target/release/libwebsocket.so`
- **macOS**: `target/release/libwebsocket.dylib`

Copy to `lib/` for deployment:
```bash
# Windows
copy target\release\websocket.dll lib\
```

---

## Dependencies

- **Rust**: `tungstenite` (WebSocket RFC 6455 + TLS via `native-tls`), `url` (URL parsing)
- **Luau Modules**: `Signal` (for `onMessage`, `onClose`, `onError` events), `task` scheduler
- **System**: `mlua-sys` with `luau` feature, native TLS (SChannel on Windows / OpenSSL on Linux)

## License

MIT License — see [LICENSE](LICENSE) file.
