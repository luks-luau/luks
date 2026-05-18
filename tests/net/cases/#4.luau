--!strict
local h = require("../../helpers")
local Net = require("../../../luks-std/Net")
local Async = require("../../../luks-std/async")

return function(expect)
    h.suite("Net: Stress Testing", function()
        h.test("50 concurrent connections", function()
            -- Note: Windows/User limits might prevent 500 easily without config, 
            -- let's start with 50 and see stability.
            local listener = Net.TcpListener.bind("127.0.0.1:0"):expect("bind failed")
            local port = listener:local_addr():expect("addr failed"):port()
            
            local connections_to_make = 50
            local server_count = 0
            
            -- Server task: accept many connections
            task.spawn(function()
                while server_count < connections_to_make do
                    local conn = listener:accept():expect("server accept failed")
                    server_count += 1
                    task.spawn(function()
                        local buf = buffer.create(16)
                        conn.stream:read(buf):expect("server read failed")
                        conn.stream:write("ACK"):expect("server write failed")
                        conn.stream:close()
                    end)
                end
                listener:close()
            end)
            
            -- Client tasks
            local client_futures = {}
            for i = 1, connections_to_make do
                local fut = task.spawn(function()
                    local stream = Net.TcpStream.connect("127.0.0.1:" .. port):expect("client connect failed")
                    stream:write("PING"):expect("client write failed")
                    local buf = buffer.create(16)
                    local n = stream:read(buf):expect("client read failed")
                    expect.eq(buffer.readstring(buf, 0, n), "ACK")
                    stream:close()
                end)
                table.insert(client_futures, fut)
            end
            
            -- Wait for all clients (polling server_count)
            local start = os.clock()
            while server_count < connections_to_make do
                if os.clock() - start > 10 then
                    error("Stress test timed out! Handled " .. server_count .. "/" .. connections_to_make)
                end
                task.wait()
            end
            
            expect.eq(server_count, connections_to_make)
        end)
    end)
end
