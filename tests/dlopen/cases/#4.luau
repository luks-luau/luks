-- Test #4: Dlopen Invalid Arg Type
local h = require("../../helpers")
local wrap = require("../wrap")

return function(expect)
    h.suite("Dlopen Negative Type Tests", function()
        h.test("dlopen with non-string arg returns Luau error", function()
            local ok, err = pcall(function()
                wrap.safe_dlopen(123)
            end)
            h.expect_false(ok, "pcall should fail for non-string arg")
            h.expect_type(err, "string", "error should be string for invalid arg")
        end)
    end)
    return true
end
