local h = require("../../helpers")
local json = require("../../../luks-std/Json")

return function(expect)
    h.suite("JSON Native Module Tests", function()
        h.test("json encode serializes object fields", function()
            local encoded = json.encode({
                level = 5,
                nome = "yanlvl99",
                active = true,
            })

            expect.type_(encoded, "string")
            expect.true_(string.find(encoded, [["level":5]], 1, true) ~= nil)
            expect.true_(string.find(encoded, [["nome":"yanlvl99"]], 1, true) ~= nil)
            expect.true_(string.find(encoded, [["active":true]], 1, true) ~= nil)
        end)

        h.test("json decode reads object fields", function()
            local decoded = json.decode([[{"level":5,"nome":"yanlvl99","active":true}]])

            expect.type_(decoded, "table")
            expect.eq(decoded.level, 5)
            expect.eq(decoded.nome, "yanlvl99")
            expect.true_(decoded.active)
        end)

        h.test("json decode handles empty object", function()
            local decoded = json.decode("{}")

            expect.type_(decoded, "table")
            expect.nil_(next(decoded))
        end)

        h.test("json round trips http-style response shape", function()
            local body = [[{"args":{},"data":"{\"level\":5,\"nome\":\"yanlvl99\"}","files":{},"form":{},"json":{"level":5,"nome":"yanlvl99"},"url":"https://httpbin.org/post"}]]
            local decoded = json.decode(body)

            expect.type_(decoded, "table")
            expect.type_(decoded.args, "table")
            expect.type_(decoded.files, "table")
            expect.type_(decoded.form, "table")
            expect.eq(decoded.json.level, 5)
            expect.eq(decoded.json.nome, "yanlvl99")
            expect.eq(decoded.url, "https://httpbin.org/post")
        end)
    end)
end
