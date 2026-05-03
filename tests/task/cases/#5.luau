-- Test #5: Cancel Tests
-- Tests task.cancel functionality

local h = require("../../helpers")

return function(expect)
    h.suite("Task Cancel Tests", function()

        h.test("task.cancel exists and is function", function()
            expect.not_nil(task.cancel, "task.cancel should exist")
            expect.type_(task.cancel, "function", "task.cancel should be a function")
        end)

        h.test("task.cancel stops a spawned thread", function()
            local executed = false
            local thread = task.spawn(function()
                task.wait(1) -- Long wait
                executed = true
            end)
            task.cancel(thread)
            task.wait(0.1)
            expect.false_(executed, "cancelled thread should not execute")
        end)

        h.test("task.cancel stops a deferred thread", function()
            local executed = false
            local thread = task.defer(function()
                executed = true
            end)
            task.cancel(thread)
            task.wait(0.05)
            expect.false_(executed, "cancelled defer should not execute")
        end)

        h.test("task.cancel on already completed thread is safe", function()
            local thread = task.spawn(function() end)
            task.wait(0.05)
            -- Should not error
            task.cancel(thread)
            expect.true_(true, "cancel on completed thread should not error")
        end)

    end)
    return true
end
