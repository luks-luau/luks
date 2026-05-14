local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Properties & Primitives", function()

        h.test("json encode and decode map string literals correctly", function()
            local encoded = json.encode("string_value")
            expect.eq(encoded, '"string_value"')
            expect.eq(json.decode(encoded), "string_value")
        end)

        h.test("json encode and decode map numeric values correctly", function()
            local encoded = json.encode(12345.67)
            expect.eq(encoded, "12345.67")
            expect.eq(json.decode(encoded), 12345.67)
        end)

        h.test("json encode and decode map boolean values correctly", function()
            expect.eq(json.encode(true), "true")
            expect.eq(json.decode("false"), false)
        end)
    end)

    h.suite("JSON Standard Objects", function()
        h.test("json encode serializes multiple map fields cleanly", function()
            local encoded = json.encode({ status = "ok", count = 10 })
            expect.true_(string.find(encoded, '"status":"ok"', 1, true) ~= nil)
            expect.true_(string.find(encoded, '"count":10', 1, true) ~= nil)
        end)

        h.test("json decode parses standard flat objects successfully", function()
            local decoded = json.decode('{"status":"ok","count":10}')
            expect.type_(decoded, "table")
            expect.eq(decoded.status, "ok")
            expect.eq(decoded.count, 10)
        end)
    end)
end
