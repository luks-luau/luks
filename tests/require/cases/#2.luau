-- Test #2: Require Cache Tests
-- Tests module caching behavior

local h = require("../../helpers")

return function(expect)
    h.suite("Require Cache Tests", function()

        h.test("require returns same table reference", function()
            local mod1 = require("./subdir/mod")
            local mod2 = require("./subdir/mod")
            expect.same_ref(mod1, mod2, "Same module should return same reference")
        end)

        h.test("require returns same reference for nested requires", function()
            local mod = require("./subdir/mod")
            local helper = require("./subdir/helper")
            expect.same_ref(mod.util, helper, "Nested require should return cached reference")
        end)

        h.test("mutations persist in cached module", function()
            local mod = require("./subdir/mod")
            local original = mod.counter
            mod.counter = mod.counter + 1
            local mod2 = require("./subdir/mod")
            expect.eq(mod2.counter, original + 1, "Mutations should persist in cache")
        end)

        h.test("cache survives multiple requires in same scope", function()
            local a = require("./subdir/mod")
            local b = require("./subdir/mod")
            local c = require("./subdir/mod")
            expect.same_ref(a, b, "All references should be identical")
            expect.same_ref(b, c, "All references should be identical")
        end)

    end)

    return true
end
