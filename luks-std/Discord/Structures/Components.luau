--!strict

--[[
    Components Builders — OOP chainable component schemas for building complex Discord UIs.
    Implements Buttons, Select Menus, Action Rows, Text Inputs, and Modal views.
]]

local Components = {}

-- Button Builder
local ButtonMT = {}
ButtonMT.__index = ButtonMT

export type ButtonBuilder = {
    _data: { [string]: any },

    --[[ Sets the custom identifier for the button. ]]
    setCustomId: (self: ButtonBuilder, id: string) -> ButtonBuilder,
    
    --[[ Sets the text label displayed on the button. ]]
    setLabel: (self: ButtonBuilder, label: string) -> ButtonBuilder,
    
    --[[ Sets the visual style of the button (Primary, Secondary, Success, Danger, Link). ]]
    setStyle: (self: ButtonBuilder, style: any) -> ButtonBuilder,
    
    --[[ Sets an emoji to display inside the button. ]]
    setEmoji: (self: ButtonBuilder, emoji: any) -> ButtonBuilder,
    
    --[[ Sets the external destination URL for a Link style button. ]]
    setUrl: (self: ButtonBuilder, url: string) -> ButtonBuilder,
    
    --[[ Disables or enables interaction with the button. ]]
    setDisabled: (self: ButtonBuilder, disabled: boolean?) -> ButtonBuilder,
    
    --[[ Serializes the button structure to standard API JSON format. ]]
    toJSON: (self: ButtonBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable ButtonBuilder.
]]
function Components.ButtonBuilder(): ButtonBuilder
    local self = {
        _data = {
            type = 2, -- Component Type 2 represents Button
            style = 1, -- Default Primary Style
        }
    }
    setmetatable(self, ButtonMT)
    return (self :: any) :: ButtonBuilder
end

function ButtonMT:setCustomId(id: string): ButtonBuilder
    self._data.custom_id = tostring(id)
    return self
end

function ButtonMT:setLabel(label: string): ButtonBuilder
    self._data.label = tostring(label)
    return self
end

function ButtonMT:setStyle(style: any): ButtonBuilder
    local s = 1
    if type(style) == "number" then
        s = style
    elseif type(style) == "string" then
        local lower = string.lower(style)
        if lower == "primary" then s = 1
        elseif lower == "secondary" then s = 2
        elseif lower == "success" then s = 3
        elseif lower == "danger" then s = 4
        elseif lower == "link" then s = 5
        end
    end
    self._data.style = s
    return self
end

function ButtonMT:setEmoji(emoji: any): ButtonBuilder
    if type(emoji) == "string" then
        self._data.emoji = { name = emoji }
    elseif type(emoji) == "table" then
        self._data.emoji = emoji
    end
    return self
end

function ButtonMT:setUrl(url: string): ButtonBuilder
    self._data.url = tostring(url)
    self._data.style = 5 -- URL buttons must use style 5 (Link)
    return self
end

function ButtonMT:setDisabled(disabled: boolean?): ButtonBuilder
    self._data.disabled = disabled == true
    return self
end

function ButtonMT:toJSON(): { [string]: any }
    local res = {}
    for k, v in pairs(self._data) do
        res[k] = v
    end
    return res
end

-- String Select Menu Builder
local SelectMenuMT = {}
SelectMenuMT.__index = SelectMenuMT

export type StringSelectMenuBuilder = {
    _data: { [string]: any },

    --[[ Sets the custom identifier for the select menu. ]]
    setCustomId: (self: StringSelectMenuBuilder, id: string) -> StringSelectMenuBuilder,
    
    --[[ Sets the placeholder text displayed when no options are selected. ]]
    setPlaceholder: (self: StringSelectMenuBuilder, placeholder: string) -> StringSelectMenuBuilder,
    
    --[[ Adds a selectable option item to the menu. ]]
    addOption: (self: StringSelectMenuBuilder, label: string, value: string, description: string?, emoji: any?) -> StringSelectMenuBuilder,
    
    --[[ Sets the minimum number of selectable items. ]]
    setMinValues: (self: StringSelectMenuBuilder, min: number) -> StringSelectMenuBuilder,
    
    --[[ Sets the maximum number of selectable items. ]]
    setMaxValues: (self: StringSelectMenuBuilder, max: number) -> StringSelectMenuBuilder,
    
    --[[ Disables or enables interaction with the select menu. ]]
    setDisabled: (self: StringSelectMenuBuilder, disabled: boolean?) -> StringSelectMenuBuilder,
    
    --[[ Serializes the select menu structure to standard API JSON format. ]]
    toJSON: (self: StringSelectMenuBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable StringSelectMenuBuilder.
]]
function Components.StringSelectMenuBuilder(): StringSelectMenuBuilder
    local self = {
        _data = {
            type = 3, -- Component Type 3 represents String Select Menu
            options = {},
        }
    }
    setmetatable(self, SelectMenuMT)
    return (self :: any) :: StringSelectMenuBuilder
