local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Advanced & Complex Structures", function()
        h.test("json encode maps empty Lua tables consistently as objects", function()
            expect.eq(json.encode({}), "{}")
        end)

        h.test("json encode maps array indices with explicit nil values correctly", function()
            local encoded = json.encode({ 10, nil, 30 })
            expect.true_(string.find(encoded, "10", 1, true) ~= nil)
            expect.true_(string.find(encoded, "30", 1, true) ~= nil)
        end)

        h.test("json encode maps mixed indexed and mapped tables cleanly", function()
            local encoded = json.encode({ "scalar", map_key = "mapped_value" })
            expect.true_(string.find(encoded, '"map_key"', 1, true) ~= nil)
            expect.true_(string.find(encoded, "scalar", 1, true) ~= nil)
        end)

        h.test("json decode preserves unicode character stream mapping representations", function()
            local decoded = json.decode('{"character":"café"}')
            expect.eq(decoded.character, "café")
        end)

        h.test("json decode parses nested multi-level dictionary arrays precisely", function()
            local decoded = json.decode('{"node":{"child":{"depth":3}}}')
            expect.eq(decoded.node.child.depth, 3)
        end)
    end)
end
