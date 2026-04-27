-- Test #9: Require Path With Spaces (Negative Edge)
local h = require("../../helpers")

return function(expect)
    h.suite("Require Edge: Spaces Path Neg", function()
        h.test("require with spaces path should fail (negative)", function()
            local ok, err = pcall(function()
                luks_safe_require("path with spaces/nonexistent_module")
            end)
            h.expect_false(ok, "pcall should fail for missing module with spaces")
            h.expect_type(err, "string", "expected error string for missing module with spaces")
        end)
    end)
    return true
end
