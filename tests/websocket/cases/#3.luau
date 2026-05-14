local h = require("../../helpers")
local WebSocket = require("../../../luks-std/WebSocket")

local ECHO_SERVER = "wss://echo.websocket.org"

return function(expect)
    h.suite("WebSocket Handshake Exceptions", function()
        h.test("websocket connect raises exception intercepting unreachable host endpoints", function()
            local ok, err = pcall(WebSocket.connect, "wss://unreachable-host-target-namespace-999.invalid", { timeout = 5 })
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("websocket connect raises exception intercepting unencrypted raw http targets", function()
            local ok, err = pcall(WebSocket.connect, "https://httpbin.org/get", { timeout = 5 })
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("websocket connect enforces required uri string parameter check", function()
            local ok, err = pcall(WebSocket.connect, nil :: any)
            expect.false_(ok)
            expect.type_(err, "string")
        end)
    end)

    h.suite("WebSocket Runtime Boundaries", function()
        h.test("websocket send blocks attempts targeting finalized socket allocations", function()
            local conn = WebSocket.connect(ECHO_SERVER, { timeout = 15 })
            conn:close()
            local ok, err = pcall(function() conn:send("stale payload") end)
            expect.false_(ok)
            expect.type_(err, "string")
        end)

        h.test("websocket connect incorporates customized map parameters successfully", function()
            local conn = WebSocket.connect(ECHO_SERVER, {
                headers = { ["Custom-Luks-Header"] = "Active" },
                timeout = 15
            })
            expect.true_(conn:isOpen())
            conn:close()
        end)
    end)
end
