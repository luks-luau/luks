local h = require("../../helpers")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Async Stress Testing", function()
        h.test("High concurrency chain and join", function()
            local total_tasks = 100
            local futures = {}
            
            for i = 1, total_tasks do
                local f, resolve = Async.new_future()
                task.spawn(function()
                    task.wait(math.random() * 0.1)
                    resolve(i)
                end)
                
                table.insert(futures, f:map(function(v) return v * 2 end))
            end
            
            local results = Async.join(futures):unwrap()
            expect.eq(#results, total_tasks)
            
            local sum = 0
            for _, v in results do sum += v end
            -- sum of 1 to 100 is 5050. results are doubled, so 10100.
            expect.eq(sum, 10100)
        end)

        h.test("Deeply nested and_then chains", function()
            local depth = 10
            local f, resolve = Async.new_future()
            
            local current = f
            for i = 1, depth do
                current = current:and_then(function(v)
                    return v + 1
                end)
            end
            
            task.defer(resolve, 0)
            local result = current:unwrap()
            expect.eq(result, depth)
        end)
        
        h.test("Rapid fire select racing", function()
            for i = 1, 50 do
                local f1, r1 = Async.new_future()
                local f2, r2 = Async.new_future()
                
                task.defer(function() r1("A") end)
                task.defer(function() r2("B") end)
                
                local winner = Async.select({f1, f2}):unwrap()
                expect.true_(winner == "A" or winner == "B")
            end
        end)
    end)
end
