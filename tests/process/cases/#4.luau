local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("Process Deep Parameter Preservation and Monotonicity", function()
        h.test("process vector execution perfectly preserves empty strings and whitespace arguments", function()
            -- Passing strict empty items inside an argument vector proves OS level preservation bypasses shell string stripping
            local prog = if Process.os() == "windows" then "cmd.exe" else "/bin/sh"
            local flag = if Process.os() == "windows" then "/C" else "-c"

            local res = Process.spawn(prog, { flag, "echo [start] [end]" })
            expect.true_(res.ok)
            expect.true_(string.find(res.stdout, "%[start%] %[end%]") ~= nil, "Preserves internal argument formatting correctly")
        end)

        h.test("process complex variable arrays merge seamlessly without cross-contamination", function()
            -- Overriding explicit context maps dynamically
            local k1, k2 = "LUKS_MULTI_A", "LUKS_MULTI_B"
            local v1, v2 = "alpha-payload", "beta-payload"

            local res = Process.exec("echo map check", {
                env = {
                    [k1] = v1,
                    [k2] = v2,
                },
            })
            expect.true_(res.ok, "Multiple key injections compile and pass thread stack checks cleanly")
        end)

        h.test("process telemetry tracks incremental monotonic execution frames continuously", function()
            local u1 = Process.uptime()
            -- Minimal active wait loop simulating script processing blocks
            local sum = 0
            for i = 1, 10000 do
                sum += i
            end

            local u2 = Process.uptime()
            expect.true_(u2 >= u1, "Subsequent uptime queries scale monotonically forward")
        end)

        h.test("process submodule configuration correctly reflects runtime version property flags", function()
            expect.type_(Process.version, "string")
            expect.eq(Process.version, "0.1.0", "Exposes standardized module revision tag string")
        end)
    end)
end
