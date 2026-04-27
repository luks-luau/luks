local h = require("../../helpers")

return function(expect)
    h.suite("Dlopen Negative Tests", function()
        h.test("dlopen missing library returns Luau error", function()
            local ok, err = pcall(function()
                luks_safe_dlopen("nonexistent_library_xyz")
            end)
            h.expect_false(ok, "pcall should fail for missing library")
            h.expect_type(err, "string", "error should be string for missing library")
        end)
    end)
    return true
end
