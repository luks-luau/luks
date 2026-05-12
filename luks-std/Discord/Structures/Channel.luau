--!strict

--[[
    Channel Structure — POO Wrapper for Discord text/voice channels.
]]

export type Channel = {
    id: string,
    name: string?,
    type: number,
    guild_id: string?,
    _rest: any,

    --[[ Envia uma mensagem neste canal contendo texto, Embeds ou Componentes visuais. ]]
    send: (self: Channel, optionsOrContent: any) -> (boolean, any),
}

local Channel = {}
local ChannelMT = {}
ChannelMT.__index = ChannelMT

function Channel.new(data: { [string]: any }, restClient: any): Channel
    local self = {
        id = tostring(data.id or ""),
        name = data.name and tostring(data.name),
        type = tonumber(data.type) or 0,
        guild_id = data.guild_id and tostring(data.guild_id),
        _rest = restClient,
    }
    setmetatable(self, ChannelMT)
    return (self :: any) :: Channel
end

function ChannelMT:send(optionsOrContent: any): (boolean, any)
    if not self._rest then
        return false, "Cliente REST ausente no objeto Channel."
    end

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

    return self._rest:post("/channels/" .. self.id .. "/messages", payload)
end

table.freeze(ChannelMT)
table.freeze(Channel)
return Channel
