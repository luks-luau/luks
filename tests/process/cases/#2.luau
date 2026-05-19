--!strict
local Process = require("../../../luks-std/Process")
local Env = require("../../../luks-std/env")
local h = require("../../helpers")
local function sh(cmd_str)
    if Env.consts.OS == "windows" then
        return Process.Command.new("cmd.exe"):args({"/C", cmd_str})
    else
        return Process.Command.new("sh"):args({"-c", cmd_str})
    end
end

return function(expect)
    h.suite("PROCESS - EXTENDED API", function()
        h.test("stdin piping", function()
            local cmd = sh("sort")
                :stdin(Process.Stdio.piped())
                :stdout(Process.Stdio.piped())
            
            local child = cmd:spawn():expect("spawn failed")
            local stdin = child.stdin
            local stdout = child.stdout
            expect.not_nil(stdin, "stdin should be piped")
            expect.not_nil(stdout, "stdout should be piped")
            
            local test_msg = "luks is awesome"
            stdin:write(test_msg):expect("write failed")
            stdin:close() -- Signal EOF
            
            local result = ""
            local buf = buffer.create(1024)
            while true do
                local n, ok = stdout:read(buf):Wait()
                if not ok or n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            
            expect.true_(string.find(result, test_msg) ~= nil, "should echo back stdin")
            child:wait():expect("wait failed")
            child:close()
        end)

        h.test("environment variables", function()
            local echo_var = if Env.consts.OS == "windows"
                then "echo %LUKS_TEST_VAR%"
                else "echo $LUKS_TEST_VAR"
            local cmd = sh(echo_var)
                :env("LUKS_TEST_VAR", "it_works")
                :stdout(Process.Stdio.piped())
            
            local child = cmd:spawn():expect("spawn failed")
            local result = ""
            local buf = buffer.create(1024)
            while true do
                local n, ok = child.stdout:read(buf):Wait()
                if not ok or n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            
            expect.true_(string.find(result, "it_works") ~= nil, "should see env var")
            child:wait():expect("wait failed")
            child:close()
        end)

        h.test("current working directory", function()
            local pwd_cmd = if Env.consts.OS == "windows" then "cd" else "pwd"
            local root = if Env.consts.OS == "windows" then "C:\\" else "/"
            local cmd = sh(pwd_cmd)
                :cwd(root)
                :stdout(Process.Stdio.piped())
            
            local child = cmd:spawn():expect("spawn failed")
            local result = ""
            local buf = buffer.create(1024)
            while true do
                local n, ok = child.stdout:read(buf):Wait()
                if not ok or n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            
            expect.true_(string.find(result, root) ~= nil, "should be in root")
            child:wait():expect("wait failed")
            child:close()
        end)

        h.test("stderr capturing", function()
            local cmd = sh("cd non_existent_folder_luks_123")
                :stderr(Process.Stdio.piped())
            
            local child = cmd:spawn():expect("spawn failed")
            local result = ""
            local buf = buffer.create(1024)
            while true do
                local n, ok = child.stderr:read(buf):Wait()
                if not ok or n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            
            expect.true_(#result > 0, "should have captured stderr")
            child:wait():expect("wait failed")
            child:close()
        end)
    end)
end
