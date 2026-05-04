local h = require("../../helpers")
local WebSocket = require("../../../luks-std/WebSocket")

local ECHO_SERVER = "wss://echo.websocket.org"

return function(expect)
    h.suite("WebSocket Send/Receive Tests", function()
        h.test("send returns true on success", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            local result = conn:send("hello")
            expect.true_(result, "send should return true on success")

            conn:close()
        end)

        h.test("echo server reflects text message back via signal", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            local received = nil
            conn.onMessage:Connect(function(msg)
                if msg.data == "ping-test" then
                    received = msg
                end
            end)

            conn:startListening()
            conn:send("ping-test")

            -- Wait up to 5 seconds for the echo
            local waited = 0
            while received == nil and waited < 50 do
                task.wait(0.1)
                waited += 1
            end

            conn:close()

            expect.not_nil(received, "should have received echo message within 5s")
            expect.type_(received, "table")
            expect.eq(received.type, "text")
            expect.eq(received.data, "ping-test")
        end)

        h.test("multiple messages are received in order", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            local messages = {}
            conn.onMessage:Connect(function(msg)
                -- Only record our specific tagged messages
                if msg.data == "first" or msg.data == "second" or msg.data == "third" then
                    table.insert(messages, msg.data)
                end
            end)

            conn:startListening()
            conn:send("first")
            conn:send("second")
            conn:send("third")

            -- Wait for all 3 echoes (up to 8 seconds)
            local waited = 0
            while #messages < 3 and waited < 80 do
                task.wait(0.1)
                waited += 1
            end

            conn:close()

            expect.eq(#messages, 3, "should receive exactly 3 echo messages")
            expect.eq(messages[1], "first")
            expect.eq(messages[2], "second")
            expect.eq(messages[3], "third")
        end)

        h.test("onClose fires after conn:close()", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            local closeFired = false
            conn.onClose:Connect(function(_info)
                closeFired = true
            end)

            conn:startListening()
            conn:close()

            -- Wait for close event to propagate (up to 3 seconds)
            local waited = 0
            while not closeFired and waited < 30 do
                task.wait(0.1)
                waited += 1
            end

            expect.true_(closeFired, "onClose signal should have fired after close()")
        end)
    end)
end
