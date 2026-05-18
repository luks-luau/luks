local h = require("../../helpers")
local Events = require("../../../luks-std/events")

return function(expect)
    h.suite("Events Basic Lifecycle", function()
        h.test("isActive: initially false, true after registration", function()
            expect.false_(Events.isActive())
            
            Events.registerPoll("test_init", function() end)
            expect.true_(Events.isActive())
            
            Events.unregisterPoll("test_init")
            -- Loop stops when no providers are left (async)
            task.wait(0.1) 
            expect.false_(Events.isActive())
        end)

        h.test("getProviders: returns list of names", function()
            Events.registerPoll("p1", function() end)
            Events.registerPoll("p2", function() end)
            
            local providers = Events.getProviders()
            expect.eq(#providers, 2)
            expect.true_(table.find(providers, "p1") ~= nil)
            expect.true_(table.find(providers, "p2") ~= nil)
            
            Events.stop() -- Clean up
            expect.eq(#Events.getProviders(), 0)
        end)
    end)

    h.suite("Events Signals and Callbacks", function()
        h.test("OnTick: fires every cycle", function()
            local count = 0
            local conn = Events.OnTick:Connect(function()
                count += 1
            end)
            
            Events.registerPoll("ticker", function() end)
            task.wait(0.05) -- Wait for some ticks
            
            conn:Disconnect()
            Events.unregisterPoll("ticker")
            
            expect.true_(count > 0)
        end)

        h.test("once: runs exactly once", function()
            local count = 0
            Events.once(function()
                count += 1
            end)
            
            task.wait(0.1)
            expect.eq(count, 1)
            
            task.wait(0.1)
            expect.eq(count, 1) -- Should still be 1
        end)
    end)

    h.suite("Events Timing", function()
        h.test("onEvery: runs at specified interval", function()
            local count = 0
            local interval = 0.1
            local stop = Events.onEvery(interval, function()
                count += 1
            end)
            
            task.wait(0.35) -- Should fire ~3 times (0.1, 0.2, 0.3)
            stop()
            
            local finalCount = count
            expect.true_(finalCount >= 3)
            
            task.wait(0.2)
            expect.eq(count, finalCount) -- Should have stopped
        end)
    end)

    h.suite("Events Error Handling", function()
        h.test("Loop continues even if a poller errors", function()
            local side_effect = false
            
            Events.registerPoll("error_poller", function()
                error("BOOM")
            end)
            
            Events.registerPoll("safe_poller", function()
                side_effect = true
            end)
            
            task.wait(0.1)
            Events.stop()
            
            expect.true_(side_effect)
        end)
    end)
end
