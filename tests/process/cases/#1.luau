--!strict
local Process = require("../../../luks-std/Process")
local h = require("../../helpers")

return function(expect)
    h.suite("PROCESS - RUST STYLE ENGINE", function()
        h.test("command builder and spawn", function()
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "echo", "hello luks"})
            
            local child = cmd:spawn():expect("spawn failed")
            expect.true_(child.id > 0)
            
            local status = child:wait():expect("wait failed")
            expect.eq(status:code(), 0)
            expect.eq(status:success(), true)
            
            child:close()
        end)

        h.test("stdout streaming", function()
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "echo line 1 && echo line 2"})
                :stdout(Process.Stdio.piped())
            
            local child = cmd:spawn():expect("spawn failed")
            local stdout = child.stdout
            expect.not_nil(stdout, "stdout should be piped")
            
            local result = ""
            local buf = buffer.create(1024)
            
            while true do
                local n, ok = stdout:read(buf):Wait()
                if not ok then break end -- EOF or error
                if n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            
            expect.true_(string.find(result, "line 1") ~= nil, "should contain line 1")
            expect.true_(string.find(result, "line 2") ~= nil, "should contain line 2")
            
            child:wait():expect("wait failed")
            child:close()
        end)

        h.test("try_wait and kill", function()
            local cmd = Process.Command.new("cmd.exe")
                :args({"/C", "pause"})
            
            local child = cmd:spawn():expect("spawn failed")
            
            local status = child:try_wait():expect("try_wait failed")
            expect.nil_(status) -- Still running
            
            child:kill():expect("kill failed")
            
            local final_status = child:wait():expect("wait failed")
            expect.eq(final_status:success(), false)
            
            child:close()
        end)
    end)
end
