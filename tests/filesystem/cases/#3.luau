local h = require("../../helpers")
local fs = require("../../../luks-std/FileSystem")

return function(expect)
    h.suite("FileSystem High-Throughput Sync Stress", function()
        local stress_dir = "test_fs_sync_stress_pool"

        h.test("fs rapid serial file writes, reads and deletions", function()
            if fs.exists(stress_dir) then fs.removeDirAll(stress_dir) end
            fs.createDir(stress_dir)

            local iterations = 50
            for i = 1, iterations do
                local filepath = string.format("%s/stress_file_%d.dat", stress_dir, i)
                local payload = "STRESS_PAYLOAD_DATA_" .. i

                fs.writeFile(filepath, payload)
                expect.true_(fs.isFile(filepath))
                expect.eq(fs.readFile(filepath), payload)

                local meta = fs.metadata(filepath)
                expect.true_(meta.size > 0)
            end

            -- Verify listing returns all 50 entries
            local entries = fs.readDir(stress_dir)
            expect.eq(#entries, iterations)

            -- Clean up individually to stress removeFile
            for i = 1, iterations do
                local filepath = string.format("%s/stress_file_%d.dat", stress_dir, i)
                fs.removeFile(filepath)
            end

            expect.eq(#fs.readDir(stress_dir), 0)
            fs.removeDir(stress_dir)
        end)
    end)

    h.suite("FileSystem High-Concurrency Async Stress", function()
        local async_stress_dir = "test_fs_async_stress_pool"

        h.test("fs concurrent asynchronous file instantiation flooding", function()
            if fs.exists(async_stress_dir) then fs.removeDirAll(async_stress_dir) end
            fs.createDir(async_stress_dir)

            local concurrent_tasks = 20
            local completed = 0
            local failures = 0

            for i = 1, concurrent_tasks do
                local filepath = string.format("%s/async_flood_%d.txt", async_stress_dir, i)
                fs.writeFileAsync(filepath, "async_flood_content"):Connect(function(res)
                    completed += 1
                    if not res.ok then
                        failures += 1
                    end
                end)
            end

            -- Wait for all async signals to settle
            local timeout = 0
            while completed < concurrent_tasks and timeout < 20 do
                task.wait(0.05)
                timeout += 1
            end

            expect.eq(completed, concurrent_tasks)
            expect.eq(failures, 0)

            -- Verify via listing
            local entries = fs.readDir(async_stress_dir)
            expect.eq(#entries, concurrent_tasks)

            fs.removeDirAll(async_stress_dir)
        end)
    end)
end
