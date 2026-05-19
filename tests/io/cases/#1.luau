--!strict
local h = require("../../helpers")
local IO = require("../../../luks-std/IO")

-- Case #1: Cursor (In-memory Streams)
return function(expect)
    h.suite("IO Cursor: Reading", function()
        h.test("read with buffer offset and length", function()
            local c = IO.Cursor.new("0123456789")
            local buf = buffer.create(10)
            buffer.fill(buf, 0, 0)
            
            -- Read 3 bytes into index 2
            local n = c:read(buf, 2, 3):unwrap()
            expect.eq(n, 3)
            expect.eq(buffer.readu8(buf, 2), string.byte("0"))
            expect.eq(buffer.readu8(buf, 4), string.byte("2"))
        end)

        h.test("read_to_end and position tracking", function()
            local c = IO.Cursor.new("hello world")
            c:read(buffer.create(6)):unwrap() -- Consume "hello "
            
            expect.eq(c:position():unwrap(), 6)
            local rest = c:read_to_end():unwrap()
            expect.eq(buffer.tostring(rest), "world")
            expect.eq(c:position():unwrap(), 11)
        end)

        h.test("read_exact failure at EOF", function()
            local c = IO.Cursor.new("12")
            local res, ok = c:read_exact(buffer.create(3), 3):Wait()
            expect.eq(ok, false)
        end)
    end)

    h.suite("IO Cursor: Writing", function()
        h.test("write and expand buffer", function()
            local c = IO.Cursor.new("")
            c:write("luks"):unwrap()
            expect.eq(buffer.tostring(c:get_ref()), "luks")
            
            c:seek({ kind = "Start", pos = 2 }):unwrap()
            c:write("XX"):unwrap()
            expect.eq(buffer.tostring(c:get_ref()), "luXX")
        end)

        h.test("write_all with string", function()
            local c = IO.Cursor.new("prefix_")
            c:seek({ kind = "End", pos = 0 }):unwrap()
            c:write_all("suffix"):unwrap()
            expect.eq(buffer.tostring(c:get_ref()), "prefix_suffix")
        end)
    end)

    h.suite("IO Cursor: Seeking", function()
        h.test("SeekFrom.End with negative offset", function()
            local c = IO.Cursor.new("12345")
            local pos = c:seek({ kind = "End", pos = -2 }):unwrap()
            expect.eq(pos, 3)
            
            local b = buffer.create(1)
            c:read(b):unwrap()
            expect.eq(buffer.tostring(b), "4")
        end)

        h.test("SeekFrom.Current relative moves", function()
            local c = IO.Cursor.new("abcdef")
            c:read(buffer.create(2)):unwrap() -- pos = 2
            c:seek({ kind = "Current", pos = 2 }):unwrap() -- pos = 4
            
            local b = buffer.create(1)
            c:read(b):unwrap()
            expect.eq(buffer.tostring(b), "e")
        end)

        h.test("error on negative absolute seek", function()
            local c = IO.Cursor.new("test")
            local res, ok = c:seek({ kind = "Start", pos = -1 }):Wait()
            expect.eq(ok, false)
        end)
    end)
end
