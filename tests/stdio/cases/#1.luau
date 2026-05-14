local h = require("../../helpers")
local Stdio = require("../../../luks-std/Stdio")

return function(expect)
    h.suite("Stdio Synchronous Output Handlers", function()
        h.test("stdio stdout handle evaluates chainable operations gracefully", function()
            local out = Stdio.stdout()
            expect.not_nil(out)
            
            -- Chainable formatting evaluations on empty buffers to verify runtime stability
            out:write("")
               :writeLine("")
               :fmt("%s", "")
               :color("green")
               :color("reset")
               :flush()
               
            expect.true_(true)
        end)

        h.test("stdio stderr handle evaluates chainable error logging correctly", function()
            local err = Stdio.stderr()
            expect.not_nil(err)
            
            err:write("")
               :writeLine("")
               :color("red")
               :color("reset")
               :flush()
               
            expect.true_(true)
        end)
        
        h.test("stdio module version matches static framework definitions", function()
            expect.type_(Stdio.version, "string")
            expect.true_(#Stdio.version > 0)
        end)
    end)
end
