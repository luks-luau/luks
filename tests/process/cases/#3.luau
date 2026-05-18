--!strict
local Process = require("../../../luks-std/Process")
local Async = require("../../../luks-std/async")
local h = require("../../helpers")

return function(expect)
    h.suite("PROCESS - STRESS TEST", function()
        h.test("concurrent spawn and wait", function()
            local count = 500
            local futures = {}
            
            for i = 1, count do
                local fut, resolve, reject = Async.new_future()
                table.insert(futures, fut)
                
                task.spawn(function()
                    local ok, err = pcall(function()
                        local cmd = Process.Command.new("cmd.exe")
                            :args({"/C", "echo", "stress " .. i})
                            :stdout(Process.Stdio.piped())
                        
                        local child = cmd:spawn():expect("spawn failed " .. i)
                        local result = ""
                        local buf = buffer.create(128)
                        while true do
                            local n, ok = child.stdout:read(buf):Wait()
                            if not ok or n == 0 then break end
                            result ..= buffer.readstring(buf, 0, n)
                        end
                        
                        child:wait():expect("wait failed " .. i)
                        child:close()
                        expect.true_(string.find(result, "stress " .. i) ~= nil)
                    end)
                    
                    if ok then resolve(nil) else reject({ kind = "StressError", message = tostring(err) }) end
                end)
            end
            
            Async.join(futures):expect("stress test failed")
        end)
    end)
end
