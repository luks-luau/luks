-- Test #4: Dlopen Invalid Arg Type
<<<<<<< HEAD
local h = require('../../helpers')
=======
local h = require("../../helpers")
local wrap = require("../wrap")
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)

return function(expect)
    h.suite("Dlopen Negative Type Tests", function()
        h.test("dlopen with non-string arg returns Luau error", function()
            local ok, err = pcall(function()
<<<<<<< HEAD
                luks_safe_dlopen(123)
=======
                wrap.safe_dlopen(123)
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)
            end)
            h.expect_false(ok, "pcall should fail for non-string arg")
            h.expect_type(err, "string", "error should be string for invalid arg")
        end)
    end)
    return true
end
