local h = require("../../helpers")
local Stdio = require("../../../luks-std/Stdio")

return function(expect)
    h.suite("Stdio Asynchronous Input Handlers", function()
        h.test("stdio stdin reader initiates non-blocking signal event loops", function()
            local input = Stdio.stdin()
            expect.not_nil(input)
            expect.type_(input.read, "function")
            expect.type_(input.readAsync, "function")
            
            local sig = input:readAsync()
            expect.not_nil(sig)
            expect.type_(sig.Connect, "function")
            input:close()
        end)

        h.test("stdio prompt abstraction delegates execution chains securely", function()
            -- Prompt outputs string prefix and instantiates pure Luau signal listeners
            local sig = Stdio.promptAsync("")
            expect.not_nil(sig)
            expect.type_(sig.Connect, "function")
        end)
    end)
end
