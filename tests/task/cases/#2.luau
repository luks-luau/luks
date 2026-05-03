-- Test #2: Wait Tests
-- Tests task.wait functionality

local h = require("../../helpers")

return function(expect)
    h.suite("Task Wait Tests", function()

        h.test("task.wait exists and is function", function()
            expect.not_nil(task.wait, "task.wait should exist")
            expect.type_(task.wait, "function", "task.wait should be a function")
        end)

        h.test("task.wait yields for specified time", function()
            local start = os.clock()
            task.wait(0.1)
            local elapsed = os.clock() - start
            expect.true_(elapsed >= 0.05, "should wait at least some time")
        end)

        h.test("task.wait with no args yields briefly", function()
            local start = os.clock()
            task.wait()
            local elapsed = os.clock() - start
            expect.true_(elapsed >= 0, "should yield without error")
        end)

        h.test("task.wait returns elapsed time", function()
            local start = os.clock()
            local elapsed = task.wait(0.1)
            local actual = os.clock() - start
            expect.type_(elapsed, "number", "wait should return a number")
            expect.true_(elapsed >= 0, "elapsed time should be positive")
        end)

        h.test("task.wait can be called multiple times", function()
            for i = 1, 3 do
                task.wait(0.01)
            end
            expect.true_(true, "should survive multiple waits")
        end)

        h.test("task.wait in spawned function works", function()
            local done = false
            task.spawn(function()
                task.wait(0.05)
                done = true
            end)
            task.wait(0.15)
            expect.true_(done, "wait in spawned function should work")
        end)

    end)
    return true
end
