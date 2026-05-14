local h = require("../../helpers")
local WebSocket = require("../../../luks-std/WebSocket")

local ECHO_SERVER = "wss://echo.websocket.org"

return function(expect)
    h.suite("WebSocket Interface Operations & Flooding Stress", function()
        h.test("websocket rapid continuous state verification cycles over 500 iterations", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            local iterations = 500
            for _ = 1, iterations do
                expect.true_(conn:isOpen())
                expect.eq(conn:url(), ECHO_SERVER)
            end
            conn:close()
        end)

        h.test("websocket high-frequency back-to-back sequential message bursts", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            local flood_count = 5
            local echoed = 0

            conn.onMessage:Connect(function(msg)
                if msg.type == "text" and string.find(msg.data or "", "FLOOD_BURST_", 1, true) then
                    echoed += 1
                end
            end)

            conn:startListening()

            for i = 1, flood_count do
                conn:send("FLOOD_BURST_" .. i)
            end

            local timeout = 0
            while echoed < flood_count and timeout < 80 do
                task.wait(0.1)
                timeout += 1
            end

            conn:close()
            expect.eq(echoed, flood_count)
        end)
    end)
end
