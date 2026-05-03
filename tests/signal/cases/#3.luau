local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Connection Disconnect", function()
        h.test("Disconnect prevents callback from being called", function()
            local sig = Signal.new()
            local called = false
            local conn = sig:Connect(function()
                called = true
            end)
            conn:Disconnect()
            sig:Fire()
            task.wait()
            expect.false_(called)
        end)

        h.test("Connected property is true when connected", function()
            local sig = Signal.new()
            local conn = sig:Connect(function() end)
            expect.true_(conn.Connected)
        end)

        h.test("Connected property is false after disconnect", function()
            local sig = Signal.new()
            local conn = sig:Connect(function() end)
            conn:Disconnect()
            expect.false_(conn.Connected)
        end)

        h.test("Disconnecting twice does not error", function()
            local sig = Signal.new()
            local conn = sig:Connect(function() end)
            conn:Disconnect()
            conn:Disconnect()
            expect.false_(conn.Connected)
        end)
    end)
end
