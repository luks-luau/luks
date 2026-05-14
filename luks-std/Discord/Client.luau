--!strict
--!native
--!optimize 2

--[[
    Client Namespace — Base Object-Oriented Application orchestrator for luks-std/Discord.
]]

local Signal = require("@self/../Signal")
local Rest = require("@self/Rest")
local Gateway = require("@self/Gateway")
local Channel = require("@self/Structures/Channel")
local User = require("@self/Structures/User")
local Message = require("@self/Structures/Message")
local Guild = require("@self/Structures/Guild")
local Member = require("@self/Structures/Member")
local Interaction = require("@self/Structures/Interaction")
local VoiceState = require("@self/Structures/VoiceState")

export type DiscordClient = {
    --[[ Authentication API Token. ]]
    token: string?,
    
    --[[ OAuth2 Application ID assigned to this bot. ]]
    application_id: string?,
    
    --[[ Authenticated User entity representation (populated upon onReady). ]]
    user: User.User?,
    
    --[[ Bitwise composed integer defining authorized Gateway event subscriptions. ]]
    intents: number?,
    
    --[[ Internal REST API consumer interface. ]]
    rest: Rest.RestClient,
    
    --[[ Internal stateful Gateway connection manager. ]]
    gateway: Gateway.GatewayManager,

    -- Strongly typed real-time execution signals
    --[[ Triggered when the bot successfully completes initial Gateway handshake and caching loops. ]]
    onReady: Signal.Signal<User.User>,
    
    --[[ Dispatched when a text message is received across accessible channels. ]]
    onMessageCreate: Signal.Signal<Message.Message>,
    
    --[[ Fired when a guild becomes accessible or is joined. ]]
    onGuildCreate: Signal.Signal<Guild.Guild>,
    
    --[[ Triggered by slash commands, button interactions, or modal popup submissions. ]]
    onInteractionCreate: Signal.Signal<Interaction.Interaction>,
    
    --[[ Dispatched when a new user joins a monitored guild. ]]
    onGuildMemberAdd: Signal.Signal<Member.Member>,
    
    --[[ Fired when a member departs or is removed from a server. ]]
    onGuildMemberRemove: Signal.Signal<{ guild_id: string, user: User.User }>,
    
    --[[ Broadcasts real-time adjustments to user voice state presence. ]]
    onVoiceStateUpdate: Signal.Signal<VoiceState.VoiceState>,
    
    --[[ Emitted when the underlying WebSocket drops connection permanently. ]]
    onClose: Signal.Signal<{ code: number, reason: string }>,
    
    --[[ Dispatched upon unrecoverable protocol execution errors. ]]
    onError: Signal.Signal<string>,

    --[[
        Authenticates and connects the client to the Discord API ecosystem.
        @param self The client instance
        @param token Optional authentication token to override the configured token
    ]]
    login: (self: DiscordClient, token: string?) -> (),
    
    --[[
        Disconnects active socket streams and terminates polling intervals.
        @param self The client instance
    ]]
    close: (self: DiscordClient) -> (),
    
    --[[
        Instantiates a channel entity interface mapped to a unique destination ID.
        @param self The client instance
        @param id The unique identifier of the target channel
        @return A new Channel instance interface
    ]]
    getChannel: (self: DiscordClient, id: string) -> Channel.Channel,
    
    --[[
        Broadcasts real-time status presence updates to the gateway stream.
        @param self The client instance
        @param presence Table containing status, activities, afk flag, and idle timestamp
        @return True if successfully enqueued or sent to the gateway stream
    ]]
    setStatus: (self: DiscordClient, presence: { status: string?, activities: { any }?, afk: boolean?, since: number? }) -> boolean,
    
    --[[
        Overwrites or synchronizes global/guild Application Slash Commands against Discord REST registries.
        @param self The client instance
        @param commands Array of structured application commands to register
        @param guildId Optional target guild ID to register local commands instead of global ones
        @return Success status and the resulting JSON payload response or error message
    ]]
    registerCommands: (self: DiscordClient, commands: { any }, guildId: string?) -> (boolean, any),

    --[[
        Directs the gateway layer to join, migrate, or leave a designated audio channel.
        @param self The client instance
        @param guildId The guild identifier hosting the target voice channel
        @param channelId Optional voice channel ID to join, or nil to disconnect
        @param mute Whether the bot should join self-muted
        @param deaf Whether the bot should join self-deafened
        @return True if the voice state update payload was successfully sent
    ]]
    joinVoiceChannel: (self: DiscordClient, guildId: string, channelId: string?, mute: boolean?, deaf: boolean?) -> boolean,
}

local Client = {}
local ClientMT = {}
ClientMT.__index = ClientMT

