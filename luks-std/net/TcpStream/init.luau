--!strict
-- luks-std/Net/TcpStream/init.luau
local Async = require("@self/../../async")
local IO = require("@self/../../io")
local types = require("@self/../types")
local SocketAddr = require("@self/../SocketAddr")

type Self = {
    _handle: any,
}

local TcpStreamMT = {}
TcpStreamMT.__index = TcpStreamMT

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
    Attempts to read bytes from the TCP stream into the provided buffer.
    @param self The TCP stream instance
    @param buf The buffer to read into
    @param offset Optional offset in the buffer to start writing
    @param len Optional number of bytes to read
    @return A future resolving to the number of bytes read
]]
function TcpStreamMT:read(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not this._handle then
                reject({ kind = "IoError", message = "stream is closed" })
                break
            end
            local n, err = native.tcp_read(this._handle, buf, offset or 0, len or buffer.len(buf))
            if n then
                resolve(n)
                break
            elseif err == "WouldBlock" then
                task.wait()
            else
                reject({ kind = "IoError", message = err or "read failed" })
                break
            end
        end
    end)
    return future
end

--[[
    Attempts to write bytes from the provided buffer or string into the TCP stream.
    @param self The TCP stream instance
    @param buf The data to write
    @param offset Optional offset in the data to start reading
    @param len Optional number of bytes to write
    @return A future resolving to the number of bytes written
]]
function TcpStreamMT:write(buf: buffer | string, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not this._handle then
                reject({ kind = "IoError", message = "stream is closed" })
                break
            end
            local n, err = native.tcp_write(this._handle, buf, offset or 0, len or (if type(buf) == "string" then #buf else buffer.len(buf)))
            if n then
                resolve(n)
                break
            elseif err == "WouldBlock" then
                task.wait()
            else
                reject({ kind = "IoError", message = err or "write failed" })
                break
            end
        end
    end)
    return future
end

--[[
    Returns the address of the remote peer of this TCP connection.
    @param self The TCP stream instance
    @return A future resolving to the remote SocketAddr
]]
function TcpStreamMT:peer_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local addr_str, err = native.tcp_stream_peer_addr(this._handle)
        if addr_str then resolve(SocketAddr.parse(addr_str)) else reject({ kind = "IoError", message = err or "peer_addr failed" }) end
    end)
    return future
end

--[[
    Returns the local address of this TCP connection.
    @param self The TCP stream instance
    @return A future resolving to the local SocketAddr
]]
function TcpStreamMT:local_addr(): Async.TaskFuture<types.SocketAddr>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local addr_str, err = native.tcp_stream_local_addr(this._handle)
        if addr_str then resolve(SocketAddr.parse(addr_str)) else reject({ kind = "IoError", message = err or "local_addr failed" }) end
    end)
    return future
end

--[[
    Shuts down the read, write, or both halves of this connection.
    @param self The TCP stream instance
    @param how Which part of the connection to shut down
    @return A future resolving when the shutdown is complete
]]
function TcpStreamMT:shutdown(how: types.Shutdown): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.tcp_stream_shutdown(this._handle, how)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "shutdown failed" }) end
    end)
    return future
end

--[[
    Sets the value of the TCP_NODELAY option on this socket.
    @param self The TCP stream instance
    @param nodelay Whether to enable nodelay
    @return A future resolving when the option is set
]]
function TcpStreamMT:set_nodelay(nodelay: boolean): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.tcp_stream_set_nodelay(this._handle, nodelay)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "set_nodelay failed" }) end
    end)
    return future
end

--[[
    Returns the value of the TCP_NODELAY option on this socket.
    @param self The TCP stream instance
    @return A future resolving to the nodelay value
]]
function TcpStreamMT:nodelay(): Async.TaskFuture<boolean>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local n, err = native.tcp_stream_nodelay(this._handle)
        if n ~= nil then resolve(n) else reject({ kind = "IoError", message = err or "nodelay failed" }) end
    end)
    return future
end

