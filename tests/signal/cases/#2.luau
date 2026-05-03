local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Signal Connect and Fire", function()
        h.test("Connected callback is called on Fire", function()
            local sig = Signal.new()
            local called = false
            sig:Connect(function()
                called = true
            end)
            sig:Fire()
            task.wait()
            expect.true_(called)
        end)

        h.test("Multiple callbacks are all called", function()
            local sig = Signal.new()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Connect(function() count += 1 end)
            sig:Connect(function() count += 1 end)
            sig:Fire()
            task.wait()
            expect.eq(count, 3)
        end)

        h.test("Fire passes arguments to callbacks", function()
            local sig = Signal.new()
            local received = nil
            sig:Connect(function(...)
                received = {...}
            end)
            sig:Fire(42, "hello", true)
            task.wait()
            expect.eq(received[1], 42)
            expect.eq(received[2], "hello")
            expect.eq(received[3], true)
        end)
    end)
end
