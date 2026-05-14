--!strict
--!native
--!optimize 2

--[[
    Discord Standard Library for luks-luau.
    An Enterprise Object-Oriented Framework compatible with Luau types.
]]

local Client = require("@self/Client")
local Embed = require("@self/Structures/Embed")
local Components = require("@self/Structures/Components")
local Data = require("@self/Data")
local VoiceState = require("@self/Structures/VoiceState")
local ThreadChannel = require("@self/Structures/ThreadChannel")

local Discord = {
    Client = Client,
    Embed = Embed,
    Components = Components,
    Data = Data,
    VoiceState = VoiceState,
    ThreadChannel = ThreadChannel,
}

table.freeze(Discord)
return Discord
