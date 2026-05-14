--!strict
--!native
--!optimize 2

--[[
    Gateway Layer — Stateful WebSocket connection engine for luks-std/Discord.
    Implements intelligent auto-reconnect, opcode routing, and memory leak mitigation protocols.
]]

local WebSocket = require("../WebSocket")
local Json = require("../Json")
local Data = require("Data")
local User = require("Structures/User")
local Message = require("Structures/Message")
local Guild = require("Structures/Guild")
local Member = require("Structures/Member")
local Interaction = require("Structures/Interaction")
local VoiceState = require("Structures/VoiceState")

export type GatewayManager = {
    _client: any,
    _conn: any?,
    _sequence: number?,
    _connected: boolean,
    _activeSignals: { any },
    _running: boolean,

    --[[
        Initiates the persistent WebSocket gateway connection and event loop polling.
        @param self The gateway manager instance
    ]]
    connect: (self: GatewayManager) -> (),
    
    --[[
        Terminates the gateway streaming channel cleanly and halts reconnection loops.
        @param self The gateway manager instance
    ]]
    disconnect: (self: GatewayManager) -> (),
    
    --[[
        Transmits real-time status and activity updates to the upstream server stream.
        @param self The gateway manager instance
        @param presence Encoded table payload representing current activity status
        @return True if transmitted successfully across active socket stream
    ]]
    sendPresence: (self: GatewayManager, presence: { [string]: any }) -> boolean,
    
    --[[
        Directs the gateway layer to update internal voice state presence metrics.
        @param self The gateway manager instance
        @param guildId Target guild identifier hosting the destination audio channel
        @param channelId Voice channel ID to join, or nil to leave
        @param selfMute Enforces a locally muted state
        @param selfDeaf Enforces a locally deafened state
        @return True if the frame payload was correctly sent
    ]]
    sendVoiceStateUpdate: (self: GatewayManager, guildId: string, channelId: string?, selfMute: boolean?, selfDeaf: boolean?) -> boolean,
    
    --[[
        Internal resource cleanup logic that disposes of leftover event handlers.
        @param self The gateway manager instance
    ]]
    _cleanup: (self: GatewayManager) -> (),
}

local Gateway = {}
local GatewayMT = {}
GatewayMT.__index = GatewayMT

--[[
    Instantiates a stateful GatewayManager layer binding directly to client loops.
    @param client Abstract application host instance reference
    @return A new GatewayManager object wrapper
]]
function Gateway.new(client: any): GatewayManager
    local self = {
        _client = client,
        _conn = nil,
        _sequence = nil,
        _connected = false,
        _activeSignals = {},
        _running = false,
    }
    setmetatable(self, GatewayMT)
    return (self :: any) :: GatewayManager
end

--[[
    Internal resource cleanup logic that disposes of leftover event handlers.
    @param self The gateway manager instance
]]
function GatewayMT:_cleanup()
    for _, sig in ipairs(self._activeSignals) do
        pcall(function() sig:Disconnect() end)
    end
    table.clear(self._activeSignals)

    local conn = self._conn
    if conn then
        pcall(function() (conn :: any):close() end)
        self._conn = nil
    end

    self._connected = false
end

--[[
    Terminates the gateway streaming channel cleanly and halts reconnection loops.
    @param self The gateway manager instance
]]
function GatewayMT:disconnect()
    self._running = false
    self:_cleanup()
    if self._client and self._client.onClose then
        self._client.onClose:Fire({ code = 1000, reason = "Disconnected intentionally by user application." })
    end
end

--[[
    Transmits real-time status and activity updates to the upstream server stream.
    @param self The gateway manager instance
    @param presence Encoded table payload representing current activity status
    @return True if transmitted successfully across active socket stream
]]
function GatewayMT:sendPresence(presence: { [string]: any }): boolean
    if not self._connected or not self._conn then return false end
    local payload = {
        op = Data.Opcodes.PresenceUpdate,
        d = presence,
    }
    local ok = pcall(function()
        self._conn:send(Json.encode(payload))
    end)
    return ok
end

--[[
    Directs the gateway layer to update internal voice state presence metrics.
    @param self The gateway manager instance
    @param guildId Target guild identifier hosting the destination audio channel
    @param channelId Voice channel ID to join, or nil to leave
    @param selfMute Enforces a locally muted state
    @param selfDeaf Enforces a locally deafened state
    @return True if the frame payload was correctly sent
]]
function GatewayMT:sendVoiceStateUpdate(guildId: string, channelId: string?, selfMute: boolean?, selfDeaf: boolean?): boolean
    if not self._connected or not self._conn then return false end
    local payload = {
        op = Data.Opcodes.VoiceStateUpdate,
        d = {
            guild_id = tostring(guildId),
            channel_id = channelId,
            self_mute = selfMute == true,
            self_deaf = selfDeaf == true,
        }
    }
    local ok = pcall(function()
        self._conn:send(Json.encode(payload))
    end)
    return ok
end

