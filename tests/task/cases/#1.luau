-- Test #1: Basic Spawn Tests
-- Tests task.spawn functionality

local h = require("../../helpers")

return function(expect)
    h.suite("Task Spawn Tests", function()

        h.test("task.spawn exists and is function", function()
            expect.not_nil(task, "task module should exist")
            expect.not_nil(task.spawn, "task.spawn should exist")
            expect.type_(task.spawn, "function", "task.spawn should be a function")
        end)

        h.test("task.spawn runs function asynchronously", function()
            local result = { executed = false }
            task.spawn(function()
                result.executed = true
            end)
            -- Give time for the spawned task to run
            task.wait(0.1)
            expect.true_(result.executed, "spawned function should have executed")
        end)

        h.test("task.spawn passes arguments to function", function()
            local received = {}
            task.spawn(function(a, b, c)
                received[1] = a
                received[2] = b
                received[3] = c
            end, "hello", 42, true)
            task.wait(0.1)
            expect.eq(received[1], "hello", "first argument should match")
            expect.eq(received[2], 42, "second argument should match")
            expect.true_(received[3], "third argument should be true")
        end)

        h.test("task.spawn returns a thread", function()
            local thread = task.spawn(function() end)
            expect.not_nil(thread, "spawn should return a thread")
            expect.type_(thread, "thread", "returned value should be a thread")
        end)

        h.test("spawned function can use task.wait", function()
            local done = false
            task.spawn(function()
                task.wait(0.05)
                done = true
            end)
            task.wait(0.15)
            expect.true_(done, "should complete after wait")
        end)

    end)
    return true
end
