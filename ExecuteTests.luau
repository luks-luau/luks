--!strict
-- ExecuteTests.luau
-- Redone from scratch: Executes all test categories concurrently and shows premium real-time terminal progress.

local fs = require("luks-std/fs")
local io = require("luks-std/io")
local process = require("luks-std/process")
local env = require("luks-std/env")

local cli_args = {...}
local is_ci = env.var("CI") ~= nil or env.var("GITHUB_ACTIONS") ~= nil

-- Standard output formatter wrapper
local function wrap_out(writer: any)
    local obj = {}
    function obj:write(s) writer:write_all(s):Wait(); return self end
    function obj:writeLine(s) self:write((s or "") .. "\n"); return self end
    function obj:flush() writer:flush():Wait(); return self end
    function obj:color(c)
        local codes = { reset = 0, red = 31, green = 32, yellow = 33, blue = 34 }
        self:write("\27[" .. (codes[c] or 0) .. "m")
        return self
    end
    function obj:fmt(f, ...)
        self:write(string.format(f, ...))
        return self
    end
    return obj
end

local out = wrap_out(io.stdout())

-- Determine the executable path
local function exists(path: string)
    local _, ok = fs.metadata(path):Wait()
    return ok
end

local luksExe = "luks"
if exists("target/release/lukscli.exe") then
    luksExe = "target/release/lukscli.exe"
elseif exists("target/release/lukscli") then
    luksExe = "target/release/lukscli"
elseif exists("./target/release/lukscli") then
    luksExe = "./target/release/lukscli"
end

local function discover_categories(): {string}
    local discovered = {}
    local read_dir_res: any = nil
    local ok = pcall(function()
        read_dir_res = fs.read_dir("tests"):Wait()
    end)
    if not ok or read_dir_res == nil then
        return {}
    end
    
    while true do
        local entry = read_dir_res:next():Wait()
        if not entry then
            break
        end
        if entry.name:sub(1, 1) == "." then
            continue
        end
        
        local is_dir = false
        pcall(function()
            local ft = entry:file_type():Wait()
            is_dir = ft:is_dir()
        end)
        
        if is_dir then
            local cases_path = entry.path .. "/cases"
            local cases_is_dir = false
            pcall(function()
                local meta = fs.metadata(cases_path):Wait()
                cases_is_dir = meta:is_dir()
            end)
            
            if cases_is_dir then
                local has_files = false
                pcall(function()
                    local cases_dir = fs.read_dir(cases_path):Wait()
                    local first_entry = cases_dir:next():Wait()
                    if first_entry then
                        has_files = true
                    end
                end)
                
                if has_files then
                    table.insert(discovered, entry.name)
                end
            end
        end
    end
    
    table.sort(discovered)
    return discovered
end

-- Parse test categories from CLI arguments or discover dynamically using filesystem
local categories = {}
if #cli_args > 0 then
    for _, arg in ipairs(cli_args) do
        table.insert(categories, arg)
    end
else
    categories = discover_categories()
end

-- Category execution state definition
type CategoryState = {
    name: string,
    statusText: string,
    statusType: "RUNNING" | "PASS" | "FAIL",
    exitCode: number?
}

local categoryStates: {CategoryState} = {}
for idx, cat in ipairs(categories) do
    categoryStates[idx] = {
        name = cat,
        statusText = "starting...",
        statusType = "RUNNING",
        exitCode = nil
    }
end

local function formatShort(tName: string)
    if #tName > 45 then
        return tName:sub(1, 42) .. "..."
    end
    return tName
end

