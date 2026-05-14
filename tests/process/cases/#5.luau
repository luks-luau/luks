local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("CLI Infinite Vararg Forwarding Integration", function()
        h.test("cli runtime propagates infinite command line tails to script varargs", function()
            local FileSystem = require("../../../luks-std/FileSystem")
            local exe = "luks"
            if FileSystem.exists("../../../target/release/lukscli.exe") then
                exe = "../../../target/release/lukscli.exe"
            elseif FileSystem.exists("../../../target/debug/lukscli.exe") then
                exe = "../../../target/debug/lukscli.exe"
            elseif FileSystem.exists("../../../target/release/lukscli") then
                exe = "../../../target/release/lukscli"
            elseif FileSystem.exists("../../../target/debug/lukscli") then
                exe = "../../../target/debug/lukscli"
            end
            local script = "./vararg_target.luau"

            -- Disparando via spawn nativo garantindo integridade e isolamento posicional de cada string posicional
            local res = Process.spawn(exe, { script, "alpha", "beta", "--gamma", "-delta", "12345" }, { cwd = "." })
            if not res.ok then
                task.wait(0.2)
                res = Process.spawn(exe, { script, "alpha", "beta", "--gamma", "-delta", "12345" }, { cwd = "." })
            end

            expect.true_(res.ok, "Evaluates varargs. STDERR=[" .. res.stderr .. "] ERR=[" .. (res.error or "nil") .. "]")
            expect.true_(string.find(res.stdout, "VARARG_COUNT=5", 1, true) ~= nil, "Validates perfect allocation count of varargs")
            expect.true_(string.find(res.stdout, "ARG_1=alpha", 1, true) ~= nil)
            expect.true_(string.find(res.stdout, "ARG_3=--gamma", 1, true) ~= nil)
            expect.true_(string.find(res.stdout, "ARG_4=-delta", 1, true) ~= nil)
            expect.true_(string.find(res.stdout, "ARG_5=12345", 1, true) ~= nil)
        end)
    end)
end
