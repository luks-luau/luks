local h = require("../../helpers")
local fs = require("../../../luks-std/FileSystem")

return function(expect)
    h.suite("FileSystem Sync File Edge Cases", function()
        local empty_file = "test_fs_empty_payload.txt"

        h.test("fs writeFile and readFile with empty string payload", function()
            fs.writeFile(empty_file, "")
            expect.true_(fs.exists(empty_file))
            expect.true_(fs.isFile(empty_file))
            expect.eq(fs.readFile(empty_file), "")
            fs.removeFile(empty_file)
        end)

        h.test("fs isFile and isDir verification on non-existent paths", function()
            local missing = "non_existent_path_file_999.xyz"
            expect.false_(fs.isFile(missing))
            expect.false_(fs.isDir(missing))
            expect.false_(fs.exists(missing))
        end)
    end)

    h.suite("FileSystem Sync Directory Edge Cases", function()
        local empty_dir = "test_fs_pristine_dir"
        local fail_dir = "test_fs_fail_rem_dir"

        h.test("fs readDir returns empty table on pristine directory", function()
            if fs.exists(empty_dir) then fs.removeDirAll(empty_dir) end
            fs.createDir(empty_dir)
            local entries = fs.readDir(empty_dir)
            expect.type_(entries, "table")
            expect.eq(#entries, 0)
            fs.removeDir(empty_dir)
        end)

        h.test("fs createDir fails gracefully on missing parent path", function()
            local ok, err = pcall(fs.createDir, "missing_parent_folder_000/child_dir")
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("fs removeDir fails gracefully on non-empty directory", function()
            if fs.exists(fail_dir) then fs.removeDirAll(fail_dir) end
            fs.createDir(fail_dir)
            local inner = fail_dir .. "/temp.txt"
            fs.writeFile(inner, "locked")
            
            local ok, err = pcall(fs.removeDir, fail_dir)
            expect.false_(ok)
            expect.type_(err, "string")

            fs.removeDirAll(fail_dir)
        end)
    end)

    h.suite("FileSystem Sync Modification Edge Cases", function()
        local base_file = "test_fs_src_overwrite.txt"
        local dest_file = "test_fs_dst_overwrite.txt"
        local rename_src = "test_fs_rename_src_folder"
        local rename_dst = "test_fs_rename_dst_folder"

        h.test("fs removeFile raises exception on non-existent target", function()
            local ok, _err = pcall(fs.removeFile, "non_existent_file_to_scrub.txt")
            expect.false_(ok)
        end)

        h.test("fs copy successfully overwrites an existing file destination", function()
            fs.writeFile(base_file, "original_content")
            fs.writeFile(dest_file, "stale_content")

            local bytes = fs.copy(base_file, dest_file)
            expect.true_(bytes > 0)
            expect.eq(fs.readFile(dest_file), "original_content")

            fs.removeFile(base_file)
            fs.removeFile(dest_file)
        end)

        h.test("fs rename successfully updates directory identification", function()
            if fs.exists(rename_src) then fs.removeDirAll(rename_src) end
            if fs.exists(rename_dst) then fs.removeDirAll(rename_dst) end

            fs.createDir(rename_src)
            fs.rename(rename_src, rename_dst)

            expect.false_(fs.exists(rename_src))
            expect.true_(fs.isDir(rename_dst))

            fs.removeDir(rename_dst)
        end)
    end)

    h.suite("FileSystem Async Inspection & Structure Creation", function()
        local single_dir = "test_fs_async_single_dir"
        local deep_dir = "test_fs_async_deep_hierarchy/sub1/sub2"

        h.test("fs isFileAsync and isDirAsync resolve false on absent entities", function()
            local f_res, d_res
            fs.isFileAsync("absent_async_target.none"):Connect(function(r) f_res = r end)
            fs.isDirAsync("absent_async_target.none"):Connect(function(r) d_res = r end)
            task.wait(0.1)
            expect.not_nil(f_res)
            expect.true_(f_res.ok)
            expect.false_(f_res.result)

            expect.not_nil(d_res)
            expect.true_(d_res.ok)
            expect.false_(d_res.result)
        end)

        h.test("fs createDirAsync instantiates single directory frame reliably", function()
            if fs.exists(single_dir) then fs.removeDirAll(single_dir) end
            local res
            fs.createDirAsync(single_dir):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.true_(fs.isDir(single_dir))
        end)

        h.test("fs isDirAsync confirms positive allocation on active directory", function()
            local res
            fs.isDirAsync(single_dir):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.true_(res.result)
        end)

        h.test("fs readDirAsync fetches empty listing array correctly", function()
            local res
            fs.readDirAsync(single_dir):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.type_(res.result, "table")
            expect.eq(#res.result, 0)
        end)

        h.test("fs removeDirAsync removes isolated directory successfully", function()
            local res
            fs.removeDirAsync(single_dir):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.false_(fs.exists(single_dir))
        end)

        h.test("fs createDirAllAsync instantiates deep folder structures", function()
            if fs.exists("test_fs_async_deep_hierarchy") then
                fs.removeDirAll("test_fs_async_deep_hierarchy")
            end
            local res
            fs.createDirAllAsync(deep_dir):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.true_(fs.isDir(deep_dir))
        end)

        h.test("fs removeDirAllAsync recursively scrubs deep hierarchy", function()
            local res
            fs.removeDirAllAsync("test_fs_async_deep_hierarchy"):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.false_(fs.exists("test_fs_async_deep_hierarchy"))
        end)
    end)

    h.suite("FileSystem Async File Manipulation & Failures", function()
        local src_file = "test_fs_async_src.txt"
        local dst_file = "test_fs_async_dst.txt"
        local renamed_file = "test_fs_async_renamed.txt"

        h.test("fs isFileAsync validates positive file storage presence", function()
            fs.writeFile(src_file, "async duplication payload")
            local res
            fs.isFileAsync(src_file):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.true_(res.result)
        end)

        h.test("fs copyAsync duplicates payload octets seamlessly", function()
            if fs.exists(dst_file) then fs.removeFile(dst_file) end
            local res
            fs.copyAsync(src_file, dst_file):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.true_(res.result > 0)
            expect.eq(fs.readFile(dst_file), "async duplication payload")
        end)

        h.test("fs renameAsync relocates file mapping pointer cleanly", function()
            if fs.exists(renamed_file) then fs.removeFile(renamed_file) end
            local res
            fs.renameAsync(dst_file, renamed_file):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.false_(fs.exists(dst_file))
            expect.true_(fs.exists(renamed_file))
        end)

        h.test("fs removeFileAsync destroys target file successfully", function()
            local res
            fs.removeFileAsync(renamed_file):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.false_(fs.exists(renamed_file))
            
            -- Cleanup source file
            if fs.exists(src_file) then fs.removeFile(src_file) end
        end)

        h.test("fs readFileAsync propagates diagnostic errors on failure", function()
            local res
            fs.readFileAsync("async_non_existent_file_path_000.bin"):Connect(function(r) res = r end)
            task.wait(0.1)
            expect.not_nil(res)
            expect.false_(res.ok)
            expect.type_(res.error, "string")
            expect.nil_(res.result)
        end)
    end)
end
