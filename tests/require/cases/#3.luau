-- Test #3: Init Module Require Tests
-- Tests that init.luau files behave as representatives of their containing folder

local h = require("../../helpers")

return function(expect)
    h.suite("Init Module Require Tests", function()

        h.test("init.luau can require sibling module", function()
            local mod = require("./init-test/pastadoscript")
            expect.not_nil(mod.module2, "Should have module2")
            expect.eq(mod.module2.hello, "world from pastadoscript2", "module2 should be loaded correctly")
        end)

        h.test("init.luau resolves bare name to parent directory", function()
            -- O require("pastadoscript2") dentro de pastadoscript/init.luau
            -- deve procurar em init-test/pastadoscript2, não em init-test/pastadoscript/pastadoscript2
            local mod = require("./init-test/pastadoscript")
            expect.eq(mod.hello, "from pastadoscript", "init module should load correctly")
        end)

    end)
    return true
end
