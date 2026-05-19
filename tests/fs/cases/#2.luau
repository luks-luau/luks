--!strict
local h = require("../../helpers")
local FS = require("../../../luks-std/fs")

return function(expect)
    h.suite("FS: File Object Advanced", function()
        h.test("seek and position", function()
            local path = "test_seek.bin"
            local file = FS.File.create(path):expect("")
            file:write_all("0123456789"):expect("")
            
            -- Seek from Start
            local pos = file:seek({ kind = "Start", pos = 5 }):expect("seek start failed")
            expect.eq(pos, 5)
            expect.eq(file:position():expect("position failed"), 5)
            
            -- Seek from Current
            pos = file:seek({ kind = "Current", pos = -2 }):expect("seek current failed")
            expect.eq(pos, 3)
            
            -- Seek from End
            pos = file:seek({ kind = "End", pos = -1 }):expect("seek end failed")
            expect.eq(pos, 9)
            
            file:close()
            FS.remove_file(path):expect("")
        end)

        h.test("read_exact behavior", function()
            local path = "test_read_exact.txt"
            FS.write(path, "precise data"):expect("")
            
            local file = FS.File.open(path):expect("")
            local buf = buffer.create(7)
            file:read_exact(buf, 7):expect("read_exact failed")
            expect.eq(buffer.tostring(buf), "precise")
            
            -- Should fail if not enough data
            local _, ok = file:read_exact(buf, 7):Wait()
            expect.false_(ok, "read_exact should fail at EOF")
            
            file:close()
            FS.remove_file(path):expect("")
        end)

        h.test("set_len truncation and expansion", function()
            local path = "test_set_len.txt"
            FS.write(path, "12345"):expect("")
            
            local file = FS.OpenOptions.new():write(true):open(path):expect("")
            
            -- Truncate
            file:set_len(3):expect("set_len truncate failed")
            file:close()
            expect.eq(#FS.read_to_string(path):expect(""), 3)
            
            -- Expand
            file = FS.OpenOptions.new():write(true):open(path):expect("")
            file:set_len(10):expect("set_len expand failed")
            file:close()
            local meta = FS.metadata(path):expect("")
            expect.eq(meta:len(), 10)
            
            FS.remove_file(path):expect("")
        end)

        h.test("sync operations", function()
            local path = "test_sync.txt"
            local file = FS.File.create(path):expect("")
            file:write_all("valuable data"):expect("")
            
            file:sync_data():expect("sync_data failed")
            file:sync_all():expect("sync_all failed")
            
            file:close()
            FS.remove_file(path):expect("")
        end)
    end)
end
