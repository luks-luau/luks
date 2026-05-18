--!strict
local h = require("../../helpers")
local Net = require("../../../luks-std/Net")

return function(expect)
    h.suite("Net: UDP Echo", function()
        h.test("udp send_to and recv_from", function()
            local socket1 = Net.UdpSocket.bind("127.0.0.1:0"):expect("socket1 bind failed")
            local socket2 = Net.UdpSocket.bind("127.0.0.1:0"):expect("socket2 bind failed")
            
            local addr1 = socket1:local_addr():expect("local_addr1 failed")
            local addr2 = socket2:local_addr():expect("local_addr2 failed")
            
            local test_data = "UDP Packet from Luks!"
            
            -- Task for receiving
            local recv_task = task.spawn(function()
                local buf = buffer.create(1024)
                local res = socket1:recv_from(buf):expect("recv_from failed")
                local received_str = buffer.readstring(buf, 0, res.bytes)
                
                expect.eq(received_str, test_data)
                expect.eq(res.addr:to_string(), addr2:to_string())
            end)
            
            -- Send from socket2 to socket1
            socket2:send_to(test_data, addr1):expect("send_to failed")
            
            -- Wait for the receive task to finish
            local start = os.clock()
            while coroutine.status(recv_task) ~= "dead" do
                if os.clock() - start > 2 then
                    error("UDP test timed out")
                end
                task.wait()
            end
            
            socket1:close()
            socket2:close()
        end)
    end)
end
