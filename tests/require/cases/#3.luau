-- Test #3: Require Negative Tests
-- Ensure proper error handling when requiring missing modules

local h = require("../../helpers")
<<<<<<< HEAD
-- use built-in runtime wrappers (no external test wrappers)
=======
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)

return function(expect)
    h.suite("Require Negative Tests", function()
        h.test("require missing module errors", function()
<<<<<<< HEAD
            local ok, err = pcall(function()
                luks_safe_require("./nonexistent_module")
            end)
            h.expect_false(ok, "pcall should fail for missing module")
            h.expect_type(err, "string", "expected error string for missing module")
=======
            expect.error(function()
                require("./nonexistent_module")
            end, "expected an error for missing module")
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)
        end)
    end)

    return true
end
