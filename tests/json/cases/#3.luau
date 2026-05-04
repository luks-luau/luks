local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Edge Case Tests", function()
        h.test("encode empty table as object", function()
            local empty = {}
            local encoded = json.encode(empty)
            expect.eq(encoded, "{}")
        end)

        h.test("encode array with nil values", function()
            local arr = {1, nil, 3}
            local encoded = json.encode(arr)
            -- nil should become null in JSON
            expect.true_(string.find(encoded, "1", 1, true) ~= nil)
            expect.true_(string.find(encoded, "null", 1, true) ~= nil)
            expect.true_(string.find(encoded, "3", 1, true) ~= nil)
        end)

        h.test("decode unicode strings", function()
            local json_str = '{"name":"café"}'
            local decoded = json.decode(json_str)
            expect.eq(decoded.name, "café")
        end)

        h.test("round trip special characters", function()
            local str = 'hello "world" \\ test'
            local encoded = json.encode(str)
            local decoded = json.decode(encoded)
            expect.eq(decoded, str)
        end)

        h.test("encode mixed key table becomes object", function()
            local mixed = { "array_item", key = "value", 2 }
            local encoded = json.encode(mixed)
            -- Mixed keys should make it an object
            expect.true_(string.find(encoded, '"key"', 1, true) ~= nil)
            expect.true_(string.find(encoded, '"1"', 1, true) ~= nil)
        end)

        h.test("decode nested structure", function()
            local json_str = '{"a":{"b":{"c":1}}}'
            local decoded = json.decode(json_str)
            expect.eq(decoded.a.b.c, 1)
        end)
    end)
end
