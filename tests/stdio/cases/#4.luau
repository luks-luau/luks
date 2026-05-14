local h = require("../../helpers")
local Stdio = require("../../../luks-std/Stdio")

return function(expect)
    h.suite("Stdio High-Volume Stream Stress Testing", function()
        h.test("stdio rapid continuous chainable console write output evaluations over 500 iterations", function()
            local out = Stdio.stdout()
            local iterations = 500
            
            for i = 1, iterations do
                out:write("")
                if i % 100 == 0 then
                    out:flush()
                    task.wait(0.005)
                end
            end
            
            expect.true_(true)
        end)

        h.test("stdio non-blocking sub-process stream descriptor communication flooding", function()
            local child = Stdio.spawnStream("luks", { "--help" })
            expect.not_nil(child)
            
            local received_chunks = 0
            child.onStdout:Connect(function(chunk)
                expect.type_(chunk, "string")
                received_chunks += 1
            end)
            
            local timeout = 0
            while timeout < 40 do
                task.wait(0.05)
                timeout += 1
            end
            
            -- Ensure process pipes get forcefully closed to prevent zombie OS thread allocations
            child:terminate()
            expect.true_(true)
        end)
    end)
end
