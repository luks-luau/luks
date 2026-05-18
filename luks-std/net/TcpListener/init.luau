--!strict
-- luks-std/Net/TcpListener/init.luau
local Async = require("@self/../../async")
local types = require("@self/../types")
local SocketAddr = require("@self/../SocketAddr")
                local TcpStream = require("@self/../TcpStream")

type Self = {
    _handle: any,
}

local TcpListenerMT = {}
TcpListenerMT.__index = TcpListenerMT

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
    Accepts a new incoming connection from this listener.
    @param self The TCP listener instance
    @return A future resolving to a table with the new TcpStream and its remote address
]]
function TcpListenerMT:accept(): Async.TaskFuture<{ stream: types.TcpStream, addr: types.SocketAddr }>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    
    task.spawn(function()
        while true do
            if not this._handle then
                reject({ kind = "IoError", message = "listener is closed" })
                break
            end
            local stream_handle, addr_str = native.tcp_accept(this._handle)
            if stream_handle then
                local stream = TcpStream._from_handle(stream_handle)
                resolve({
                    stream = stream,
                    addr = SocketAddr.parse(addr_str)
                })
                break
            elseif addr_str == "WouldBlock" then
                task.wait() -- Let other tasks run
            else
                reject({ kind = "IoError", message = addr_str or "accept failed" })
                break
            end
        end
    end)
    
    return future
end

--[[
    Returns the local address that this listener is bound to.
    @param self The TCP listener instance
    @return A future resolving to the local SocketAddr
]]
function TcpListenerMT:local_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    
    task.spawn(function()
        local addr_str, err = native.tcp_listener_local_addr(this._handle)
        if addr_str then
            resolve(SocketAddr.parse(addr_str))
        else
            reject({ kind = "IoError", message = err or "local_addr failed" })
        end
    end)
    
    return future
end

--[[
    Sets the value for the IP_TTL option on this socket.
    @param self The TCP listener instance
    @param ttl The time-to-live value
    @return A future resolving when the option is set
]]
function TcpListenerMT:set_ttl(ttl: number): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.tcp_listener_set_ttl(this._handle, ttl)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "set_ttl failed" }) end
    end)
    return future
end

--[[
    Returns the time-to-live option for this socket.
    @param self The TCP listener instance
    @return A future resolving to the TTL value
]]
function TcpListenerMT:ttl(): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local n, err = native.tcp_listener_ttl(this._handle)
        if n then resolve(n) else reject({ kind = "IoError", message = err or "ttl failed" }) end
    end)
    return future
end

--[[
    Closes the TCP listener.
    @param self The TCP listener instance
]]
function TcpListenerMT:close()
    (self :: any)._handle = nil
end

local TcpListenerObj = {}

--[[
    Creates a new TcpListener which will be bound to the specified address.
    @param addr The address to bind to (string or SocketAddr)
    @return A future resolving to the new TcpListener
]]
function TcpListenerObj.bind(addr: string | types.SocketAddr): Async.TaskFuture<types.TcpListener>
    local addr_str = if type(addr) == "string" then addr else addr:to_string()
    local future, resolve, reject = Async.new_future()
    
    task.defer(function()
        local handle, err = native.tcp_bind(addr_str)
        if handle then
            local self: Self = { _handle = handle }
            resolve(setmetatable(self, TcpListenerMT) :: any)
        else
            reject({ kind = "AddrInUse", message = err or "bind failed" })
        end
    end)
    
    return future
end

return TcpListenerObj
