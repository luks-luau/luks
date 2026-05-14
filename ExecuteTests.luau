local FileSystem = require("luks-std/FileSystem")
local Stdio = require("luks-std/Stdio")
local Process = require("luks-std/Process")

local out = Stdio.stdout()
local cli_args = {...}

local is_ci = Process.getEnv("CI") ~= nil or Process.getEnv("GITHUB_ACTIONS") ~= nil

local luksExe = "luks"
if FileSystem.exists("target/release/lukscli.exe") then
    luksExe = "target/release/lukscli.exe"
elseif FileSystem.exists("target/release/lukscli") then
    luksExe = "target/release/lukscli"
elseif FileSystem.exists("./target/release/lukscli") then
    luksExe = "./target/release/lukscli"
end

-- Parse execution categories either from provided CLI parameters or autonomously from main.luau
local categories = {}

if #cli_args > 0 then
    for _, arg in ipairs(cli_args) do
        table.insert(categories, arg)
    end
else
    local ok_read_main, mainContent = pcall(FileSystem.readFile, "tests/main.luau")
    if ok_read_main and mainContent then
        local categoriesBlock = mainContent:match("local%s+categories%s*=%s*.-{%s*([^}]+)%s*}")
        if categoriesBlock then
            for cat in categoriesBlock:gmatch('["\']([^"\']+)["\']') do
                table.insert(categories, cat)
            end
        end
    end

    -- Secure static fallback array ensuring coverage if source reading encounters errors
    if #categories == 0 then
        categories = { "require", "dlopen", "task", "signal", "json", "http", "websocket", "zlib", "crypto", "process", "filesystem", "stdio", "jit" }
    end
end

local total_passed = 0
local total_failed = 0
local completed_categories = 0
local failureReports = {}

local categoryStates = {}
for idx, cat in ipairs(categories) do
    categoryStates[idx] = {
        name = cat,
        statusText = "starting...",
        statusType = "RUNNING", -- RUNNING, PASS, FAIL
        exitCode = nil
    }
end

local function formatShort(tName)
    if #tName > 35 then
        return tName:sub(1, 32) .. "..."
    end
    return tName
end

local function renderDashboard()
    if is_ci then return end
    -- Construct a single atomic string buffer to prevent thread interleaving
    local buf = "\27[" .. #categories .. "A" -- Move up to the first category row
    for i = 1, #categories do
        local st = categoryStates[i]
        local prefix = string.format("[%s]", st.name)
        local lineText = ""
        if st.statusType == "PASS" then
            lineText = string.format("\27[32m%-15s ok\27[0m", prefix)
        elseif st.statusType == "FAIL" then
            lineText = string.format("\27[31m%-15s fail (exit status: %s)\27[0m", prefix, tostring(st.exitCode))
        else
            lineText = string.format("%-15s running: %s", prefix, st.statusText)
        end
        
        -- Guarantee text length never exceeds standard column width to avoid wrapping shifts
        buf = buf .. "\r\27[2K" .. lineText .. "\n"
    end
    out:write(buf):flush()
end

if not is_ci then
    out:writeLine("")
    for _ = 1, #categories do
        out:writeLine("")
    end
    out:flush()
    renderDashboard()
end

for idx, category in ipairs(categories) do
    task.spawn(function()
        local scheduledTests = {}
        local ok_dir, files = pcall(FileSystem.readDir, "tests/" .. category .. "/cases")
        if ok_dir and files then
            local sortedFiles = {}
            for _, f in ipairs(files) do
                local num = f:match("#(%d+)%.luau")
                if num then
                    table.insert(sortedFiles, { name = f, num = tonumber(num) })
                end
            end
            table.sort(sortedFiles, function(a, b) return a.num < b.num end)

            for _, sf in ipairs(sortedFiles) do
                local ok_read_case, content = pcall(FileSystem.readFile, "tests/" .. category .. "/cases/" .. sf.name)
                if ok_read_case and content then
                    for testName in content:gmatch("h%.test%(['\"]%s*([^'\"]+)%s*['\"]") do
                        local cleanTestName = testName:upper():match("^%s*(.-)%s*$")
                        table.insert(scheduledTests, { file = sf.name, test = cleanTestName })
                    end
                end
            end
        end

        local child = Stdio.spawnStream(luksExe, { "tests/main.luau", category })
        
        local _lastSuccessfulTest = nil
        local firstFailedTest = nil
        local activeRunningTest = nil
        local streamBuffer = ""

        child.onStdout:Connect(function(chunk)
            streamBuffer = streamBuffer .. chunk
            while true do
                local newlinePos = streamBuffer:find("\n")
                if not newlinePos then
                    break
                end

                local line = streamBuffer:sub(1, newlinePos - 1)
                streamBuffer = streamBuffer:sub(newlinePos + 1)

                local cleanLine = line:gsub("\27%[%d+m", "")
                local matchedName, statusStr = cleanLine:match("->%s*(.-)%s*%[([A-Z]+)%]")
                if matchedName then
                    local cleanName = matchedName:match("^%s*(.-)%s*$")

                    if statusStr == "RUNNING" then
                        activeRunningTest = cleanName:upper()
                        categoryStates[idx].statusText = formatShort(cleanName:lower())
                        renderDashboard()
                    elseif statusStr == "PASS" then
                        local _lastSuccessfulTest = cleanName:upper()
                        if activeRunningTest == cleanName:upper() then
                            activeRunningTest = nil
                        end
                        if is_ci then
                            out:fmt("[%s] success: %s\n", category, cleanName:lower()):flush()
                        end
                    elseif statusStr == "FAIL" then
                        if not firstFailedTest then
                            firstFailedTest = cleanName:upper()
                        end
                        if activeRunningTest == cleanName:upper() then
                            activeRunningTest = nil
                        end
                        if is_ci then
                            out:fmt("[%s] failed: %s\n", category, cleanName:lower()):flush()
                        end
                    end
                end
            end
        end)

        child.onStderr:Connect(function(_) end)

        local exitCode = nil
        child.onExit:Once(function(code)
            exitCode = code
        end)

        while exitCode == nil do
            task.wait(0.01)
        end

        categoryStates[idx].exitCode = exitCode
        if exitCode == 0 then
            categoryStates[idx].statusType = "PASS"
            total_passed += 1
            if is_ci then
                out:color("green"):fmt("[%s] ok\n", category):color("reset"):flush()
            end
        else
            categoryStates[idx].statusType = "FAIL"
            total_failed += 1
            if is_ci then
                out:color("red"):fmt("[%s] fail (exit status: %d)\n", category, exitCode):color("reset"):flush()
            end

            local targetCaseName = firstFailedTest or activeRunningTest
            if targetCaseName then
                local originFile = "unknown"
                for _, item in ipairs(scheduledTests) do
                    if item.test == targetCaseName then
                        originFile = item.file
                        break
                    end
                end
                table.insert(failureReports, string.format("[%s] fail\n  -> target case: %s\n  -> origin file: tests/%s/cases/%s", category, targetCaseName:lower(), category, originFile))
            else
                table.insert(failureReports, string.format("[%s] fail (exit status: %d)", category, exitCode))
            end
        end

        renderDashboard()
        completed_categories += 1
    end)
end

while completed_categories < #categories do
    task.wait(0.01)
end

if #failureReports > 0 then
    out:writeLine("\n")
    for _, rep in ipairs(failureReports) do
        out:color("red"):writeLine(rep):color("reset")
    end
    out:flush()
end

if total_failed == 0 then
    out:color("green"):writeLine("\nall categories passed."):color("reset"):flush()
end

if total_failed > 0 then
    Process.exit(1)
end
