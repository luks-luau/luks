--!strict
-- luks-std/Net/UdpSocket/init.luau
local Async = require("@self/../../async")
local types = require("@self/../types")
local SocketAddr = require("@self/../SocketAddr")

type Self = {
    _handle: any,
}

local UdpSocketMT = {}
UdpSocketMT.__index = UdpSocketMT

--[[ Native layer for Net ]]
local native = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    local lib = try_load("@self/../lib/luks_net")
        or try_load("@self/../../../target/release/luks_net")
        or try_load("@self/../../../target/debug/luks_net")
        or error("Could not load Net native library")
    return lib :: any
end)()

--[[
    Sends data on the socket to the given address.
    @param self The UDP socket instance
    @param buf The data to send (buffer or string)
    @param addr The destination address (string or SocketAddr)
    @return A future resolving to the number of bytes sent
]]
function UdpSocketMT:send_to(buf: buffer | string, addr: string | types.SocketAddr): Async.TaskFuture<number>
    local this: Self = self :: any
    local addr_str = if type(addr) == "string" then addr else addr:to_string()
    local future, resolve, reject = Async.new_future()
    
    task.spawn(function()
        while true do
            if not this._handle then
                reject({ kind = "IoError", message = "socket is closed" })
                break
            end
            local n, err = native.udp_send_to(this._handle, buf, addr_str)
            if n then
                resolve(n)
                break
            elseif err == "WouldBlock" then
                task.wait()
            else
                reject({ kind = "IoError", message = err or "send_to failed" })
                break
            end
        end
    end)
    
    return future
end

--[[
    Receives data from the socket.
    @param self The UDP socket instance
    @param buf The buffer to receive into
    @return A future resolving to a table with the number of bytes received and the remote address
]]
function UdpSocketMT:recv_from(buf: buffer): Async.TaskFuture<{ bytes: number, addr: types.SocketAddr }>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    
    task.spawn(function()
        while true do
            if not this._handle then
                reject({ kind = "IoError", message = "socket is closed" })
                break
            end
            local n, addr_str = native.udp_recv_from(this._handle, buf)
            if n then
                resolve({
                    bytes = n,
                    addr = SocketAddr.parse(addr_str)
                })
                break
            elseif addr_str == "WouldBlock" then
                task.wait()
            else
                reject({ kind = "IoError", message = addr_str or "recv_from failed" })
                break
            end
        end
    end)
    
    return future
end

--[[
    Receives data from the socket without removing it from the queue.
    @param self The UDP socket instance
    @param buf The buffer to peek into
    @return A future resolving to a table with the number of bytes peeked and the remote address
]]
function UdpSocketMT:peek_from(buf: buffer): Async.TaskFuture<{ bytes: number, addr: types.SocketAddr }>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not this._handle then reject({ kind = "IoError", message = "socket is closed" }); break end
            local n, addr_str = native.udp_peek_from(this._handle, buf)
            if n then
                resolve({
                    bytes = n,
                    addr = SocketAddr.parse(addr_str)
                })
                break
            elseif addr_str == "WouldBlock" then task.wait()
            else reject({ kind = "IoError", message = addr_str or "peek_from failed" }); break end
        end
    end)
    return future
end

--[[
    Returns the local address this socket is bound to.
    @param self The UDP socket instance
    @return A future resolving to the local SocketAddr
]]
function UdpSocketMT:local_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local addr_str, err = native.udp_socket_local_addr(this._handle)
        if addr_str then resolve(SocketAddr.parse(addr_str)) else reject({ kind = "IoError", message = err or "local_addr failed" }) end
    end)
    return future
end

--[[
    Connects this UDP socket to a remote address.
    @param self The UDP socket instance
    @param addr The remote address
    @return A future resolving when the connection is complete
]]
function UdpSocketMT:connect(addr: string | types.SocketAddr): Async.TaskFuture<any>
    local this: Self = self :: any
    local addr_str = if type(addr) == "string" then addr else addr:to_string()
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.udp_connect(this._handle, addr_str)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "connect failed" }) end
    end)
    return future
