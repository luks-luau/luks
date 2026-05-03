# Luks Test Suite

Modular test structure for the Luks runtime.

## Test Suite Overview

The test suite is a modular Luau test framework with auto-discovery.

- **Test Runner**: `main.luau` discovers and executes test cases automatically.
- **Helpers**: `helpers.luau` provides assertion functions (`expect_eq`, `expect_true`, etc.).
- **Categories**: Tests are organized by category (e.g., `require/`, `dlopen/`, `task/`).
- **Adding Tests**: Create a new file `CATEGORY/cases/#N.luau` with sequential numbers.

## Running

```bash
.\target\release\lukscli.exe .\tests\main.luau
```

## Adding New Tests

1. Create file in `CATEGORY/cases/#N.luau`
2. Add entry to `test_cases` table in `main.luau`
3. Follow the format:
   ```lua
   return function(expect)
       h.suite("NAME", function()
           h.test("TEST NAME", function()
               expect.eq(value, expected)
           end)
       end)
   end
   ```

## Available Helpers

- `expect_eq(a, b, msg?)` - Equality
- `expect_true(v, msg?)` - True
- `expect_false(v, msg?)` - False
- `expect_nil(v, msg?)` - Nil
- `expect_not_nil(v, msg?)` - Not nil
- `expect_type(v, t, msg?)` - Type check
- `expect_error(fn, msg?)` - Expected error
- `expect_same_ref(a, b, msg?)` - Same reference

## Output Format

```
CATEGORY -> FUNCTION_NAME [PASS/FAIL]
```

Colors:
- Blue: PASS
- Yellow: FAIL

## Notes

- All `dlopen` calls in tests are wrapped in `pcall` so missing libraries do not abort the full suite.