--[[
    Initiates the persistent WebSocket gateway connection and event loop polling.
    @param self The gateway manager instance
]]
function GatewayMT:connect()
    if self._running then return end
    self._running = true

    task.spawn(function()
        while self._running do
            if not self._connected then
                self:_cleanup()
                
                local rest = self._client and self._client.rest
                if not rest then
                    task.wait(2)
                    continue
                end

                local ok, data = rest:get("https://discord.com/api/v10/gateway")
                if not ok or type(data) ~= "table" or not data.url then
                    task.wait(5)
                    continue
                end

                local gatewayUrl = tostring(data.url) .. Data.Constants.GatewayParams
                local connOk, conn = pcall(WebSocket.connect, gatewayUrl)
                if not connOk or not conn then
                    task.wait(5)
                    continue
                end

                self._connected = true
                self._conn = conn

                table.insert(self._activeSignals, conn.onMessage:Connect(function(msg)
                    if not msg or not msg.data then return end
                    
                    local jsonOk, payload = pcall(Json.decode, msg.data)
                    if not jsonOk or type(payload) ~= "table" then return end

                    if payload.s then
                        self._sequence = payload.s
                    end

                    local op = payload.op
                    local t = payload.t

                    if op == Data.Opcodes.Hello then
                        local interval = payload.d and payload.d.heartbeat_interval or 41250
                        local intentsMask = self._client.intents or 33281
                        
                        local identifyPayload = {
                            op = Data.Opcodes.Identify,
                            d = {
                                token = self._client.token or "",
                                intents = intentsMask,
                                properties = {
                                    os = "luks-luau",
                                    browser = "luks-luau",
                                    device = "luks-luau",
                                }
                            }
                        }
                        pcall(function() conn:send(Json.encode(identifyPayload)) end)

                        task.spawn(function()
                            while self._connected and self._conn == conn do
                                task.wait(interval / 1000)
                                if self._connected and self._conn == conn then
                                    local hbOk = pcall(function()
                                        if conn:isOpen() then
                                            conn:send(Json.encode({
                                                op = Data.Opcodes.Heartbeat,
                                                d = self._sequence or "null"
                                            }))
                                        end
                                    end)
                                    if not hbOk then break end
                                 end
                            end
                        end)
                    end

                    if op == Data.Opcodes.Dispatch then
                        if t == "READY" then
                            local userData = payload.d and payload.d.user or {}
                            local selfUser = User.new(userData)
                            if self._client then
                                self._client.user = selfUser
                                -- Automatically cache assigned application_id
                                if payload.d and payload.d.application and payload.d.application.id then
                                    self._client.application_id = tostring(payload.d.application.id)
                                end
                                if self._client.onReady then
                                    self._client.onReady:Fire(selfUser)
                                end
                            end
                        elseif t == "MESSAGE_CREATE" then
                            if self._client and self._client.onMessageCreate then
                                local msgObj = Message.new(payload.d or {}, self._client.rest)
                                self._client.onMessageCreate:Fire(msgObj)
                            end
                        elseif t == "GUILD_CREATE" then
                            if self._client and self._client.onGuildCreate then
                                local guildObj = Guild.new(payload.d or {}, self._client.rest)
                                self._client.onGuildCreate:Fire(guildObj)
                            end
                        elseif t == "INTERACTION_CREATE" then
                            if self._client and self._client.onInteractionCreate then
                                local interactionObj = Interaction.new(payload.d or {}, self._client.rest)
                                -- Enforce fallback caching of application_id if omitted
                                if not interactionObj.application_id or interactionObj.application_id == "" then
                                    interactionObj.application_id = self._client.application_id or ""
                                end
                                self._client.onInteractionCreate:Fire(interactionObj)
                            end
                        elseif t == "GUILD_MEMBER_ADD" then
                            if self._client and self._client.onGuildMemberAdd then
                                local guildId = payload.d and payload.d.guild_id
                                local memberObj = Member.new(payload.d or {}, guildId, self._client.rest)
                                self._client.onGuildMemberAdd:Fire(memberObj)
                            end
                        elseif t == "GUILD_MEMBER_REMOVE" then
                            if self._client and self._client.onGuildMemberRemove then
                                local remData = payload.d or {}
                                self._client.onGuildMemberRemove:Fire({
                                    guild_id = tostring(remData.guild_id or ""),
                                    user = User.new(remData.user or {}),
                                })
                            end
                        elseif t == "VOICE_STATE_UPDATE" then
                            if self._client and self._client.onVoiceStateUpdate then
                                local vsObj = VoiceState.new(payload.d or {})
                                self._client.onVoiceStateUpdate:Fire(vsObj)
                            end
                        end
                    end

                    if op == Data.Opcodes.Reconnect then
                        self._connected = false
                    end
                end))

                table.insert(self._activeSignals, conn.onClose:Connect(function(info)
                    self._connected = false
                    if self._client and self._client.onClose then
                        self._client.onClose:Fire(info or { code = 1000, reason = "Connection closed remotely by target server." })
                    end
                end))

                table.insert(self._activeSignals, conn.onError:Connect(function(err)
                    self._connected = false
                    if self._client and self._client.onError then
                        self._client.onError:Fire(tostring(err))
                    end
                end))

                conn:startListening()
            end

            task.wait()
        end
    end)
end

table.freeze(GatewayMT)
table.freeze(Gateway)
return Gateway