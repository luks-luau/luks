--!strict

--[[
    Message Structure — OOP Wrapper modeling text messages sent across guild and DM channels.
]]

local User = require("./User")
local Member = require("./Member")
local ThreadChannel = require("./ThreadChannel")

export type Message = {
    --[[ Unique identifier of this message. ]]
    id: string,
    
    --[[ Channel identifier where this message was dispatched. ]]
    channel_id: string,
    
    --[[ Guild identifier if this message belongs to a server. ]]
    guild_id: string?,
    
    --[[ Raw textual content of the message payload. ]]
    content: string,
    
    --[[ The user entity who authored this message. ]]
    author: User.User,
    
    --[[ Guild member context if authored inside a server channel. ]]
    member: Member.Member?,
    
    --[[ Embedded rich output cards appended to the message. ]]
    embeds: { any }?,
    
    --[[ Attached interactive UI framework layouts (ActionRows). ]]
    components: { any }?,
    
    _rest: any,

    --[[
        Dispatches a reply targeting this original message context ID.
        @param self The message instance
        @param contentOrOptions String text content or constructed parameter maps
        @return Success condition alongside the newly created Message object wrapper if successful
    ]]
    reply: (self: Message, contentOrOptions: any) -> (boolean, Message?),
    
    --[[
        Edits the text body, embedded cards, or UI layouts appended to this message.
        @param self The message instance
        @param newContentOrOptions Updated message content strings or structured tables
        @return Success condition alongside the updated Message structure wrapper
    ]]
    edit: (self: Message, newContentOrOptions: any) -> (boolean, Message?),
    
    --[[
        Permanently wipes/deletes this message from channel storage records.
        @param self The message instance
        @return True if deletion completes without backend routing faults
    ]]
    delete: (self: Message) -> boolean,
    
    --[[
        Appends an individual Unicode or customized platform reaction emoji to this message.
        @param self The message instance
        @param emoji String representation or raw format character code
        @return True if the reaction packet executes correctly
    ]]
    react: (self: Message, emoji: string) -> boolean,

    --[[
        Spawns a nested discussion forum sub-thread branching from this message context.
        @param self The message instance
        @param name Title heading assigned to the newly spawned thread
        @param autoArchiveMinutes Inactivity timeout threshold boundary (default 1440)
        @return Success condition alongside the instantiated ThreadChannel wrapper object
    ]]
    startThread: (self: Message, name: string, autoArchiveMinutes: number?) -> (boolean, ThreadChannel.ThreadChannel?),
}

local Message = {}
local MessageMT = {}
MessageMT.__index = MessageMT

--[[
    Instantiates a structured Message wrapper parsing base incoming payloads.
    @param data Dictionary block encoding incoming API properties
    @param restClient Application HTTP network client layer interface
    @return A new Message structure wrapper
]]
function Message.new(data: { [string]: any }, restClient: any): Message
    local authorObj = User.new(data.author or {})
    local memberObj: Member.Member? = nil
    
    if data.member and type(data.member) == "table" then
        local memberPayload = {}
        for k, v in pairs(data.member) do
            memberPayload[k] = v
        end
        memberPayload.user = data.author or {}
        memberObj = Member.new(memberPayload, data.guild_id, restClient)
    end

    local self = {
        id = tostring(data.id or ""),
        channel_id = tostring(data.channel_id or ""),
        guild_id = data.guild_id and tostring(data.guild_id),
        content = tostring(data.content or ""),
        author = authorObj,
        member = memberObj,
        embeds = data.embeds,
        components = data.components,
        _rest = restClient,
    }
    setmetatable(self, MessageMT)
    return (self :: any) :: Message
end

