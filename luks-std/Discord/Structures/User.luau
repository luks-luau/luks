--!strict
--!native
--!optimize 2

--[[
    User Structure — OOP Wrapper framework modeling global Discord User entities.
]]

export type User = {
    id: string,
    username: string,
    discriminator: string?,
    avatar: string?,
    bot: boolean,

    --[[
        Generates the standard structural mention string mapping directly to this user ID.
        @param self The user instance
        @return Direct platform-compliant formatted mention string (<@id>)
    ]]
    mention: (self: User) -> string,
    
    --[[
        Generates the formatted absolute CDN resource URL pointing to the user's avatar image.
        @param self The user instance
        @param format Desired file extension variant (png, gif)
        @param size Pixel dimension limit rendering bound
        @return Full absolute resource web URL string
    ]]
    avatarUrl: (self: User, format: string?, size: number?) -> string,
}

local User = {}
local UserMT = {}
UserMT.__index = UserMT

--[[
    Instantiates a structured User framework wrapper parsing incoming payload properties.
    @param data Dictionary map containing base entity identification parameters
    @return A new User instance wrapper
]]
function User.new(data: { [string]: any }): User
    local self = {
        id = tostring(data.id or ""),
        username = tostring(data.username or ""),
        discriminator = data.discriminator and tostring(data.discriminator),
        avatar = data.avatar and tostring(data.avatar),
        bot = data.bot == true,
    }
    setmetatable(self, UserMT)
    return (self :: any) :: User
end

--[[
    Generates the standard structural mention string mapping directly to this user ID.
    @return Direct platform-compliant formatted mention string (<@id>)
]]
function UserMT.mention(self: User): string
    return "<@" .. self.id .. ">"
end

--[[
    Generates the formatted absolute CDN resource URL pointing to the user's avatar image.
    @param format Desired file extension variant (png, gif)
    @param size Pixel dimension limit rendering bound
    @return Full absolute resource web URL string
]]
function UserMT.avatarUrl(self: User, format: string?, size: number?): string
    local fmt = format or (self.avatar and string.find(self.avatar, "^a_") and "gif" or "png")
    local sz = size or 1024
    if self.avatar then
        return "https://cdn.discordapp.com/avatars/" .. self.id .. "/" .. self.avatar .. "." .. fmt .. "?size=" .. tostring(sz)
    else
        -- Default avatar index fallback selection mapping based on legacy discriminator or modern IDs
        local defaultIndex = 0
        if self.discriminator and self.discriminator ~= "0" then
            defaultIndex = tonumber(self.discriminator) or 0
        else
            -- Modern pomelo user migration framework defaults to ending integers of the base user ID
            local numId = tonumber(string.sub(self.id, -4)) or 0
            defaultIndex = numId
        end
        return "https://cdn.discordapp.com/embed/avatars/" .. tostring(defaultIndex % 5) .. ".png"
    end
end

table.freeze(UserMT)
table.freeze(User)
return User
