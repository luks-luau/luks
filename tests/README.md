# Luks Test Suite

Modular test structure for the Luks runtime.

## Structure

```
tests/
├── helpers.luau              # Assertion functions and utilities
├── main.luau                 # Main test runner
├── README.md                 # This file
├── require/
│   ├── cases/
│   │   ├── #1.luau          # Basic require tests
│   │   └── #2.luau          # Module cache tests
│   └── subdir/
│       └── mod.luau         # Helper module for tests
└── dlopen/
    ├── cases/
    │   └── #1.luau          # Object passing tests
    └── object_receiver.luau # Helper for dlopen tests
```

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

- **pcall with require**: pcall still doesn't catch errors from requiring non-existent modules (causes panic in Rust). Use the explicit test_cases list in main.luau as a workaround.
