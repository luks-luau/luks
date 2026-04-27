-- Test #3: Require Negative Tests
-- Ensure proper error handling when requiring missing modules

local h = require("../../helpers")
local wrap = require("../wrap")

return function(expect)
    h.suite("Require Negative Tests", function()
        h.test("require missing module errors", function()
            local ok, err = pcall(function()
                wrap.safe_require("./nonexistent_module")
            end)
            h.expect_false(ok, "pcall should fail for missing module")
            h.expect_type(err, "string", "expected error string for missing module")
        end)
    end)

    return true
end
