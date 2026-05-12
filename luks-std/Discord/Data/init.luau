--!strict

--[[
    Data Namespace — Mappings, Gateway Opcodes, and Bitwise Intents registry
    for the enterprise luks-std/Discord library.
]]

local Data = {}

-- [[ Gateway Intents Registry ]]
-- Utiliza inteiros exatos correspondentes à documentação oficial da API do Discord (v10).
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
    Combina múltiplos Intents utilizando a operação bitwise OR nativa do Luau (bit32.bor).
    @param ... Inteiros representando cada Intent.
    @return O bitmask combinado.
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
    Retorna os Intents padrões recomendados para a maioria dos bots comuns.
]]
function Intents.default(): number
    return Intents.create(
        IntentsFlags.Guilds,
        IntentsFlags.GuildMessages,
        IntentsFlags.MessageContent
    )
end

--[[
    Retorna todos os Intents possíveis ativados (requer permissão no portal Developer do Discord).
]]
function Intents.all(): number
    local result = 0
    for _, flag in pairs(IntentsFlags) do
        result = bit32.bor(result, flag)
    end
    return result
end

--[[ Retorna o valor 0 (nenhum intent ativado). ]]
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
