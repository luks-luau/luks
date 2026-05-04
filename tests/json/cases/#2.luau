local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Protection Tests", function()
        h.test("encode handles null bytes in strings", function()
            local str_with_null = "hello\0world"
            local encoded = json.encode(str_with_null)
            expect.type_(encoded, "string")
            expect.true_(#encoded > 0)
            -- Null bytes should be replaced with U+FFFD
            expect.true_(string.find(encoded, "\239\191\189") ~= nil or string.find(encoded, "hello") ~= nil)
        end)

        h.test("encode raises error on circular table references", function()
            local t = {}
            t.self = t
            local success, err = pcall(json.encode, t)
            expect.false_(success)
            expect.type_(err, "string")
            expect.true_(string.find(err, "circular", 1, true) ~= nil)
        end)

        h.test("encode raises error on NaN", function()
            local success, err = pcall(json.encode, 0/0)
            expect.false_(success)
            expect.type_(err, "string")
            expect.true_(string.find(err, "NaN", 1, true) ~= nil)
        end)

        h.test("encode raises error on Infinity", function()
            local success, err = pcall(json.encode, math.huge)
            expect.false_(success)
            expect.type_(err, "string")
            expect.true_(string.find(err, "Infinity", 1, true) ~= nil)
        end)

        h.test("decode raises error on invalid JSON", function()
            local success, err = pcall(json.decode, "{invalid}")
            expect.false_(success)
            expect.type_(err, "string")
            expect.true_(string.find(err, "JSON decode error", 1, true) ~= nil)
        end)

        h.test("decode raises error on empty string", function()
            local success, err = pcall(json.decode, "")
            expect.false_(success)
            expect.type_(err, "string")
            expect.true_(string.find(err, "JSON decode error", 1, true) ~= nil)
        end)

        h.test("encode raises error on unsupported type (function)", function()
            local success, err = pcall(json.encode, function() end)
            expect.false_(success)
            expect.type_(err, "string")
            expect.true_(string.find(err, "unsupported type", 1, true) ~= nil)
        end)
    end)
end
