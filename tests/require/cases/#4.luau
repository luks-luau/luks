-- Test #4: Require Syntax Error Tests
local h = require("../../helpers")
local wrap = require("../wrap")

return function(expect)
    h.suite("Require Syntax Error Tests", function()
        h.test("require syntax error", function()
            local ok, err = pcall(function()
                wrap.safe_require("./subdir/broke")
            end)
            h.expect_false(ok, "pcall should fail for broken module")
            h.expect_type(err, "string", "expected error string for broken module")
        end)
    end)
    return true
end
