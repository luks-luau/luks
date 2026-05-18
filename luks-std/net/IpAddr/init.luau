--!strict
-- luks-std/Net/IpAddr/init.luau
local types = require("@self/../types")

type Self = {
    _addr: string,
    _is_v6: boolean,
}

local IpAddr = {}
local IpAddrMT = {}
IpAddrMT.__index = IpAddrMT

--[[
    Returns whether the address is an IPv4 address.
    @param self The IP address instance
    @return True if IPv4
]]
function IpAddrMT:is_v4() return not self._is_v6 end

--[[
    Returns whether the address is an IPv6 address.
    @param self The IP address instance
    @return True if IPv6
]]
function IpAddrMT:is_v6() return self._is_v6 end

--[[
    Returns whether the address is a loopback address.
    @param self The IP address instance
    @return True if loopback
]]
function IpAddrMT:is_loopback()
    if self._is_v6 then
        return self._addr == "::1"
    else
        return string.match(self._addr, "^127%.") ~= nil
    end
end

--[[
    Returns whether the address is an unspecified address (0.0.0.0 or ::).
    @param self The IP address instance
    @return True if unspecified
]]
function IpAddrMT:is_unspecified()
    return self._addr == "0.0.0.0" or self._addr == "::"
end

--[[
    Returns whether the address is a multicast address.
    @param self The IP address instance
    @return True if multicast
]]
function IpAddrMT:is_multicast()
    if self._is_v6 then
        return string.match(self._addr, "^ff") ~= nil
    else
        local first_str = string.match(self._addr, "^(%d+)")
        local first = if first_str then tonumber(first_str) else nil
        return if first then (first >= 224 and first <= 239) else false
    end
end

--[[
    Returns a string representation of the IP address.
    @param self The IP address instance
    @return The formatted IP string
]]
function IpAddrMT:to_string() return self._addr end

--[[
    Creates a new IpAddr instance from a string.
    @param addr The IP address string
    @return A new IpAddr instance
]]
function IpAddr.new(addr: string): types.IpAddr
    local is_v6 = string.find(addr, ":") ~= nil
    local self: Self = {
        _addr = addr,
        _is_v6 = is_v6,
    }
    return setmetatable(self, IpAddrMT) :: any
end

return IpAddr
