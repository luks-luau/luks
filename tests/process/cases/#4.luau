--!strict
local Process = require("../../../luks-std/Process")
local Env = require("../../../luks-std/env")
local Async = require("../../../luks-std/async")
local h = require("../../helpers")
local function sh(cmd_str)
    if Env.consts.OS == "windows" then
        return Process.Command.new("cmd.exe"):args({"/C", cmd_str})
    else
        return Process.Command.new("sh"):args({"-c", cmd_str})
    end
end

return function(expect)
    h.suite("Process Binary Safety and Edge Cases", function()
        h.test("Process.id() returns a positive integer", function()
            local pid = Process.id()
            expect.type_(pid, "number")
            expect.true_(pid > 0)
        end)

        h.test("stdin and stdout with binary data containing null bytes", function()
            local binary_data = "a\0b\0c\0d\0e\0f"
            if Env.consts.OS ~= "windows" then
                local cmd = Process.Command.new("sh"):args({"-c", "cat"})
                    :stdin(Process.Stdio.piped())
                    :stdout(Process.Stdio.piped())

                local child = cmd:spawn():expect("spawn failed")
                child.stdin:write(binary_data):expect("stdin write failed")
                child.stdin:close()

                local result = ""
                local buf = buffer.create(256)
                while true do
                    local n, ok = child.stdout:read(buf):Wait()
                    if not ok or n == 0 then break end
                    result ..= buffer.readstring(buf, 0, n)
                end
                child:wait()
                child:close()
                expect.true_(string.len(result) >= string.len(binary_data))
            end
        end)

        h.test("multiple arguments are passed in order", function()
            local cmd
            if Env.consts.OS == "windows" then
                cmd = Process.Command.new("cmd.exe"):args({"/C", "echo one two three"})
            else
                cmd = Process.Command.new("sh"):args({"-c", "echo one two three"})
            end
            cmd = cmd:stdout(Process.Stdio.piped())
            local child = cmd:spawn():expect("spawn failed")
            local result = ""
            local buf = buffer.create(128)
            while true do
                local n, ok = child.stdout:read(buf):Wait()
                if not ok or n == 0 then break end
                result ..= buffer.readstring(buf, 0, n)
            end
            child:wait()
            child:close()
            expect.true_(string.find(result, "one two three") ~= nil)
        end)

        h.test("try_wait returns status after process finishes", function()
            local cmd = sh("echo done"):stdout(Process.Stdio.piped())
            local child = cmd:spawn():expect("spawn failed")
            local buf = buffer.create(128)
            while true do
                local n, ok = child.stdout:read(buf):Wait()
                if not ok or n == 0 then break end
            end
            child:wait():expect("wait failed")
            local status = child:try_wait():expect("try_wait failed")
            expect.not_nil(status)
            expect.true_(status:success())
            expect.eq(status:code(), 0)
            child:close()
        end)

        h.test("kill on already exited process is safe", function()
            local cmd = sh("echo quick"):stdout(Process.Stdio.piped())
            local child = cmd:spawn():expect("spawn failed")
            local buf = buffer.create(128)
            while true do
                local n, ok = child.stdout:read(buf):Wait()
                if not ok or n == 0 then break end
            end
            child:wait():expect("wait failed")
            local ok_kill, err = pcall(function()
                child:kill():Wait()
            end)
            child:close()
        end)
    end)
end
