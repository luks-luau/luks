--!strict
--!native
--!optimize 2

--[[
    VoiceState Structure — OOP Wrapper modeling active channel connectivity state presences.
]]

local User = require("./User")

export type VoiceState = {
    --[[ The guild ID this voice state is for. ]]
    guild_id: string?,
    
    --[[ The channel ID this user is connected to. ]]
    channel_id: string?,
    
    --[[ The user ID this voice state is for. ]]
    user_id: string,
    
    --[[ The session ID for this voice state. ]]
    session_id: string,
    
    --[[ Whether this user is deafened by the server. ]]
    deaf: boolean,
    
    --[[ Whether this user is muted by the server. ]]
    mute: boolean,
    
    --[[ Whether this user is locally deafened. ]]
    self_deaf: boolean,
    
    --[[ Whether this user is locally muted. ]]
    self_mute: boolean,
    
    --[[ Whether this user is streaming using "Go Live". ]]
    self_stream: boolean?,
    
    --[[ Whether this user's camera is enabled. ]]
    self_video: boolean,
    
    --[[ Whether this user is muted by the current user. ]]
    suppress: boolean,
    
    --[[ The time at which the user requested to speak. ]]
    request_to_speak_timestamp: string?,

    --[[ The user object associated with this voice state. ]]
    user: User.User?,
}

local VoiceState = {}
local VoiceStateMT = {}
VoiceStateMT.__index = VoiceStateMT

--[[
    Instantiates a structured VoiceState wrapper mapped to state presence payload frames.
    @param payload Base incoming state attribute dictionary maps
    @return A new VoiceState instance wrapper
]]
function VoiceState.new(payload: { [string]: any }): VoiceState
    local self = {
        guild_id = payload.guild_id and tostring(payload.guild_id),
        channel_id = payload.channel_id and tostring(payload.channel_id),
        user_id = tostring(payload.user_id or ""),
        session_id = tostring(payload.session_id or ""),
        deaf = payload.deaf == true,
        mute = payload.mute == true,
        self_deaf = payload.self_deaf == true,
        self_mute = payload.self_mute == true,
        self_stream = payload.self_stream == true,
        self_video = payload.self_video == true,
        suppress = payload.suppress == true,
        request_to_speak_timestamp = payload.request_to_speak_timestamp,
        
        user = payload.user and User.new(payload.user) or nil,
    }
    setmetatable(self, VoiceStateMT)
    return (self :: any) :: VoiceState
end

table.freeze(VoiceStateMT)
table.freeze(VoiceState)
return VoiceState