end

--[[
    Sends data on the socket to the remote address to which it is connected.
    @param self The UDP socket instance
    @param buf The data to send
    @return A future resolving to the number of bytes sent
]]
function UdpSocketMT:send(buf: buffer | string): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not this._handle then reject({ kind = "IoError", message = "socket is closed" }); break end
            local n, err = native.udp_send(this._handle, buf)
            if n then resolve(n); break
            elseif err == "WouldBlock" then task.wait()
            else reject({ kind = "IoError", message = err or "send failed" }); break end
        end
    end)
    return future
end

--[[
    Receives data from the socket from the remote address to which it is connected.
    @param self The UDP socket instance
    @param buf The buffer to receive into
    @return A future resolving to the number of bytes received
]]
function UdpSocketMT:recv(buf: buffer): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not this._handle then reject({ kind = "IoError", message = "socket is closed" }); break end
            local n, err = native.udp_recv(this._handle, buf)
            if n then resolve(n); break
            elseif err == "WouldBlock" then task.wait()
            else reject({ kind = "IoError", message = err or "recv failed" }); break end
        end
    end)
    return future
end

--[[
    Returns the remote address to which this socket is connected.
    @param self The UDP socket instance
    @return A future resolving to the peer SocketAddr
]]
function UdpSocketMT:peer_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local addr_str, err = native.udp_socket_peer_addr(this._handle)
        if addr_str then resolve(SocketAddr.parse(addr_str)) else reject({ kind = "IoError", message = err or "peer_addr failed" }) end
    end)
    return future
end

--[[
    Sets the value for the IP_TTL option on this socket.
    @param self The UDP socket instance
    @param ttl The time-to-live value
    @return A future resolving when the option is set
]]
function UdpSocketMT:set_ttl(ttl: number): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.udp_socket_set_ttl(this._handle, ttl)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "set_ttl failed" }) end
    end)
    return future
end

--[[
    Returns the time-to-live option for this socket.
    @param self The UDP socket instance
    @return A future resolving to the TTL value
]]
function UdpSocketMT:ttl(): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local n, err = native.udp_socket_ttl(this._handle)
        if n then resolve(n) else reject({ kind = "IoError", message = err or "ttl failed" }) end
    end)
    return future
end

--[[
    Sets the value of the SO_BROADCAST option for this socket.
    @param self The UDP socket instance
    @param broadcast Whether to enable broadcast
    @return A future resolving when the option is set
]]
function UdpSocketMT:set_broadcast(broadcast: boolean): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.udp_socket_set_broadcast(this._handle, broadcast)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "set_broadcast failed" }) end
    end)
    return future
end

--[[
    Returns the value of the SO_BROADCAST option for this socket.
    @param self The UDP socket instance
    @return A future resolving to the broadcast value
]]
function UdpSocketMT:broadcast(): Async.TaskFuture<boolean>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local b, err = native.udp_socket_broadcast(this._handle)
        if b ~= nil then resolve(b) else reject({ kind = "IoError", message = err or "broadcast failed" }) end
    end)
    return future
end

--[[
    Closes the UDP socket.
    @param self The UDP socket instance
]]
function UdpSocketMT:close()
    (self :: any)._handle = nil
end

local UdpSocketObj = {}

--[[
    Creates a new UDP socket which will be bound to the specified address.
    @param addr The address to bind to (string or SocketAddr)
    @return A future resolving to the new UdpSocket
]]
function UdpSocketObj.bind(addr: string | types.SocketAddr): Async.TaskFuture<types.UdpSocket>
    local addr_str = if type(addr) == "string" then addr else addr:to_string()
    local future, resolve, reject = Async.new_future()
    
    task.defer(function()
        local handle, err = native.udp_bind(addr_str)
        if handle then
            local self: Self = { _handle = handle }
            resolve(setmetatable(self, UdpSocketMT) :: any)
        else
            reject({ kind = "AddrInUse", message = err or "bind failed" })
        end
    end)
    
    return future
end

return UdpSocketObj