-- Normalizes variable argument structures for sending or editing payloads
local function normalizePayload(optionsOrContent: any): { [string]: any }
    local payload = {}
    if type(optionsOrContent) == "string" then
        payload.content = optionsOrContent
    elseif type(optionsOrContent) == "table" then
        if type(optionsOrContent.toJSON) == "function" then
            local compiled = optionsOrContent:toJSON()
            if compiled.type == 1 then
                payload.components = { compiled }
            else
                payload.embeds = { compiled }
            end
        else
            for k, v in pairs(optionsOrContent) do
                payload[k] = v
            end
            
            if payload.embeds and type(payload.embeds) == "table" then
                local serializedEmbeds = {}
                for _, emb in ipairs(payload.embeds) do
                    if type(emb) == "table" and type(emb.toJSON) == "function" then
                        table.insert(serializedEmbeds, emb:toJSON())
                    else
                        table.insert(serializedEmbeds, emb)
                    end
                end
                payload.embeds = serializedEmbeds
            end

            if payload.components and type(payload.components) == "table" then
                local serializedComponents = {}
                for _, comp in ipairs(payload.components) do
                    if type(comp) == "table" and type(comp.toJSON) == "function" then
                        table.insert(serializedComponents, comp:toJSON())
                    else
                        table.insert(serializedComponents, comp)
                    end
                end
                payload.components = serializedComponents
            end
        end
    else
        payload.content = tostring(optionsOrContent)
    end
    return payload
end

--[[
    Dispatches a reply targeting this original message context ID.
    @param contentOrOptions String text content or constructed parameter maps
    @return Success condition alongside the newly created Message object wrapper if successful
]]
function MessageMT.reply(self: Message, contentOrOptions: any): (boolean, Message?)
    if not self._rest then
        return false, nil
    end

    local payload = normalizePayload(contentOrOptions)
    payload.message_reference = {
        message_id = self.id,
        channel_id = self.channel_id,
        guild_id = self.guild_id,
        fail_if_not_exists = false,
    }

    local ok, res = self._rest:post("/channels/" .. self.channel_id .. "/messages", payload)
    if ok and type(res) == "table" then
        return true, Message.new(res, self._rest)
    else
        return false, nil
    end
end

--[[
    Edits the text body, embedded cards, or UI layouts appended to this message.
    @param newContentOrOptions Updated message content strings or structured tables
    @return Success condition alongside the updated Message structure wrapper
]]
function MessageMT.edit(self: Message, newContentOrOptions: any): (boolean, Message?)
    if not self._rest then
        return false, nil
    end

    local payload = normalizePayload(newContentOrOptions)
    local ok, res = self._rest:patch("/channels/" .. self.channel_id .. "/messages/" .. self.id, payload)
    if ok and type(res) == "table" then
        return true, Message.new(res, self._rest)
    else
        return false, nil
    end
end

--[[
    Permanently wipes/deletes this message from channel storage records.
    @return True if deletion completes without backend routing faults
]]
function MessageMT.delete(self: Message): boolean
    if not self._rest then return false end
    local ok, _ = self._rest:delete("/channels/" .. self.channel_id .. "/messages/" .. self.id)
    return ok
end

--[[
    Appends an individual Unicode or customized platform reaction emoji to this message.
    @param emoji String representation or raw format character code
    @return True if the reaction packet executes correctly
]]
function MessageMT.react(self: Message, emoji: string): boolean
    if not self._rest then return false end
    local encodedEmoji = string.gsub(emoji, "[^%w%-%._~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    local ok, _ = self._rest:put("/channels/" .. self.channel_id .. "/messages/" .. self.id .. "/reactions/" .. encodedEmoji .. "/@me")
    return ok
end

--[[
    Spawns a nested discussion forum sub-thread branching from this message context.
    @param name Title heading assigned to the newly spawned thread
    @param autoArchiveMinutes Inactivity timeout threshold boundary (default 1440)
    @return Success condition alongside the instantiated ThreadChannel wrapper object
]]
function MessageMT.startThread(self: Message, name: string, autoArchiveMinutes: number?): (boolean, ThreadChannel.ThreadChannel?)
    if not self._rest then return false, nil end
    local payload = {
        name = tostring(name),
        auto_archive_duration = tonumber(autoArchiveMinutes) or 1440,
    }
    local ok, res = self._rest:post("/channels/" .. self.channel_id .. "/messages/" .. self.id .. "/threads", payload)
    if ok and type(res) == "table" then
        return true, ThreadChannel.new(res, self._rest)
    else
        return false, nil
    end
end

table.freeze(MessageMT)
table.freeze(Message)
return Message
