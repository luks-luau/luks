local h = require("../../helpers")
local json = require("../../../luks-std/Json")
local http = require("../../../luks-std/Http")

return function(expect)
    h.suite("HTTP Utilities & Properties", function()
        h.test("http exposes native client version string", function()
            expect.type_(http.version, "string")
            expect.true_(#http.version > 0)
        end)

        h.test("http urlencodePart encodes unsafe characters correctly", function()
            expect.eq(http.urlencodePart("hello world"), "hello%20world")
            expect.eq(http.urlencodePart("a+b/c"), "a%2Bb%2Fc")
        end)

        h.test("http urlencode constructs query strings perfectly", function()
            local query = http.urlencode({ q = "luks runtime", p = "1" })
            -- Map order is unordered in Lua, check both possible strings
            local option1 = "q=luks%20runtime&p=1"
            local option2 = "p=1&q=luks%20runtime"
            expect.true_(query == option1 or query == option2)
        end)
    end)

    h.suite("HTTP Synchronous REST Methods", function()
        h.test("http get retrieves status and body payload", function()
            local res = http.get("https://httpbin.org/get", { ["Accept"] = "application/json" })
            expect.type_(res, "table")
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)
            expect.type_(res.body, "string")
        end)

        h.test("http post submits body payload correctly", function()
            local res = http.post("https://httpbin.org/post", {
                headers = { ["Content-Type"] = "application/json" },
                body = json.encode({ status = "active" })
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)
            local data = json.decode(res.body or "")
            expect.eq(data.json.status, "active")
        end)

        h.test("http put updates destination payload cleanly", function()
            local res = http.put("https://httpbin.org/put", {
                body = "raw_put_data"
            })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)
        end)

        h.test("http delete removes entity correctly", function()
            local res = http.delete("https://httpbin.org/delete")
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)
        end)

        h.test("http patch modifies partial attributes", function()
            local res = http.patch("https://httpbin.org/patch", { body = "patch_data" })
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)
        end)

        h.test("http head fetches header fields omitting body", function()
            local res = http.head("https://httpbin.org/get")
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 200)
        end)

        h.test("http request supports customized method evaluation", function()
            local res = http.request("GET", "https://httpbin.org/status/204")
            expect.true_(res.ok, res.error)
            expect.eq(res.status, 204)
        end)
    end)

    h.suite("HTTP Asynchronous Evaluation", function()
        h.test("http getAsync fires signal upon non-blocking network return", function()
            local res
            http.getAsync("https://httpbin.org/status/200"):Connect(function(r) res = r end)
            
            local timeout = 0
            while res == nil and timeout < 40 do
                task.wait(0.1)
                timeout += 1
            end
            
            expect.not_nil(res)
            expect.true_(res.ok)
            expect.eq(res.status, 200)
        end)

        h.test("http postAsync handles non-blocking submission payload", function()
            local res
            http.postAsync("https://httpbin.org/post", { body = "async_payload" }):Connect(function(r) res = r end)

            local timeout = 0
            while res == nil and timeout < 40 do
                task.wait(0.1)
                timeout += 1
            end

            expect.not_nil(res)
            expect.true_(res.ok)
            expect.eq(res.status, 200)
        end)
    end)

    h.suite("HTTP Exception Paths", function()
        h.test("http get returns ok=false on invalid network target", function()
            local res = http.get("https://invalid_host_target_domain_000.none")
            expect.false_(res.ok)
            expect.type_(res.error, "string")
        end)
    end)
end
