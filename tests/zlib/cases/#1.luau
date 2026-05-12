local h = require("../../helpers")
local zlib = require("../../../luks-std/ZLib")

return function(expect)
    h.suite("ZLib Native Module Tests", function()
        h.test("zlib compress reduces size of repetitive string", function()
            local original = string.rep("luks zlib compression test string. ", 50)
            local compressed = zlib.compress(original)

            expect.type_(compressed, "string")
            expect.true_(#compressed < #original, "Compressed size should be strictly smaller than original")
        end)

        h.test("zlib decompress restores exact original string", function()
            local original = string.rep("luks zlib compression test string. ", 50)
            local compressed = zlib.compress(original, 9)
            local decompressed = zlib.decompress(compressed)

            expect.eq(decompressed, original, "Decompressed payload should exactly match original")
        end)

        h.test("zlib decompress errors gracefully on invalid payload", function()
            local success, err = pcall(zlib.decompress, "invalid non-zlib raw bytes lixo")
            expect.false_(success, "Decompressing junk should fail")
            expect.type_(err, "string")
            expect.true_(string.find(string.lower(err), "decompress", 1, true) ~= nil, "Error message should contain 'decompress' prefix")
        end)

        h.test("zlib compress and decompress handle empty string", function()
            local compressed = zlib.compress("")
            expect.type_(compressed, "string")
            local decompressed = zlib.decompress(compressed)
            expect.eq(decompressed, "", "Decompressed empty string should match original")
        end)

        h.test("zlib compress supports edge compression levels", function()
            local original = "testing levels"
            local c0 = zlib.compress(original, 0)
            local c1 = zlib.compress(original, 1)
            local c9 = zlib.compress(original, 9)

            expect.type_(c0, "string")
            expect.type_(c1, "string")
            expect.type_(c9, "string")
            expect.eq(zlib.decompress(c0), original)
            expect.eq(zlib.decompress(c1), original)
            expect.eq(zlib.decompress(c9), original)
        end)

        h.test("zlib methods error on missing or invalid arguments", function()
            -- compress missing arg
            local s1, e1 = pcall(zlib.compress :: any)
            expect.false_(s1)
            expect.type_(e1, "string")
            expect.true_(string.find(e1, "must be a string", 1, true) ~= nil, "Should report argument type failure")

            -- compress invalid arg type
            local s2, e2 = pcall(zlib.compress :: any, true)
            expect.false_(s2)
            expect.type_(e2, "string")
            expect.true_(string.find(e2, "must be a string", 1, true) ~= nil, "Should report invalid arg type")

            -- decompress missing arg
            local s3, e3 = pcall(zlib.decompress :: any)
            expect.false_(s3)
            expect.type_(e3, "string")
            expect.true_(string.find(e3, "must be a string", 1, true) ~= nil, "Should report argument type failure")
        end)
    end)
end
