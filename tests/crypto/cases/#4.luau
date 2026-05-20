local h = require("../../helpers")
local Crypto = require("../../../luks-std/Crypto")

return function(expect)
    h.suite("Crypto Binary Safety and Edge Cases", function()
        h.test("hash preserves data with null bytes", function()
            local data = "before\0after\0end"
            local md5_hex = Crypto.md5(data)
            local sha256_hex = Crypto.sha256(data)
            expect.eq(#md5_hex, 32)
            expect.eq(#sha256_hex, 64)

            local md5_raw = Crypto.md5(data, true)
            expect.eq(#md5_raw, 16)
        end)

        h.test("hmac with empty key", function()
            local result = Crypto.hmacSha256("", "some data")
            expect.eq(#result, 64)
        end)

        h.test("hmac with empty data", function()
            local result = Crypto.hmacSha256("key", "")
            expect.eq(#result, 64)
        end)

        h.test("aes-gcm with empty data", function()
            local key = string.rep("A", 16)
            local nonce = string.rep("N", 12)
            local ct = Crypto.encryptAesGcm(key, nonce, "")
            expect.true_(#ct > 0)
            local pt = Crypto.decryptAesGcm(key, nonce, ct)
            expect.eq(pt, "")
        end)

        h.test("aes-gcm with empty aad", function()
            local key = string.rep("A", 16)
            local nonce = string.rep("N", 12)
            local ct = Crypto.encryptAesGcm(key, nonce, "data", "")
            local pt = Crypto.decryptAesGcm(key, nonce, ct, "")
            expect.eq(pt, "data")
        end)

        h.test("aes-gcm with binary data containing null bytes", function()
            local key = string.rep("K", 16)
            local nonce = string.rep("N", 12)
            local plaintext = "bin\0ary\0data\0here"
            local ct = Crypto.encryptAesGcm(key, nonce, plaintext)
            local pt = Crypto.decryptAesGcm(key, nonce, ct)
            expect.eq(pt, plaintext)
        end)

        h.test("base64 and hex roundtrip binary data with null bytes", function()
            local data = "a\0b\0c\0d\0e"
            local hexEnc = Crypto.hex.encode(data)
            local hexDec = Crypto.hex.decode(hexEnc)
            expect.eq(hexDec, data)

            local b64Enc = Crypto.base64.encode(data)
            local b64Dec = Crypto.base64.decode(b64Enc)
            expect.eq(b64Dec, data)
        end)

        h.test("hex decode rejects odd length", function()
            local ok, err = pcall(Crypto.hex.decode, "ABC")
            expect.false_(ok)
        end)

        h.test("randomBytes with large size", function()
            local bytes = Crypto.randomBytes(4096)
            expect.eq(#bytes, 4096)
        end)

        h.test("truncated ciphertext is rejected", function()
            local key = string.rep("K", 16)
            local nonce = string.rep("N", 12)
            local ct = Crypto.encryptAesGcm(key, nonce, "some data")
            local ct_truncated = string.sub(ct, 1, #ct - 1)
            local ok, err = pcall(Crypto.decryptAesGcm, key, nonce, ct_truncated)
            expect.false_(ok)
        end)
    end)
end
