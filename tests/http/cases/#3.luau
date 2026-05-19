local h = require("../../helpers")
local json = require("../../../luks-std/Json")
local http = require("../../../luks-std/Http")

return function(expect)
    h.suite("HTTP Null Byte Handling in Body", function()
        h.test("http post preserves null bytes in binary body", function()
            local body = "binary\0data\0with\0zeros"
            local res = http.post("https://httpbin.org/post", {
                headers = { ["Content-Type"] = "application/octet-stream" },
                body = body,
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)

            local data = json.decode(res.body or "{}")
            expect.type_(data.data, "string")
            expect.eq(data.data, body)
        end)

        h.test("http put preserves null bytes in binary body", function()
            local body = "put\0payload\0test"
            local res = http.put("https://httpbin.org/put", {
                body = body,
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)

            local data = json.decode(res.body or "{}")
            expect.type_(data.data, "string")
            expect.eq(data.data, body)
        end)

        h.test("http patch preserves null bytes in binary body", function()
            local body = "patch\0data\0here"
            local res = http.patch("https://httpbin.org/patch", {
                body = body,
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)

            local data = json.decode(res.body or "{}")
            expect.type_(data.data, "string")
            expect.eq(data.data, body)
        end)

        h.test("http request with custom method preserves null bytes in body", function()
            local body = "custom\0body\0test"
            local res = http.request("POST", "https://httpbin.org/post", {
                body = body,
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)

            local data = json.decode(res.body or "{}")
            expect.type_(data.data, "string")
            expect.eq(data.data, body)
        end)

        h.test("http post with empty string body round-trips correctly", function()
            local res = http.post("https://httpbin.org/post", {
                body = "",
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)

            local data = json.decode(res.body or "{}")
            expect.eq(data.data, "")
        end)

        h.test("http post without body field does not send payload", function()
            local res = http.post("https://httpbin.org/post", {})
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)

            local data = json.decode(res.body or "{}")
            expect.eq(data.data, "")
        end)
    end)
end
