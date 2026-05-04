local h = require("../../helpers")
local WebSocket = require("../../../luks-std/WebSocket")

local ECHO_SERVER = "wss://echo.websocket.org"

return function(expect)
    h.suite("WebSocket Error Handling Tests", function()
        h.test("connect raises error on invalid host", function()
            local ok, err = pcall(WebSocket.connect, "wss://this-host-definitely-does-not-exist-luks.invalid", {
                timeout = 5,
            })

            expect.false_(ok, "connect to invalid host should raise a Lua error")
            expect.type_(err, "string")
        end)

        h.test("connect raises error on non-websocket url (plain http)", function()
            local ok, err = pcall(WebSocket.connect, "https://httpbin.org/get", {
                timeout = 5,
            })

            expect.false_(ok, "connect to HTTP endpoint should raise a Lua error")
            expect.type_(err, "string")
        end)

        h.test("connect raises error on missing url argument", function()
            local ok, err = pcall(WebSocket.connect, nil :: any)

            expect.false_(ok, "connect without URL should raise a Lua error")
            expect.type_(err, "string")
            expect.true_(
                string.find(err, "argument #1", 1, true) ~= nil,
                "error should mention argument #1"
            )
        end)

        h.test("send raises error on invalid handle after close", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            conn:close()

            -- After close the handle is removed from the registry
            local ok, err = pcall(function()
                conn:send("should fail")
            end)

            expect.false_(ok, "send on closed connection should raise an error")
            expect.type_(err, "string")
        end)

        h.test("multiple concurrent connections are independent", function()
            local conn1 = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            local conn2 = WebSocket.connect(ECHO_SERVER, { timeout = 15 })

            expect.true_(conn1:isOpen(), "conn1 should be open")
            expect.true_(conn2:isOpen(), "conn2 should be open")

            expect.eq(conn1:url(), ECHO_SERVER)
            expect.eq(conn2:url(), ECHO_SERVER)

            conn1:close()
            conn2:close()

            expect.false_(conn1:isOpen(), "conn1 should be closed")
            expect.false_(conn2:isOpen(), "conn2 should be closed")
        end)

        h.test("connect with custom headers succeeds", function()
            local conn = WebSocket.connect(ECHO_SERVER, {
                timeout = 15,
                headers = {
                    ["User-Agent"] = "luks-luau-test/0.1",
                },
            })

            expect.true_(conn:isOpen(), "connection with custom headers should succeed")

            conn:close()
        end)
    end)
end
