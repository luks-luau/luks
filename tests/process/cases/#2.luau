local h = require("../../helpers")
local Process = require("../../../luks-std/Process")

return function(expect)
    h.suite("Process Advanced Dispatch Constraints", function()
        h.test("process validation logic intercepts argument typing errors", function()
            local res = Process.spawn(nil :: any)
            expect.false_(res.ok, "Intercepts uninstantiated string targets returning graceful ok=false map")
            expect.true_(res.error ~= nil and string.find(res.error, "must be a string", 1, true) ~= nil)
        end)

        h.test("process pipeline bindings transfer standard input buffers", function()
            local inputStr = "dynamic runtime stream integration buffers"
            -- Using portable approach executing shell inline reflection
            local cmd = if Process.os() == "windows" then "findstr dynamic" else "grep dynamic"

            local res = Process.exec(cmd, {
                stdin = inputStr,
            })

            -- Since stdin successfully routes into the child pipe, grep/findstr filters and yields matching buffers
            expect.true_(res.ok, "Stdin channels successfully stream across child kernel bounds")
            expect.true_(string.find(res.stdout, "dynamic", 1, true) ~= nil, "Reflects pipelined stdin streams")
        end)

        h.test("process asynchronous signal mechanisms dispatch non-blocking records", function()
            local signal = Process.execAsync("echo event payload verification")
            expect.type_(signal, "table")
            expect.type_(signal.Connect, "function")
        end)

        h.test("process runtime maps handle absent variable resolution bounds", function()
            expect.eq(Process.getEnv("NON_EXISTENT_DYNAMIC_MAP_KEY_!!"), nil, "Absent OS string keys yield explicit nils")
        end)
    end)
end
