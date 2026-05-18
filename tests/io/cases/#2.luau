--!strict
local h = require("../../helpers")
local IO = require("../../../luks-std/IO")

-- Case #2: BufReader (Buffered Reading)
return function(expect)
    h.suite("BufReader: Fundamental Operations", function()
        h.test("small reads triggered by buffering", function()
            local inner = IO.Cursor.new("0123456789")
            local reader = IO.BufReader.new(inner, 4) -- Small buffer
            
            local b = buffer.create(2)
            expect.eq(reader:read(b):unwrap(), 2)
            expect.eq(buffer.tostring(b), "01")
            
            -- Next read should use already buffered data
            expect.eq(reader:read(b):unwrap(), 2)
            expect.eq(buffer.tostring(b), "23")
        end)

        h.test("manual fill_buf and consume", function()
            local inner = IO.Cursor.new("abcdef")
            local reader = IO.BufReader.new(inner, 10)
            
            local buf = reader:fill_buf():unwrap()
            expect.eq(reader:cap(), 6)
            expect.eq(buffer.readu8(buf, reader:pos()), string.byte("a"))
            
            reader:consume(3)
            expect.eq(reader:pos(), 3)
            
            local res = reader:read_to_string():unwrap()
            expect.eq(res, "def")
        end)
    end)

    h.suite("BufReader: Delimited Reading", function()
        h.test("read_until basic and missing", function()
            local r = IO.BufReader.new(IO.Cursor.new("a,b,c"))
            
            local chunk = r:read_until(string.byte(",")):unwrap()
            expect.not_nil(chunk)
            expect.eq(buffer.tostring(chunk :: any), "a,")
            
            local rest = r:read_to_string():unwrap()
            expect.eq(rest, "b,c")
        end)

        h.test("lines() iterator verification", function()
            local r = IO.BufReader.new(IO.Cursor.new("first\nsecond\nthird"))
            local count = 0
            for line in r:lines() do
                count += 1
                if count == 1 then expect.eq(line, "first\n") end
                if count == 3 then expect.eq(line, "third") end
            end
            expect.eq(count, 3)
        end)
    end)

    h.suite("BufReader: Edge Cases", function()
        h.test("read larger than buffer bypasses it", function()
            local inner = IO.Cursor.new("0123456789ABCDEF")
            local reader = IO.BufReader.new(inner, 4)
            
            local large_buf = buffer.create(16)
            -- Should bypass internal 4-byte buffer
            expect.eq(reader:read(large_buf):unwrap(), 16)
            expect.eq(buffer.tostring(large_buf), "0123456789ABCDEF")
        end)
    end)
end
