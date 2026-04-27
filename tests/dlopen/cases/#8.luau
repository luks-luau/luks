-- Test #8: Dlopen Path With Spaces (Require-style)
local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen Edge: Path with spaces for require", function()
        h.test("dlopen with spaces path via require should fail gracefully", function()
            local ok, err = pcall(function()
                luks_safe_require("path with spaces/nonexistent_module")
            end)
            h.expect_false(ok, "pcall should fail for non-existent module with spaces in path")
            h.expect_type(err, "string", "expected error string for missing module with spaces")
        end)
    end)
    return true
end
