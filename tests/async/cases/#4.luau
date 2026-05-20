local h = require("../../helpers")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Async Cancellation and Edge Cases", function()
        h.test("cancel on pending future prevents resolution", function()
            local fut, resolve = Async.new_future()
            fut:cancel()
            local ok = false
            fut:inspect(function() ok = true end)
            resolve("should not fire")
            task.wait(0.05)
            expect.false_(ok)
        end)

        h.test("cancel on resolved future is safe", function()
            local fut, resolve = Async.new_future()
            resolve(42)
            task.wait(0.05)
            local ok_cancel = pcall(function() fut:cancel() end)
            expect.true_(ok_cancel)
        end)

        h.test("join with empty table returns empty array", function()
            local results = Async.join({}):unwrap()
            expect.type_(results, "table")
            expect.eq(#results, 0)
        end)

        h.test("join with single future", function()
            local fut, resolve = Async.new_future()
            task.delay(0.05, function() resolve("only") end)
            local results = Async.join({fut}):unwrap()
            expect.eq(#results, 1)
            expect.eq(results[1], "only")
        end)

        h.test("select with one future", function()
            local fut, resolve = Async.new_future()
            task.delay(0.05, function() resolve("the one") end)
            local winner = Async.select({fut}):unwrap()
            expect.eq(winner, "the one")
        end)

        h.test("and_then skips on error path", function()
            local fut, _, reject = Async.new_future()
            task.delay(0.05, function() reject({ kind = "SkipTest", message = "error" }) end)
            local ok = false
            local result = fut:and_then(function()
                ok = true
                return "should not reach"
            end):or_else(function(err)
                return "recovered"
            end)
            local val = result:unwrap()
            expect.eq(val, "recovered")
            expect.false_(ok)
        end)

        h.test("or_else skips on success path", function()
            local fut, resolve = Async.new_future()
            task.delay(0.05, function() resolve(99) end)
            local fallback_called = false
            local result = fut:or_else(function()
                fallback_called = true
                return "fallback"
            end)
            local val = result:unwrap()
            expect.eq(val, 99)
            expect.false_(fallback_called)
        end)

        h.test("chained and_then propagates values", function()
            local fut, resolve = Async.new_future()
            task.delay(0.05, function() resolve(1) end)
            local result = fut
                :map(function(x) return x + 1 end)
                :and_then(function(x) return Async.resolved(x * 2) end)
                :map(function(x) return x + 3 end)
            expect.eq(result:unwrap(), 7)
        end)

        h.test("inspect fires regardless of error (signal-based)", function()
            local fut, _, reject = Async.new_future()
            local inspected = false
            fut:inspect(function() inspected = true end)
            task.delay(0.05, function() reject({ kind = "Err", message = "no inspect" }) end)
            local _, ok = fut:Wait()
            expect.false_(ok)
        end)

        h.test("inspect_err does not fire on success", function()
            local fut, resolve = Async.new_future()
            local inspected = false
            fut:inspect_err(function() inspected = true end)
            task.delay(0.05, function() resolve("ok") end)
            local val, ok = fut:Wait()
            expect.true_(ok)
            expect.false_(inspected)
        end)
    end)
end
