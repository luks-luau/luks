local h = require("../../helpers")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Async Basic Combinators", function()
        h.test("map: transforming resolved values", function()
            local fut, resolve = Async.new_future()
            local result
            
            fut:map(function(val)
                return val * 2
            end).OnData:Connect(function(val)
                result = val
            end)
            
            resolve(10)
            expect.eq(result, 20)
        end)

        h.test("and_then: chaining futures", function()
            local fut, resolve = Async.new_future()
            local result
            
            fut:and_then(function(val)
                local next_fut, next_resolve = Async.new_future()
                task.defer(function() next_resolve(val + 5) end)
                return next_fut
            end).OnData:Connect(function(val)
                result = val
            end)
            
            resolve(10)
            -- Wait for defer
            local start = os.clock()
            while result == nil and os.clock() - start < 1 do task.wait() end
            
            expect.eq(result, 15)
        end)

        h.test("and_then: chaining direct values", function()
            local fut, resolve = Async.new_future()
            local result
            
            fut:and_then(function(val)
                return val + 10
            end).OnData:Connect(function(val)
                result = val
            end)
            
            resolve(10)
            expect.eq(result, 20)
        end)
    end)

    h.suite("Async Error Handling (Rust-Style)", function()
        h.test("or_else: recovering from errors", function()
            local fut, _, reject = Async.new_future()
            local result
            
            fut:or_else(function(err)
                expect.eq(err.kind, "TestError")
                return "recovered"
            end).OnData:Connect(function(val)
                result = val
            end)
            
            reject({ kind = "TestError", message = "failed" })
            expect.eq(result, "recovered")
        end)

        h.test("map_err: transforming error objects", function()
            local fut, _, reject = Async.new_future()
            local error_obj
            
            fut:map_err(function(err)
                return { kind = "Transformed", message = err.message:upper() }
            end).OnError:Connect(function(err)
                error_obj = err
            end)
            
            reject({ kind = "Original", message = "error" })
            expect.not_nil(error_obj)
            expect.eq(error_obj.kind, "Transformed")
            expect.eq(error_obj.message, "ERROR")
        end)
    end)

    h.suite("Async Inspection (Side-Effects)", function()
        h.test("inspect: side-effect on success", function()
            local fut, resolve = Async.new_future()
            local side_effect = 0
            local final
            
            local chained = fut:inspect(function(val)
                side_effect = val
            end)
            
            chained.OnData:Connect(function(val) 
                final = val 
            end)
            
            resolve(42)
            
            -- Wait for task.spawn cycles
            local start = os.clock()
            while (side_effect == 0 or final == nil) and os.clock() - start < 1 do 
                task.wait() 
            end
            
            expect.eq(side_effect, 42)
            expect.eq(final, 42)
        end)

        h.test("inspect_err: side-effect on failure", function()
            local fut, _, reject = Async.new_future()
            local side_effect = ""
            
            fut:inspect_err(function(err)
                side_effect = err.kind
            end)
            
            reject({ kind = "SideEffect", message = "msg" })
            expect.eq(side_effect, "SideEffect")
        end)
    end)
end
