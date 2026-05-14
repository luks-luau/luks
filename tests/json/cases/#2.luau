local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Serialization Protection Limits", function()
        h.test("json encode gracefully replaces null bytes inside strings", function()
            local encoded = json.encode("base\0string")
            expect.true_(string.find(encoded, "base") ~= nil)
        end)

        h.test("json encode intercepts and rejects circular table structures", function()
            local t = {}
            t.circle = t
            local ok, err = pcall(json.encode, t)
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("json encode rejects NaN float mappings", function()
            local ok, err = pcall(json.encode, 0 / 0)
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("json encode rejects infinite float bounds", function()
            local ok, err = pcall(json.encode, math.huge)
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("json encode blocks attempts serializing opaque function types", function()
            local ok, err = pcall(json.encode, function() end)
            expect.false_(ok)
            expect.type_(err, "string")
        end)
    end)

    h.suite("JSON Deserialization Boundary Failures", function()
        h.test("json decode intercepts syntax errors on malformed payloads", function()
            local ok, err = pcall(json.decode, "{ malformed_key: }")
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("json decode raises explicit exception on empty input strings", function()
            local ok, err = pcall(json.decode, "")
            expect.false_(ok)
            expect.type_(err, "string")
        end)
    end)
end
