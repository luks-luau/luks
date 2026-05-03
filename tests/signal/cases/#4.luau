local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Signal Once", function()
        h.test("Once callback is called only once", function()
            local sig = Signal.new()
            local count = 0
            sig:Once(function()
                count += 1
            end)
            sig:Fire()
            task.wait()
            expect.eq(count, 1)
            sig:Fire()
            task.wait()
            expect.eq(count, 1)
        end)

        h.test("Once connection disconnects after firing", function()
            local sig = Signal.new()
            local conn = sig:Once(function() end)
            sig:Fire()
            task.wait()
            expect.false_(conn.Connected)
        end)

        h.test("Once passes arguments correctly", function()
            local sig = Signal.new()
            local result = nil
            sig:Once(function(a, b)
                result = a + b
            end)
            sig:Fire(2, 3)
            task.wait()
            expect.eq(result, 5)
        end)
    end)
end
