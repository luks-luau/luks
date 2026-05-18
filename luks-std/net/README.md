# Net Module

High-performance, strictly-typed asynchronous networking primitives for Luau inspired by the Rust `std::net` ecosystem. This module provides a robust suite of tools for TCP and UDP communication, address parsing, and socket management with full Rust authenticity.

## Features

- **Rust-Authentic Primitives** — Implements core `std::net` components including `TcpListener`, `TcpStream`, and `UdpSocket`.
- **Stream Integration** — `Net.TcpStream` fully implements `IO.Reader` and `IO.Writer` traits.
- **Asynchronous First** — All networking operations are integrated with the `TaskFuture` system for non-blocking execution using Luau's task scheduler.
- **Buffer Support** — Direct integration with Luau's native `buffer` type for zero-copy data transfers.
- **Strict Type Safety** — Comprehensive Luau type definitions ensure zero `any` usage and premium LSP support.
- **System Parity** — Direct mapping to Rust's high-level networking system calls for maximum reliability and performance.

---

## API Reference

### `TcpListener` Object
Used to listen for incoming TCP connections.

```luau
export type TcpListener = {
    accept: (self: TcpListener) -> TaskFuture<{ stream: TcpStream, addr: SocketAddr }>,
    local_addr: (self: TcpListener) -> TaskFuture<SocketAddr>,
    set_ttl: (self: TcpListener, ttl: number) -> TaskFuture<()>,
    ttl: (self: TcpListener) -> TaskFuture<number>,
    close: (self: TcpListener) -> (),
}
```

### `TcpStream` Object
The primary handle for a TCP connection.

```luau
export type TcpStream = Reader & Writer & {
    peer_addr: (self: TcpStream) -> TaskFuture<SocketAddr>,
    local_addr: (self: TcpStream) -> TaskFuture<SocketAddr>,
    shutdown: (self: TcpStream, how: Shutdown) -> TaskFuture<()>,
    set_nodelay: (self: TcpStream, nodelay: boolean) -> TaskFuture<()>,
    nodelay: (self: TcpStream) -> TaskFuture<boolean>,
    set_ttl: (self: TcpStream, ttl: number) -> TaskFuture<()>,
    ttl: (self: TcpStream) -> TaskFuture<number>,
    peek: (self: TcpStream, buf: buffer, offset: number?, len: number?) -> TaskFuture<number>,
    close: (self: TcpStream) -> (),
}
```

### `UdpSocket` Object
The primary handle for UDP communication.

```luau
export type UdpSocket = {
    send_to: (self: UdpSocket, buf: buffer | string, addr: string | SocketAddr) -> TaskFuture<number>,
    recv_from: (self: UdpSocket, buf: buffer) -> TaskFuture<{ bytes: number, addr: SocketAddr }>,
    peek_from: (self: UdpSocket, buf: buffer) -> TaskFuture<{ bytes: number, addr: SocketAddr }>,
    local_addr: (self: UdpSocket) -> TaskFuture<SocketAddr>,
    peer_addr: (self: UdpSocket) -> TaskFuture<SocketAddr>,
    connect: (self: UdpSocket, addr: string | SocketAddr) -> TaskFuture<()>,
    send: (self: UdpSocket, buf: buffer | string) -> TaskFuture<number>,
    recv: (self: UdpSocket, buf: buffer) -> TaskFuture<number>,
    set_broadcast: (self: UdpSocket, broadcast: boolean) -> TaskFuture<()>,
    broadcast: (self: UdpSocket) -> TaskFuture<boolean>,
    set_ttl: (self: UdpSocket, ttl: number) -> TaskFuture<()>,
    ttl: (self: UdpSocket) -> TaskFuture<number>,
    close: (self: UdpSocket) -> (),
}
```

---

## Usage Examples

### TCP Echo Server
```luau
local Net = require("./path/to/Net")

local listener = Net.TcpListener.bind("127.0.0.1:8080"):expect("Bind failed")
print("Listening on:", listener:local_addr():Wait():to_string())

while true do
    local conn = listener:accept():expect("Accept failed")
    task.spawn(function()
        local stream = conn.stream
        local buf = buffer.create(1024)
        while true do
            local n = stream:read(buf):expect("Read failed")
            if n == 0 then break end
            stream:write(buf, 0, n):Wait()
        end
        stream:close()
    end)
end
```

### UDP Broadcast
```luau
local Net = require("./path/to/Net")

local socket = Net.UdpSocket.bind("0.0.0.0:0"):expect("Bind failed")
socket:set_broadcast(true):Wait()

local data = "Luks Discovery Packet"
socket:send_to(data, "255.255.255.255:9000"):expect("Send failed")
```

---

## Implementation Details

The `Net` module leverages a dedicated native Rust crate (`luks_net`) to provide true socket management via `Boxed` native handles. This ensures memory safety and prevents segmentation faults by enforcing rigorous FFI boundary checks. Concurrency is managed via Luau's non-blocking task scheduler, eliminating the overhead of internal reactors while maintaining maximum throughput.

---

## License

MIT License — see [LICENSE](LICENSE) file for details.
