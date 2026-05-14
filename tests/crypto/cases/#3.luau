local h = require("../../helpers")
local Crypto = require("../../../luks-std/Crypto")

return function(expect)
    h.suite("Crypto Intensive Computational Stress", function()
        h.test("crypto rapid sequential hash derivations and HMAC stream iterations", function()
            local base_data = "Cryptographic execution evaluation core boundary loop testing block. "
            local iterations = 500

            for i = 1, iterations do
                local payload = base_data .. i
                local d_md5 = Crypto.md5(payload)
                local d_sha = Crypto.sha256(payload)
                local d_hmac = Crypto.hmacSha256("stress_key", payload)

                expect.eq(#d_md5, 32)
                expect.eq(#d_sha, 64)
                expect.eq(#d_hmac, 64)
            end
        end)
    end)
end
