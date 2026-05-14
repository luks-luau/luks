local h = require("../../helpers")
local zlib = require("../../../luks-std/ZLib")

return function(expect)
    h.suite("ZLib Iterative Stress", function()
        h.test("zlib massive continuous payload stream roundtrip cycling", function()
            local base_chunk = string.rep("Stress execution streaming buffer blocks for compression layer verification. ", 10)
            local iterations = 500

            for i = 1, iterations do
                -- append dynamic content to prevent trivial caching
                local dynamic_payload = base_chunk .. "ITERATION_" .. i
                local compressed = zlib.compress(dynamic_payload, (i % 9) + 1)
                
                expect.true_(#compressed > 0)
                local decompressed = zlib.decompress(compressed)
                expect.eq(decompressed, dynamic_payload)
            end
        end)
    end)
end
