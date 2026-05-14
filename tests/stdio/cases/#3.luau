local h = require("../../helpers")
local Stdio = require("../../../luks-std/Stdio")

return function(expect)
    h.suite("Stdio Sub-Process Streaming Pipelining", function()
        h.test("stdio spawnStream allocates bidirectional event pipes securely", function()
            -- Invoke safe non-destructive host shell parameter flag evaluations
            local child = Stdio.spawnStream("luks", { "--version" })
            expect.not_nil(child)
            
            expect.not_nil(child.onStdout)
            expect.not_nil(child.onStderr)
            expect.not_nil(child.onExit)
            
            expect.type_(child.writeStdin, "function")
            expect.type_(child.closeStdin, "function")
            expect.type_(child.terminate, "function")
            
            -- Spin short execution barrier waiting for process evaluation drainage
            local timeout = 0
            local exited = false
            child.onExit:Once(function(code)
                exited = true
                expect.type_(code, "number")
            end)
            
            while not exited and timeout < 30 do
                task.wait(0.05)
                timeout += 1
            end
        end)
    end)
end
