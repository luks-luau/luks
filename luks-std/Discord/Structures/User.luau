--!strict

--[[
    User Structure — POO Wrapper for Discord User entities.
]]

export type User = {
    id: string,
    username: string,
    discriminator: string?,
    avatar: string?,
    bot: boolean,

    --[[ Gera a string de menção com a sintaxe oficial (<@id>). ]]
    mention: (self: User) -> string,
    
    --[[ Retorna a URL completa da imagem de avatar do usuário. ]]
    avatarUrl: (self: User, format: string?, size: number?) -> string,
}

local User = {}
local UserMT = {}
UserMT.__index = UserMT

--[[
    Instancia um novo modelo de User baseado nos dados brutos do JSON da API.
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

function UserMT:mention(): string
    return "<@" .. self.id .. ">"
end

function UserMT:avatarUrl(format: string?, size: number?): string
    local fmt = format or (self.avatar and string.find(self.avatar, "^a_") and "gif" or "png")
    local sz = size or 1024
    if self.avatar then
        return "https://cdn.discordapp.com/avatars/" .. self.id .. "/" .. self.avatar .. "." .. fmt .. "?size=" .. tostring(sz)
    else
        -- Avatar padrão baseado no discriminador ou ID
        local defaultIndex = 0
        if self.discriminator and self.discriminator ~= "0" then
            defaultIndex = tonumber(self.discriminator) or 0
        else
            -- Migração moderna do Discord sem discriminador usa a parte do ID
            local numId = tonumber(string.sub(self.id, -4)) or 0
            defaultIndex = numId
        end
        return "https://cdn.discordapp.com/embed/avatars/" .. tostring(defaultIndex % 5) .. ".png"
    end
end

table.freeze(UserMT)
table.freeze(User)
return User
