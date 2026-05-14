local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("Process Concurrent Spawning & High-Volume FFI Stress", function()
        h.test("process rapid continuous local engine telemetry access over 500 iterations", function()
            local iterations = 500
            for _ = 1, iterations do
                expect.true_(Process.id() > 0)
                expect.true_(Process.uptime() >= 0)
            end
        end)

        h.test("process high-concurrency non-blocking subprocess execution flooding", function()
            local concurrency = 5
            local completed = 0

            for i = 1, concurrency do
                Process.execAsync("echo STRESS_SPAWN_" .. i):Connect(function(res)
                    completed += 1
                    expect.true_(res.ok)
                    expect.true_(string.find(res.stdout, "STRESS_SPAWN_" .. i, 1, true) ~= nil)
                end)
            end

            local timeout = 0
            while completed < concurrency and timeout < 50 do
                task.wait(0.1)
                timeout += 1
            end

            expect.eq(completed, concurrency)
        end)
    end)
end
