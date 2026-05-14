--!strict

--[[
    ThreadChannel Structure — OOP representation modeling nested forum discussion threads or sub-channels.
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

    --[[
        Joins the active forum discussion thread using authorized bot credentials.
        @param self The thread channel instance
        @return True if successfully joined without API restriction blocks
    ]]
    join: (self: ThreadChannel) -> boolean,
    
    --[[
        Leaves/withdraws from the target discussion thread scope.
        @param self The thread channel instance
        @return True if executed cleanly
    ]]
    leave: (self: ThreadChannel) -> boolean,
    
    --[[
        Toggles the historical archiving metrics status assigned to the thread.
        @param self The thread channel instance
        @param archived Boolean target archiving condition
        @return True if modification routes to the backend successfully
    ]]
    setArchived: (self: ThreadChannel, archived: boolean) -> boolean,
}

local ThreadChannel = {}
local ThreadChannelMT = {}
ThreadChannelMT.__index = ThreadChannelMT

--[[
    Instantiates a structured ThreadChannel object wrapper mapped to incoming payload metrics.
    @param payload Incoming thread attribute metadata dictionary
    @param restClient Core network REST application dispatcher interface
    @return A new ThreadChannel instance wrapper
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

--[[
    Joins the active forum discussion thread using authorized bot credentials.
    @return True if successfully joined without API restriction blocks
]]
function ThreadChannelMT.join(self: ThreadChannel): boolean
    if not self._rest then return false end
    -- Route: PUT /channels/{thread.id}/thread-members/@me
    local ok, _ = self._rest:put("/channels/" .. self.id .. "/thread-members/@me")
    return ok
end

--[[
    Leaves/withdraws from the target discussion thread scope.
    @return True if executed cleanly
]]
function ThreadChannelMT.leave(self: ThreadChannel): boolean
    if not self._rest then return false end
    -- Route: DELETE /channels/{thread.id}/thread-members/@me
    local ok, _ = self._rest:delete("/channels/" .. self.id .. "/thread-members/@me")
    return ok
end

--[[
    Toggles the historical archiving metrics status assigned to the thread.
    @param archived Boolean target archiving condition
    @return True if modification routes to the backend successfully
]]
function ThreadChannelMT.setArchived(self: ThreadChannel, archived: boolean): boolean
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
