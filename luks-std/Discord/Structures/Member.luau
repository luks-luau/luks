--!strict

--[[
    Member Structure — POO Wrapper representando um Membro específico de uma Guilda.
    Permite acionar moderação, timeouts e gerenciar cargos diretamente.
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

    --[[ Expulsa (Kick) o membro da guilda associada. ]]
    kick: (self: Member, reason: string?) -> boolean,
    
    --[[ Bane o membro da guilda associada. ]]
    ban: (self: Member, options: { delete_message_seconds: number?, reason: string? }?) -> boolean,
    
    --[[ Coloca o membro de castigo (Timeout). Use durationSeconds = 0 ou nil para remover o castigo. ]]
    timeout: (self: Member, durationSeconds: number?, reason: string?) -> boolean,
    
    --[[ Adiciona um cargo ao membro. ]]
    addRole: (self: Member, roleId: string, reason: string?) -> boolean,
    
    --[[ Remove um cargo do membro. ]]
    removeRole: (self: Member, roleId: string, reason: string?) -> boolean,
}

local Member = {}
local MemberMT = {}
MemberMT.__index = MemberMT

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

function MemberMT:kick(reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    
    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    local ok, _ = self._rest:delete("/guilds/" .. self.guild_id .. "/members/" .. self.user.id, headers)
    return ok
end

function MemberMT:ban(options: { delete_message_seconds: number?, reason: string? }?): boolean
    if not self._rest or not self.guild_id then return false end
    
    local opts = options or {}
    local body: { [string]: any } = {}
    if opts.delete_message_seconds then
        body.delete_message_seconds = tonumber(opts.delete_message_seconds) or 0
    end

    local headers = opts.reason and { ["X-Audit-Log-Reason"] = opts.reason } or {}
    local ok, _ = self._rest:put("/guilds/" .. self.guild_id .. "/bans/" .. self.user.id, body, headers)
    return ok
end

function MemberMT:timeout(durationSeconds: number?, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    
    local targetTimestamp: string? = nil
    if durationSeconds and durationSeconds > 0 then
        -- Calcula o timestamp futuro base de fallback simplificado ou injeta instrução nativa
        -- O Luau suporta os.time() e podemos gerar formato string de data de término aproximado
        -- Para precisão rigorosa de ISO-8601, passamos a string calculada
        local futureTime = os.time() + durationSeconds
        targetTimestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z", futureTime)
    else
        targetTimestamp = nil -- Remover timeout requer passar nil
    end

    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    -- O endpoint de timeout atualiza o membro passando communication_disabled_until
    local ok, _ = self._rest:patch("/guilds/" .. self.guild_id .. "/members/" .. self.user.id, {
        communication_disabled_until = targetTimestamp
    }, headers)
    return ok
end

function MemberMT:addRole(roleId: string, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    local ok, _ = self._rest:put("/guilds/" .. self.guild_id .. "/members/" .. self.user.id .. "/roles/" .. tostring(roleId), nil, headers)
    return ok
end

function MemberMT:removeRole(roleId: string, reason: string?): boolean
    if not self._rest or not self.guild_id then return false end
    local headers = reason and { ["X-Audit-Log-Reason"] = reason } or {}
    local ok, _ = self._rest:delete("/guilds/" .. self.guild_id .. "/members/" .. self.user.id .. "/roles/" .. tostring(roleId), headers)
    return ok
end

table.freeze(MemberMT)
table.freeze(Member)
return Member
