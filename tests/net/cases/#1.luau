--!strict
local h = require("../../helpers")
local Net = require("../../../luks-std/Net")

return function(expect)
    h.suite("Net: Addressing", function()
        h.test("IpAddr v4 and v6 parsing", function()
            local v4 = Net.IpAddr.new("127.0.0.1")
            expect.true_(v4:is_v4())
            expect.false_(v4:is_v6())
            expect.true_(v4:is_loopback())
            expect.eq(v4:to_string(), "127.0.0.1")
            
            local v6 = Net.IpAddr.new("::1")
            expect.true_(v6:is_v6())
            expect.true_(v6:is_loopback())
            expect.eq(v6:to_string(), "::1")
        end)

        h.test("SocketAddr creation and parsing", function()
            local addr = Net.SocketAddr.new("127.0.0.1", 8080)
            expect.eq(addr:port(), 8080)
            expect.eq(addr:to_string(), "127.0.0.1:8080")
            
            local parsed = Net.SocketAddr.parse("[::1]:443")
            expect.true_(parsed:ip():is_v6())
            expect.eq(parsed:port(), 443)
        end)
    end)

    h.suite("Net: TCP Basic", function()
        h.test("TcpListener bind", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("Failed to bind")
            expect.not_nil(listener)
            listener:close()
        end)
    end)
end
