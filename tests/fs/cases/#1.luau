--!strict
local h = require("../../helpers")
local FS = require("../../../luks-std/fs")

return function(expect)
    h.suite("FS: Static Utilities", function()
        h.test("write and read_to_string", function()
            local path = "test_static_string.txt"
            FS.write(path, "luks runtime"):expect("write failed")
            local content = FS.read_to_string(path):expect("read failed")
            expect.eq(content, "luks runtime")
            FS.remove_file(path):expect("cleanup failed")
        end)

        h.test("write and read (buffer)", function()
            local path = "test_static_buffer.bin"
            local data = buffer.create(4)
            buffer.writeu32(data, 0, 0xDEADBEEF)
            
            FS.write(path, data):expect("write failed")
            local res = FS.read(path):expect("read failed")
            expect.eq(buffer.readu32(res, 0), 0xDEADBEEF)
            FS.remove_file(path):expect("cleanup failed")
        end)

        h.test("copy operation", function()
            local src = "test_copy_src.txt"
            local dst = "test_copy_dst.txt"
            FS.write(src, "source content"):expect("")
            
            local bytes = FS.copy(src, dst):expect("copy failed")
            expect.eq(bytes, 14)
            expect.eq(FS.read_to_string(dst):expect(""), "source content")
            
            FS.remove_file(src):expect("")
            FS.remove_file(dst):expect("")
        end)

        h.test("rename operation", function()
            local old = "test_rename_old.txt"
            local new = "test_rename_new.txt"
            FS.write(old, "data"):expect("")
            
            FS.rename(old, new):expect("rename failed")
            expect.eq(FS.read_to_string(new):expect(""), "data")
            
            local _, ok = FS.metadata(old):Wait()
            expect.false_(ok, "old file should not exist")
            
            FS.remove_file(new):expect("")
        end)
    end)

    h.suite("FS: OpenOptions Builder", function()
        h.test("create_new failure on existing file", function()
            local path = "test_create_new.txt"
            FS.write(path, "exists"):expect("")
            
            local opts = FS.OpenOptions.new():write(true):create_new(true)
            local _, ok = opts:open(path):Wait()
            expect.false_(ok, "open should fail with create_new on existing file")
            
            FS.remove_file(path):expect("")
        end)

        h.test("append mode", function()
            local path = "test_append.txt"
            FS.write(path, "A"):expect("")
            
            local file = FS.OpenOptions.new():write(true):append(true):open(path):expect("")
            file:write_all("B"):expect("")
            file:close()
            
            expect.eq(FS.read_to_string(path):expect(""), "AB")
            FS.remove_file(path):expect("")
        end)

        h.test("truncate mode", function()
            local path = "test_truncate.txt"
            FS.write(path, "LONGER CONTENT"):expect("")
            
            local file = FS.OpenOptions.new():write(true):truncate(true):open(path):expect("")
            file:write_all("S"):expect("")
            file:close()
            
            expect.eq(FS.read_to_string(path):expect(""), "S")
            FS.remove_file(path):expect("")
        end)
    end)
end
