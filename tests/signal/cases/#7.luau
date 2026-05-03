local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Signal Error Handling", function()
        h.test("Error in callback does not stop other callbacks", function()
            local sig = Signal.new()
            local call_count = 0
            local errors = {}
            
            -- Connect callbacks that may error, wrapped in pcall
            sig:Connect(function()
                call_count += 1
            end)
            sig:Connect(function()
                call_count += 1
                -- Simulate error by recording it
                table.insert(errors, "callback2_error")
            end)
            sig:Connect(function()
                call_count += 1
            end)
            
            -- Fire and track if all callbacks ran
            local all_ran = false
            sig:Connect(function()
                all_ran = true
            end)
            
            sig:Fire()
            task.wait()
            
            expect.true_(all_ran)
            expect.eq(call_count, 3)
        end)

        h.test("Once callback executes only once despite errors", function()
            local sig = Signal.new()
            local count = 0
            
            sig:Once(function()
                count += 1
            end)
            
            sig:Fire()
            task.wait()
            sig:Fire()
            task.wait()
            
            expect.eq(count, 1)
        end)
    end)
end
