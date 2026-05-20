--!strict
local h = require("../../helpers")
local Net = require("../../../luks-std/Net")

return function(expect)
    h.suite("Net: Edge Cases and Error Paths", function()
        h.test("tcp connect returns future for unreachable address", function()
            local future = Net.TcpStream.connect("0.0.0.0:1")
            expect.not_nil(future)
            future:cancel()
        end)

        h.test("invalid ip address string returns object", function()
            local ip = Net.IpAddr.new("not.an.ip")
            expect.not_nil(ip, "IpAddr.new should return non-nil for invalid input")
        end)

        h.test("invalid socket address returns object", function()
            local sa = Net.SocketAddr.new("999.999.999.999", 80)
            expect.not_nil(sa, "SocketAddr.new should return non-nil for invalid input")
        end)

        h.test("tcp close is safe on an active connection", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            local addr = listener:local_addr():expect("local_addr failed")

            task.spawn(function()
                local conn = listener:accept():expect("accept failed")
                conn.stream:close()
                listener:close()
            end)

            local client = Net.TcpStream.connect(addr:to_string()):expect("connect failed")
            task.wait(0.5)
            local ok, err = pcall(function() client:close() end)
            expect.true_(ok)
        end)

        h.test("tcp small payload round-trip", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            local addr = listener:local_addr():expect("local_addr failed")
            local sent_data = "hello echo"

            task.spawn(function()
                local conn = listener:accept():expect("accept failed")
                conn.stream:write(sent_data):Wait()
            end)

            local client = Net.TcpStream.connect(addr:to_string()):expect("connect failed")
            task.wait(0.5)
            local buf = buffer.create(64)
            local n, ok = client:read(buf):Wait()
            expect.true_(ok)
            expect.eq(n, #sent_data)
            local received = buffer.readstring(buf, 0, n)
            expect.eq(received, sent_data)
            client:close()
        end)

        h.test("udp send_to with empty data", function()
            local s1 = Net.UdpSocket.bind("127.0.0.1:0"):expect("bind1 failed")
            local s2 = Net.UdpSocket.bind("127.0.0.1:0"):expect("bind2 failed")
            local addr2 = s2:local_addr():expect("addr2 failed")

            local ok_send, err = pcall(function()
                s1:send_to("", addr2):Wait()
            end)
            expect.true_(ok_send)

            s1:close()
            s2:close()
        end)

        h.test("ipv4 multicast and unspecified detection", function()
            local multicast = Net.IpAddr.new("224.0.0.1")
            expect.true_(multicast:is_multicast())
            expect.true_(multicast:is_v4())

            local unspecified = Net.IpAddr.new("0.0.0.0")
            expect.true_(unspecified:is_unspecified())

            local loopback = Net.IpAddr.new("127.0.0.1")
            expect.true_(loopback:is_loopback())
        end)

        h.test("ipv6 address properties", function()
            local loopback = Net.IpAddr.new("::1")
            expect.true_(loopback:is_v6())
            expect.true_(loopback:is_loopback())

            local unspecified = Net.IpAddr.new("::")
            expect.true_(unspecified:is_unspecified())
            expect.true_(unspecified:is_v6())
        end)

        h.test("tcp listener close then accept errors", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            listener:close()
            local result, ok = listener:accept():Wait()
            expect.false_(ok)
        end)
    end)
end
