--!native
--!strict
return function(expect)
    local h = require("../../helpers")

    h.suite("Luau JIT Performance Benchmark", function()
        h.test("monte carlo pi estimation math stress", function()
            -- Linear Congruential Generator parameters (Pure Math/CSPRNG simulation)
            local seed: number = 123456789
            local M: number = 2^32
            local A: number = 1664525
            local C: number = 1013904223

            local inside_circle: number = 0
            -- 30 million iterations to evaluate execution acceleration bounds
            local total_iterations: number = 30000000 

            local start_time = os.clock()

            -- CPU intensive execution loop compiled directly to native machine instructions under JIT
            for i = 1, total_iterations do
                -- Generate pseudo-random X between 0 and 1
                seed = (A * seed + C) % M
                local x: number = seed / M

                -- Generate pseudo-random Y between 0 and 1
                seed = (A * seed + C) % M
                local y: number = seed / M

                -- Euclidean distance verification from origin (x^2 + y^2)
                if (x * x + y * y) <= 1.0 then
                    inside_circle = inside_circle + 1
                end
            end

            local pi_estimate: number = (inside_circle / total_iterations) * 4
            local end_time = os.clock()
            local duration = end_time - start_time

            print(string.format("\n  [BENCHMARK] Total execution duration: %.4f seconds", duration))
            print(string.format("  [BENCHMARK] Estimated Pi value: %.6f", pi_estimate))

            -- Basic mathematical verification guaranteeing estimation accuracy
            expect.true_(math.abs(pi_estimate - 3.14159) < 0.01)
        end)
    end)
end
