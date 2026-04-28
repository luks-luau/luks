-- Test #2: @self semantics for dlopen
-- Ensures @self uses the caller chunk directory:
-- - regular file module
-- - package init.luau module

local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen @self Semantics", function()
        h.test("@self in file module resolves to module directory", function()
            local ok, mod_or_err = pcall(function()
                return require("./self/file_module")
            end)
            expect.true_(ok, "require should not raise for file module")
            local mod = mod_or_err

            expect.true_(mod.load_ok, "dlopen should succeed in file module")
            expect.not_nil(mod.native, "native module should load")
            expect.eq(mod.native.version, "1.0.0", "version should match")
            expect.eq(mod.native.hello(), "Greetings from Rust!", "hello() should work")
        end)

        h.test("@self in init module resolves to package directory", function()
            local ok, pkg_or_err = pcall(function()
                return require("./self/pkg")
            end)
            expect.true_(ok, "require should not raise for package module")
            local pkg = pkg_or_err

            expect.true_(pkg.load_ok, "dlopen should succeed in init module")
            expect.not_nil(pkg.native, "native module should load")
            expect.eq(pkg.native.version, "1.0.0", "version should match")
            expect.eq(pkg.native.hello(), "Greetings from Rust!", "hello() should work")
        end)
    end)

    return true
end
