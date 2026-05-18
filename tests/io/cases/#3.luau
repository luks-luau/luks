--!strict
local h = require("../../helpers")
local IO = require("../../../luks-std/IO")

-- Case #3: BufWriter (Buffered Writing)
return function(expect)
    h.suite("BufWriter: Buffering Logic", function()
        h.test("small writes are buffered until flush", function()
            local inner = IO.Cursor.new("")
            local writer = IO.BufWriter.new(inner, 10)
            
            writer:write("abc"):unwrap()
            expect.eq(buffer.len(inner:get_ref()), 0) -- Still in buffer
            
            writer:flush():unwrap()
            expect.eq(buffer.tostring(inner:get_ref()), "abc")
        end)

        h.test("automatic flush on overflow", function()
            local inner = IO.Cursor.new("")
            local writer = IO.BufWriter.new(inner, 4)
            
            writer:write("123"):unwrap()
            -- Next write of 2 bytes overflows 4-byte buffer
            writer:write("45"):unwrap()
            
            -- Buffer was 123. 45 triggers flush. 
            -- Implementation choice: flush then write 45 into empty buffer or write 45 directly.
            -- Our implementation flushes then copies 45 into buffer.
            expect.eq(buffer.tostring(inner:get_ref()):sub(1, 3), "123")
        end)
    end)

    h.suite("BufWriter: Large Writes", function()
        h.test("write_all with large content bypasses buffer", function()
            local inner = IO.Cursor.new("")
            local writer = IO.BufWriter.new(inner, 4)
            
            local large = "this_is_much_larger_than_four_bytes"
            writer:write_all(large):unwrap()
            
            expect.eq(buffer.tostring(inner:get_ref()), large)
        end)
    end)
end