end

function SelectMenuMT:setCustomId(id: string): StringSelectMenuBuilder
    self._data.custom_id = tostring(id)
    return self
end

function SelectMenuMT:setPlaceholder(placeholder: string): StringSelectMenuBuilder
    self._data.placeholder = tostring(placeholder)
    return self
end

function SelectMenuMT:addOption(label: string, value: string, description: string?, emoji: any?): StringSelectMenuBuilder
    local opt: { [string]: any } = {
        label = tostring(label),
        value = tostring(value),
    }
    if description then opt.description = tostring(description) end
    if emoji then
        if type(emoji) == "string" then opt.emoji = { name = emoji }
        elseif type(emoji) == "table" then opt.emoji = emoji
        end
    end
    table.insert(self._data.options, opt)
    return self
end

function SelectMenuMT:setMinValues(min: number): StringSelectMenuBuilder
    self._data.min_values = tonumber(min) or 1
    return self
end

function SelectMenuMT:setMaxValues(max: number): StringSelectMenuBuilder
    self._data.max_values = tonumber(max) or 1
    return self
end

function SelectMenuMT:setDisabled(disabled: boolean?): StringSelectMenuBuilder
    self._data.disabled = disabled == true
    return self
end

function SelectMenuMT:toJSON(): { [string]: any }
    local res = {}
    for k, v in pairs(self._data) do
        res[k] = v
    end
    return res
end

-- Action Row Builder
local ActionRowMT = {}
ActionRowMT.__index = ActionRowMT

export type ActionRowBuilder = {
    _components: { any },

    --[[ Appends one or more components (Buttons, Select Menus, TextInputs) into this layout container. ]]
    addComponents: (self: ActionRowBuilder, ...any) -> ActionRowBuilder,
    
    --[[ Serializes the layout boundary to standard API JSON format. ]]
    toJSON: (self: ActionRowBuilder) -> { [string]: any },
}

--[[
    Instantiates a new layout ActionRowBuilder container.
]]
function Components.ActionRowBuilder(): ActionRowBuilder
    local self = {
        _components = {},
    }
    setmetatable(self, ActionRowMT)
    return (self :: any) :: ActionRowBuilder
end

function ActionRowMT:addComponents(...: any): ActionRowBuilder
    for i = 1, select("#", ...) do
        local comp = select(i, ...)
        if comp then
            table.insert(self._components, comp)
        end
    end
    return self
end

function ActionRowMT:toJSON(): { [string]: any }
    local serialized = {}
    for _, comp in ipairs(self._components) do
        if type(comp) == "table" and type(comp.toJSON) == "function" then
            table.insert(serialized, comp:toJSON())
        else
            table.insert(serialized, comp)
        end
    end
    return {
        type = 1, -- Component Type 1 represents Action Row
        components = serialized,
    }
end

-- Text Input Builder (For Modals)
local TextInputMT = {}
TextInputMT.__index = TextInputMT

