--!strict
-- luks-std/Net/SocketAddr/init.luau
local types = require("@self/../types")
local IpAddr = require("@self/../IpAddr")

type Self = {
    _ip: types.IpAddr,
    _port: number,
}

local SocketAddr = {}
local SocketAddrMT = {}
SocketAddrMT.__index = SocketAddrMT

--[[
    Returns the IP address part of the socket address.
    @param self The socket address instance
    @return The IpAddr object
]]
function SocketAddrMT:ip(): types.IpAddr
    local this: Self = self :: any
    return this._ip
end

--[[
    Returns the port number.
    @param self The socket address instance
    @return The port number
]]
function SocketAddrMT:port(): number
    local this: Self = self :: any
    return this._port
end

--[[
    Returns whether the address is IPv4.
    @param self The socket address instance
    @return True if IPv4
]]
function SocketAddrMT:is_ipv4(): boolean
    local this: Self = self :: any
    return this._ip:is_v4()
end

--[[
    Returns whether the address is IPv6.
    @param self The socket address instance
    @return True if IPv6
]]
function SocketAddrMT:is_ipv6(): boolean
    local this: Self = self :: any
    return this._ip:is_v6()
end

--[[
    Returns a string representation of the socket address.
    @param self The socket address instance
    @return The formatted address string
]]
function SocketAddrMT:to_string(): string
    local this: Self = self :: any
    local ip_str = this._ip:to_string()
    if this._ip:is_v6() then
        return "[" .. ip_str .. "]:" .. tostring(this._port)
    else
        return ip_str .. ":" .. tostring(this._port)
    end
end

--[[
    Creates a new SocketAddr instance from an IP and a port.
    @param ip The IP address (string or IpAddr)
    @param port The port number
    @return A new SocketAddr instance
]]
function SocketAddr.new(ip: string | types.IpAddr, port: number): types.SocketAddr
    local ip_obj = if type(ip) == "string" then IpAddr.new(ip) else ip
    local self: Self = {
        _ip = ip_obj,
        _port = port,
    }
    return setmetatable(self, SocketAddrMT) :: any
end

--[[
    Parses a string into a SocketAddr.
    Supports "ip:port" (IPv4) and "[ip]:port" (IPv6) formats.
    @param addr The address string to parse
    @return A new SocketAddr instance
]]
function SocketAddr.parse(addr: string): types.SocketAddr
    -- Basic parser for "ip:port" or "[ip]:port"
    local ip, port
    if string.sub(addr, 1, 1) == "[" then
        local close = string.find(addr, "]", 2, true)
        if close then
            ip = string.sub(addr, 2, close - 1)
            port = tonumber(string.sub(addr, close + 2))
        end
    else
        local colon = string.find(addr, ":", 1, true)
        if colon then
            ip = string.sub(addr, 1, colon - 1)
            port = tonumber(string.sub(addr, colon + 1))
        end
    end
    
    if not ip or not port then
        error("Invalid SocketAddr format: " .. addr)
    end
    
    return SocketAddr.new(ip, port)
end

return SocketAddr
