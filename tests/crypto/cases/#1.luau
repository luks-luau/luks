local h = require("../../helpers")
local Crypto = require("../../../luks-std/Crypto")

return function(expect)
    h.suite("Crypto Native Module Tests", function()
        h.test("crypto computes standard deterministic hash digests", function()
            -- Test vectors for empty strings
            local md5Empty = Crypto.md5("")
            local sha256Empty = Crypto.sha256("")

            expect.eq(md5Empty, "d41d8cd98f00b204e9800998ecf8427e", "MD5 empty vector matches")
            expect.eq(sha256Empty, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA-256 empty vector matches")

            -- Hashing output format verification
            expect.type_(Crypto.sha1("test"), "string")
            expect.type_(Crypto.sha384("test"), "string")
            expect.type_(Crypto.sha512("test"), "string")
        end)

        h.test("crypto supports raw digest delivery bounds", function()
            local rawHash = Crypto.sha256("binary", true)
            expect.eq(#rawHash, 32, "Raw SHA-256 byte output length is precisely 32 bytes")
        end)

        h.test("crypto generates validated HMAC-SHA authentication streams", function()
            local key = "secret-key"
            local data = "authentication payload"

            local sig256 = Crypto.hmacSha256(key, data)
            local sig512 = Crypto.hmacSha512(key, data)

            expect.type_(sig256, "string")
            expect.type_(sig512, "string")
            expect.true_(#sig512 > #sig256, "HMAC-SHA512 stream size exceeds HMAC-SHA256")
        end)

        h.test("crypto executes perfect AES-GCM symmetric encryption roundtrips", function()
            local key = Crypto.randomBytes(32)   -- AES-256
            local nonce = Crypto.randomBytes(12) -- 96-bit standard nonce
            local plaintext = "Confidential standard library binary payload stream."

            local ciphertext = Crypto.encryptAesGcm(key, nonce, plaintext)
            expect.type_(ciphertext, "string")
            expect.true_(#ciphertext > #plaintext, "Ciphertext wraps trailing GCM authentication tags")

            local restored = Crypto.decryptAesGcm(key, nonce, ciphertext)
            expect.eq(restored, plaintext, "Symmetric expansion correctly restores authenticated buffer")
        end)

        h.test("crypto rejects tampered ciphertexts and unpadded symmetric boundaries", function()
            local key = Crypto.randomBytes(16)   -- AES-128
            local nonce = Crypto.randomBytes(12)
            local plaintext = "Secure payload stream."

            local ciphertext = Crypto.encryptAesGcm(key, nonce, plaintext)

            -- Tamper with the last byte (corrupting the authentication tag)
            local tampered = string.sub(ciphertext, 1, #ciphertext - 1) .. string.char(0xFF)
            local success, err = pcall(Crypto.decryptAesGcm, key, nonce, tampered)

            expect.false_(success, "Decryption boundary blocks tampered buffers")
            expect.type_(err, "string")
            expect.true_(string.find(err, "authentication failed", 1, true) ~= nil, "Reports auth fault")

            -- Test invalid key lengths
            local sKey, eKey = pcall(Crypto.encryptAesGcm, "short-key", nonce, plaintext)
            expect.false_(sKey)
            expect.true_(string.find(eKey, "exactly 16 bytes", 1, true) ~= nil, "Enforces key size limits")
        end)

        h.test("crypto translation namespaces roundtrip string transformations", function()
            local buffer = "Luau runtime binary translations mapping engine."

            -- Hex namespace validation
            local hexStr = Crypto.hex.encode(buffer)
            expect.type_(hexStr, "string")
            expect.eq(Crypto.hex.decode(hexStr), buffer, "Hex decode restores byte buffer")

            -- Base64 namespace validation
            local b64Str = Crypto.base64.encode(buffer)
            expect.type_(b64Str, "string")
            expect.eq(Crypto.base64.decode(b64Str), buffer, "Base64 decode restores byte buffer")
        end)

        h.test("crypto translation decoders error gracefully on invalid structures", function()
            local sHex, eHex = pcall(Crypto.hex.decode, "invalid-hex-chars-!!")
            expect.false_(sHex)
            expect.true_(string.find(eHex, "invalid hex string", 1, true) ~= nil)

            local sB64, eB64 = pcall(Crypto.base64.decode, "invalid-base64-chars-@@")
            expect.false_(sB64)
            expect.true_(string.find(eB64, "invalid base64 string", 1, true) ~= nil)
        end)
    end)
end
