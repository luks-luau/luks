local h = require("../../helpers")
local Crypto = require("../../../luks-std/Crypto")

return function(expect)
    h.suite("Crypto Advanced Integration Constraints", function()
        h.test("crypto validates exact hexadecimal string mapping lengths", function()
            local payload = "mathematical boundary consistency verification"

            expect.eq(#Crypto.md5(payload), 32, "MD5 produces 32 hexadecimal chars")
            expect.eq(#Crypto.sha1(payload), 40, "SHA-1 produces 40 hexadecimal chars")
            expect.eq(#Crypto.sha256(payload), 64, "SHA-256 produces 64 hexadecimal chars")
            expect.eq(#Crypto.sha384(payload), 96, "SHA-384 produces 96 hexadecimal chars")
            expect.eq(#Crypto.sha512(payload), 128, "SHA-512 produces 128 hexadecimal chars")
        end)

        h.test("crypto computes deterministic byte output limits for HMAC raw modes", function()
            local key = "deterministic-key"
            local data = "payload data block stream"

            local raw256 = Crypto.hmacSha256(key, data, true)
            local raw512 = Crypto.hmacSha512(key, data, true)

            expect.eq(#raw256, 32, "Raw HMAC-SHA256 returns exactly 32 bytes")
            expect.eq(#raw512, 64, "Raw HMAC-SHA512 returns exactly 64 bytes")
        end)

        h.test("crypto authenticated symmetric layers enforce strict AAD containment", function()
            local key = Crypto.randomBytes(32)
            local nonce = Crypto.randomBytes(12)
            local plaintext = "Data secured with additional context block metadata."
            local validAad = "Context metadata version 1.0"
            local invalidAad = "Context metadata version 2.0"

            -- Encrypt stream using valid AAD context mapping
            local ciphertext = Crypto.encryptAesGcm(key, nonce, plaintext, validAad)

            -- Successful restoration matching exact AAD context
            local restored = Crypto.decryptAesGcm(key, nonce, ciphertext, validAad)
            expect.eq(restored, plaintext, "Successfully decodes passing correct target AAD")

            -- Strict failure intercepting mismatched AAD strings
            local success, err = pcall(Crypto.decryptAesGcm, key, nonce, ciphertext, invalidAad)
            expect.false_(success, "Decryption boundary explicitly blocks mismatched AAD parameters")
            expect.true_(string.find(err, "authentication failed", 1, true) ~= nil)
        end)

        h.test("crypto secure randomness limits handles zero requests safely", function()
            local emptyRng = Crypto.randomBytes(0)
            expect.eq(emptyRng, "", "Returns empty strings when zero bytes are requested")

            local tinyRng = Crypto.randomBytes(5)
            expect.eq(#tinyRng, 5, "Fills precise array buffer byte lengths")
        end)

        h.test("crypto runtime execution wrappers validate argument type limits", function()
            -- Passing invalid parameter types to MD5
            local sMd5, eMd5 = pcall(Crypto.md5, nil :: any)
            expect.false_(sMd5)
            expect.true_(string.find(eMd5, "must be a string", 1, true) ~= nil or string.find(eMd5, "expected argument", 1, true) ~= nil)

            -- Passing incorrect keys to AES-GCM
            local sAes, eAes = pcall(Crypto.encryptAesGcm, "invalid-key-len", "123456789012", "data")
            expect.false_(sAes)
            expect.true_(string.find(eAes, "exactly 16 bytes", 1, true) ~= nil)
        end)
    end)
end
