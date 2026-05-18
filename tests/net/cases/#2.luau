--!strict
local h = require("../../helpers")
local Net = require("../../../luks-std/Net")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Net: TCP Echo Lifecycle", function()
        h.test("echo server and client", function()
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            local addr = listener:local_addr():expect("local_addr failed")
            local port = addr:port()
            
            local test_data = "Hello Luks Networking!"
            local server_received = ""
            
            -- Server task
            local server_task = task.spawn(function()
                local conn = listener:accept():expect("accept failed")
                local stream = conn.stream
                
                local buf = buffer.create(1024)
                local n = stream:read(buf):expect("read failed")
                server_received = buffer.readstring(buf, 0, n)
                
                stream:write(server_received):expect("write failed")
                stream:close()
                listener:close()
            end)
            
            -- Client task
            local stream = Net.TcpStream.connect("127.0.0.1:" .. port):expect("connect failed")
            stream:write(test_data):expect("client write failed")
            
            local read_buf = buffer.create(1024)
            local n = stream:read(read_buf):expect("client read failed")
            local response = buffer.readstring(read_buf, 0, n)
            
            expect.eq(response, test_data)
            expect.eq(server_received, test_data)
            
            -- Ensure server task is finished
            local start = os.clock()
            while coroutine.status(server_task) ~= "dead" do
                if os.clock() - start > 2 then break end
                task.wait()
            end

            stream:close()
        end)
    end)
end
