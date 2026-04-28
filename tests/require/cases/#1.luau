-- Test #1: Basic Require Tests
-- Tests basic require functionality

local h = require("../../helpers")

return function(expect)
    h.suite("Basic Require Tests", function()

        h.test("require loads module with functions", function()
            local mod = require("./subdir/mod")
            expect.not_nil(mod, "Module should load")
            expect.type_(mod.add, "function", "add should be a function")
            expect.type_(mod.greet, "function", "greet should be a function")
        end)

        h.test("module function works correctly", function()
            local mod = require("./subdir/mod")
            local result = mod.add(2, 3)
            expect.eq(result, 5, "add(2, 3) should return 5")
            local greeting = mod.greet("World")
            expect.eq(greeting, "Hello, World!", "greet should work")
        end)

        h.test("require loads nested dependencies", function()
            local mod = require("./subdir/mod")
            expect.not_nil(mod.util, "Nested dependency should be accessible")
            expect.type_(mod.util.add, "function", "util.add should be a function")
        end)

        h.test("nested dependency is accessible", function()
            local mod = require("./subdir/mod")
            local result = mod.util.add(10, 5)
            expect.eq(result, 15, "util.add should work")
        end)

        h.test("require with bare name works", function()
            local mod = require("subdir/mod")
            expect.not_nil(mod, "Bare name require should work")
            expect.type_(mod.add, "function", "Function should be accessible")
        end)

        h.test("require missing module raises luau error (pcall)", function()
            local ok, err = pcall(function()
                return require("./subdir/module_that_does_not_exist")
            end)

            expect.false_(ok, "pcall should capture require missing-module error")
            expect.not_nil(err, "pcall should return an error value")
            expect.type_(tostring(err), "string", "pcall error should be printable")
        end)

        h.test("require syntax error raises luau error (pcall)", function()
            local ok, err = pcall(function()
                return require("./subdir/bad_syntax")
            end)

            expect.false_(ok, "pcall should capture require syntax error")
            expect.not_nil(err, "pcall should return an error value")
            expect.type_(tostring(err), "string", "pcall error should be printable")
        end)

    end)

    return true
end
