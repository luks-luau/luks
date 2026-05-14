--!strict
--!native
--!optimize 2

--[[
    Data Namespace — Mappings, Gateway Opcodes, and Bitwise Intents registry
    for the enterprise luks-std/Discord library.
]]

local Data = {}

-- [[ Gateway Intents Registry ]]
-- Uses exact integer bitmask flags mapped to official Discord API v10 specifications.
local IntentsFlags = {
    Guilds = bit32.lshift(1, 0),
    GuildMembers = bit32.lshift(1, 1),
    GuildModeration = bit32.lshift(1, 2),
    GuildEmojisAndStickers = bit32.lshift(1, 3),
    GuildIntegrations = bit32.lshift(1, 4),
    GuildWebhooks = bit32.lshift(1, 5),
    GuildInvites = bit32.lshift(1, 6),
    GuildVoiceStates = bit32.lshift(1, 7),
    GuildPresences = bit32.lshift(1, 8),
    GuildMessages = bit32.lshift(1, 9),
    GuildMessageReactions = bit32.lshift(1, 10),
    GuildMessageTyping = bit32.lshift(1, 11),
    DirectMessages = bit32.lshift(1, 12),
    DirectMessageReactions = bit32.lshift(1, 13),
    DirectMessageTyping = bit32.lshift(1, 14),
    MessageContent = bit32.lshift(1, 15),
    GuildScheduledEvents = bit32.lshift(1, 16),
    AutoModerationConfiguration = bit32.lshift(1, 20),
    AutoModerationExecution = bit32.lshift(1, 21),
    GuildMessagePolls = bit32.lshift(1, 24),
    DirectMessagePolls = bit32.lshift(1, 25),
}

table.freeze(IntentsFlags)

local Intents = {}
setmetatable(Intents, {
    __index = IntentsFlags
})

--[[
    Combines multiple Intent bitmask flags using native Luau bitwise OR operations (bit32.bor).
    @param ... Integers representing individual Intent flags
    @return The composed aggregate bitmask integer
]]
function Intents.create(...: number): number
    local result = 0
    for i = 1, select("#", ...) do
        local val = select(i, ...)
        if type(val) == "number" then
            result = bit32.bor(result, val)
        end
    end
    return result
end

--[[
    Returns standard recommended Intent subscriptions suitable for ordinary bot operations.
    @return The default composed bitmask integer
]]
function Intents.default(): number
    return Intents.create(
        IntentsFlags.Guilds,
        IntentsFlags.GuildMessages,
        IntentsFlags.MessageContent
    )
end

--[[
    Returns an unconstrained bitmask activating all possible Gateway Intents.
    Note: Privileged intents require explicit activation within the Discord Developer portal.
    @return The comprehensive bitmask integer
]]
function Intents.all(): number
    local result = 0
    for _, flag in pairs(IntentsFlags) do
        result = bit32.bor(result, flag)
    end
    return result
end

--[[
    Returns an empty subscription mask (no active intents).
    @return Zero bitmask integer
]]
function Intents.none(): number
    return 0
end

table.freeze(Intents)
Data.Intents = Intents

-- [[ Gateway Opcodes ]]
local Opcodes = {
    Dispatch = 0,
    Heartbeat = 1,
    Identify = 2,
    PresenceUpdate = 3,
    VoiceStateUpdate = 4,
    Resume = 6,
    Reconnect = 7,
    RequestGuildMembers = 8,
    InvalidSession = 9,
    Hello = 10,
    HeartbeatAck = 11,
}

table.freeze(Opcodes)
Data.Opcodes = Opcodes

-- [[ REST & Gateway Constants ]]
local Constants = {
    ApiVersion = 10,
    BaseUrl = "https://discord.com/api/v10",
    GatewayParams = "/?v=10&encoding=json",
}

table.freeze(Constants)
Data.Constants = Constants

table.freeze(Data)
return Data
