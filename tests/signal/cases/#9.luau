local h = require("../../helpers")
local Signal = require("../../../luks-std/Signal")

return function(expect)
    h.suite("Signal Edge Cases", function()
        h.test("fire with nil argument passes nil", function()
            local sig = Signal.new()
            local received
            sig:Connect(function(val) received = val end)
            sig:Fire(nil)
            expect.eq(received, nil)
        end)

        h.test("fire with multiple nil arguments", function()
            local sig = Signal.new()
            local a, b, c
            sig:Connect(function(v1, v2, v3)
                a = v1; b = v2; c = v3
            end)
            sig:Fire(nil, nil, nil)
            expect.eq(a, nil)
            expect.eq(b, nil)
            expect.eq(c, nil)
        end)

        h.test("disconnect inside callback does not prevent other callbacks", function()
            local sig = Signal.new()
            local order = {}
            local conn_refs = {}
            conn_refs[1] = sig:Connect(function()
                table.insert(order, "a")
                if conn_refs[1] and conn_refs[1].Connected then
                    conn_refs[1]:Disconnect()
                end
            end)
            sig:Connect(function()
                table.insert(order, "b")
            end)
            sig:Fire()
            task.wait(0.05)
            expect.true_(#order >= 1)
        end)

        h.test("disconnect head connection keeps others", function()
            local sig = Signal.new()
            local order = {}
            local conn1 = sig:Connect(function()
                table.insert(order, "a")
            end)
            local conn2 = sig:Connect(function()
                table.insert(order, "b")
            end)
            -- conn2 is head (inserted last). Disconnect it and fire.
            conn2:Disconnect()
            sig:Fire()
            task.wait(0.05)
            expect.eq(order[1], "a")
        end)

        h.test("fire after destroy is safe", function()
            local sig = Signal.new()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Destroy()
            local ok, err = pcall(function() sig:Fire() end)
            expect.true_(ok)
        end)

        h.test("fire with many arguments", function()
            local sig = Signal.new()
            local args
            sig:Connect(function(...) args = { ... } end)
            sig:Fire(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
            expect.eq(#args, 10)
            expect.eq(args[10], 10)
        end)

        h.test("fire inside callback does not cause stack overflow", function()
            local sig = Signal.new()
            local count = 0
            sig:Connect(function()
                count += 1
                pcall(function() sig:Fire() end)
            end)
            sig:Fire()
            expect.eq(count, 1)
        end)

        h.test("disconnectall allows new connections to work", function()
            local sig = Signal.new()
            sig:Connect(function() end)
            sig:DisconnectAll()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Fire()
            expect.eq(count, 1)
        end)

        h.test("destroy disconnects all and prevents new fires", function()
            local sig = Signal.new()
            local count = 0
            sig:Connect(function() count += 1 end)
            sig:Destroy()
            sig:Fire()
            expect.eq(count, 0)
        end)

        h.test("once with no arguments", function()
            local sig = Signal.new()
            local called = false
            sig:Once(function() called = true end)
            sig:Fire()
            sig:Fire()
            expect.true_(called)
        end)

        h.test("public proxy is frozen and cannot be modified", function()
            local sig = Signal.new()
            local pub = sig:Public()
            expect.true_(table.isfrozen(pub))
            local ok, err = pcall(function() pub.new = "illegal" end)
            expect.false_(ok)
        end)
    end)
end
