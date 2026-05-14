--!strict

--[[
    Member Structure — OOP Wrapper modeling guild-specific member entities.
    Enables invoking moderation routing, timeouts, and explicit role assignment operations.
]]

local User = require("./User")

export type Member = {
    user: User.User,
    nick: string?,
    roles: { string },
    joined_at: string?,
    communication_disabled_until: string?,
    guild_id: string?,
    _rest: any,

    --[[
        Evicts/kicks the targeted member entity from the hosting server.
        @param self The member instance
        @param reason Optional moderation audit log reason descriptive justification
        @return True if successfully executed without API access constraints
    ]]
    kick: (self: Member, reason: string?) -> boolean,
    
    --[[
        Enforces a permanent server banishment action against this member.
        @param self The member instance
        @param options Configuration mapping setting historical message deletion windows and reason strings
        @return True if the banishment executes successfully
    ]]
    ban: (self: Member, options: { delete_message_seconds: number?, reason: string? }?) -> boolean,
    
    --[[
        Applies a localized timeout limitation disabling message and channel connectivity.
        @param self The member instance
        @param durationSeconds Expiration duration limit, or nil/zero to clear active restrictions
        @param reason Optional operational justification trail string
        @return True if successfully routed to the destination endpoint
    ]]
    timeout: (self: Member, durationSeconds: number?, reason: string?) -> boolean,
    
    --[[
        Assigns an additional structured guild role mapping identifier to the member.
        @param self The member instance
        @param roleId Target server role unique integer/string string identifier
        @param reason Optional logging reason record string
        @return True if assignment completes cleanly
    ]]
    addRole: (self: Member, roleId: string, reason: string?) -> boolean,
    
    --[[
        Revokes a previously assigned guild role mapping identifier from the member.
        @param self The member instance
        @param roleId Target server role unique integer/string string identifier
        @param reason Optional logging reason record string
        @return True if successfully unassigned
    ]]
    removeRole: (self: Member, roleId: string, reason: string?) -> boolean,
}

local Member = {}
local MemberMT = {}
MemberMT.__index = MemberMT

--[[
    Instantiates a structured Member wrapper object parsing entity metrics.
    @param payload Incoming entity dictionary map
    @param guildId Destination server identifier context string
    @param restClient Authorized core REST gateway dispatcher reference
    @return A new Member instance wrapper
]]
function Member.new(payload: { [string]: any }, guildId: string?, restClient: any): Member
    local rawRoles = {}
    if payload.roles and type(payload.roles) == "table" then
        for _, r in ipairs(payload.roles) do
            table.insert(rawRoles, tostring(r))
        end
    end

    local self = {
        user = User.new(payload.user or {}),
        nick = payload.nick and tostring(payload.nick),
        roles = rawRoles,
        joined_at = payload.joined_at and tostring(payload.joined_at),
        communication_disabled_until = payload.communication_disabled_until and tostring(payload.communication_disabled_until),
        guild_id = guildId and tostring(guildId),
        _rest = restClient,
    }
    setmetatable(self, MemberMT)
    return (self :: any) :: Member
end

--[[
    Evicts/kicks the targeted member entity from the hosting server.
    @param reason Optional moderation audit log reason descriptive justification
    @return True if successfully executed without API access constraints
]]
function MemberMT.kick(self: Member, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    local guildId = self.guild_id :: string
    
    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    local ok, _ = self._rest:delete("/guilds/" .. guildId .. "/members/" .. self.user.id, headers)
    return ok
end

--[[
    Enforces a permanent server banishment action against this member.
    @param options Configuration mapping setting historical message deletion windows and reason strings
    @return True if the banishment executes successfully
]]
function MemberMT.ban(self: Member, options: { delete_message_seconds: number?, reason: string? }?): boolean
    if not self._rest or not self.guild_id then return false end
    local guildId = self.guild_id :: string
    
    local opts = (options or {}) :: { delete_message_seconds: number?, reason: string? }
    local body: { [string]: any } = {}
    if opts.delete_message_seconds then
        body.delete_message_seconds = tonumber(opts.delete_message_seconds) or 0
    end

    local headers = opts.reason and { ["X-Audit-Log-Reason"] = opts.reason } or {}
    local ok, _ = self._rest:put("/guilds/" .. guildId .. "/bans/" .. self.user.id, body, headers)
    return ok
end

--[[
    Applies a localized timeout limitation disabling message and channel connectivity.
    @param durationSeconds Expiration duration limit, or nil/zero to clear active restrictions
    @param reason Optional operational justification trail string
    @return True if successfully routed to the destination endpoint
]]
function MemberMT.timeout(self: Member, durationSeconds: number?, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    local guildId = self.guild_id :: string
    
    local targetTimestamp: string? = nil
    if durationSeconds and durationSeconds > 0 then
        -- Computes future target end timestamp string fallback mapping
        -- Luau native os.time() generates precise delta strings
        -- Pass ISO-8601 compliant string representation for strict API parsing
        local futureTime = os.time() + durationSeconds
        targetTimestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z", futureTime)
    else
        targetTimestamp = nil -- Removing active timeout enforces passing nil
    end

    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    -- Timeout endpoint routes via PATCH modifying communication_disabled_until
    local ok, _ = self._rest:patch("/guilds/" .. guildId .. "/members/" .. self.user.id, {
        communication_disabled_until = targetTimestamp
    }, headers)
    return ok
end

--[[
    Assigns an additional structured guild role mapping identifier to the member.
    @param roleId Target server role unique integer/string identifier
    @param reason Optional logging reason record string
    @return True if assignment completes cleanly
]]
function MemberMT.addRole(self: Member, roleId: string, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    local guildId = self.guild_id :: string
    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    local ok, _ = self._rest:put("/guilds/" .. guildId .. "/members/" .. self.user.id .. "/roles/" .. tostring(roleId), nil, headers)
    return ok
end

--[[
    Revokes a previously assigned guild role mapping identifier from the member.
    @param roleId Target server role unique integer/string identifier
    @param reason Optional logging reason record string
    @return True if successfully unassigned
]]
function MemberMT.removeRole(self: Member, roleId: string, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    local guildId = self.guild_id :: string
    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    local ok, _ = self._rest:delete("/guilds/" .. guildId .. "/members/" .. self.user.id .. "/roles/" .. tostring(roleId), headers)
    return ok
end

table.freeze(MemberMT)
table.freeze(Member)
return Member
