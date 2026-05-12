--!strict

--[[
    Guild Structure — OOP Wrapper modeling Discord Guild (Server) entities.
]]

export type Guild = {
    --[[ Unique identifier of the guild. ]]
    id: string,
    
    --[[ Official name of the server. ]]
    name: string,
    
    --[[ Static hash representing the guild's avatar icon. ]]
    icon: string?,
    
    --[[ The user ID of the server owner. ]]
    owner_id: string?,
    
    --[[ Total count of members occupying this server. ]]
    member_count: number,
    
    _rest: any,

    --[[ Generates the absolute asset URL pointing to the server's avatar icon. ]]
    iconUrl: (self: Guild, format: string?, size: number?) -> string?,
    
    --[[ Triggers bot withdrawal/departure from this guild. ]]
    leave: (self: Guild) -> (boolean, string?),

    --[[ Retrieves moderation records stored inside the guild's audit logs. ]]
    fetchAuditLogs: (self: Guild, options: { limit: number?, action_type: number?, user_id: string?, before: string? }?) -> (boolean, any),
    
    --[[ Enumerates all active server invites assigned to this guild. ]]
    fetchInvites: (self: Guild) -> (boolean, any),
}

local Guild = {}
local GuildMT = {}
GuildMT.__index = GuildMT

--[[
    Instantiates a new structured Guild model object.
]]
function Guild.new(data: { [string]: any }, restClient: any): Guild
    local self = {
        id = tostring(data.id or ""),
        name = tostring(data.name or ""),
        icon = data.icon and tostring(data.icon),
        owner_id = data.owner_id and tostring(data.owner_id),
        member_count = tonumber(data.member_count) or 0,
        _rest = restClient,
    }
    setmetatable(self, GuildMT)
    return (self :: any) :: Guild
end

function GuildMT:iconUrl(format: string?, size: number?): string?
    if not self.icon then return nil end
    local fmt = format or (string.find(self.icon, "^a_") and "gif" or "png")
    local sz = size or 1024
    return "https://cdn.discordapp.com/icons/" .. self.id .. "/" .. self.icon .. "." .. fmt .. "?size=" .. tostring(sz)
end

function GuildMT:leave(): (boolean, string?)
    if not self._rest then
        return false, "REST client reference unavailable on this Guild structure."
    end
    -- Official route for bot users to leave a guild: DELETE /users/@me/guilds/{guild.id}
    local ok, res = self._rest:delete("/users/@me/guilds/" .. self.id)
    if ok then
        return true, nil
    else
        return false, tostring(res)
    end
end

function GuildMT:fetchAuditLogs(options: { limit: number?, action_type: number?, user_id: string?, before: string? }?): (boolean, any)
    if not self._rest then return false, "REST client reference unavailable." end
    local endpoint = "/guilds/" .. self.id .. "/audit-logs"
    local query = {}
    if options then
        if options.limit then table.insert(query, "limit=" .. tostring(options.limit)) end
        if options.action_type then table.insert(query, "action_type=" .. tostring(options.action_type)) end
        if options.user_id then table.insert(query, "user_id=" .. tostring(options.user_id)) end
        if options.before then table.insert(query, "before=" .. tostring(options.before)) end
    end
    if #query > 0 then
        endpoint = endpoint .. "?" .. table.concat(query, "&")
    end
    return self._rest:get(endpoint)
end

function GuildMT:fetchInvites(): (boolean, any)
    if not self._rest then return false, "REST client reference unavailable." end
    return self._rest:get("/guilds/" .. self.id .. "/invites")
end

table.freeze(GuildMT)
table.freeze(Guild)
return Guild
