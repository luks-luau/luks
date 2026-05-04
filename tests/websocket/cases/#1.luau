local h = require("../../helpers")
local WebSocket = require("../../../luks-std/WebSocket")

-- Public WebSocket echo server maintained by Postman
local ECHO_SERVER = "wss://echo.websocket.org"

return function(expect)
    h.suite("WebSocket Module API Tests", function()
        h.test("websocket module exposes connect function and version", function()
            expect.type_(WebSocket.connect, "function")
            expect.type_(WebSocket.version, "string")
        end)

        h.test("connect returns connection object with expected fields", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            expect.type_(conn, "table")
            expect.type_(conn.send, "function")
            expect.type_(conn.sendBinary, "function")
            expect.type_(conn.close, "function")
            expect.type_(conn.isOpen, "function")
            expect.type_(conn.url, "function")
            expect.type_(conn.startListening, "function")
            expect.not_nil(conn.onMessage)
            expect.not_nil(conn.onClose)
            expect.not_nil(conn.onError)

            conn:close()
        end)

        h.test("connection is open after connect", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            expect.true_(conn:isOpen(), "connection should be open immediately after connect")

            conn:close()
        end)

        h.test("url returns the original connection url", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            expect.eq(conn:url(), ECHO_SERVER)

            conn:close()
        end)

        h.test("connection is closed after close()", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            conn:close()

            expect.false_(conn:isOpen(), "connection should not be open after close")
        end)
    end)
end
