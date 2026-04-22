-- Test Helpers Module
-- Provides assertion functions for structured testing

local helpers = {}

-- Current category and case being tested (set by runner)
helpers.current_category = "TEST"
helpers.current_case = 0

-- ANSI color codes
local colors = {
    yellow = "\27[33m",
    blue = "\27[34m",
    red = "\27[31m",
    green = "\27[32m",
    reset = "\27[0m"
}

-- Stats tracking
local stats = {
    passed = 0,
    failed = 0,
    tests = {}
}

-- Format status with ANSI color
-- PASS = blue, FAIL = yellow (as requested)
function helpers.format_status(status)
    if status == "PASS" then
        return colors.blue .. "[PASS]" .. colors.reset
    else
        return colors.yellow .. "[FAIL]" .. colors.reset
    end
end

-- Print test result in required format
-- Format: CATEGORY -> FUNCTION_NAME [STATUS]
-- All colored in blue for PASS, yellow for FAIL
function helpers.print_result(category, _case_num, test_name, status)
    local colored_status = helpers.format_status(status)
    -- Color the whole line based on status
    if status == "PASS" then
        print(string.format("%s%s -> %s %s%s",
            colors.blue, category:upper(), test_name:upper(), colored_status, colors.reset))
    else
        print(string.format("%s%s -> %s %s%s",
            colors.yellow, category:upper(), test_name:upper(), colored_status, colors.reset))
    end
end

-- Assertion functions
function helpers.expect_eq(a, b, msg)
    if a ~= b then
        error((msg or "Assertion failed") .. ": expected " .. tostring(b) .. " but got " .. tostring(a))
    end
end

function helpers.expect_true(v, msg)
    if not v then
        error(msg or "Expected true but got false")
    end
end

function helpers.expect_false(v, msg)
    if v then
        error(msg or "Expected false but got true")
    end
end

function helpers.expect_nil(v, msg)
    if v ~= nil then
        error((msg or "Assertion failed") .. ": expected nil but got " .. tostring(v))
    end
end

function helpers.expect_not_nil(v, msg)
    if v == nil then
        error(msg or "Expected non-nil value")
    end
end

function helpers.expect_type(v, t, msg)
    if type(v) ~= t then
        error((msg or "Type assertion failed") .. ": expected " .. t .. " but got " .. type(v))
    end
end

function helpers.expect_error(fn, msg)
    local success = pcall(fn)
    if success then
        error(msg or "Expected error but got none")
    end
end

function helpers.expect_same_ref(a, b, msg)
    if a ~= b then
        error(msg or "Expected same reference")
    end
end

-- Run a test function with tracking
-- Prints immediately in required format
function helpers.test(name, fn)
    local success, err = pcall(fn)
    local status = success and "PASS" or "FAIL"

    if success then
        stats.passed += 1
        table.insert(stats.tests, { name = name, status = "PASS" })
    else
        stats.failed += 1
        table.insert(stats.tests, { name = name, status = "FAIL", error = err })
    end

    -- Print in required format: CATEGORY -> FUNCTION_NAME [STATUS]
    helpers.print_result(helpers.current_category, helpers.current_case, name, status)

    return status, err
end

-- Run a test suite
function helpers.suite(name, fn)
    -- Just run the tests - they will print themselves
    fn()
end

-- Get current stats
function helpers.get_stats()
    return {
        passed = stats.passed,
        failed = stats.failed,
        total = stats.passed + stats.failed
    }
end

-- Reset stats
function helpers.reset_stats()
    stats = {
        passed = 0,
        failed = 0,
        tests = {}
    }
end

-- Print minimal summary (English)
function helpers.print_summary()
    local s = helpers.get_stats()
    print(string.format("\nTotal: %d | Passed: %d | Failed: %d",
        s.total, s.passed, s.failed))
end

-- Full summary (for compatibility)
function helpers.summary()
    helpers.print_summary()
    return stats.failed == 0
end

return helpers
