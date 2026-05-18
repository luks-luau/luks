--!strict
local h = require("../../helpers")
local IO = require("../../../luks-std/IO")

-- Case #5: Utilities & Streams
return function(expect)
    h.suite("IO Global Utilities", function()
        h.test("IO.copy: large data transfer", function()
            local size = 65536 -- 64KB
            local src = IO.repeat_byte(string.byte(".")):take(size)
            local dst = IO.Cursor.new("")
            
            local copied = IO.copy(src, dst):unwrap()
            expect.eq(copied, size)
            expect.eq(buffer.len(dst:get_ref()), size)
        end)

        h.test("IO.empty and IO.sink consistency", function()
            local empty = IO.empty()
            local sink = IO.sink()
            
            expect.eq(empty:read(buffer.create(10)):unwrap(), 0)
            expect.eq(sink:write("ignored"):unwrap(), 7)
            sink:flush():unwrap() -- Should not error
        end)
    end)

    h.suite("Standard Streams", function()
        h.test("stdout and stderr write access", function()
            local out = IO.stdout()
            local err = IO.stderr()
            
            -- We just verify methods exist and don't crash
            expect.not_nil(out.write)
            expect.not_nil(err.write)
            
            out:flush():unwrap()
            err:flush():unwrap()
        end)

        h.test("stdin availability", function()
            local si = IO.stdin()
            expect.not_nil(si.read)
        end)
    end)
end
