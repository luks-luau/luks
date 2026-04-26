-- Test #2: @self semantics for dlopen
-- Ensures @self uses the caller chunk directory:
-- - regular file module
-- - package init.luau module

local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen @self Semantics", function()
        h.test("@self in file module resolves to module directory", function()
            local mod = require("./self/file_module")
            expect.not_nil(mod.native, "native module should load")
            expect.eq(mod.native.version, "1.0.0", "version should match")
            expect.eq(mod.native.hello(), "Greetings from Rust!", "hello() should work")
        end)

        h.test("@self in init module resolves to package directory", function()
            local pkg = require("./self/pkg")
            expect.not_nil(pkg.native, "native module should load")
            expect.eq(pkg.native.version, "1.0.0", "version should match")
            expect.eq(pkg.native.hello(), "Greetings from Rust!", "hello() should work")
        end)
    end)

    return true
end
