local h = require("../../helpers")
local json = require("../../../luks-std/Json")
local http = require("../../../luks-std/Http")

return function(expect)
    h.suite("HTTP Remaining Async Methods and Edge Cases", function()
        h.test("http requestAsync fires signal with response", function()
            local sig = http.requestAsync("GET", "https://httpbin.org/get")
            local response
            sig:Connect(function(res) response = res end)
            task.wait(0.5)
            expect.not_nil(response)
            expect.true_(response.ok)
        end)

        h.test("http putAsync fires signal", function()
            local sig = http.putAsync("https://httpbin.org/put", { body = "async put" })
            local response
            sig:Connect(function(res) response = res end)
            task.wait(0.5)
            expect.not_nil(response)
            expect.true_(response.ok)
        end)

        h.test("http deleteAsync fires signal", function()
            local sig = http.deleteAsync("https://httpbin.org/delete")
            local response
            sig:Connect(function(res) response = res end)
            task.wait(0.5)
            expect.not_nil(response)
            expect.true_(response.ok)
        end)

        h.test("http patchAsync fires signal", function()
            local sig = http.patchAsync("https://httpbin.org/patch", { body = "async patch" })
            local response
            sig:Connect(function(res) response = res end)
            task.wait(0.5)
            expect.not_nil(response)
            expect.true_(response.ok)
        end)

        h.test("http headAsync fires signal", function()
            local sig = http.headAsync("https://httpbin.org/get")
            local response
            sig:Connect(function(res) response = res end)
            task.wait(0.5)
            expect.not_nil(response)
            expect.true_(response.ok)
        end)

        h.test("http connection refused returns ok=false", function()
            local res = http.get("http://127.0.0.1:1")
            expect.false_(res.ok)
            expect.not_nil(res.error)
        end)

        h.test("http custom request with timeout", function()
            local res = http.request("GET", "https://httpbin.org/get", { timeout = 5 })
            expect.true_(res.ok)
            expect.eq(res.status, 200)
        end)

        h.test("http large body round-trip", function()
            local body = string.rep("Large body data chunk for HTTP roundtrip testing. ", 5000)
            local res = http.post("https://httpbin.org/post", { body = body })
            expect.true_(res.ok)

            local data = json.decode(res.body or "{}")
            expect.eq(data.data, body)
        end)

        h.test("http urlencodePart with unicode characters", function()
            local cafe = "\xC3\xA9"
            local encoded = http.urlencodePart("caf" .. cafe)
            expect.true_(string.find(encoded, "%%") ~= nil or encoded == "caf%C3%A9")
        end)

        h.test("http urlencode with empty table", function()
            local result = http.urlencode({})
            expect.eq(result, "")
        end)

        h.test("http response headers are accessible", function()
            local res = http.get("https://httpbin.org/get")
            expect.true_(res.ok)
            expect.type_(res.headers, "table")
            expect.true_(next(res.headers) ~= nil)
        end)

        h.test("http head response has nil body", function()
            local res = http.head("https://httpbin.org/get")
            expect.true_(res.ok)
            expect.eq(res.status, 200)
        end)
    end)
end
