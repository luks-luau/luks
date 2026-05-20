local h = require("../../helpers")
local Json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Unicode and Edge Cases", function()
        h.test("encode and decode unicode text: accents, CJK, emoji", function()
            local crab = string.char(0xF0, 0x9F, 0xA6, 0x80)   -- U+1F980
            local car  = string.char(0xF0, 0x9F, 0x9A, 0x99)   -- U+1F699
            local bana = string.char(0xF0, 0x9F, 0x8D, 0x8C)   -- U+1F34C
            local glob = string.char(0xF0, 0x9F, 0x8C, 0x8D)   -- U+1F30D globe
            local cjk  = string.char(0xE4, 0xB8, 0xAD, 0xE6, 0x96, 0x87, 0xE6, 0x97, 0xA5, 0xE6, 0x9C, 0xAC, 0xE8, 0xAA, 0x9E) -- 中文日本語
            local acc  = "caf\xC3\xA9 r\xC3\xA9sum\xC3\xA9 pi\xC3\xB1ata"
            local data = {
                accents = acc,
                cjk = cjk,
                emoji = crab .. car .. bana .. "\xE2\x9C\xA8",
                mixed = "Hello, \xE4\xB8\x96\xE7\x95\x8C! " .. glob,
            }
            local encoded = Json.encode(data)
            local decoded = Json.decode(encoded)
            expect.eq(decoded.accents, data.accents)
            expect.eq(decoded.cjk, data.cjk)
            expect.eq(decoded.emoji, data.emoji)
            expect.eq(decoded.mixed, data.mixed)
        end)

        h.test("decode handles surrogate pairs in escaped form", function()
            local json = '"\\uD83C\\uDF4C"'
            local decoded = Json.decode(json)
            -- \uD83C\uDF4C surrogate pair = U+1F34C banana emoji
            local banana = string.char(0xF0, 0x9F, 0x8D, 0x8C)
            expect.eq(decoded, banana)
        end)

        h.test("decode ignores trailing whitespace", function()
            local decoded = Json.decode('  \t\n  {"key": 42}  \n  ')
            expect.type_(decoded, "table")
            expect.eq(decoded.key, 42)
        end)

        h.test("encode large integer loses precision gracefully", function()
            local large = 9007199254740993
            local encoded = Json.encode(large)
            local decoded = Json.decode(encoded)
            expect.type_(decoded, "number")
        end)

        h.test("encode negative zero produces zero", function()
            local encoded = Json.encode(-0.0)
            expect.eq(encoded, "0")
        end)

        h.test("encode table with __tostring metamethod", function()
            local mt = { __tostring = function() return "custom" end }
            local t = setmetatable({}, mt)
            local ok, err = pcall(Json.encode, t)
            -- Either encodes as {} or errors with clear message
            if ok then
                expect.eq(err, "{}")
            else
                expect.type_(err, "string")
            end
        end)

        h.test("decode empty object and array", function()
            local obj = Json.decode("{}")
            expect.type_(obj, "table")
            expect.eq(#obj, 0)

            local arr = Json.decode("[]")
            expect.type_(arr, "table")
            expect.eq(#arr, 0)
        end)

        h.test("decode special numeric values: negative zero, exponents", function()
            local neg = Json.decode("-0.0")
            expect.type_(neg, "number")

            local exp = Json.decode("1.5e10")
            expect.eq(exp, 15000000000)

            local small = Json.decode("3.14e-10")
            expect.type_(small, "number")
        end)

        h.test("encode table with both string keys and array indices", function()
            local t = { "first", "second", named = "value", num = 42 }
            local encoded = Json.encode(t)
            local decoded = Json.decode(encoded)
            -- mixed tables are encoded as objects with stringified numeric keys
            expect.eq(decoded["1"], "first")
            expect.eq(decoded["2"], "second")
            expect.eq(decoded.named, "value")
            expect.eq(decoded.num, 42)
        end)
    end)
end