--[[
    Instantiates a fresh DiscordClient application host.
    @param options Optional client options containing token, intents, and application ID
    @return A new DiscordClient instance
]]
function Client.new(options: { token: string?, intents: number?, application_id: string? }?): DiscordClient
    local opts = (options or {}) :: { token: string?, intents: number?, application_id: string? }
    
    local onReadySig = Signal.new()
    local onMessageSig = Signal.new()
    local onGuildSig = Signal.new()
    local onInteractionSig = Signal.new()
    local onMemberAddSig = Signal.new()
    local onMemberRemoveSig = Signal.new()
    local onVoiceStateSig = Signal.new()
    local onCloseSig = Signal.new()
    local onErrorSig = Signal.new()

    local self = {
        token = opts.token,
        application_id = opts.application_id,
        user = nil,
        intents = opts.intents,
        
        onReady = onReadySig:Public(),
        onMessageCreate = onMessageSig:Public(),
        onGuildCreate = onGuildSig:Public(),
        onInteractionCreate = onInteractionSig:Public(),
        onGuildMemberAdd = onMemberAddSig:Public(),
        onGuildMemberRemove = onMemberRemoveSig:Public(),
        onVoiceStateUpdate = onVoiceStateSig:Public(),
        onClose = onCloseSig:Public(),
        onError = onErrorSig:Public(),
    }

    self.rest = Rest.new(self)
    self.gateway = Gateway.new(self)

    ;(self.gateway :: any)._client = {
        token = self.token,
        application_id = self.application_id,
        intents = self.intents,
        rest = self.rest,
        onReady = onReadySig,
        onMessageCreate = onMessageSig,
        onGuildCreate = onGuildSig,
        onInteractionCreate = onInteractionSig,
        onGuildMemberAdd = onMemberAddSig,
        onGuildMemberRemove = onMemberRemoveSig,
        onVoiceStateUpdate = onVoiceStateSig,
        onClose = onCloseSig,
        onError = onErrorSig,
    }

    setmetatable(self, ClientMT)
    return (self :: any) :: DiscordClient
end

--[[
    Authenticates and connects the client to the Discord API ecosystem.
    @param self The client instance
    @param token Optional authentication token to override the configured token
]]
function ClientMT:login(token: string?)
    if token then
        self.token = token
        ;(self.gateway :: any)._client.token = token
    end
    if not self.token or self.token == "" then
        error("[Discord.Client] A valid authentication token is mandatory to establish connection streams.")
    end

    print("[Discord.Client] Establishing connection loops to the Discord ecosystem...")
    self.gateway:connect()
end

--[[
    Disconnects active socket streams and terminates polling intervals.
    @param self The client instance
]]
function ClientMT:close()
    print("[Discord.Client] Disconnecting and tearing down the bot execution context...")
    self.gateway:disconnect()
end

--[[
    Instantiates a channel entity interface mapped to a unique destination ID.
    @param self The client instance
    @param id The unique identifier of the target channel
    @return A new Channel instance interface
]]
function ClientMT:getChannel(id: string): Channel.Channel
    return Channel.new({ id = tostring(id) }, self.rest)
end

--[[
    Broadcasts real-time status presence updates to the gateway stream.
    @param self The client instance
    @param presence Table containing status, activities, afk flag, and idle timestamp
    @return True if successfully enqueued or sent to the gateway stream
]]
function ClientMT:setStatus(presence: { status: string?, activities: { any }?, afk: boolean?, since: number? }): boolean
    local p = {
        status = presence.status or "online",
        since = presence.since or 0,
        afk = presence.afk == true,
        activities = presence.activities or {},
    }
    return self.gateway:sendPresence(p)
end

--[[
    Overwrites or synchronizes global/guild Application Slash Commands against Discord REST registries.
    @param self The client instance
    @param commands Array of structured application commands to register
    @param guildId Optional target guild ID to register local commands instead of global ones
    @return Success status and the resulting JSON payload response or error message
]]
function ClientMT:registerCommands(commands: { any }, guildId: string?): (boolean, any)
    local appId = self.application_id
    if not appId or appId == "" then
        if self.user and self.user.id and self.user.id ~= "" then
            appId = self.user.id
            self.application_id = appId
        else
            return false, "application_id is unavailable. Please provide the application_id parameter inside Client.new() options or await the onReady runtime signal."
        end
    end

    local finalAppId = (appId or "") :: string
    local endpoint = ""
    if guildId and guildId ~= "" then
        endpoint = "/applications/" .. finalAppId .. "/guilds/" .. guildId .. "/commands"
    else
        endpoint = "/applications/" .. finalAppId .. "/commands"
    end

    return self.rest:put(endpoint, commands)
end

--[[
    Directs the gateway layer to join, migrate, or leave a designated audio channel.
    @param self The client instance
    @param guildId The guild identifier hosting the target voice channel
    @param channelId Optional voice channel ID to join, or nil to disconnect
    @param mute Whether the bot should join self-muted
    @param deaf Whether the bot should join self-deafened
    @return True if the voice state update payload was successfully sent
]]
function ClientMT:joinVoiceChannel(guildId: string, channelId: string?, mute: boolean?, deaf: boolean?): boolean
    return self.gateway:sendVoiceStateUpdate(guildId, channelId, mute, deaf)
end

table.freeze(ClientMT)
table.freeze(Client)
return Client
