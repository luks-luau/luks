--!strict
local h = require("../../helpers")
local Net = require("../../../luks-std/Net")

return function(expect)
    h.suite("Net: Advanced Features", function()
        h.test("tcp shutdown", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            local addr = listener:local_addr():expect("local_addr failed")
            
            local server_task = task.spawn(function()
                local conn = listener:accept():expect("accept failed")
                local stream = conn.stream
                
                -- Wait for client to write
                local buf = buffer.create(1024)
                stream:read(buf):expect("read failed")
                
                -- Shutdown write but keep read
                stream:shutdown("Write"):expect("shutdown write failed")
                
                -- Try to write should fail or at least be signaled
                local ok, err = pcall(function() return stream:write("data"):Wait() end)
                -- Depending on implementation, write might succeed but data never sent, 
                -- or return an error. Rust shutdown(Write) makes subsequent writes error.
                
                stream:close()
                listener:close()
            end)
            
            local client = Net.TcpStream.connect(addr:to_string()):expect("connect failed")
            client:write("hello"):expect("write failed")
            
            -- Client should receive EOF because server shutdown its write side
            local buf = buffer.create(1024)
            local n = client:read(buf):expect("read failed")
            expect.eq(n, 0) -- EOF
            
            client:close()
            
            local start = os.clock()
            while coroutine.status(server_task) ~= "dead" do
                if os.clock() - start > 2 then break end
                task.wait()
            end
        end)

        h.test("udp connected mode", function()
            local socket1 = Net.UdpSocket.bind("127.0.0.1:0"):expect("bind1 failed")
            local socket2 = Net.UdpSocket.bind("127.0.0.1:0"):expect("bind2 failed")
            
            local addr1 = socket1:local_addr():expect("addr1 failed")
            local addr2 = socket2:local_addr():expect("addr2 failed")
            
            -- Connect socket1 to socket2
            socket1:connect(addr2):expect("connect failed")
            
            local test_data = "Connected UDP!"
            
            local recv_task = task.spawn(function()
                local buf = buffer.create(1024)
                local n = socket2:recv_from(buf):expect("recv_from failed")
                expect.eq(buffer.readstring(buf, 0, n.bytes), test_data)
                
                -- Send back using connected mode if we want, but let's just test socket1 send()
                socket2:connect(addr1):expect("connect2 failed")
                socket2:send(test_data):expect("send failed")
            end)
            
            socket1:send(test_data):expect("send1 failed")
            
            local buf = buffer.create(1024)
            local n = socket1:recv(buf):expect("recv1 failed")
            expect.eq(buffer.readstring(buf, 0, n), test_data)
            
            local start = os.clock()
            while coroutine.status(recv_task) ~= "dead" do
                if os.clock() - start > 2 then break end
                task.wait()
            end
            
            socket1:close()
            socket2:close()
        end)

        h.test("tcp peek and nodelay", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            local addr = listener:local_addr():expect("local_addr failed")
            
            task.spawn(function()
                local conn = listener:accept():expect("accept failed")
                conn.stream:write("peek-a-boo"):expect("write failed")
                conn.stream:close()
                listener:close()
            end)
            
            local client = Net.TcpStream.connect(addr:to_string()):expect("connect failed")
            
            -- Test nodelay
            client:set_nodelay(true):expect("set_nodelay failed")
            expect.eq(client:nodelay():expect("get nodelay failed"), true)
            
            -- Test peek
            task.wait(0.1) -- Wait for data
            local buf = buffer.create(4)
            local n = client:peek(buf):expect("peek failed")
            expect.eq(n, 4)
            expect.eq(buffer.readstring(buf, 0, 4), "peek")
            
            -- Read should still get the same data
            local buf2 = buffer.create(4)
            local n2 = client:read(buf2):expect("read failed")
            expect.eq(n2, 4)
            expect.eq(buffer.readstring(buf2, 0, 4), "peek")
            
            client:close()
        end)

        h.test("network options (ttl, broadcast, linger)", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("listener bind failed")
            listener:set_ttl(32):expect("listener set_ttl failed")
            expect.eq(listener:ttl():expect("listener ttl failed"), 32)
            
            local udp = Net.UdpSocket.bind("127.0.0.1:0"):expect("udp bind failed")
            udp:set_ttl(64):expect("udp set_ttl failed")
            expect.eq(udp:ttl():expect("udp ttl failed"), 64)
            
            udp:set_broadcast(true):expect("set_broadcast failed")
            expect.eq(udp:broadcast():expect("broadcast failed"), true)
            
            task.spawn(function()
                local conn = listener:accept():expect("accept failed")
                local stream = conn.stream
                stream:set_ttl(45):expect("stream set_ttl failed")
                expect.eq(stream:ttl():expect("stream ttl failed"), 45)
                
                stream:close()
                listener:close()
            end)
            
            local client = Net.TcpStream.connect(listener:local_addr():Wait():to_string()):expect("connect failed")
            
            udp:close()
        end)
    end)
end
