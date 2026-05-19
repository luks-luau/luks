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
        local ok, err = pcall(function()
            while true do
                if not this._handle then error("socket is closed") end
                local ok_, result, wb = pcall(native.udp_send_to, this._handle, buf, addr_str)
                if ok_ then
                    if result then return result end
                    if wb == "WouldBlock" then task.wait() else error("send_to failed") end
                else
                    error(tostring(result))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
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
        local ok, err = pcall(function()
            while true do
                if not this._handle then error("socket is closed") end
                local ok_, result, addr_str = pcall(native.udp_recv_from, this._handle, buf)
                if ok_ then
                    if result then return { bytes = result, addr = SocketAddr.parse(addr_str) } end
                    if addr_str == "WouldBlock" then task.wait() else error("recv_from failed") end
                else
                    error(tostring(result))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
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
        local ok, err = pcall(function()
            while true do
                if not this._handle then error("socket is closed") end
                local ok_, result, addr_str = pcall(native.udp_peek_from, this._handle, buf)
                if ok_ then
                    if result then return { bytes = result, addr = SocketAddr.parse(addr_str) } end
                    if addr_str == "WouldBlock" then task.wait() else error("peek_from failed") end
                else
                    error(tostring(result))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
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
        local ok, result = pcall(native.udp_socket_local_addr, this._handle)
        if ok then resolve(SocketAddr.parse(result)) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function UdpSocketMT:connect(addr: string | types.SocketAddr): Async.TaskFuture<any>
    local this: Self = self :: any
    local addr_str = if type(addr) == "string" then addr else addr:to_string()
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.udp_connect, this._handle, addr_str)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function UdpSocketMT:send(buf: buffer | string): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local ok, err = pcall(function()
            while true do
                if not this._handle then error("socket is closed") end
                local ok_, result, wb = pcall(native.udp_send, this._handle, buf)
                if ok_ then
                    if result then return result end
                    if wb == "WouldBlock" then task.wait() else error("send failed") end
                else
                    error(tostring(result))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
    end)
    return future
end

function UdpSocketMT:recv(buf: buffer): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local ok, err = pcall(function()
            while true do
                if not this._handle then error("socket is closed") end
                local ok_, result, wb = pcall(native.udp_recv, this._handle, buf)
                if ok_ then
                    if result then return result end
                    if wb == "WouldBlock" then task.wait() else error("recv failed") end
                else
                    error(tostring(result))
                end
            end
        end)
        if ok then resolve(err) else reject({ kind = "IoError", message = tostring(err) }) end
    end)
    return future
end

function UdpSocketMT:peer_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.udp_socket_peer_addr, this._handle)
        if ok then resolve(SocketAddr.parse(result)) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function UdpSocketMT:set_ttl(ttl: number): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.udp_socket_set_ttl, this._handle, ttl)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function UdpSocketMT:ttl(): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.udp_socket_ttl, this._handle)
        if ok then resolve(result) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function UdpSocketMT:set_broadcast(broadcast: boolean): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.udp_socket_set_broadcast, this._handle, broadcast)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function UdpSocketMT:broadcast(): Async.TaskFuture<boolean>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.udp_socket_broadcast, this._handle)
        if ok then resolve(result) else reject({ kind = "IoError", message = tostring(result) }) end
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
        local ok, handle = pcall(native.udp_bind, addr_str)
        if ok then
            local self: Self = { _handle = handle }
            resolve(setmetatable(self, UdpSocketMT) :: any)
        else
            reject({ kind = "AddrInUse", message = tostring(handle) })
        end
    end)
    
    return future
end

return UdpSocketObj
