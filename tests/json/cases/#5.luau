local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Null Byte Handling", function()
        h.test("json encode preserves null bytes in strings", function()
            local original = "before\0after"
            local encoded = json.encode(original)
            local decoded = json.decode(encoded)
            expect.eq(decoded, original)
        end)

        h.test("json decode handles escaped null bytes (\\u0000)", function()
            local decoded = json.decode('"before\\u0000after"')
            expect.eq(decoded, "before\0after")
        end)

        h.test("json encode/decode round-trips strings with multiple null bytes", function()
            local original = "a\0b\0c\0d"
            local encoded = json.encode(original)
            local decoded = json.decode(encoded)
            expect.eq(decoded, original)
        end)

        h.test("json encode preserves null bytes in table values", function()
            local t = { name = "test\0value", data = "normal" }
            local encoded = json.encode(t)
            local decoded = json.decode(encoded)
            expect.eq(decoded.name, t.name)
            expect.eq(decoded.data, t.data)
        end)

        h.test("json encode preserves null bytes in table keys", function()
            local t = { ["key\0name"] = "value" }
            local encoded = json.encode(t)
            local decoded = json.decode(encoded)
            expect.eq(decoded["key\0name"], "value")
        end)

        h.test("json decode preserves null bytes in nested structures", function()
            local input = '{"outer":{"inner":"mid\\u0000dle"}}'
            local decoded = json.decode(input)
            expect.eq(decoded.outer.inner, "mid\0dle")
        end)
    end)
end
