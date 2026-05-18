--!strict
local Process = require("../../../luks-std/Process")
local h = require("../../helpers")

return function(expect)
    h.suite("PROCESS - EXTENDED API", function()
        h.test("stdin piping", function()
            -- use 'sort' to echo back stdin
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "sort"})
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
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "echo %LUKS_TEST_VAR%"})
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
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "cd"})
                :cwd("C:\\")
                :stdout(Process.Stdio.piped())
            
            local child = cmd:spawn():expect("spawn failed")
            local result = ""
            local buf = buffer.create(1024)
            while true do
                local n, ok = child.stdout:read(buf):Wait()
                if not ok or n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            
            expect.true_(string.find(result, "C:\\") ~= nil, "should be in C:\\")
            child:wait():expect("wait failed")
            child:close()
        end)

        h.test("stderr capturing", function()
            -- try to cd into a non-existent dir to trigger stderr
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "cd", "non_existent_folder_luks_123"})
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