--[[
    Receives data from the socket without removing it from the queue.
    @param self The TCP stream instance
    @param buf The buffer to peek into
    @param offset Optional offset in the buffer
    @param len Optional number of bytes to peek
    @return A future resolving to the number of bytes peeked
]]
function TcpStreamMT:peek(buf: buffer, offset: number?, len: number?): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        while true do
            if not this._handle then reject({ kind = "IoError", message = "stream is closed" }); break end
            local n, err = native.tcp_peek(this._handle, buf, offset or 0, len or buffer.len(buf))
            if n then resolve(n); break
            elseif err == "WouldBlock" then task.wait()
            else reject({ kind = "IoError", message = err or "peek failed" }); break end
        end
    end)
    return future
end

--[[
    Sets the value for the IP_TTL option on this socket.
    @param self The TCP stream instance
    @param ttl The time-to-live value
    @return A future resolving when the option is set
]]
function TcpStreamMT:set_ttl(ttl: number): Async.TaskFuture<any>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local ok, err = native.tcp_stream_set_ttl(this._handle, ttl)
        if ok then resolve(nil) else reject({ kind = "IoError", message = err or "set_ttl failed" }) end
    end)
    return future
end

--[[
    Returns the time-to-live option for this socket.
    @param self The TCP stream instance
    @return A future resolving to the TTL value
]]
function TcpStreamMT:ttl(): Async.TaskFuture<number>
    local this: Self = self :: any
    local future, resolve, reject = Async.new_future()
    task.defer(function()
        local n, err = native.tcp_stream_ttl(this._handle)
        if n then resolve(n) else reject({ kind = "IoError", message = err or "ttl failed" }) end
    end)
    return future
end

--[[
    Closes the TCP stream.
    @param self The TCP stream instance
]]
function TcpStreamMT:close()
    (self :: any)._handle = nil
end

-- IO trait combinators
function TcpStreamMT:read_to_end(): Async.TaskFuture<buffer>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local res = buffer.create(0)
        local tmp = buffer.create(8192)
        while true do
            local n, ok = (self :: any):read(tmp):Wait()
            if not ok then reject(n :: any); return end
            if n == 0 then break end
            local num: number = n :: number
            local new_res = buffer.create(buffer.len(res) + num)
            buffer.copy(new_res, 0, res)
            buffer.copy(new_res, buffer.len(res), tmp, 0, num)
            res = new_res
        end
        resolve(res)
    end)
    return future
end
--[[
    Attempts to write all bytes from the provided buffer or string.
    @param self The TCP stream instance
    @param buf The data to write
    @return A future resolving when all data is written
]]
function TcpStreamMT:write_all(buf: buffer | string): Async.TaskFuture<any>
    local future, resolve, reject = Async.new_future()
    task.spawn(function()
        local total = 0
        local len = if type(buf) == "string" then #buf else buffer.len(buf)
        while total < len do
            local n, ok = (self :: IO.Writer):write(buf, total, len - total):Wait()
            if not ok then reject(n :: any); return end
            total += n :: number
        end
        resolve(nil)
    end)
    return future
end

local TcpStreamObj = {}

--[[
    Opens a TCP connection to a remote host.
    @param addr The address to connect to (string or SocketAddr)
    @return A future resolving to the new TcpStream
]]
function TcpStreamObj.connect(addr: string | types.SocketAddr): Async.TaskFuture<types.TcpStream>
    local addr_str = if type(addr) == "string" then addr else addr:to_string()
    local future, resolve, reject = Async.new_future()
    
    task.defer(function()
        local handle, err = native.tcp_connect(addr_str)
        if handle then
            resolve(TcpStreamObj._from_handle(handle))
        else
            reject({ kind = "ConnectionRefused", message = err or "connect failed" })
        end
    end)
    
    return future
end

--[[
    Internal: Creates a new TcpStream from a native handle.
    @param handle The native stream handle
    @return A new TcpStream instance
]]
function TcpStreamObj._from_handle(handle: any): types.TcpStream
    local self: Self = { _handle = handle }
    return setmetatable(self, TcpStreamMT) :: any
end

return TcpStreamObj