export type TextInputBuilder = {
    _data: { [string]: any },

    --[[ Sets the custom identifier mapped to this input field. ]]
    setCustomId: (self: TextInputBuilder, id: string) -> TextInputBuilder,
    
    --[[ Sets the label header displayed above the input field. ]]
    setLabel: (self: TextInputBuilder, label: string) -> TextInputBuilder,
    
    --[[ Sets the input presentation style (Short or Paragraph). ]]
    setStyle: (self: TextInputBuilder, style: any) -> TextInputBuilder,
    
    --[[ Sets a placeholder background guide string. ]]
    setPlaceholder: (self: TextInputBuilder, placeholder: string) -> TextInputBuilder,
    
    --[[ Pre-fills the form field with a default string value. ]]
    setValue: (self: TextInputBuilder, value: string) -> TextInputBuilder,
    
    --[[ Controls whether the field must be populated before submission. ]]
    setRequired: (self: TextInputBuilder, required: boolean?) -> TextInputBuilder,
    
    --[[ Enforces minimum length constraint on character inputs. ]]
    setMinLength: (self: TextInputBuilder, min: number) -> TextInputBuilder,
    
    --[[ Enforces maximum length limit on character entries. ]]
    setMaxLength: (self: TextInputBuilder, max: number) -> TextInputBuilder,
    
    --[[ Serializes the structure to standard API JSON format. ]]
    toJSON: (self: TextInputBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable TextInputBuilder schema for Modal popup structures.
]]
function Components.TextInputBuilder(): TextInputBuilder
    local self = {
        _data = {
            type = 4, -- Component Type 4 represents TextInput
            style = 1, -- Short style by default
        }
    }
    setmetatable(self, TextInputMT)
    return (self :: any) :: TextInputBuilder
end

function TextInputMT:setCustomId(id: string): TextInputBuilder
    self._data.custom_id = tostring(id)
    return self
end

function TextInputMT:setLabel(label: string): TextInputBuilder
    self._data.label = tostring(label)
    return self
end

function TextInputMT:setStyle(style: any): TextInputBuilder
    local s = 1
    if type(style) == "number" then
        s = style
    elseif type(style) == "string" then
        local lower = string.lower(style)
        if lower == "short" then s = 1
        elseif lower == "paragraph" then s = 2
        end
    end
    self._data.style = s
    return self
end

function TextInputMT:setPlaceholder(placeholder: string): TextInputBuilder
    self._data.placeholder = tostring(placeholder)
    return self
end

function TextInputMT:setValue(value: string): TextInputBuilder
    self._data.value = tostring(value)
    return self
end

function TextInputMT:setRequired(required: boolean?): TextInputBuilder
    self._data.required = required ~= false
    return self
end

function TextInputMT:setMinLength(min: number): TextInputBuilder
    self._data.min_length = tonumber(min)
    return self
end

function TextInputMT:setMaxLength(max: number): TextInputBuilder
    self._data.max_length = tonumber(max)
    return self
end

function TextInputMT:toJSON(): { [string]: any }
    local res = {}
    for k, v in pairs(self._data) do
        res[k] = v
    end
    return res
end

-- Modal Builder
local ModalMT = {}
ModalMT.__index = ModalMT

export type ModalBuilder = {
    _data: { [string]: any },
    _components: { any },

    --[[ Sets the custom identifier mapped to this popup window. ]]
    setCustomId: (self: ModalBuilder, id: string) -> ModalBuilder,
    
    --[[ Sets the top header title of the modal layout box. ]]
    setTitle: (self: ModalBuilder, title: string) -> ModalBuilder,
    
    --[[ Embeds ActionRow wrapper layouts containing input fields into the modal window. ]]
    addComponents: (self: ModalBuilder, ...any) -> ModalBuilder,
    
    --[[ Serializes the complete modal schema to standard API JSON format. ]]
    toJSON: (self: ModalBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable ModalBuilder view structure.
]]
function Components.ModalBuilder(): ModalBuilder
    local self = {
        _data = {},
        _components = {},
    }
    setmetatable(self, ModalMT)
    return (self :: any) :: ModalBuilder
end

function ModalMT:setCustomId(id: string): ModalBuilder
    self._data.custom_id = tostring(id)
    return self
end

function ModalMT:setTitle(title: string): ModalBuilder
    self._data.title = tostring(title)
    return self
end

function ModalMT:addComponents(...: any): ModalBuilder
    for i = 1, select("#", ...) do
        local comp = select(i, ...)
        if comp then
            table.insert(self._components, comp)
        end
    end
    return self
end

function ModalMT:toJSON(): { [string]: any }
    local serializedComponents = {}
    for _, comp in ipairs(self._components) do
        if type(comp) == "table" and type(comp.toJSON) == "function" then
            table.insert(serializedComponents, comp:toJSON())
        else
            table.insert(serializedComponents, comp)
        end
    end

    local res = {
        title = self._data.title or "",
        custom_id = self._data.custom_id or "",
        components = serializedComponents,
    }
    return res
end

table.freeze(ButtonMT)
table.freeze(SelectMenuMT)
table.freeze(ActionRowMT)
table.freeze(TextInputMT)
table.freeze(ModalMT)
table.freeze(Components)
return Components
