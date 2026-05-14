# Luks Test Suite

Modular test structure for the Luks runtime.

## Test Suite Overview

The test suite is a modular Luau test framework with auto-discovery.

- **Test Runner**: `main.luau` discovers and executes test cases automatically.
- **Helpers**: `helpers.luau` provides assertion functions (`expect_eq`, `expect_true`, etc.).
- **Categories**: Tests are organized by category (e.g., `require/`, `dlopen/`, `task/`, `filesystem/`).
- **Adding Tests**: Create a new file `CATEGORY/cases/#N.luau` with sequential numbers.

## Architecture & Design Standards

To maintain an enterprise-grade test framework and ensure absolute precision when diagnosing failures, all test files **MUST** adhere to the following core principles:

1. **Granular Separation (Suites & Tests)**:
   - Each test file should organize its validations using distinct `h.suite("Suite Name", function() ... end)` blocks.
   - Individual tests inside a suite **MUST** be declared with `h.test("Targeted Feature Name", function() ... end)` focusing on a single, specific responsibility.
   - Avoid long, multi-assertion test functions where a failure at the beginning masks subsequent checks.

2. **Full API Coverage (100% Requirement)**:
   - Every publicly exported module function, optional argument path, exception propagation via `pcall`, and asynchronous interface backed by `Signal` must be comprehensively tested.

3. **Mandatory Stress Testing**:
   - Each native module category must include a dedicated stress-testing file (typically the last sequential case file, e.g., `#3.luau` or `#4.luau`).
   - Stress tests are designed to execute highly concurrent asynchronous operations, rapid data manipulations, and intense event loop/thread pool utilization to verify robust stability under load.

## Running

Run all tests across all modules:
```bash
.\target\release\lukscli.exe .\tests\main.luau
```

Run tests for a specific category (e.g., filesystem):
```bash
.\target\release\lukscli.exe .\tests\main.luau filesystem
```

## Adding New Tests

1. Create a file in `CATEGORY/cases/#N.luau`. Sequential auto-discovery loads files automatically up to `#100.luau`.
2. Follow the multi-suite granular pattern:
   ```lua
   local h = require("../../helpers")
   local module = require("../../../luks-std/ModuleName")

   return function(expect)
       h.suite("Module Feature Area A", function()
           h.test("module targeted function behavior", function()
               expect.eq(module.fn(), expected)
           end)
       end)

       h.suite("Module Feature Area B", function()
           h.test("module edge case handling", function()
               expect.true_(module.check())
           end)
       end)
   end
   ```

## Available Helpers

- `expect_eq(a, b, msg?)` / `expect.eq` - Equality
- `expect_true(v, msg?)` / `expect.true_` - True
- `expect_false(v, msg?)` / `expect.false_` - False
- `expect_nil(v, msg?)` / `expect.nil_` - Nil
- `expect_not_nil(v, msg?)` / `expect.not_nil` - Not nil
- `expect_type(v, t, msg?)` / `expect.type_` - Type check
- `expect_error(fn, msg?)` / `expect.error` - Expected error
- `expect_same_ref(a, b, msg?)` / `expect.same_ref` - Same reference

## Output Format

```
CATEGORY -> FUNCTION_NAME [PASS/FAIL]
```

Colors:
- **Blue**: PASS
- **Yellow**: FAIL

## Notes

- All `dlopen` calls in tests are wrapped in `pcall` so missing libraries do not abort the full suite.
