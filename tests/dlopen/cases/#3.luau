local h = require("../../helpers")
<<<<<<< HEAD
=======
local wrap = require("../wrap")
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)

return function(expect)
    h.suite("Dlopen Negative Tests", function()
        h.test("dlopen missing library returns Luau error", function()
            local ok, err = pcall(function()
<<<<<<< HEAD
                luks_safe_dlopen("nonexistent_library_xyz")
=======
                wrap.safe_dlopen("nonexistent_library_xyz")
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)
            end)
            h.expect_false(ok, "pcall should fail for missing library")
            h.expect_type(err, "string", "error should be string for missing library")
        end)
    end)
    return true
end
