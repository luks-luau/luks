local h = require("../../helpers")
local wrap = require("../wrap")

return function(expect)
    h.suite("Dlopen Negative Tests", function()
        h.test("dlopen missing library returns Luau error", function()
            local ok, err = pcall(function()
                wrap.safe_dlopen("nonexistent_library_xyz")
            end)
            h.expect_false(ok, "pcall should fail for missing library")
            h.expect_type(err, "string", "error should be string for missing library")
        end)
    end)
    return true
end
