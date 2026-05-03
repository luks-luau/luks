local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Signal DisconnectAll and Destroy", function()
        h.test("DisconnectAll disconnects all connections", function()
            local sig = Signal.new()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Connect(function() count += 1 end)
            sig:DisconnectAll()
            sig:Fire()
            task.wait()
            expect.eq(count, 0)
        end)

        h.test("Destroy calls DisconnectAll", function()
            local sig = Signal.new()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Destroy()
            sig:Fire()
            task.wait()
            expect.eq(count, 0)
        end)

        h.test("DisconnectAll allows new connections", function()
            local sig = Signal.new()
            sig:Connect(function() end)
            sig:DisconnectAll()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Fire()
            task.wait()
            expect.eq(count, 1)
        end)
    end)
end
