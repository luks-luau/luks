-- Test #4: Delay Tests
-- Tests task.delay functionality

local h = require("../../helpers")

return function(expect)
    h.suite("Task Delay Tests", function()

        h.test("task.delay exists and is function", function()
            expect.not_nil(task.delay, "task.delay should exist")
            expect.type_(task.delay, "function", "task.delay should be a function")
        end)

        h.test("task.delay waits before executing", function()
            local executed = false
            task.delay(0.1, function()
                executed = true
            end)
            expect.false_(executed, "should not execute immediately")
            task.wait(0.2)
            expect.true_(executed, "should execute after delay")
        end)

        h.test("task.delay passes arguments to function", function()
            local received = {}
            task.delay(0.05, function(a, b)
                received[1] = a
                received[2] = b
            end, "test", 123)
            task.wait(0.15)
            expect.eq(received[1], "test", "should pass first argument")
            expect.eq(received[2], 123, "should pass second argument")
        end)

        h.test("task.delay returns a thread", function()
            local thread = task.delay(0.1, function() end)
            expect.not_nil(thread, "delay should return a thread")
            expect.type_(thread, "thread", "returned value should be a thread")
        end)

        h.test("multiple delays with different times", function()
            local order = {}
            task.delay(0.1, function() table.insert(order, "first") end)
            task.delay(0.05, function() table.insert(order, "second") end)
            task.wait(0.2)
            -- Second has shorter delay, should execute first
            expect.eq(order[1], "second", "shorter delay should execute first")
            expect.eq(order[2], "first", "longer delay should execute second")
        end)

    end)
    return true
end
