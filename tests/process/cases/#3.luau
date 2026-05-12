local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("Process Sandbox and Edge Compatibility", function()
        h.test("process parameter parsing transfers string arrays correctly", function()
            -- Utilizing host explicit launcher boundaries ensuring array vector integrity
            local prog = if Process.os() == "windows" then "cmd.exe" else "/bin/sh"
            local flag = if Process.os() == "windows" then "/C" else "-c"

            local res = Process.spawn(prog, { flag, "echo sequential parameter extraction testing" })
            expect.true_(res.ok, "Handles sequential string table parsing without unhandled crashes")
            expect.true_(string.find(res.stdout, "sequential", 1, true) ~= nil, "Verifies successful transfer of vector arrays")
        end)

        h.test("process runtime bindings validate custom working directory overrides", function()
            -- Validating successful mapping executing safe target CWD anchors
            local res1 = Process.exec("echo cwd mapping check", {
                cwd = "./",
            })
            expect.true_(res1.ok, "Successfully roots child execution frames within specified working directories")

            -- Passing unmapped or non-existent target paths cleanly yields output maps documenting system launch rejections
            local res2 = Process.exec("echo unreachable", {
                cwd = "./non-existent-sandbox-directory-path-!!",
            })
            expect.false_(res2.ok, "Fails initialization boundary intercepting non-existent target anchor directories")
            expect.type_(res2.error, "string")
        end)

        h.test("process native engines evaluate env_clear isolation layers safely", function()
            local res = Process.exec("echo sandbox initialization verification", {
                env_clear = true,
                env = {
                    ["LUKS_SANDBOX_KEY"] = "active-containment",
                },
            })
            expect.true_(res.ok, "Kernel successfully binds child scopes applying complete context clearing flags")
            expect.eq(res.status, 0, "Returns absolute status success integer under environment clearance rules")
        end)

        h.test("process native parser gracefully bypasses corrupted argument maps", function()
            -- Injecting malformed types directly into nested option definitions
            local res = Process.exec("echo resilience", {
                cwd = 12345 :: any,
                env = {
                    [999] = "numeric-key-invalid" :: any,
                    ["VALID_KEY"] = "retained",
                } :: any,
            })
            expect.true_(res.ok, "Defensive FFI layers skip malformed key assertions yielding normal output flows")
            expect.type_(res.stdout, "string")
        end)

        h.test("process output payload defaults resolve absent streams securely", function()
            -- Command executing clean evaluation paths yielding empty string maps
            local cmd = if Process.os() == "windows" then "cd ." else "true"
            local res = Process.exec(cmd)

            expect.true_(res.ok)
            expect.eq(res.stdout, "", "Empty terminal stdout buffers resolve to standard valid blank text strings")
            expect.eq(res.stderr, "", "Empty terminal stderr buffers resolve to standard valid blank text strings")
        end)
    end)
end
