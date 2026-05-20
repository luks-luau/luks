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
        local ok, err = pcall(function()
            while true do
                if not this._handle then error("listener is closed") end
                local ok_, result, addr = pcall(native.tcp_accept, this._handle)
                if ok_ then
                    if result then
                        local stream = TcpStream._from_handle(result)
                        return { stream = stream, addr = SocketAddr.parse(addr) }
                    end
                    if addr == "WouldBlock" then task.wait() else error("accept failed") end
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
    Returns the local address that this listener is bound to.
    @param self The TCP listener instance
    @return A future resolving to the local SocketAddr
]]
function TcpListenerMT:local_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    
    task.spawn(function()
        local ok, result = pcall(native.tcp_listener_local_addr, this._handle)
        if ok then resolve(SocketAddr.parse(result)) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    
    return future
end

function TcpListenerMT:set_ttl(ttl: number): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.tcp_listener_set_ttl, this._handle, ttl)
        if ok then resolve(nil) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end

function TcpListenerMT:ttl(): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, result = pcall(native.tcp_listener_ttl, this._handle)
        if ok then resolve(result) else reject({ kind = "IoError", message = tostring(result) }) end
    end)
    return future
end
--[[
    Closes the TCP listener.
    @param self The TCP listener instance
]]
function TcpListenerMT:close()
    local handle = (self :: any)._handle
    if handle then
        pcall(native.tcp_listener_close, handle)
    end
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
        local ok, handle = pcall(native.tcp_bind, addr_str)
        if ok then
            local self: Self = { _handle = handle }
            resolve(setmetatable(self, TcpListenerMT) :: any)
        else
            reject({ kind = "AddrInUse", message = tostring(handle) })
        end
    end)
    
    return future
end

return TcpListenerObj
