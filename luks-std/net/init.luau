--!strict
-- luks-std/Net/init.luau
-- Networking library for luks-luau (TCP/UDP/IP)
-- Networking module following Rust std::net API

local types = require("@self/types")
local IpAddr = require("@self/IpAddr")
local SocketAddr = require("@self/SocketAddr")
local TcpListener = require("@self/TcpListener")
local TcpStream = require("@self/TcpStream")
local UdpSocket = require("@self/UdpSocket")

export type IpAddr = types.IpAddr
export type SocketAddr = types.SocketAddr
export type TcpListener = types.TcpListener
export type TcpStream = types.TcpStream
export type UdpSocket = types.UdpSocket
export type Shutdown = types.Shutdown

local Net = {}

Net.IpAddr = IpAddr
Net.SocketAddr = SocketAddr
Net.TcpListener = TcpListener
Net.TcpStream = TcpStream
Net.UdpSocket = UdpSocket

return Net
