local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("Process Native Interface Automation", function()
        h.test("process direct engine operations handle absent binary paths gracefully", function()
            local res = Process.spawn("non-existent-binary-target-9999", { "--flag" })
            expect.false_(res.ok, "Missing executables flag explicit failed operational status")
            expect.type_(res.error, "string")
            expect.true_(res.status ~= 0, "Yields non-zero system return status mapping")
        end)

        h.test("process inline native shell wrapper evaluates platform streams", function()
            local res = Process.exec("echo runtime validation stream output")
            expect.true_(res.ok, "Shell strings successfully instantiate execution contexts")
            expect.type_(res.stdout, "string")
            expect.true_(string.find(res.stdout, "validation", 1, true) ~= nil, "Captures underlying process textual emissions")
        end)

        h.test("process global environment mappings persist execution variable assignments", function()
            local testKey = "LUKS_DYNAMIC_TEST_VAR"
            local testVal = "enterprise-binary-mapping-value"

            -- Set state
            Process.setEnv(testKey, testVal)
            expect.eq(Process.getEnv(testKey), testVal, "Accurately resolves dynamic assigned environmental string values")

            -- Verify complete table aggregation inclusion
            local maps = Process.getAllEnv()
            expect.type_(maps, "table")
            expect.eq(maps[testKey], testVal, "Global mapping context retains explicit variables")

            -- Remove state
            Process.removeEnv(testKey)
            expect.eq(Process.getEnv(testKey), nil, "Purges specified contexts globally upon evaluation")
        end)

        h.test("process telemetry operations query host processor runtime bounds", function()
            expect.type_(Process.os(), "string")
            expect.type_(Process.arch(), "string")
            expect.type_(Process.id(), "number")
            expect.true_(Process.id() > 0, "Host Operating System returns authentic non-zero PID integer")

            local t1 = Process.uptime()
            expect.type_(t1, "number")
            expect.true_(t1 >= 0, "Floating uptime intervals reflect initialized dynamic tracking frames")
        end)
    end)
end
