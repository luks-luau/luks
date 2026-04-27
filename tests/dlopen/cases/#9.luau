-- Test #9: Dlopen Path With Spaces (Negative Edge)
local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen Edge: Spaces Path Neg", function()
        h.test("dlopen with spaces path should fail (negative)", function()
            local ok, err = pcall(function()
                luks_safe_dlopen("path with spaces/nonexistent.dll")
            end)
            h.expect_false(ok, "pcall should fail for missing library with spaces")
            h.expect_type(err, "string", "expected error string for missing library with spaces")
        end)
    end)
    return true
end
