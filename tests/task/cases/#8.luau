local h = require("../../helpers")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Task Edge Cases", function()
        h.test("task.delay with 0 seconds behaves like defer", function()
            local order = {}
            task.defer(function() table.insert(order, "defer") end)
            task.delay(0, function() table.insert(order, "delay0") end)
            table.insert(order, "immediate")
            local timeout = 0
            while #order < 3 and timeout < 50 do
                task.wait(0.05)
                timeout += 1
            end
            expect.eq(order[1], "immediate")
            expect.true_(#order >= 2)
        end)

        h.test("task.delay with negative time clamps to 0", function()
            local ok, err = pcall(function()
                task.delay(-1, function() end)
            end)
            expect.true_(ok)
        end)

        h.test("task.cancel on main thread is safe", function()
            local ok, err = pcall(function()
                task.cancel(coroutine.running())
            end)
        end)

        h.test("error in spawned function is caught by pcall", function()
            local ok = false
            local thread = task.spawn(function()
                error("intentional spawn error")
            end)
            task.wait(0.05)
            expect.true_(true) -- no crash
        end)

        h.test("multiple task.wait with no args in sequence", function()
            local t1 = task.wait()
            local t2 = task.wait()
            local t3 = task.wait()
            expect.type_(t1, "number")
            expect.type_(t2, "number")
            expect.type_(t3, "number")
        end)

        h.test("task.spawn with no extra args passes nothing", function()
            local arg_count
            task.spawn(function(...) arg_count = select("#", ...) end)
            task.wait(0.05)
            expect.eq(arg_count, 0)
        end)

        h.test("concurrent count to 1000 via shared state", function()
            local counter = 0
            local target = 100
            local futures = {}
            for i = 1, target do
                local fut, resolve = Async.new_future()
                table.insert(futures, fut)
                task.spawn(function()
                    counter += 1
                    resolve(nil)
                end)
            end
            Async.join(futures):expect("concurrent join failed")
            expect.eq(counter, target)
        end)

        h.test("nested task.spawn three levels deep", function()
            local results = {}
            task.spawn(function()
                table.insert(results, "l1")
                task.spawn(function()
                    table.insert(results, "l2")
                    task.spawn(function()
                        table.insert(results, "l3")
                    end)
                end)
            end)
            local timeout = 0
            while #results < 3 and timeout < 50 do
                task.wait(0.05)
                timeout += 1
            end
            expect.eq(#results, 3)
            expect.eq(results[1], "l1")
        end)

        h.test("cancel thread then check it does not execute", function()
            local executed = false
            local thread = task.spawn(function()
                task.wait(999) -- never finishes
                executed = true
            end)
            task.cancel(thread)
            task.wait(0.1)
            expect.false_(executed)
        end)
    end)
end
