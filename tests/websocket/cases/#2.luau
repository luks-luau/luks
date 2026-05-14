local h = require("../../helpers")
local WebSocket = require("../../../luks-std/WebSocket")

local ECHO_SERVER = "wss://echo.websocket.org"

return function(expect)
    h.suite("WebSocket Text Payload Exchange", function()
        h.test("websocket send delivers string payloads returning success confirmation", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            expect.true_(conn:send("simple string payload"))
            conn:close()
        end)

        h.test("websocket onMessage captures echoed string payloads perfectly", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            local res
            conn.onMessage:Connect(function(msg)
                if msg.data == "text_echo_target" then
                    res = msg
                end
            end)

            conn:startListening()
            conn:send("text_echo_target")

            local timeout = 0
            while res == nil and timeout < 60 do
                task.wait(0.1)
                timeout += 1
            end

            conn:close()
            expect.not_nil(res)
            expect.eq(res.type, "text")
            expect.eq(res.data, "text_echo_target")
        end)
    end)

    h.suite("WebSocket Binary & Multi-frame Exchange", function()
        h.test("websocket sendBinary delivers byte buffers returning success confirmation", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            expect.true_(conn:sendBinary("binary_buffer_octets"))
            conn:close()
        end)

        h.test("websocket receives consecutive multi-message streams maintaining precise order", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            local sequence = {}
            conn.onMessage:Connect(function(msg)
                if msg.data == "msg_A" or msg.data == "msg_B" then
                    table.insert(sequence, msg.data)
                end
            end)

            conn:startListening()
            conn:send("msg_A")
            conn:send("msg_B")

            local timeout = 0
            while #sequence < 2 and timeout < 80 do
                task.wait(0.1)
                timeout += 1
            end

            conn:close()
            expect.eq(#sequence, 2)
            expect.eq(sequence[1], "msg_A")
            expect.eq(sequence[2], "msg_B")
        end)
    end)
end
