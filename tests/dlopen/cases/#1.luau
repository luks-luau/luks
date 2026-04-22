-- Test #1: Dlopen Object Passing and Caching
-- Tests passing dlopen-loaded objects between modules

local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen Object Passing Tests", function()

        h.test("dlopen returns valid module object", function()
            local mymod = dlopen("@self/../../target/release/testmodule")

            expect.not_nil(mymod, "dlopen should return a module")
            expect.type_(mymod, "table", "module should be a table")
        end)

        h.test("module has expected exports", function()
            local mymod = dlopen("@self/../../target/release/testmodule")

            expect.not_nil(mymod.version, "module should export version")
            expect.type_(mymod.hello, "function", "module should export hello function")
        end)

        h.test("hello function returns string", function()
            local mymod = dlopen("@self/../../target/release/testmodule")
            local result = mymod.hello()

            expect.type_(result, "string", "hello() should return a string")
        end)

        h.test("can pass dlopen object to another module", function()
            local mymod = dlopen("@self/../../target/release/testmodule")
            expect.not_nil(mymod, "dlopen should return module")
            expect.eq(mymod.version, "1.0.0", "module should have correct version")

            -- Store locally to verify it can be passed
            local stored = mymod
            expect.not_nil(stored, "stored object should exist")
            expect.eq(stored.version, "1.0.0", "stored object should have same version")
        end)

        h.test("can call methods on passed object", function()
            local mymod = dlopen("@self/../../target/release/testmodule")
            expect.not_nil(mymod.hello, "hello function should exist")

            local result = mymod.hello()
            expect.type_(result, "string", "hello() should return string")
            expect.eq(result, "Greetings from Rust!", "hello() should return expected value")

            -- Test passing object to local function
            local function call_on_obj(obj)
                return obj.hello()
            end
            local passed_result = call_on_obj(mymod)
            expect.eq(passed_result, "Greetings from Rust!", "method should work on passed object")
        end)

    end)

    return true
end
