--!strict

--[[
    Interaction Structure — OOP Wrapper for managing incoming Application Commands, Buttons, and Modal interactions.
]]

local User = require("./User")

export type Interaction = {
    --[[ The unique ID of the interaction. ]]
    id: string,
    
    --[[ The application ID of the bot. ]]
    application_id: string,
    
    --[[ The interaction type (2 for Application Command, 3 for Message Component, 5 for Modal Submit). ]]
    type: number,
    
    --[[ The payload data containing commands, component IDs, or submitted values. ]]
    data: { [string]: any }?,
    
    --[[ The guild ID where the interaction was triggered. ]]
    guild_id: string?,
    
    --[[ The channel ID where the interaction occurred. ]]
    channel_id: string?,
    
    --[[ The user entity who invoked the interaction. ]]
    user: User.User,
    
    --[[ The interaction token required for responding or followups. ]]
    token: string,
    
    _rest: any,
    _replied: boolean,
    _deferred: boolean,

    --[[ Sends the initial callback response to this interaction. ]]
    reply: (self: Interaction, contentOrOptions: any) -> boolean,
    
    --[[ Defers the response, displaying a thinking state to the user. ]]
    deferReply: (self: Interaction, ephemeral: boolean?) -> boolean,
    
    --[[ Edits the initial reply previously sent. ]]
    editReply: (self: Interaction, contentOrOptions: any) -> (boolean, any),
    
    --[[ Sends a followup message associated with this interaction's webhook token. ]]
    followUp: (self: Interaction, contentOrOptions: any) -> (boolean, any),

    --[[ Displays a pop-up input form (Modal) dialog to the user. ]]
    showModal: (self: Interaction, modalBuilder: any) -> boolean,
    
    --[[ Retrieves the text value submitted for a given component custom ID within a ModalSubmit interaction. ]]
    getTextInputValue: (self: Interaction, customId: string) -> string?,
}

local Interaction = {}
local InteractionMT = {}
InteractionMT.__index = InteractionMT

--[[
    Instantiates a new Interaction wrapper object.
]]
function Interaction.new(payload: { [string]: any }, restClient: any): Interaction
    local rawUser = payload.user or (payload.member and payload.member.user) or {}
    
    local self = {
        id = tostring(payload.id or ""),
        application_id = tostring(payload.application_id or ""),
        type = tonumber(payload.type) or 1,
        data = payload.data,
        guild_id = payload.guild_id and tostring(payload.guild_id),
        channel_id = payload.channel_id and tostring(payload.channel_id),
        user = User.new(rawUser),
        token = tostring(payload.token or ""),
        _rest = restClient,
        _replied = false,
        _deferred = false,
    }
    setmetatable(self, InteractionMT)
    return (self :: any) :: Interaction
end

-- Normalizes payload data structures for interaction responses
local function buildInteractionData(contentOrOptions: any): { [string]: any }
    local data = {}
    if type(contentOrOptions) == "string" then
        data.content = contentOrOptions
    elseif type(contentOrOptions) == "table" then
        if type(contentOrOptions.toJSON) == "function" then
            data.embeds = { contentOrOptions:toJSON() }
        else
            for k, v in pairs(contentOrOptions) do
                data[k] = v
            end
            
            if data.embeds and type(data.embeds) == "table" then
                local arr = {}
                for _, emb in ipairs(data.embeds) do
                    if type(emb) == "table" and type(emb.toJSON) == "function" then
                        table.insert(arr, emb:toJSON())
                    else
                        table.insert(arr, emb)
                    end
                end
                data.embeds = arr
            end
            
            if data.components and type(data.components) == "table" then
                local arr = {}
                for _, comp in ipairs(data.components) do
                    if type(comp) == "table" and type(comp.toJSON) == "function" then
                        table.insert(arr, comp:toJSON())
                    else
                        table.insert(arr, comp)
                    end
                end
                data.components = arr
            end

            if data.ephemeral == true then
                data.flags = bit32.bor(data.flags or 0, 64) -- Bit flag 64 = EPHEMERAL
                data.ephemeral = nil
            end
        end
    else
        data.content = tostring(contentOrOptions)
    end
    return data
end

function InteractionMT:reply(contentOrOptions: any): boolean
    if not self._rest or self._replied then return false end
    
    local resData = buildInteractionData(contentOrOptions)
    local payload = {
        type = 4, -- Type 4: ChannelMessageWithSource
        data = resData,
    }

    local ok, _ = self._rest:post("/interactions/" .. self.id .. "/" .. self.token .. "/callback", payload)
    if ok then
        self._replied = true
    end
    return ok
end

function InteractionMT:deferReply(ephemeral: boolean?): boolean
    if not self._rest or self._replied or self._deferred then return false end
    
    local flags = ephemeral == true and 64 or 0
    local payload = {
        type = 5, -- Type 5: DeferredChannelMessageWithSource
        data = { flags = flags },
    }

    local ok, _ = self._rest:post("/interactions/" .. self.id .. "/" .. self.token .. "/callback", payload)
    if ok then
        self._deferred = true
    end
    return ok
end

function InteractionMT:editReply(contentOrOptions: any): (boolean, any)
    if not self._rest then return false, nil end
    
    local payload = buildInteractionData(contentOrOptions)
    return self._rest:patch("/webhooks/" .. self.application_id .. "/" .. self.token .. "/messages/@original", payload)
end

function InteractionMT:followUp(contentOrOptions: any): (boolean, any)
    if not self._rest then return false, nil end
    
    local payload = buildInteractionData(contentOrOptions)
    return self._rest:post("/webhooks/" .. self.application_id .. "/" .. self.token, payload)
end

function InteractionMT:showModal(modalBuilder: any): boolean
    if not self._rest or self._replied then return false end
    
    local modalData = {}
    if type(modalBuilder) == "table" and type(modalBuilder.toJSON) == "function" then
        modalData = modalBuilder:toJSON()
    else
        modalData = modalBuilder
    end

    local payload = {
        type = 9, -- Type 9: Modal
        data = modalData,
    }

    local ok, _ = self._rest:post("/interactions/" .. self.id .. "/" .. self.token .. "/callback", payload)
    if ok then
        self._replied = true
    end
    return ok
end

function InteractionMT:getTextInputValue(customId: string): string?
    if self.type ~= 5 or not self.data or not self.data.components then
        return nil
    end

    for _, row in ipairs(self.data.components) do
        if row.components and type(row.components) == "table" then
            for _, input in ipairs(row.components) do
                if input.custom_id == customId then
                    return type(input.value) == "string" and input.value or tostring(input.value or "")
                end
            end
        end
    end
    return nil
end

table.freeze(InteractionMT)
table.freeze(Interaction)
return Interaction
