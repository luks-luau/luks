local h = require("../../helpers")
local fs = require("../../../luks-std/FileSystem")

return function(expect)
    h.suite("FileSystem Native Module Tests", function()
        local test_file = "test_fs_roundtrip.txt"
        local test_dir = "test_fs_dir"
        local nested_dir = "test_fs_nested/sub1/sub2"

        h.test("fs version property is exposed", function()
            expect.type_(fs.version, "string")
            expect.true_(#fs.version > 0)
        end)

        h.test("fs writeFile and readFile basic interaction", function()
            local content = "Premium dynamic testing for luks standard library!"
            fs.writeFile(test_file, content)

            expect.true_(fs.exists(test_file))
            expect.true_(fs.isFile(test_file))
            expect.false_(fs.isDir(test_file))

            local read_content = fs.readFile(test_file)
            expect.eq(read_content, content)
        end)

        h.test("fs metadata retrieves size, timestamps and status", function()
            local meta = fs.metadata(test_file)
            expect.type_(meta, "table")
            expect.true_(meta.is_file)
            expect.false_(meta.is_dir)
            expect.false_(meta.is_symlink)
            expect.type_(meta.size, "number")
            expect.true_(meta.size > 0)
            expect.type_(meta.modified, "number")
            expect.type_(meta.created, "number")
            expect.type_(meta.accessed, "number")
            expect.type_(meta.readonly, "boolean")
        end)

        h.test("fs createDir, readDir and removeDir explicit manipulation", function()
            if fs.exists(test_dir) then
                fs.removeDirAll(test_dir)
            end

            fs.createDir(test_dir)
            expect.true_(fs.exists(test_dir))
            expect.true_(fs.isDir(test_dir))

            local child_file = test_dir .. "/temp.txt"
            fs.writeFile(child_file, "data")

            local list = fs.readDir(test_dir)
            expect.type_(list, "table")
            expect.true_(#list >= 1)

            fs.removeFile(child_file)
            expect.false_(fs.exists(child_file))

            fs.removeDir(test_dir)
            expect.false_(fs.exists(test_dir))
        end)

        h.test("fs createDirAll and removeDirAll deep hierarchy recursion", function()
            if fs.exists("test_fs_nested") then
                fs.removeDirAll("test_fs_nested")
            end

            fs.createDirAll(nested_dir)
            expect.true_(fs.exists(nested_dir))
            expect.true_(fs.isDir(nested_dir))

            fs.removeDirAll("test_fs_nested")
            expect.false_(fs.exists("test_fs_nested"))
        end)

        h.test("fs copy and rename entity manipulation", function()
            local target_copy = "test_fs_copy.txt"
            local bytes = fs.copy(test_file, target_copy)
            expect.true_(bytes > 0)
            expect.true_(fs.exists(target_copy))

            local target_rename = "test_fs_rename.txt"
            if fs.exists(target_rename) then
                fs.removeFile(target_rename)
            end

            fs.rename(target_copy, target_rename)
            expect.false_(fs.exists(target_copy))
            expect.true_(fs.exists(target_rename))

            fs.removeFile(target_rename)
        end)

        h.test("fs raises clean Lua exceptions on failure paths", function()
            local ok, err = pcall(fs.readFile, "arquivo_inexistente_123.bin")
            expect.false_(ok)
            expect.type_(err, "string")
            expect.true_(string.find(err, "FileSystem.readFile error") ~= nil)

            local ok_dir, err_dir = pcall(fs.readDir, "caminho_invalido_dir_999")
            expect.false_(ok_dir)
            expect.type_(err_dir, "string")
        end)

        h.test("fs async operations leverage task.defer perfectly", function()
            local async_file = "test_fs_async.txt"
            
            -- Test writeFileAsync
            local write_res = nil
            local sig_write = fs.writeFileAsync(async_file, "Async content")
            sig_write:Connect(function(r) write_res = r end)
            
            task.wait(0.1)
            expect.not_nil(write_res)
            expect.true_(write_res.ok)
            expect.true_(fs.exists(async_file))

            -- Test readFileAsync
            local read_res = nil
            local sig_read = fs.readFileAsync(async_file)
            sig_read:Connect(function(r) read_res = r end)

            task.wait(0.1)
            expect.not_nil(read_res)
            expect.true_(read_res.ok)
            expect.eq(read_res.result, "Async content")

            -- Test metadataAsync
            local meta_res = nil
            local sig_meta = fs.metadataAsync(async_file)
            sig_meta:Connect(function(r) meta_res = r end)

            task.wait(0.1)
            expect.not_nil(meta_res)
            expect.true_(meta_res.ok)
            expect.true_(meta_res.result.is_file)

            -- Test existsAsync
            local exists_res = nil
            local sig_exists = fs.existsAsync(async_file)
            sig_exists:Connect(function(r) exists_res = r end)

            task.wait(0.1)
            expect.not_nil(exists_res)
            expect.true_(exists_res.ok)
            expect.true_(exists_res.result)

            -- Cleanup async file and initial test file
            fs.removeFile(async_file)
            if fs.exists(test_file) then
                fs.removeFile(test_file)
            end
        end)
    end)
end
