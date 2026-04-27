-- Test #4: Require Syntax Error Tests
local h = require("../../helpers")
<<<<<<< HEAD
-- use built-in runtime wrappers (no external test wrappers)
=======
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)

return function(expect)
    h.suite("Require Syntax Error Tests", function()
        h.test("require syntax error", function()
<<<<<<< HEAD
            local ok, err = pcall(function()
                luks_safe_require("./subdir/broke")
            end)
            h.expect_false(ok, "pcall should fail for broken module")
            h.expect_type(err, "string", "expected error string for broken module")
=======
            expect.error(function()
                require("./subdir/broke")
            end, "expected syntax error on broken module")
>>>>>>> 53ebcbb (feat(dlopen): surface Luau errors on dlopen failure; return nil + error)
        end)
    end)
    return true
end
