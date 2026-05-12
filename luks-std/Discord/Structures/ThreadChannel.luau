--!strict

--[[
    ThreadChannel Structure — OOP representation of a thread or forum discussion subchannel.
]]

export type ThreadChannel = {
    --[[ The unique ID of this thread. ]]
    id: string,
    
    --[[ The guild ID this thread belongs to. ]]
    guild_id: string?,
    
    --[[ The parent channel ID this thread was created inside. ]]
    parent_id: string?,
    
    --[[ The user ID of the creator of this thread. ]]
    owner_id: string?,
    
    --[[ The name of the thread. ]]
    name: string,
    
    --[[ The channel type (11 for Public Thread, 12 for Private Thread). ]]
    type: number,
    
    --[[ An approximate count of messages in this thread. ]]
    message_count: number,
    
    --[[ An approximate count of unique members in this thread. ]]
    member_count: number,
    
    --[[ Whether the thread is archived. ]]
    archived: boolean,
    
    --[[ Whether the thread is locked. ]]
    locked: boolean,
    
    _rest: any,

    --[[ Joins the active thread as the current authenticated bot user. ]]
    join: (self: ThreadChannel) -> boolean,
    
    --[[ Leaves the active thread. ]]
    leave: (self: ThreadChannel) -> boolean,
    
    --[[ Archives or unarchives the thread. ]]
    setArchived: (self: ThreadChannel, archived: boolean) -> boolean,
}

local ThreadChannel = {}
local ThreadChannelMT = {}
ThreadChannelMT.__index = ThreadChannelMT

--[[
    Instantiates a new ThreadChannel object from a REST or Gateway payload.
]]
function ThreadChannel.new(payload: { [string]: any }, restClient: any): ThreadChannel
    local threadMeta = payload.thread_metadata or {}
    
    local self = {
        id = tostring(payload.id or ""),
        guild_id = payload.guild_id and tostring(payload.guild_id),
        parent_id = payload.parent_id and tostring(payload.parent_id),
        owner_id = payload.owner_id and tostring(payload.owner_id),
        name = tostring(payload.name or ""),
        type = tonumber(payload.type) or 11, -- 11: Public Thread, 12: Private Thread
        message_count = tonumber(payload.message_count) or 0,
        member_count = tonumber(payload.member_count) or 0,
        archived = threadMeta.archived == true,
        locked = threadMeta.locked == true,
        
        _rest = restClient,
    }
    setmetatable(self, ThreadChannelMT)
    return (self :: any) :: ThreadChannel
end

function ThreadChannelMT:join(): boolean
    if not self._rest then return false end
    -- Route: PUT /channels/{thread.id}/thread-members/@me
    local ok, _ = self._rest:put("/channels/" .. self.id .. "/thread-members/@me")
    return ok
end

function ThreadChannelMT:leave(): boolean
    if not self._rest then return false end
    -- Route: DELETE /channels/{thread.id}/thread-members/@me
    local ok, _ = self._rest:delete("/channels/" .. self.id .. "/thread-members/@me")
    return ok
end

function ThreadChannelMT:setArchived(archived: boolean): boolean
    if not self._rest then return false end
    -- Route: PATCH /channels/{thread.id}
    local ok, res = self._rest:patch("/channels/" .. self.id, {
        archived = archived == true,
    })
    if ok and type(res) == "table" and res.thread_metadata then
        self.archived = res.thread_metadata.archived == true
    end
    return ok
end

table.freeze(ThreadChannelMT)
table.freeze(ThreadChannel)
return ThreadChannel
