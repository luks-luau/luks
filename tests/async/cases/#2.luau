local h = require("../../helpers")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Async Control Flow (Yielding)", function()
        h.test("Wait: successful resolution", function()
            local fut, resolve = Async.new_future()
            task.delay(0.1, function() resolve("data") end)
            
            local result, success = fut:Wait()
            expect.true_(success)
            expect.eq(result, "data")
        end)

        h.test("Wait: error resolution", function()
            local fut, _, reject = Async.new_future()
            task.delay(0.1, function() reject({ kind = "WaitErr", message = "failed" }) end)
            
            local result, success = fut:Wait()
            expect.false_(success)
            expect.eq(result.kind, "WaitErr")
        end)

        h.test("unwrap: returns value on success", function()
            local fut, resolve = Async.new_future()
            task.delay(0.1, function() resolve("ok") end)
            
            local result = fut:unwrap()
            expect.eq(result, "ok")
        end)

        h.test("unwrap: panics on error", function()
            local fut, _, reject = Async.new_future()
            task.delay(0.1, function() reject({ kind = "Panic", message = "boom" }) end)
            
            expect.error(function()
                fut:unwrap()
            end)
        end)

        h.test("expect: panics with custom message", function()
            local fut, _, reject = Async.new_future()
            task.delay(0.1, function() reject({ kind = "Panic", message = "boom" }) end)
            
            local ok, err = pcall(function()
                fut:expect("CUSTOM_MSG")
            end)
            expect.false_(ok)
            expect.true_(string.find(tostring(err), "CUSTOM_MSG"))
        end)
    end)

    h.suite("Async Global Combinators", function()
        h.test("join: awaiting multiple futures", function()
            local f1, r1 = Async.new_future()
            local f2, r2 = Async.new_future()
            
            task.delay(0.1, function() r1(1) end)
            task.delay(0.2, function() r2(2) end)
            
            local results = Async.join({f1, f2}):unwrap()
            expect.eq(#results, 2)
            expect.eq(results[1], 1)
            expect.eq(results[2], 2)
        end)

        h.test("select: racing multiple futures", function()
            local f1, r1 = Async.new_future()
            local f2, r2 = Async.new_future()
            
            task.delay(0.5, function() r1("slow") end)
            task.delay(0.1, function() r2("fast") end)
            
            local winner = Async.select({f1, f2}):unwrap()
            expect.eq(winner, "fast")
        end)
    end)
end
