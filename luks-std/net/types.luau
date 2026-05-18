--!strict
-- luks-std/Net/types.luau
local Async = require("@self/../async")
local IO = require("@self/../io")

export type Shutdown = "Read" | "Write" | "Both"

--[[
    Represents an IP address, either IPv4 or IPv6.
]]
export type IpAddr = {
    --[[
        Returns whether the address is an IPv4 address.
        @param self The IP address instance
        @return True if IPv4
    ]]
    is_v4: (self: IpAddr) -> boolean,
    --[[
        Returns whether the address is an IPv6 address.
        @param self The IP address instance
        @return True if IPv6
    ]]
    is_v6: (self: IpAddr) -> boolean,
    --[[
        Returns whether the address is a loopback address.
        @param self The IP address instance
        @return True if loopback
    ]]
    is_loopback: (self: IpAddr) -> boolean,
    --[[
        Returns whether the address is an unspecified address (0.0.0.0 or ::).
        @param self The IP address instance
        @return True if unspecified
    ]]
    is_unspecified: (self: IpAddr) -> boolean,
    --[[
        Returns whether the address is a multicast address.
        @param self The IP address instance
        @return True if multicast
    ]]
    is_multicast: (self: IpAddr) -> boolean,
    --[[
        Returns a string representation of the IP address.
        @param self The IP address instance
        @return The formatted IP string
    ]]
    to_string: (self: IpAddr) -> string,
}

--[[
    Represents a socket address (IP and port).
]]
export type SocketAddr = {
    --[[
        Returns the IP address part of the socket address.
        @param self The socket address instance
        @return The IpAddr object
    ]]
    ip: (self: SocketAddr) -> IpAddr,
    --[[
        Returns the port number.
        @param self The socket address instance
        @return The port number
    ]]
    port: (self: SocketAddr) -> number,
    --[[
        Returns whether the address is IPv4.
        @param self The socket address instance
        @return True if IPv4
    ]]
    is_ipv4: (self: SocketAddr) -> boolean,
    --[[
        Returns whether the address is IPv6.
        @param self The socket address instance
        @return True if IPv6
    ]]
    is_ipv6: (self: SocketAddr) -> boolean,
    --[[
        Returns a string representation of the socket address (e.g., "127.0.0.1:80").
        @param self The socket address instance
        @return The formatted address string
    ]]
    to_string: (self: SocketAddr) -> string,
}

--[[
    Represents a TCP stream between a local and a remote socket.
    Implements IO.Reader and IO.Writer.
]]
export type TcpStream = IO.Reader & IO.Writer & {
    --[[
        Returns the address of the remote peer of this TCP connection.
        @param self The TCP stream instance
        @return A future resolving to the remote SocketAddr
    ]]
    peer_addr: (self: TcpStream) -> Async.TaskFuture<SocketAddr>,
    --[[
        Returns the local address of this TCP connection.
        @param self The TCP stream instance
        @return A future resolving to the local SocketAddr
    ]]
    local_addr: (self: TcpStream) -> Async.TaskFuture<SocketAddr>,
    --[[
        Shuts down the read, write, or both halves of this connection.
        @param self The TCP stream instance
        @param how Which part of the connection to shut down
        @return A future resolving when the shutdown is complete
    ]]
    shutdown: (self: TcpStream, how: Shutdown) -> Async.TaskFuture<any>,
    --[[
        Sets the value of the TCP_NODELAY option on this socket.
        @param self The TCP stream instance
        @param nodelay Whether to enable nodelay
        @return A future resolving when the option is set
    ]]
    set_nodelay: (self: TcpStream, nodelay: boolean) -> Async.TaskFuture<any>,
    --[[
        Sets the value for the IP_TTL option on this socket.
        @param self The TCP stream instance
        @param ttl The time-to-live value
        @return A future resolving when the option is set
    ]]
    set_ttl: (self: TcpStream, ttl: number) -> Async.TaskFuture<any>,
    --[[
        Closes the TCP stream and releases native resources.
        @param self The TCP stream instance
    ]]
    close: (self: TcpStream) -> (),
}

--[[
    Represents a TCP server, listening for incoming connections.
]]
export type TcpListener = {
    --[[
        Accepts a new incoming connection from this listener.
        @param self The TCP listener instance
        @return A future resolving to a table with the new TcpStream and its remote address
    ]]
    accept: (self: TcpListener) -> Async.TaskFuture<{ stream: TcpStream, addr: SocketAddr }>,
    --[[
        Returns the local address that this listener is bound to.
        @param self The TCP listener instance
        @return A future resolving to the local SocketAddr
    ]]
    local_addr: (self: TcpListener) -> Async.TaskFuture<SocketAddr>,
    --[[
        Closes the TCP listener and releases native resources.
        @param self The TCP listener instance
    ]]
    close: (self: TcpListener) -> (),
}

--[[
    Represents a UDP socket.
]]
export type UdpSocket = {
    --[[
        Sends data on the socket to the given address.
        @param self The UDP socket instance
        @param buf The data to send (buffer or string)
        @param addr The destination address (string or SocketAddr)
        @return A future resolving to the number of bytes sent
    ]]
    send_to: (self: UdpSocket, buf: buffer | string, addr: string | SocketAddr) -> Async.TaskFuture<number>,
    --[[
        Receives data from the socket.
        @param self The UDP socket instance
        @param buf The buffer to receive into
        @return A future resolving to a table with the number of bytes received and the remote address
    ]]
    recv_from: (self: UdpSocket, buf: buffer) -> Async.TaskFuture<{ bytes: number, addr: SocketAddr }>,
    --[[
        Returns the local address this socket is bound to.
        @param self The UDP socket instance
        @return A future resolving to the local SocketAddr
    ]]
    local_addr: (self: UdpSocket) -> Async.TaskFuture<SocketAddr>,
    --[[
        Connects this UDP socket to a remote address, allowing the use of send and recv.
        @param self The UDP socket instance
        @param addr The remote address
        @return A future resolving when the connection is complete
    ]]
    connect: (self: UdpSocket, addr: string | SocketAddr) -> Async.TaskFuture<any>,
    --[[
        Sends data on the socket to the remote address to which it is connected.
        @param self The UDP socket instance
        @param buf The data to send
        @return A future resolving to the number of bytes sent
    ]]
    send: (self: UdpSocket, buf: buffer | string) -> Async.TaskFuture<number>,
    --[[
        Receives data from the socket from the remote address to which it is connected.
        @param self The UDP socket instance
        @param buf The buffer to receive into
        @return A future resolving to the number of bytes received
    ]]
    recv: (self: UdpSocket, buf: buffer) -> Async.TaskFuture<number>,
    --[[
        Closes the UDP socket and releases native resources.
        @param self The UDP socket instance
    ]]
    close: (self: UdpSocket) -> (),
}

return {}
