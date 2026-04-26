# Dlopen Test Cases

## #1.luau - Object Passing Tests

Tests native library loading and object passing.

### Tests

1. **DLOPEN RETURNS VALID MODULE OBJECT**
   - `dlopen` returns a valid module object
   - Type must be `table`
   - Path: `@self/../../../target/release/testmodule`

2. **MODULE HAS EXPECTED EXPORTS**
   - Verifies that the Rust module exports `version` and `hello`
   - `hello` must be a function

3. **HELLO FUNCTION RETURNS STRING**
   - `hello()` returns a string
   - Expected value: `"Greetings from Rust!"`

4. **CAN PASS DLOPEN OBJECT TO ANOTHER MODULE**
   - Module objects can be passed between functions
   - Reference is maintained correctly

5. **CAN CALL METHODS ON PASSED OBJECT**
   - Methods can be called on passed objects
   - `obj.hello()` works after passing

## object_receiver.luau

Helper module for object passing tests.

Functions:
- `store(obj)` - Stores object for verification
- `call_hello(obj)` - Calls hello method on object
- `pass_through(obj)` - Returns received object
- `verify_same(obj)` - Verifies if it's the same reference

## Notes

- The Rust test module (`testmodule`) must be compiled in `target/release/`
- Tests verify actual values to avoid "fake pass"

## #2.luau - `@self` Semantics

Validates `@self` behavior for dynamic loading from different module shapes.

### Tests

1. **@SELF IN FILE MODULE RESOLVES TO MODULE DIRECTORY**
   - Loads a regular module file that calls `dlopen("@self/...")`
   - `@self` must resolve from that file's directory

2. **@SELF IN INIT MODULE RESOLVES TO PACKAGE DIRECTORY**
   - Loads a package module (`init.luau`) that calls `dlopen("@self/...")`
   - `@self` must resolve from the package directory containing `init.luau`
