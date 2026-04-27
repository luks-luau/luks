-- Test #4: Require Syntax Error Tests
local h = require("../../helpers")

return function(expect)
    h.suite("Require Syntax Error Tests", function()
        h.test("require syntax error", function()
            expect.error(function()
                require("./subdir/broke")
            end, "expected syntax error on broken module")
        end)
    end)
    return true
end
