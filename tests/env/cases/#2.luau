local FS = require("../../../luks-std/fs")
local h = require("../../helpers")
local Env = require("../../../luks-std/env")

return function(expect)
    h.suite("Env Edge Cases", function()
        h.test("var returns nil for non-existent key", function()
            local val = Env.var("LUKS_NONEXISTENT_VAR_" .. tostring(math.random(10000, 99999)))
            expect.nil_(val)
        end)

        h.test("removeVar on non-existent key does not error", function()
            local ok, err = pcall(Env.removeVar, "LUKS_NEVER_SET_" .. tostring(math.random(10000, 99999)))
            expect.true_(ok)
        end)

        h.test("setVar with empty string value", function()
            local key = "LUKS_EMPTY_VAL_" .. tostring(math.random(10000, 99999))
            Env.setVar(key, "")
            expect.eq(Env.var(key), "")
            Env.removeVar(key)
        end)

        h.test("setVar with unicode value", function()
            local key = "LUKS_UNICODE_" .. tostring(math.random(10000, 99999))
            local emoji = string.char(0xF0, 0x9F, 0xA6, 0x80) -- U+1F980 crab
            local cjk = string.char(0xE4, 0xB8, 0xAD, 0xE6, 0x96, 0x87) -- 中文
            Env.setVar(key, "caf\xC3\xA9 " .. emoji .. " " .. cjk)
            local val = Env.var(key)
            expect.not_nil(val)
            Env.removeVar(key)
        end)

        h.test("joinPaths with empty table returns empty string", function()
            local result = Env.joinPaths({})
            expect.eq(result, "")
        end)

        h.test("joinPaths with single element returns that element", function()
            local result = Env.joinPaths({"single"})
            expect.eq(result, "single")
        end)

        h.test("splitPaths with empty string", function()
            local result = Env.splitPaths("")
            expect.type_(result, "table")
        end)

        h.test("setCurrentDir with non-existent path returns false", function()
            local ok = Env.setCurrentDir("C:\\__LUKS_NONEXISTENT_DIR_12345__")
            expect.false_(ok)
        end)

        h.test("args[1] is the program name", function()
            local args = Env.args()
            expect.type_(args[1], "string")
            expect.true_(string.len(args[1]) > 0)
        end)

        h.test("tempDir exists and is writable", function()
            local temp = Env.tempDir()
            expect.not_nil(temp)
            local test_file = Env.joinPaths({temp, "_luks_temp_test_" .. tostring(math.random(10000, 99999))})
            FS.write(test_file, "writable"):expect("temp dir not writable")
            FS.remove_file(test_file):expect("cleanup failed")
        end)

        h.test("currentExe path is absolute", function()
            local exe = Env.currentExe()
            if Env.consts.OS == "windows" then
                expect.true_(string.find(exe, ":\\") ~= nil or string.find(exe, ":/") ~= nil)
            else
                expect.eq(string.sub(exe, 1, 1), "/")
            end
        end)
    end)
end
