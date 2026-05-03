-- Test #3: Defer Tests
-- Tests task.defer functionality

local h = require("../../helpers")

return function(expect)
    h.suite("Task Defer Tests", function()

        h.test("task.defer exists and is function", function()
            expect.not_nil(task.defer, "task.defer should exist")
            expect.type_(task.defer, "function", "task.defer should be a function")
        end)

        h.test("task.defer runs after current thread yields", function()
            local order = {}
            task.defer(function()
                table.insert(order, "deferred")
            end)
            table.insert(order, "immediate")
            task.wait(0.05)
            expect.eq(order[1], "immediate", "immediate should run first")
            expect.eq(order[2], "deferred", "deferred should run after yield")
        end)

        h.test("task.defer passes arguments", function()
            local received = {}
            task.defer(function(a, b)
                received[1] = a
                received[2] = b
            end, "hello", 42)
            task.wait(0.05)
            expect.eq(received[1], "hello", "should pass first argument")
            expect.eq(received[2], 42, "should pass second argument")
        end)

        h.test("task.defer returns a thread", function()
            local thread = task.defer(function() end)
            expect.not_nil(thread, "defer should return a thread")
            expect.type_(thread, "thread", "returned value should be a thread")
        end)

        h.test("multiple defers run in order", function()
            local order = {}
            task.defer(function() table.insert(order, 1) end)
            task.defer(function() table.insert(order, 2) end)
            task.defer(function() table.insert(order, 3) end)
            task.wait(0.05)
            expect.eq(order[1], 1, "first defer should be first")
            expect.eq(order[2], 2, "second defer should be second")
            expect.eq(order[3], 3, "third defer should be third")
        end)

    end)
    return true
end
