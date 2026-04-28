-- Test #1: Dlopen Object Passing and Caching
-- Tests passing dlopen-loaded objects between modules

local h = require("../../helpers")

local function load_testmodule(expect)
    local ok, result = pcall(function()
        return dlopen("@self/../../../target/release/testmodule")
    end)

    expect.true_(ok, "dlopen should not raise for testmodule")
    expect.not_nil(result, "dlopen should return module table")

    return result
end

return function(expect)
    h.suite("Dlopen Object Passing Tests", function()

        h.test("dlopen returns valid module object", function()
            local mymod = load_testmodule(expect)

            expect.not_nil(mymod, "dlopen should return a module")
            expect.type_(mymod, "table", "module should be a table")
        end)

        h.test("module has expected exports", function()
            local mymod = load_testmodule(expect)

            expect.not_nil(mymod.version, "module should export version")
            expect.type_(mymod.hello, "function", "module should export hello function")
        end)

        h.test("hello function returns string", function()
            local mymod = load_testmodule(expect)
            local result = mymod.hello()

            expect.type_(result, "string", "hello() should return a string")
        end)

        h.test("can pass dlopen object to another module", function()
            local mymod = load_testmodule(expect)
            expect.not_nil(mymod, "dlopen should return module")
            expect.eq(mymod.version, "1.0.0", "module should have correct version")

            -- Store locally to verify it can be passed
            local stored = mymod
            expect.not_nil(stored, "stored object should exist")
            expect.eq(stored.version, "1.0.0", "stored object should have same version")
        end)

        h.test("can call methods on passed object", function()
            local mymod = load_testmodule(expect)
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

        h.test("dlopen invalid argument raises luau error (pcall)", function()
            local ok, err = pcall(function()
                dlopen(123)
            end)

            expect.false_(ok, "pcall should capture dlopen argument error")
            expect.not_nil(err, "pcall should return an error value")
        end)

        h.test("dlopen missing library raises luau error (pcall)", function()
            local ok, err = pcall(function()
                dlopen("@self/../../../target/release/module_that_does_not_exist")
            end)

            expect.false_(ok, "pcall should capture dlopen load failure")
            expect.not_nil(err, "pcall should return an error value")
        end)

    end)

    return true
end
