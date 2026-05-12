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

    --[[
        Sets the custom identifier for the button.
        @param self The button builder instance
        @param id Unique application string identifier mapped to this action
        @return The chainable button builder instance
    ]]
    setCustomId: (self: ButtonBuilder, id: string) -> ButtonBuilder,
    
    --[[
        Sets the text label displayed on the button.
        @param self The button builder instance
        @param label Display text header string
        @return The chainable button builder instance
    ]]
    setLabel: (self: ButtonBuilder, label: string) -> ButtonBuilder,
    
    --[[
        Sets the visual style of the button.
        @param self The button builder instance
        @param style Presentation format variant (Primary, Secondary, Success, Danger, Link)
        @return The chainable button builder instance
    ]]
    setStyle: (self: ButtonBuilder, style: any) -> ButtonBuilder,
    
    --[[
        Sets an emoji icon to display inside the button layout.
        @param self The button builder instance
        @param emoji Direct string code or table structure modeling the emoji
        @return The chainable button builder instance
    ]]
    setEmoji: (self: ButtonBuilder, emoji: any) -> ButtonBuilder,
    
    --[[
        Sets the external destination URL for a Link style button.
        @param self The button builder instance
        @param url Destination hyperlink web address
        @return The chainable button builder instance
    ]]
    setUrl: (self: ButtonBuilder, url: string) -> ButtonBuilder,
    
    --[[
        Disables or enables interaction with the button component.
        @param self The button builder instance
        @param disabled State boolean condition
        @return The chainable button builder instance
    ]]
    setDisabled: (self: ButtonBuilder, disabled: boolean?) -> ButtonBuilder,
    
    --[[
        Serializes the button structure to standard API JSON format.
        @param self The button builder instance
        @return Clean dictionary table map payload
    ]]
    toJSON: (self: ButtonBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable ButtonBuilder layout structure.
    @return A new ButtonBuilder instance schema
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

--[[
    Sets the custom identifier for the button.
    @param id Unique application string identifier mapped to this action
    @return The chainable button builder instance
]]
function ButtonMT:setCustomId(id: string): ButtonBuilder
    self._data.custom_id = tostring(id)
    return self
end

--[[
    Sets the text label displayed on the button.
    @param label Display text header string
    @return The chainable button builder instance
]]
function ButtonMT:setLabel(label: string): ButtonBuilder
    self._data.label = tostring(label)
    return self
end

--[[
    Sets the visual style of the button.
    @param style Presentation format variant (Primary, Secondary, Success, Danger, Link)
    @return The chainable button builder instance
]]
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

--[[
    Sets an emoji icon to display inside the button layout.
    @param emoji Direct string code or table structure modeling the emoji
    @return The chainable button builder instance
]]
function ButtonMT:setEmoji(emoji: any): ButtonBuilder
    if type(emoji) == "string" then
        self._data.emoji = { name = emoji }
    elseif type(emoji) == "table" then
        self._data.emoji = emoji
    end
    return self
end

--[[
    Sets the external destination URL for a Link style button.
    @param url Destination hyperlink web address
    @return The chainable button builder instance
]]
function ButtonMT:setUrl(url: string): ButtonBuilder
    self._data.url = tostring(url)
    self._data.style = 5 -- URL buttons must use style 5 (Link)
    return self
end

--[[
    Disables or enables interaction with the button component.
    @param disabled State boolean condition
    @return The chainable button builder instance
]]
function ButtonMT:setDisabled(disabled: boolean?): ButtonBuilder
    self._data.disabled = disabled == true
    return self
end

--[[
    Serializes the button structure to standard API JSON format.
    @return Clean dictionary table map payload
]]
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

    --[[
        Sets the custom identifier for the select menu.
        @param self The select menu builder instance
        @param id Unique application routing string mapped to this interaction
        @return The chainable select menu builder instance
    ]]
    setCustomId: (self: StringSelectMenuBuilder, id: string) -> StringSelectMenuBuilder,
    
    --[[
        Sets the placeholder text displayed when no options are selected.
        @param self The select menu builder instance
        @param placeholder Initial greyed-out guide header string
        @return The chainable select menu builder instance
    ]]
    setPlaceholder: (self: StringSelectMenuBuilder, placeholder: string) -> StringSelectMenuBuilder,
    
    --[[
        Adds a selectable option item to the menu structure.
        @param self The select menu builder instance
        @param label Visible text header assigned to the item
        @param value Internal payload string string transmitted upon selection
        @param description Secondary explanatory descriptor line
        @param emoji Accompanying graphic icon
        @return The chainable select menu builder instance
    ]]
    addOption: (self: StringSelectMenuBuilder, label: string, value: string, description: string?, emoji: any?) -> StringSelectMenuBuilder,
    
    --[[
        Sets the minimum number of selectable items.
        @param self The select menu builder instance
        @param min Allowed minimum boundary count
        @return The chainable select menu builder instance
    ]]
    setMinValues: (self: StringSelectMenuBuilder, min: number) -> StringSelectMenuBuilder,
    
    --[[
        Sets the maximum number of selectable items.
        @param self The select menu builder instance
        @param max Permitted upper limit count
        @return The chainable select menu builder instance
    ]]
    setMaxValues: (self: StringSelectMenuBuilder, max: number) -> StringSelectMenuBuilder,
    
    --[[
        Disables or enables interaction with the select menu.
        @param self The select menu builder instance
        @param disabled Disabling boolean flag
        @return The chainable select menu builder instance
    ]]
    setDisabled: (self: StringSelectMenuBuilder, disabled: boolean?) -> StringSelectMenuBuilder,
    
    --[[
        Serializes the select menu structure to standard API JSON format.
        @param self The select menu builder instance
        @return Clean dictionary map array structure
    ]]
    toJSON: (self: StringSelectMenuBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable StringSelectMenuBuilder component schema.
    @return A new StringSelectMenuBuilder instance
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

--[[
    Sets the custom identifier for the select menu.
    @param id Unique application routing string mapped to this interaction
    @return The chainable select menu builder instance
]]
function SelectMenuMT:setCustomId(id: string): StringSelectMenuBuilder
    self._data.custom_id = tostring(id)
    return self
end

--[[
    Sets the placeholder text displayed when no options are selected.
    @param placeholder Initial greyed-out guide header string
    @return The chainable select menu builder instance
]]
function SelectMenuMT:setPlaceholder(placeholder: string): StringSelectMenuBuilder
    self._data.placeholder = tostring(placeholder)
    return self
end

--[[
    Adds a selectable option item to the menu structure.
    @param label Visible text header assigned to the item
    @param value Internal payload string transmitted upon selection
    @param description Secondary explanatory descriptor line
    @param emoji Accompanying graphic icon
    @return The chainable select menu builder instance
]]
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

--[[
    Sets the minimum number of selectable items.
    @param min Allowed minimum boundary count
    @return The chainable select menu builder instance
]]
function SelectMenuMT:setMinValues(min: number): StringSelectMenuBuilder
    self._data.min_values = tonumber(min) or 1
    return self
end

--[[
    Sets the maximum number of selectable items.
    @param max Permitted upper limit count
    @return The chainable select menu builder instance
]]
function SelectMenuMT:setMaxValues(max: number): StringSelectMenuBuilder
    self._data.max_values = tonumber(max) or 1
    return self
end

--[[
    Disables or enables interaction with the select menu.
    @param disabled Disabling boolean flag
    @return The chainable select menu builder instance
]]
function SelectMenuMT:setDisabled(disabled: boolean?): StringSelectMenuBuilder
    self._data.disabled = disabled == true
    return self
end

--[[
    Serializes the select menu structure to standard API JSON format.
    @return Clean dictionary map array structure
]]
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

    --[[
        Appends one or more structured sub-components into this single layout container line.
        @param self The action row builder instance
        @param ... Successive component object instances (Buttons, Menus, TextInputs)
        @return The chainable action row builder instance
    ]]
    addComponents: (self: ActionRowBuilder, ...any) -> ActionRowBuilder,
    
    --[[
        Serializes the layout boundary to standard API JSON format.
        @param self The action row builder instance
        @return Composed action row wrapper table
    ]]
    toJSON: (self: ActionRowBuilder) -> { [string]: any },
}

--[[
    Instantiates a new layout ActionRowBuilder container view.
    @return A new ActionRowBuilder instance
]]
function Components.ActionRowBuilder(): ActionRowBuilder
    local self = {
        _components = {},
    }
    setmetatable(self, ActionRowMT)
    return (self :: any) :: ActionRowBuilder
end

--[[
    Appends one or more structured sub-components into this single layout container line.
    @param ... Successive component object instances (Buttons, Menus, TextInputs)
    @return The chainable action row builder instance
]]
function ActionRowMT:addComponents(...: any): ActionRowBuilder
    for i = 1, select("#", ...) do
        local comp = select(i, ...)
        if comp then
            table.insert(self._components, comp)
        end
    end
    return self
end

--[[
    Serializes the layout boundary to standard API JSON format.
    @return Composed action row wrapper table
]]
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

    --[[
        Sets the custom identifier mapped to this input field.
        @param self The text input builder instance
        @param id Target application extraction string matching this entry
        @return The chainable text input builder instance
    ]]
    setCustomId: (self: TextInputBuilder, id: string) -> TextInputBuilder,
    
    --[[
        Sets the label header displayed directly above the input box.
        @param self The text input builder instance
        @param label Header label prompt text
        @return The chainable text input builder instance
    ]]
    setLabel: (self: TextInputBuilder, label: string) -> TextInputBuilder,
    
    --[[
        Sets the input presentation dimension style.
        @param self The text input builder instance
        @param style Presentation variant format (Short or Paragraph)
        @return The chainable text input builder instance
    ]]
    setStyle: (self: TextInputBuilder, style: any) -> TextInputBuilder,
    
    --[[
        Sets a background placeholder guide string.
        @param self The text input builder instance
        @param placeholder Faded hint text overlay
        @return The chainable text input builder instance
    ]]
    setPlaceholder: (self: TextInputBuilder, placeholder: string) -> TextInputBuilder,
    
    --[[
        Pre-fills the form field with a static default string value.
        @param self The text input builder instance
        @param value Preset textual content
        @return The chainable text input builder instance
    ]]
    setValue: (self: TextInputBuilder, value: string) -> TextInputBuilder,
    
    --[[
        Controls whether the field must be populated prior to validation submission.
        @param self The text input builder instance
        @param required Mandatory condition boolean
        @return The chainable text input builder instance
    ]]
    setRequired: (self: TextInputBuilder, required: boolean?) -> TextInputBuilder,
    
    --[[
        Enforces a minimum character length boundary constraint.
        @param self The text input builder instance
        @param min Minimum string length limit
        @return The chainable text input builder instance
    ]]
    setMinLength: (self: TextInputBuilder, min: number) -> TextInputBuilder,
    
    --[[
        Enforces a maximum character length limit constraint.
        @param self The text input builder instance
        @param max Maximum allowable string string length
        @return The chainable text input builder instance
    ]]
    setMaxLength: (self: TextInputBuilder, max: number) -> TextInputBuilder,
    
    --[[
        Serializes the text input properties to standard API JSON format.
        @param self The text input builder instance
        @return Clean component representation map dictionary
    ]]
    toJSON: (self: TextInputBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable TextInputBuilder layout schema for Modal popup windows.
    @return A new TextInputBuilder instance schema
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

--[[
    Sets the custom identifier mapped to this input field.
    @param id Target application extraction string matching this entry
    @return The chainable text input builder instance
]]
function TextInputMT:setCustomId(id: string): TextInputBuilder
    self._data.custom_id = tostring(id)
    return self
end

--[[
    Sets the label header displayed directly above the input box.
    @param label Header label prompt text
    @return The chainable text input builder instance
]]
function TextInputMT:setLabel(label: string): TextInputBuilder
    self._data.label = tostring(label)
    return self
end

--[[
    Sets the input presentation dimension style.
    @param style Presentation variant format (Short or Paragraph)
    @return The chainable text input builder instance
]]
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

--[[
    Sets a background placeholder guide string.
    @param placeholder Faded hint text overlay
    @return The chainable text input builder instance
]]
function TextInputMT:setPlaceholder(placeholder: string): TextInputBuilder
    self._data.placeholder = tostring(placeholder)
    return self
end

--[[
    Pre-fills the form field with a static default string value.
    @param value Preset textual content
    @return The chainable text input builder instance
]]
function TextInputMT:setValue(value: string): TextInputBuilder
    self._data.value = tostring(value)
    return self
end

--[[
    Controls whether the field must be populated prior to validation submission.
    @param required Mandatory condition boolean
    @return The chainable text input builder instance
]]
function TextInputMT:setRequired(required: boolean?): TextInputBuilder
    self._data.required = required ~= false
    return self
end

--[[
    Enforces a minimum character length boundary constraint.
    @param min Minimum string length limit
    @return The chainable text input builder instance
]]
function TextInputMT:setMinLength(min: number): TextInputBuilder
    self._data.min_length = tonumber(min)
    return self
end

--[[
    Enforces a maximum character length limit constraint.
    @param max Maximum allowable string length
    @return The chainable text input builder instance
]]
function TextInputMT:setMaxLength(max: number): TextInputBuilder
    self._data.max_length = tonumber(max)
    return self
end

--[[
    Serializes the text input properties to standard API JSON format.
    @return Clean component representation map dictionary
]]
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

    --[[
        Sets the custom identifier mapped to this complete popup dialogue window.
        @param self The modal builder instance
        @param id Target application string identifier routed upon user validation
        @return The chainable modal builder instance
    ]]
    setCustomId: (self: ModalBuilder, id: string) -> ModalBuilder,
    
    --[[
        Sets the top heading header title overlay of the popup form layout box.
        @param self The modal builder instance
        @param title Upper window header label string
        @return The chainable modal builder instance
    ]]
    setTitle: (self: ModalBuilder, title: string) -> ModalBuilder,
    
    --[[
        Embeds ActionRow wrapper collections hosting user entries inside the popup layout.
        @param self The modal builder instance
        @param ... ActionRow builder interface objects wrapping text entry fields
        @return The chainable modal builder instance
    ]]
    addComponents: (self: ModalBuilder, ...any) -> ModalBuilder,
    
    --[[
        Serializes the complete modal screen envelope schema to standard API JSON format.
        @param self The modal builder instance
        @return Complete dictionary map block representing the modal envelope
    ]]
    toJSON: (self: ModalBuilder) -> { [string]: any },
}

--[[
    Instantiates a new chainable ModalBuilder structure view.
    @return A new ModalBuilder instance schema
]]
function Components.ModalBuilder(): ModalBuilder
    local self = {
        _data = {},
        _components = {},
    }
    setmetatable(self, ModalMT)
    return (self :: any) :: ModalBuilder
end

--[[
    Sets the custom identifier mapped to this complete popup dialogue window.
    @param id Target application string identifier routed upon user validation
    @return The chainable modal builder instance
]]
function ModalMT:setCustomId(id: string): ModalBuilder
    self._data.custom_id = tostring(id)
    return self
end

--[[
    Sets the top heading header title overlay of the popup form layout box.
    @param title Upper window header label string
    @return The chainable modal builder instance
]]
function ModalMT:setTitle(title: string): ModalBuilder
    self._data.title = tostring(title)
    return self
end

--[[
    Embeds ActionRow wrapper collections hosting user entries inside the popup layout.
    @param ... ActionRow builder interface objects wrapping text entry fields
    @return The chainable modal builder instance
]]
function ModalMT:addComponents(...: any): ModalBuilder
    for i = 1, select("#", ...) do
        local comp = select(i, ...)
        if comp then
            table.insert(self._components, comp)
        end
    end
    return self
end

--[[
    Serializes the complete modal screen envelope schema to standard API JSON format.
    @return Complete dictionary map block representing the modal envelope
]]
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
