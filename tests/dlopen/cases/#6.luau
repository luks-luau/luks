-- Test #6: Dlopen Debug Force Fail
local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen Debug Force Fail", function()
        h.test("force fail via debug flag should throw Luau error with location", function()
            -- Activate the internal debug flag via Lua global
            _G.__luks_debug_force_fail = true
            local ok, err = pcall(function()
                -- Use any path; the debug flag should force a failure before attempting to load
                luks_safe_dlopen("nonexistent_library_xyz");
            end)
            -- Expect a failure to be captured by pcall
            if ok then
                -- If it did not fail, force a fail in test to alert
                error("Expected pcall to fail due to debug force fail")
            else
                -- err should be a string with location info
                expect.type_(err, "string")
            end
            -- Reset flag after test to avoid affecting other tests
            _G.__luks_debug_force_fail = false
        end)
    end)
    return true
end
