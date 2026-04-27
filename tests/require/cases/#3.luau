-- Test #3: Require Negative Tests
-- Ensure proper error handling when requiring missing modules

local h = require("../../helpers")
-- use built-in runtime wrappers (no external test wrappers)

return function(expect)
    h.suite("Require Negative Tests", function()
        h.test("require missing module errors", function()
            local ok, err = pcall(function()
                luks_safe_require("./nonexistent_module")
            end)
            h.expect_false(ok, "pcall should fail for missing module")
            h.expect_type(err, "string", "expected error string for missing module")
        end)
    end)

    return true
end
