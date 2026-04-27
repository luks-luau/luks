-- Test #3: Require Negative Tests
-- Ensure proper error handling when requiring missing modules

local h = require("../../helpers")

return function(expect)
    h.suite("Require Negative Tests", function()
        h.test("require missing module errors", function()
            expect.error(function()
                require("./nonexistent_module")
            end, "expected an error for missing module")
        end)
    end)

    return true
end
