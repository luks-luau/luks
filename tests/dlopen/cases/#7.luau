-- Test #7: Dlopen Path With Spaces (Negative)
local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen Edge: Path with spaces", function()
        h.test("dlopen with spaces path should fail gracefully", function()
            local ok, err = pcall(function()
                luks_safe_dlopen("path with spaces/nonexistent.dll")
            end)
            h.expect_false(ok, "pcall should fail for non-existent path with spaces")
            h.expect_type(err, "string", "expected error string for missing library with spaces")
        end)
    end)
    return true
end
