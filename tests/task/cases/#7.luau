local h = require("../../helpers")

return function(expect)
    h.suite("Task Engine High-Volume Scheduling Stress", function()
        h.test("task continuous batch deferred execution scheduling cycling over 500 iterations", function()
            local iterations = 500
            local executed = 0

            for i = 1, iterations do
                task.defer(function()
                    executed += 1
                end)

                -- Yield every 50 scheduled tasks to let the engine drain threads perfectly
                if i % 50 == 0 then
                    task.wait()
                end
            end

            -- Final settlement wait
            local timeout = 0
            while executed < iterations and timeout < 50 do
                task.wait(0.05)
                timeout += 1
            end

            expect.eq(executed, iterations)
        end)
    end)
    return true
end
