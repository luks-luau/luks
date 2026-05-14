local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Deep Structure Stress", function()
        h.test("json continuous intensive nested dictionary serialization cycling", function()
            local iterations = 500

            for i = 1, iterations do
                local root = { id = i, items = {} }
                for idx = 1, 50 do
                    table.insert(root.items, { level = idx, payload = "JSON_STRESS_BUFFER_PAYLOAD_" .. idx })
                end

                local encoded = json.encode(root)
                expect.true_(#encoded > 0)

                local decoded = json.decode(encoded)
                expect.eq(decoded.id, i)
                expect.not_nil(decoded.items[1])
                expect.eq(decoded.items[1].level, 1)
            end
        end)
    end)
end
