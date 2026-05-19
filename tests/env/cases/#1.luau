local FS = require("../../../luks-std/fs")
local h = require("../../helpers")
local Env = require("../../../luks-std/env")

return function(expect)
    h.suite("Env Variables", function()
        h.test("setVar and var", function()
            local key = "LUKS_TEST_VAR_" .. tostring(math.random(1000, 9999))
            Env.setVar(key, "hello_world")
            expect.eq(Env.var(key), "hello_world")
            
            Env.removeVar(key)
            expect.nil_(Env.var(key))
        end)

        h.test("vars (all variables)", function()
            Env.setVar("LUKS_TOTAL_TEST", "123")
            local all = Env.vars()
            expect.eq(all["LUKS_TOTAL_TEST"], "123")
        end)
    end)

    h.suite("Env Process Information", function()
        h.test("args: returns a non-empty array", function()
            local args = Env.args()
            expect.type_(args, "table")
            expect.true_(#args > 0)
            -- First arg is usually the runner or the script
            expect.type_(args[1], "string")
        end)

        h.test("currentExe: returns a valid path", function()
            local exe = Env.currentExe()
            expect.not_nil(exe)
            expect.type_(exe, "string")
            -- Should contain "luks"
            expect.true_(string.find(exe:lower(), "luks") ~= nil)
        end)
    end)

    h.suite("Env Directories", function()
        h.test("currentDir and setCurrentDir", function()
            local original = Env.currentDir()
            expect.not_nil(original)
            
            local test_dir = "_luks_test_cd_" .. tostring(math.random(10000, 99999))
            FS.create_dir(test_dir):expect("failed to create test dir")
            local abs_dir = FS.canonicalize(test_dir):expect("failed to canonicalize")
            
            local ok = Env.setCurrentDir(abs_dir)
            expect.true_(ok)
            
            local new_dir = Env.currentDir()
            local function normalize(p)
                return p:gsub("[\\/]+$", "")
            end
            expect.eq(normalize(new_dir), normalize(abs_dir))
            
            -- Restore
            Env.setCurrentDir(original)
            expect.eq(normalize(Env.currentDir()), normalize(original))
            
            FS.remove_dir(abs_dir):expect("cleanup failed")
        end)

        h.test("tempDir: returns a path", function()
            local temp = Env.tempDir()
            expect.not_nil(temp)
            expect.type_(temp, "string")
        end)
    end)

    h.suite("Env Path Utils", function()
        h.test("joinPaths and splitPaths", function()
            local paths = {"a", "b", "c"}
            local joined = Env.joinPaths(paths)
            expect.not_nil(joined)
            
            local split = Env.splitPaths(joined)
            expect.eq(#split, 3)
            expect.eq(split[1], "a")
            expect.eq(split[2], "b")
            expect.eq(split[3], "c")
        end)
    end)

    h.suite("Env Constants", function()
        h.test("consts presence", function()
            expect.not_nil(Env.consts.OS)
            expect.not_nil(Env.consts.ARCH)
            expect.not_nil(Env.consts.FAMILY)
            
            if Env.consts.OS == "windows" then
                expect.eq(Env.consts.FAMILY, "windows")
                expect.eq(Env.consts.EXE_EXTENSION, "exe")
            else
                expect.eq(Env.consts.FAMILY, "unix")
            end
        end)
    end)
end
