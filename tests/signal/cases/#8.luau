local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Signal High-Frequency Event Flooding Stress", function()
        h.test("signal intensive firing cycling across multiple subscriber connections over 500 iterations", function()
            local sig = Signal.new()
            local iterations = 500
            local count_a = 0
            local count_b = 0

            sig:Connect(function(val)
                count_a += val
            end)

            sig:Connect(function(val)
                count_b += 1
            end)

            for i = 1, iterations do
                sig:Fire(1)
                if i % 50 == 0 then
                    task.wait()
                end
            end

            -- wait for pending spawned event dispatchers to drain
            local timeout = 0
            while count_b < iterations and timeout < 50 do
                task.wait(0.05)
                timeout += 1
            end

            expect.eq(count_a, iterations)
            expect.eq(count_b, iterations)
        end)
    end)
end
