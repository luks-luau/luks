--!strict

--[[
    Embed Builder — Padronização Enterprise Fluente para construção de Rich Embeds.
]]

export type Embed = {
    _data: { [string]: any },

    -- Setters encadeáveis que retornam a própria instância (self)
    setTitle: (self: Embed, title: string) -> Embed,
    setDescription: (self: Embed, description: string) -> Embed,
    setUrl: (self: Embed, url: string) -> Embed,
    setColor: (self: Embed, color: any) -> Embed,
    setTimestamp: (self: Embed, timestamp: string?) -> Embed,
    setFooter: (self: Embed, text: string, iconUrl: string?) -> Embed,
    setImage: (self: Embed, url: string) -> Embed,
    setThumbnail: (self: Embed, url: string) -> Embed,
    setAuthor: (self: Embed, name: string, url: string?, iconUrl: string?) -> Embed,
    addField: (self: Embed, name: string, value: string, inline: boolean?) -> Embed,
    
    -- Finaliza o objeto para exportação em JSON
    toJSON: (self: Embed) -> { [string]: any },
}

local Embed = {}
local EmbedMT = {}
EmbedMT.__index = EmbedMT

--[[ Cria uma nova instância de Embed em branco. ]]
function Embed.new(): Embed
    local self = {
        _data = {},
    }
    setmetatable(self, EmbedMT)
    return (self :: any) :: Embed
end

function EmbedMT:setTitle(title: string): Embed
    self._data.title = tostring(title)
    return self
end

function EmbedMT:setDescription(description: string): Embed
    self._data.description = tostring(description)
    return self
end

function EmbedMT:setUrl(url: string): Embed
    self._data.url = tostring(url)
    return self
end

function EmbedMT:setColor(color: any): Embed
    local numColor = 0
    if type(color) == "number" then
        numColor = color
    elseif type(color) == "string" then
        -- Suporte flexível para hexadecimais puros (#ff0000 ou ff0000)
        local cleaned = string.gsub(color, "^#", "")
        numColor = tonumber(cleaned, 16) or 0
    elseif type(color) == "table" and color.r and color.g and color.b then
        -- Suporte para tabela RGB
        numColor = bit32.bor(
            bit32.lshift(bit32.band(color.r, 255), 16),
            bit32.lshift(bit32.band(color.g, 255), 8),
            bit32.band(color.b, 255)
        )
    end
    self._data.color = numColor
    return self
end

function EmbedMT:setTimestamp(timestamp: string?): Embed
    -- Usa uma representação de string ISO ou gera dinamicamente se a engine suportar
    self._data.timestamp = timestamp or "2026-05-12T12:00:00.000Z"
    return self
end

function EmbedMT:setFooter(text: string, iconUrl: string?): Embed
    self._data.footer = {
        text = tostring(text),
        icon_url = iconUrl and tostring(iconUrl),
    }
    return self
end

function EmbedMT:setImage(url: string): Embed
    self._data.image = {
        url = tostring(url),
    }
    return self
end

function EmbedMT:setThumbnail(url: string): Embed
    self._data.thumbnail = {
        url = tostring(url),
    }
    return self
end

function EmbedMT:setAuthor(name: string, url: string?, iconUrl: string?): Embed
    self._data.author = {
        name = tostring(name),
        url = url and tostring(url),
        icon_url = iconUrl and tostring(iconUrl),
    }
    return self
end

function EmbedMT:addField(name: string, value: string, inline: boolean?): Embed
    if not self._data.fields then
        self._data.fields = {}
    end
    table.insert(self._data.fields, {
        name = tostring(name),
        value = tostring(value),
        inline = inline == true,
    })
    return self
end

function EmbedMT:toJSON(): { [string]: any }
    -- Retorna uma cópia limpa pronta para o payload REST
    local result = {}
    for k, v in pairs(self._data) do
        result[k] = v
    end
    return result
end

table.freeze(EmbedMT)
table.freeze(Embed)
return Embed
