--!strict
--!native
--!optimize 2

--[[
    Embed Builder — Fluent Enterprise standardization layout for composing rich message Embeds.
]]

export type Embed = {
    _data: { [string]: any },

    --[[
        Sets the top prominent bold title overlay string.
        @param self The embed builder instance
        @param title Primary card layout title string
        @return The chainable embed builder instance
    ]]
    setTitle: (self: Embed, title: string) -> Embed,
    
    --[[
        Sets the main descriptive text block content.
        @param self The embed builder instance
        @param description Primary multiline paragraph message contents
        @return The chainable embed builder instance
    ]]
    setDescription: (self: Embed, description: string) -> Embed,
    
    --[[
        Sets the primary hyperlink redirection web address mapped to the title overlay.
        @param self The embed builder instance
        @param url Destination web page URL
        @return The chainable embed builder instance
    ]]
    setUrl: (self: Embed, url: string) -> Embed,
    
    --[[
        Sets the accent strip side indicator display color.
        @param self The embed builder instance
        @param color Hexadecimal string, raw decimal integer, or RGB color structure map
        @return The chainable embed builder instance
    ]]
    setColor: (self: Embed, color: any) -> Embed,
    
    --[[
        Appends a footer timestamp metric indication.
        @param self The embed builder instance
        @param timestamp Optional ISO-8601 formatted metric date string
        @return The chainable embed builder instance
    ]]
    setTimestamp: (self: Embed, timestamp: string?) -> Embed,
    
    --[[
        Sets the small bottom trailing footer note overlay line.
        @param self The embed builder instance
        @param text Footer baseline message string
        @param iconUrl Optional accompanying trailing badge avatar URL
        @return The chainable embed builder instance
    ]]
    setFooter: (self: Embed, text: string, iconUrl: string?) -> Embed,
    
    --[[
        Embeds a large visual image graphic inside the content card body.
        @param self The embed builder instance
        @param url Direct source image web URL
        @return The chainable embed builder instance
    ]]
    setImage: (self: Embed, url: string) -> Embed,
    
    --[[
        Embeds a smaller visual thumbnail corner accent badge graphic.
        @param self The embed builder instance
        @param url Thumbnail graphic web URL
        @return The chainable embed builder instance
    ]]
    setThumbnail: (self: Embed, url: string) -> Embed,
    
    --[[
        Sets the upper leading author credit signature line.
        @param self The embed builder instance
        @param name Author display name signature
        @param url Optional hyperlinked signature redirection destination
        @param iconUrl Optional accompanying leading thumbnail badge URL
        @return The chainable embed builder instance
    ]]
    setAuthor: (self: Embed, name: string, url: string?, iconUrl: string?) -> Embed,
    
    --[[
        Appends an individual structured header/value display block field.
        @param self The embed builder instance
        @param name Distinct field sub-heading label
        @param value Field descriptive body text
        @param inline Positions field side-by-side horizontally if width permits
        @return The chainable embed builder instance
    ]]
    addField: (self: Embed, name: string, value: string, inline: boolean?) -> Embed,
    
    --[[
        Finalizes the structure object for JSON output export.
        @param self The embed builder instance
        @return Clean dictionary payload target table map
    ]]
    toJSON: (self: Embed) -> { [string]: any },
}

local Embed = {}
local EmbedMT = {}
EmbedMT.__index = EmbedMT

--[[
    Instantiates a pristine blank Embed builder object wrapper.
    @return A new Embed instance
]]
function Embed.new(): Embed
    local self = {
        _data = {},
    }
    setmetatable(self, EmbedMT)
    return (self :: any) :: Embed
end

--[[
    Sets the top prominent bold title overlay string.
    @param title Primary card layout title string
    @return The chainable embed builder instance
]]
function EmbedMT:setTitle(title: string): Embed
    self._data.title = tostring(title)
    return self
end

--[[
    Sets the main descriptive text block content.
    @param description Primary multiline paragraph message contents
    @return The chainable embed builder instance
]]
function EmbedMT:setDescription(description: string): Embed
    self._data.description = tostring(description)
    return self
end

--[[
    Sets the primary hyperlink redirection web address mapped to the title overlay.
    @param url Destination web page URL
    @return The chainable embed builder instance
]]
function EmbedMT:setUrl(url: string): Embed
    self._data.url = tostring(url)
    return self
end

--[[
    Sets the accent strip side indicator display color.
    @param color Hexadecimal string, raw decimal integer, or RGB color structure map
    @return The chainable embed builder instance
]]
function EmbedMT:setColor(color: any): Embed
    local numColor = 0
    if type(color) == "number" then
        numColor = color
    elseif type(color) == "string" then
        -- Flexible validation parsing hexadecimal strings (#ff0000 or ff0000)
        local cleaned = string.gsub(color, "^#", "")
        numColor = tonumber(cleaned, 16) or 0
    elseif type(color) == "table" and color.r and color.g and color.b then
        -- Support passing explicit RGB integer structures
        numColor = bit32.bor(
            bit32.lshift(bit32.band(color.r, 255), 16),
            bit32.lshift(bit32.band(color.g, 255), 8),
            bit32.band(color.b, 255)
        )
    end
    self._data.color = numColor
    return self
end

--[[
    Appends a footer timestamp metric indication.
    @param timestamp Optional ISO-8601 formatted metric date string
    @return The chainable embed builder instance
]]
function EmbedMT:setTimestamp(timestamp: string?): Embed
    -- Fallback preset ISO format string timestamp representation
    self._data.timestamp = timestamp or "2026-05-12T12:00:00.000Z"
    return self
end

--[[
    Sets the small bottom trailing footer note overlay line.
    @param text Footer baseline message string
    @param iconUrl Optional accompanying trailing badge avatar URL
    @return The chainable embed builder instance
]]
function EmbedMT:setFooter(text: string, iconUrl: string?): Embed
    self._data.footer = {
        text = tostring(text),
        icon_url = iconUrl and tostring(iconUrl),
    }
    return self
end

--[[
    Embeds a large visual image graphic inside the content card body.
    @param url Direct source image web URL
    @return The chainable embed builder instance
]]
function EmbedMT:setImage(url: string): Embed
    self._data.image = {
        url = tostring(url),
    }
    return self
end

--[[
    Embeds a smaller visual thumbnail corner accent badge graphic.
    @param url Thumbnail graphic web URL
    @return The chainable embed builder instance
]]
function EmbedMT:setThumbnail(url: string): Embed
    self._data.thumbnail = {
        url = tostring(url),
    }
    return self
end

--[[
    Sets the upper leading author credit signature line.
    @param name Author display name signature
    @param url Optional hyperlinked signature redirection destination
    @param iconUrl Optional accompanying leading thumbnail badge URL
    @return The chainable embed builder instance
]]
function EmbedMT:setAuthor(name: string, url: string?, iconUrl: string?): Embed
    self._data.author = {
        name = tostring(name),
        url = url and tostring(url),
        icon_url = iconUrl and tostring(iconUrl),
    }
    return self
end

--[[
    Appends an individual structured header/value display block field.
    @param name Distinct field sub-heading label
    @param value Field descriptive body text
    @param inline Positions field side-by-side horizontally if width permits
    @return The chainable embed builder instance
]]
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

--[[
    Finalizes the structure object for JSON output export.
    @return Clean dictionary payload target table map
]]
function EmbedMT:toJSON(): { [string]: any }
    -- Return clean shallow map dictionary for REST execution
    local result = {}
    for k, v in pairs(self._data) do
        result[k] = v
    end
    return result
end

table.freeze(EmbedMT)
table.freeze(Embed)
return Embed
