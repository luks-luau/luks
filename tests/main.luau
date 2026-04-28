-- Main Test Runner
-- Executes all test cases from multiple folders with ANSI colors
-- Usage: main.luau takes a list of folders to test

local h = require("./helpers")

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

-- ANSI colors
local colors = {
    yellow = "\27[33m",
    blue = "\27[34m",
    reset = "\27[0m"
}

-- Auto-discovered test categories.
local categories = { "require", "dlopen" }
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
    local _ok, _result = pcall(function()
        return test_fn(expect)
    end)

    return h.get_stats()
end

-- Main execution
print("=========================================")
print("      Luks Runtime Test Suite")
print("=========================================")

-- Load all test cases into cache using sequential discovery.
print("\n>> Loading tests into cache...")

for _, folder in ipairs(categories) do
    for case_num = 1, 100 do
        local ok, test_fn_or_err = pcall(function()
            return load_test_case(folder, case_num)
        end)

        if not ok then
            break
        end

        local key = folder .. "_" .. case_num
        test_cache[key] = test_fn_or_err
        table.insert(test_cases, { folder = folder, case = case_num })
    end
end

print(string.format("Loaded %d test case(s)", #test_cases))

-- Execute all cached tests
print("\n>> Executing tests...\n")

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

-- Final summary (minimal)
print(string.format("\nTotal: %d | Passed: %s%d%s | Failed: %s%d%s",
    total_stats.total,
    colors.yellow, total_stats.passed, colors.reset,
    colors.blue, total_stats.failed, colors.reset))

return all_passed
