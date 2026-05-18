--!strict
--!native
--!optimize 2

--[[
    Events Module — Centralized Event Loop and Polling Service for luks-luau.
    Provides a unified tick system for native module polling and periodic tasks.
    Inspired by high-performance event loops, featuring Signal-based updates.
]]

local Signal = require("@self/deps/signal")

local Events = {}

--[[ 
    Signal fired once per Luau scheduler cycle. 
    Can be used for custom logic that needs to run every tick.
]]
Events.OnTick = Signal.new()

-- Compatibility alias for older versions
Events.onTick = Events.OnTick

local pollProviders: { [string]: () -> ...any } = {}
local isRunning = false

--[[
    Registers a polling function (usually from a native module).
    The callback should be non-blocking and return quickly.
    
    @param name A unique identifier for this poll provider.
    @param callback The function to be called every tick.
]]
function Events.registerPoll(name: string, callback: () -> ...any): ()
    pollProviders[name] = callback
    if not isRunning then
        Events.start()
    end
end

--[[
    Unregisters a polling function.
    
    @param name The unique identifier of the poll provider to remove.
]]
function Events.unregisterPoll(name: string): ()
    pollProviders[name] = nil
end

--[[
    Registers a callback to run exactly once on the next tick.
    
    @param callback The function to run once.
]]
function Events.once(callback: () -> ...any): ()
    local name = "once_" .. tostring(os.clock()) .. "_" .. tostring(math.random())
    Events.registerPoll(name, function()
        Events.unregisterPoll(name)
        callback()
    end)
end

--[[
    Registers a callback to run every X seconds.
    Note: The precision is limited by the underlying task.wait() or poll cycle.
    
    @param seconds The interval between calls.
    @param callback The function to run periodically.
    @return A function that can be called to stop the interval.
]]
function Events.onEvery(seconds: number, callback: () -> ...any): () -> ()
    local lastRun = os.clock()
    local name = "every_" .. tostring(lastRun) .. "_" .. tostring(math.random())
    
    Events.registerPoll(name, function()
        local now = os.clock()
        if now - lastRun >= seconds then
            lastRun = now
            callback()
        end
    end)
    
    return function()
        Events.unregisterPoll(name)
    end
end

--[[
    Starts the global event loop if not already running.
    The loop continues as long as there are registered poll providers.
]]
function Events.start(): ()
    if isRunning then return end
    isRunning = true
    
    task.spawn(function()
        while isRunning and next(pollProviders) ~= nil do
            -- 1. Fire the tick signal
            (Events.OnTick :: any):Fire()
            
            -- 2. Run all registered poll providers
            for name, poll in pairs(pollProviders) do
                local success, err = pcall(poll)
                if not success then
                    print(string.format("[Events][WARN] Error in poll provider '%s': %s", name, tostring(err)))
                end
            end
            
            -- 3. Yield to next cycle (wait 0 yields for exactly one tick)
            task.wait(0)
        end
        isRunning = false
    end)
end

--[[
    Stops the global event loop and unregisters all providers.
]]
function Events.stop(): ()
    isRunning = false
    table.clear(pollProviders)
end

--[[
    Returns whether the event loop is currently running.
]]
function Events.isActive(): boolean
    return isRunning
end

--[[
    Returns a list of all currently registered poll provider names.
]]
function Events.getProviders(): {string}
    local names = {}
    for name in pairs(pollProviders) do
        table.insert(names, name)
    end
    return names
end

return Events
