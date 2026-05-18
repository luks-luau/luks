--!strict
local h = require("../../helpers")
local IO = require("../../../luks-std/IO")

-- Case #4: Combinators (Take, Chain, Repeat)
return function(expect)
    h.suite("IO.Repeat", function()
        h.test("repeat_byte generates data", function()
            local r = IO.repeat_byte(string.byte("Z"))
            local b = buffer.create(100)
            expect.eq(r:read(b):unwrap(), 100)
            expect.eq(buffer.tostring(b):sub(1, 1), "Z")
        end)
    end)

    h.suite("Reader: Take", function()
        h.test("take limits input", function()
            local inner = IO.Cursor.new("0123456789")
            local t = inner:take(5)
            
            expect.eq(t:read_to_string():unwrap(), "01234")
            expect.eq(t:read(buffer.create(1)):unwrap(), 0) -- EOF
        end)

        h.test("take: set_limit", function()
            local t = IO.repeat_byte(65):take(10)
            expect.eq(t:read(buffer.create(5)):unwrap(), 5);
            (t :: any):set_limit(2)
            expect.eq(t:read(buffer.create(10)):unwrap(), 2)
        end)
    end)

    h.suite("Reader: Chain", function()
        h.test("chain transitions correctly", function()
            local a = IO.Cursor.new("AAA")
            local b = IO.Cursor.new("BBB")
            local c = a:chain(b)
            
            expect.eq(c:read_to_string():unwrap(), "AAABBB")
        end)

        h.test("nested chaining", function()
            local chained = IO.Cursor.new("1")
                :chain(IO.Cursor.new("2"))
                :chain(IO.Cursor.new("3"))
            
            expect.eq(chained:read_to_string():unwrap(), "123")
        end)
    end)

    h.suite("Fluent Combinators", function()
        h.test("repeat -> take -> chain -> take", function()
            local r = IO.repeat_byte(65) -- A
            local stream = r:take(2):chain(IO.repeat_byte(66):take(2)) -- AABB
            
            expect.eq(stream:read_to_string():unwrap(), "AABB")
        end)
    end)
end
