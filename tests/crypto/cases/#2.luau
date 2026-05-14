local h = require("../../helpers")
local Crypto = require("../../../luks-std/Crypto")

return function(expect)
    h.suite("Crypto Symmetric AES-GCM Processing", function()
        local k128 = Crypto.randomBytes(16)
        local k256 = Crypto.randomBytes(32)
        local nonce = Crypto.randomBytes(12)
        local plaintext = "Confidential application internal payload block."
        local context = "Transaction revision metadata v1.0"

        h.test("crypto encryptAesGcm and decryptAesGcm roundtrip securely under AES-128", function()
            local ciphertext = Crypto.encryptAesGcm(k128, nonce, plaintext)
            expect.true_(#ciphertext > #plaintext)
            expect.eq(Crypto.decryptAesGcm(k128, nonce, ciphertext), plaintext)
        end)

        h.test("crypto encryptAesGcm and decryptAesGcm roundtrip securely under AES-256", function()
            local ciphertext = Crypto.encryptAesGcm(k256, nonce, plaintext)
            expect.true_(#ciphertext > #plaintext)
            expect.eq(Crypto.decryptAesGcm(k256, nonce, ciphertext), plaintext)
        end)

        h.test("crypto authenticated layer enforces strict AAD containment strings", function()
            local ciphertext = Crypto.encryptAesGcm(k256, nonce, plaintext, context)
            expect.eq(Crypto.decryptAesGcm(k256, nonce, ciphertext, context), plaintext)

            -- Mismatched AAD
            local ok, err = pcall(Crypto.decryptAesGcm, k256, nonce, ciphertext, "Tampered context string")
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("crypto decryptAesGcm strictly blocks tampered ciphertext authentication tags", function()
            local ciphertext = Crypto.encryptAesGcm(k128, nonce, plaintext)
            local tampered = string.sub(ciphertext, 1, #ciphertext - 1) .. string.char(0x00)
            
            local ok, err = pcall(Crypto.decryptAesGcm, k128, nonce, tampered)
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("crypto symmetric boundary validates explicit key lengths", function()
            local ok, err = pcall(Crypto.encryptAesGcm, "invalid_length_key", nonce, plaintext)
            expect.false_(ok)
            expect.type_(err, "string")
        end)
    end)
end
