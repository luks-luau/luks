local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("CLI Infinite Vararg Forwarding Integration", function()
        h.test("cli runtime propagates infinite command line tails to script varargs", function()
            local exe = if Process.os() == "windows" then "target\\release\\lukscli.exe" else "./target/release/lukscli"
            local script = "tests/process/cases/vararg_target.luau"

            -- Disparando via spawn nativo garantindo integridade e isolamento posicional de cada string posicional
            local res = Process.spawn(exe, { script, "alpha", "beta", "--gamma", "-delta", "12345" })

            expect.true_(res.ok, "Evaluates varargs. STDERR=[" .. res.stderr .. "] ERR=[" .. (res.error or "nil") .. "]")
            expect.true_(string.find(res.stdout, "VARARG_COUNT=5", 1, true) ~= nil, "Validates perfect allocation count of varargs")
            expect.true_(string.find(res.stdout, "ARG_1=alpha", 1, true) ~= nil)
            expect.true_(string.find(res.stdout, "ARG_3=--gamma", 1, true) ~= nil)
            expect.true_(string.find(res.stdout, "ARG_4=-delta", 1, true) ~= nil)
            expect.true_(string.find(res.stdout, "ARG_5=12345", 1, true) ~= nil)
        end)
    end)
end
