local h = require("../../helpers")
local Crypto = require("../../../luks-std/Crypto")

return function(expect)
    h.suite("Crypto Version & Randomness", function()
        h.test("crypto exposes native cryptographic revision string", function()
            expect.type_(Crypto.version, "string")
            expect.true_(#Crypto.version > 0)
        end)

        h.test("crypto randomBytes generates correct sequence arrays", function()
            expect.eq(Crypto.randomBytes(0), "")
            local rng = Crypto.randomBytes(16)
            expect.eq(#rng, 16)
        end)
    end)

    h.suite("Crypto Hash Algorithms", function()
        h.test("crypto md5 computes standard deterministic vectors", function()
            expect.eq(Crypto.md5(""), "d41d8cd98f00b204e9800998ecf8427e")
            expect.eq(#Crypto.md5("data", true), 16)
        end)

        h.test("crypto sha1 computes standard deterministic vectors", function()
            expect.eq(#Crypto.sha1(""), 40)
            expect.eq(#Crypto.sha1("data", true), 20)
        end)

        h.test("crypto sha256 computes standard deterministic vectors", function()
            expect.eq(Crypto.sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            expect.eq(#Crypto.sha256("data", true), 32)
        end)

        h.test("crypto sha384 computes standard deterministic vectors", function()
            expect.eq(#Crypto.sha384(""), 96)
            expect.eq(#Crypto.sha384("data", true), 48)
        end)

        h.test("crypto sha512 computes standard deterministic vectors", function()
            expect.eq(#Crypto.sha512(""), 128)
            expect.eq(#Crypto.sha512("data", true), 64)
        end)
    end)

    h.suite("Crypto HMAC Authentication", function()
        local key = "luks-hmac-secret-signature-key"
        local payload = "luks protected data pipeline buffer stream"

        h.test("crypto hmacSha256 evaluates streams correctly", function()
            local res = Crypto.hmacSha256(key, payload)
            expect.eq(#res, 64)
            expect.eq(#Crypto.hmacSha256(key, payload, true), 32)
        end)

        h.test("crypto hmacSha512 evaluates streams correctly", function()
            local res = Crypto.hmacSha512(key, payload)
            expect.eq(#res, 128)
            expect.eq(#Crypto.hmacSha512(key, payload, true), 64)
        end)
    end)

    h.suite("Crypto Translation Namespaces", function()
        local source = "Luau base memory frame representation mapping."

        h.test("crypto hex encode and decode roundtrip correctly", function()
            local encoded = Crypto.hex.encode(source)
            expect.type_(encoded, "string")
            expect.eq(Crypto.hex.decode(encoded), source)
        end)

        h.test("crypto base64 encode and decode roundtrip correctly", function()
            local encoded = Crypto.base64.encode(source)
            expect.type_(encoded, "string")
            expect.eq(Crypto.base64.decode(encoded), source)
        end)

        h.test("crypto hex decode rejects invalid characters", function()
            local ok, err = pcall(Crypto.hex.decode, "invalid-hex-chars-!!")
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("crypto base64 decode rejects invalid characters", function()
            local ok, err = pcall(Crypto.base64.decode, "invalid-base64-chars-@@")
            expect.false_(ok)
            expect.type_(err, "string")
        end)
    end)
end
