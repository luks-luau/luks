-- Main test runner.
-- Discovers numbered case files per category and executes them.

local h = require("./helpers")
local args = {...}

-- Get expect functions
local expect = {
    eq = h.expect_eq,
    true_ = h.expect_true,
    false_ = h.expect_false,
    nil_ = h.expect_nil,
    not_nil = h.expect_not_nil,
    type_ = h.expect_type,
    error = h.expect_error,
    same_ref = h.expect_same_ref,
}

local fs = require("../luks-std/fs")

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

-- Auto-discovered test categories.
local categories = args[1] ~= nil and args or discover_categories()
local test_cases = {}

-- Cache for loaded test cases
-- Structure: { folder_num = fn }
local test_cache = {}

-- Load a specific test case
local function load_test_case(folder, case_num)
    local module_name = string.format("./%s/cases/#%d", folder, case_num)
    local test_fn = require(module_name)
    return test_fn
end

-- Execute a single test case and print results
local function execute_test_case(folder, case_num, test_fn)
    h.reset_stats()

    -- Set current category and case for proper output
    h.current_category = folder
    h.current_case = case_num

    -- Run the test case
    local ok, result = pcall(function()
        return test_fn(expect)
    end)

    if not ok then
        h.print_result(folder, case_num, "case bootstrap", "FAIL")
        print(string.format("  error: %s", tostring(result)))
        return { passed = 0, failed = 1, total = 1 }
    end

    return h.get_stats()
end

h.print_banner("Luks Runtime Test Suite")

-- Load all test cases into cache using sequential discovery.
h.print_phase("Loading tests into cache...")

for _, folder in ipairs(categories) do
    for case_num = 1, 100 do
        local ok, test_fn_or_err = pcall(function()
            return load_test_case(folder, case_num)
        end)

        if not ok then
            local reason = tostring(test_fn_or_err):match("^[^\n]+") or tostring(test_fn_or_err)
            if reason ~= "runtime error: no module present at resolved path" then
                print(string.format("skip %s case #%d: %s", folder, case_num, reason))
            end
            break
        end

        local key = folder .. "_" .. case_num
        test_cache[key] = test_fn_or_err
        table.insert(test_cases, { folder = folder, case = case_num })
    end
end

print(string.format("Loaded %d test case(s)", #test_cases))

-- Execute all cached tests
h.print_phase("Executing tests...\n")

local total_stats = { passed = 0, failed = 0, total = 0 }
local all_passed = true

for _, tc in ipairs(test_cases) do
    local key = tc.folder .. "_" .. tc.case
    local test_fn = test_cache[key]

    if test_fn then
        local stats = execute_test_case(tc.folder, tc.case, test_fn)

        total_stats.passed += stats.passed
        total_stats.failed += stats.failed
        total_stats.total += stats.total

        if stats.failed > 0 then
            all_passed = false
        end
    end
end

h.print_final_summary(total_stats.total, total_stats.passed, total_stats.failed)

local Process = require("../luks-std/Process")
if not all_passed then
    Process.exit(1)
else
    Process.exit(0)
end

return all_passed
