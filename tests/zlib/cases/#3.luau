local h = require("../../helpers")
local zlib = require("../../../luks-std/ZLib")

return function(expect)
    h.suite("ZLib Binary Safety and Edge Cases", function()
        h.test("compress and decompress data with null bytes", function()
            local data = "before\0mid\0after\0end"
            local compressed = zlib.compress(data)
            expect.true_(#compressed > 0)
            local decompressed = zlib.decompress(compressed)
            expect.eq(decompressed, data)
        end)

        h.test("compress with default level (nil)", function()
            local data = "test data for default compression level"
            local compressed = zlib.compress(data)
            expect.true_(#compressed > 0)
            local decompressed = zlib.decompress(compressed)
            expect.eq(decompressed, data)
        end)

        h.test("compress level 0 preserves data exactly roundtrip", function()
            local data = string.rep("Hello World! ", 100)
            local compressed = zlib.compress(data, 0)
            expect.eq(zlib.decompress(compressed), data)
        end)

        h.test("very large data compresses and decompresses", function()
            local data = string.rep("Large payload data block for compression testing. ", 20000)
            local compressed = zlib.compress(data, 6)
            expect.true_(#compressed < #data)
            local decompressed = zlib.decompress(compressed)
            expect.eq(decompressed, data)
        end)

        h.test("compress with all valid levels 0-9", function()
            local data = "Level test data with some repetition " .. string.rep("x", 100)
            for level = 0, 9 do
                local compressed = zlib.compress(data, level)
                local decompressed = zlib.decompress(compressed)
                expect.eq(decompressed, data)
            end
        end)

        h.test("decompress random garbage returns error", function()
            local ok, err = pcall(zlib.decompress, string.rep("x", 100))
            expect.false_(ok)
        end)
    end)
end
