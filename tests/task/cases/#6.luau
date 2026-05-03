-- Test #6: Concurrent Tasks and Main Thread Wait
-- Tests multiple concurrent tasks and task.wait in main thread

local h = require("../../helpers")

return function(expect)
    h.suite("Concurrent Tasks Tests", function()

        h.test("multiple spawned tasks run concurrently", function()
            local results = {}
            task.spawn(function()
                task.wait(0.05)
                table.insert(results, "task1")
            end)
            task.spawn(function()
                task.wait(0.03)
                table.insert(results, "task2")
            end)
            task.spawn(function()
                table.insert(results, "task3")
            end)
            task.wait(0.1)
            expect.eq(#results, 3, "all three tasks should complete")
        end)

        h.test("tasks can communicate via shared state", function()
            local counter = 0
            for i = 1, 5 do
                task.spawn(function()
                    task.wait(0.01)
                    counter = counter + 1
                end)
            end
            task.wait(0.1)
            expect.eq(counter, 5, "all tasks should increment counter")
        end)

        h.test("task.wait works in main thread", function()
            -- This tests that task.wait works in the main thread
            -- (which was the goal of our luks_execute modification)
            local start = os.clock()
            task.wait(0.05)
            local elapsed = os.clock() - start
            expect.true_(elapsed >= 0.03, "task.wait should work in main thread")
        end)

        h.test("spawn with immediate execution and wait", function()
            local order = {}
            task.spawn(function()
                table.insert(order, "spawned")
            end)
            table.insert(order, "main")
            task.wait(0.05)
            -- Both should have executed
            expect.eq(#order, 2, "both main and spawned should run")
        end)

        h.test("nested spawn and wait", function()
            local result = ""
            task.spawn(function()
                task.spawn(function()
                    task.wait(0.02)
                    result = result .. "inner"
                end)
                task.wait(0.05)
                result = result .. "outer"
            end)
            task.wait(0.1)
            expect.not_nil(string.find(result, "inner"), "inner should execute")
            expect.not_nil(string.find(result, "outer"), "outer should execute")
        end)

    end)
    return true
end