local function renderDashboard()
    if is_ci then return end
    local half = math.ceil(#categories / 2)
    local buf = "\27[" .. half .. "A" -- Move up to the first row of columns
    
    for i = 1, half do
        -- Left Column
        local st1 = categoryStates[i]
        local prefix1 = string.format("[%s]", st1.name)
        local leftText = ""
        if st1.statusType == "PASS" then
            leftText = string.format("\27[32m%-15s ok\27[0m", prefix1)
        elseif st1.statusType == "FAIL" then
            leftText = string.format("\27[31m%-15s fail (%s)\27[0m", prefix1, tostring(st1.exitCode))
        else
            local shortStatus = st1.statusText
            if #shortStatus > 15 then
                shortStatus = shortStatus:sub(1, 12) .. "..."
            end
            leftText = string.format("%-15s running: %s", prefix1, shortStatus)
        end
        
        -- Pad left visible text to exactly 40 chars for perfect column alignment (ignoring ANSI codes)
        local visibleLeft = leftText:gsub("\27%[%d+m", "")
        local paddingNeeded = 40 - #visibleLeft
        if paddingNeeded > 0 then
            leftText = leftText .. string.rep(" ", paddingNeeded)
        end
        
        -- Right Column
        local rightText = ""
        local rightIdx = i + half
        if rightIdx <= #categories then
            local st2 = categoryStates[rightIdx]
            local prefix2 = string.format("[%s]", st2.name)
            if st2.statusType == "PASS" then
                rightText = string.format("\27[32m%-15s ok\27[0m", prefix2)
            elseif st2.statusType == "FAIL" then
                rightText = string.format("\27[31m%-15s fail (%s)\27[0m", prefix2, tostring(st2.exitCode))
            else
                local shortStatus = st2.statusText
                if #shortStatus > 15 then
                    shortStatus = shortStatus:sub(1, 12) .. "..."
                end
                rightText = string.format("%-15s running: %s", prefix2, shortStatus)
            end
        end
        
        buf = buf .. "\r\27[2K" .. leftText .. " | " .. rightText .. "\n"
    end
    out:write(buf):flush()
end

local total_passed = 0
local total_failed = 0
local completed_categories = 0
local failureReports = {}
local debugLogs = {}

-- Allocate blank lines first so that relative cursor movement is perfectly inside the console buffer
if not is_ci then
    local half = math.ceil(#categories / 2)
    out:writeLine("")
    for _ = 1, half do
        out:writeLine("")
    end
    out:flush()
    renderDashboard()

    -- Start high-performance 30 FPS background TUI renderer
    task.spawn(function()
        local fs = require("luks-std/fs")
        local lastLogWrite = os.clock()
        while completed_categories < #categories do
            task.wait(0.033)
            renderDashboard()

            if os.clock() - lastLogWrite >= 0.5 then
                lastLogWrite = os.clock()
                pcall(function()
                    fs.write("debug_test.log", table.concat(debugLogs, "\n")):Wait()
                end)
            end
        end
        renderDashboard() -- Final update to guarantee accurate end state
        pcall(function()
            fs.write("debug_test.log", table.concat(debugLogs, "\n")):Wait()
        end)
    end)
end

-- Run all test categories concurrently
for idx, category in ipairs(categories) do
    task.spawn(function()
        table.insert(debugLogs, string.format("[%s] Category thread started", category))
        
        -- Spawn child process with piped standard output
        local child = process.Command.new(luksExe)
            :args({ "tests/main.luau", category })
            :stdin("null")
            :stdout("piped")
            :stderr("null")
            :spawn()
            :unwrap()

        table.insert(debugLogs, string.format("[%s] Child process spawned with ID %s", category, tostring(child.id)))

        local activeRunningTest: any = nil
        local firstFailedTest = nil

        -- Read real-time console streaming directly in this thread until EOF
        local reader = io.BufReader.new(child.stdout :: any)
        while true do
            local line, ok = reader:read_line():Wait()
            table.insert(debugLogs, string.format("[%s] READ_LINE ok=%s: %s", category, tostring(ok), (tostring(line):gsub("\n", ""))))
            if not ok or not line then
                table.insert(debugLogs, string.format("[%s] READ_LINE EOF reached", category))
                break
            end

            -- Strip ANSI styling codes for accurate pattern matching
            local cleanLine = line:gsub("\27%[%d+m", "")
            
            -- Detect result lines of format: CATEGORY -> TEST_NAME [STATUS]
            local matchedName, statusStr = cleanLine:match("->%s*(.-)%s*%[([A-Z]+)%]")
            if matchedName then
                local cleanName = matchedName:match("^%s*(.-)%s*$")
                if not cleanName then return end
                
                if statusStr == "RUNNING" then
                    activeRunningTest = cleanName
                    categoryStates[idx].statusText = formatShort(cleanName:lower())
                elseif statusStr == "FAIL" then
                    if not firstFailedTest then
                        firstFailedTest = cleanName
                    end
                    if activeRunningTest == cleanName then
                        activeRunningTest = nil
                    end
                elseif statusStr == "PASS" then
                    if activeRunningTest == cleanName then
                        activeRunningTest = nil
                    end
                    if is_ci then
                        out:fmt("[%s] success: %s\n", category, cleanName:lower()):flush()
                    end
                end
            end
        end

        -- Await process termination asynchronously (returns immediately as stdout reached EOF)
        table.insert(debugLogs, string.format("[%s] Awaiting child process exit...", category))
        local exitStatus = child:wait():unwrap()
        local exitCode = exitStatus:code() or 0
        table.insert(debugLogs, string.format("[%s] Child process exited with code %d", category, exitCode))

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

            -- Record detailed failure summary
            local failedTestName = firstFailedTest or activeRunningTest or "unknown test"
            table.insert(failureReports, string.format("[%s] fail\n  -> target case: %s\n  -> exit status: %d", category, failedTestName:lower(), exitCode))
        end

        completed_categories += 1
        table.insert(debugLogs, string.format("[%s] Category completed! (completed_categories=%d)", category, completed_categories))
    end)
end

-- Wait until all concurrent tasks complete
while completed_categories < #categories do
    task.wait(0.01)
end

-- Write debug log file
pcall(function()
    fs.write("debug_test.log", table.concat(debugLogs, "\n")):Wait()
end)

-- No cursor move down needed as renderDashboard naturally leaves the cursor at the end of the list

-- Print failure reports
if #failureReports > 0 then
    out:writeLine("\n")
    for _, rep in ipairs(failureReports) do
        out:color("red"):writeLine(rep):color("reset")
    end
    out:flush()
end

-- Final summary output
if total_failed == 0 then
    out:color("green"):writeLine("\nall categories passed."):color("reset"):flush()
else
    process.exit(1)
end
