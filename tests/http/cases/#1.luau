local h = require("../../helpers")
local json = require("../../../luks-std/Json")
local http = require("../../../luks-std/Http")

return function(expect)
    h.suite("HTTP Native Module Tests", function()
        h.test("http module exposes request functions", function()
            expect.type_(http.version, "string")
            expect.type_(http.get, "function")
            expect.type_(http.post, "function")
            expect.type_(http.request, "function")
        end)

        h.test("http get returns successful response", function()
            local response = http.get("https://httpbin.org/get", {
                ["Accept"] = "application/json",
            })

            expect.type_(response, "table")
            expect.true_(response.ok, response.error or response.status_text)
            expect.eq(response.status, 200)
            expect.type_(response.body, "string")
        end)

        h.test("http post sends json body and headers", function()
            local payload = {
                level = 5,
                nome = "yanlvl99",
            }
            local response = http.post("https://httpbin.org/post", {
                headers = {
                    ["Content-Type"] = "application/json",
                },
                body = json.encode(payload),
                timeout = 10,
            })

            expect.type_(response, "table")
            expect.true_(response.ok, response.error or response.status_text)
            expect.eq(response.status, 200)
            expect.type_(response.body, "string")

            local decoded = json.decode(response.body)
            expect.eq(decoded.json.level, 5)
            expect.eq(decoded.json.nome, "yanlvl99")
            expect.eq(decoded.url, "https://httpbin.org/post")
        end)

        h.test("http request supports generic method", function()
            local response = http.request("GET", "https://httpbin.org/get", {
                timeout = 10,
            })

            expect.type_(response, "table")
            expect.true_(response.ok, response.error or response.status_text)
            expect.eq(response.status, 200)
        end)
    end)
end
