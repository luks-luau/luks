--!strict
local h = require("../../helpers")
local FS = require("../../../luks-std/FS")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("FS: Directory Iteration", function()
        h.test("read_dir full traversal", function()
            local root = "test_readdir_all"
            pcall(function() FS.remove_dir_all(root):Wait() end)
            FS.create_dir_all(root):expect("")
            
            local count = 5
            for i = 1, count do
                FS.write(string.format("%s/file%d.txt", root, i), tostring(i)):expect("")
            end
            
            local it = FS.read_dir(root):expect("read_dir failed")
            local found = 0
            while true do
                local entry = it:next():expect("next failed")
                if not entry then break end
                found += 1
                expect.type_(entry.name, "string")
                expect.true_(entry:metadata():expect(""):is_file())
                expect.true_(entry:file_type():expect(""):is_file())
            end
            expect.eq(found, count)
            
            FS.remove_dir_all(root):expect("")
        end)
    end)

    h.suite("FS: Stress Testing", function()
        h.test("concurrent massive writes and reads", function()
            local root = "test_fs_stress"
            pcall(function() FS.remove_dir_all(root):Wait() end)
            FS.create_dir_all(root):expect("")
            
            local iterations = 100
            local futures = {}
            
            for i = 1, iterations do
                local path = string.format("%s/stress_%d.txt", root, i)
                local data = string.rep("X", 1024) -- 1KB
                
                local fut = FS.write(path, data):and_then(function()
                    return FS.read_to_string(path)
                end):inspect(function(read)
                    if read ~= data then
                        error("Stress data mismatch at " .. i)
                    end
                end)
                
                table.insert(futures, fut)
            end
            
            -- Wait for all futures to complete using join
            Async.join(futures):expect("Massive concurrent operations failed")
            
            -- Verify directory count
            local it = FS.read_dir(root):expect("")
            local found = 0
            while it:next():expect("") do found += 1 end
            expect.eq(found, iterations)
            
            FS.remove_dir_all(root):expect("")
        end)

        h.test("rapid handle churn", function()
            local path = "test_churn.txt"
            FS.write(path, "initial"):expect("")
            
            for i = 1, 200 do
                local file = FS.File.open(path):expect("failed at open " .. i)
                file:read_to_string():expect("failed at read " .. i)
                file:close()
            end
            
            FS.remove_file(path):expect("")
        end)
    end)
end
