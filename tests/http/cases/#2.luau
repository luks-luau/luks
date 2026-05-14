local h = require("../../helpers")
local http = require("../../../luks-std/Http")

return function(expect)
    h.suite("HTTP High-Volume Encoding & Networking Stress", function()
        h.test("http intensive local utility execution cycling over 500 iterations", function()
            local iterations = 500
            for i = 1, iterations do
                local encoded = http.urlencodePart("stress_test_buffer_part_&_=" .. i)
                expect.true_(#encoded > 0)
            end
        end)

        h.test("http concurrent async get flooding", function()
            local concurrency = 5
            local completed = 0

            for _ = 1, concurrency do
                http.getAsync("https://httpbin.org/status/200"):Connect(function(res)
                    completed += 1
                    expect.true_(res.ok)
                    expect.eq(res.status, 200)
                end)
            end

            local timeout = 0
            while completed < concurrency and timeout < 60 do
                task.wait(0.1)
                timeout += 1
            end

            expect.eq(completed, concurrency)
        end)
    end)
end
