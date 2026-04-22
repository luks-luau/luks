# Require Test Cases

## #1.luau - Basic Require Tests

Tests basic module system functionality.

### Tests

1. **REQUIRE LOADS MODULE WITH FUNCTIONS**
   - Verifies that `require` loads modules that export functions
   - Path: `./require/subdir/mod`

2. **MODULE FUNCTION WORKS CORRECTLY**
   - Validates that exported functions return expected values
   - `add(2, 3)` should return `5`

3. **REQUIRE LOADS NESTED DEPENDENCIES**
   - Tests modules that require other modules
   - `subdir/mod` requires `subdir/helper`

4. **NESTED DEPENDENCY IS ACCESSIBLE**
   - Verifies that nested dependencies are accessible
   - `util` exported by `helper` should be available

5. **REQUIRE WITH BARE NAME WORKS**
   - Tests compatibility with `require("mod")` (without `./`)
   - Should resolve to `./mod`

## #2.luau - Cache Tests

Tests the module caching system.

### Tests

1. **REQUIRE RETURNS SAME TABLE REFERENCE**
   - Multiple requires of the same module return the same table
   - Verifies identity with `rawequal`

2. **REQUIRE RETURNS SAME REFERENCE FOR NESTED REQUIRES**
   - Cache works for nested dependencies

3. **MUTATIONS PERSIST IN CACHED MODULE**
   - Changes to modules are preserved between requires
   - Incremented `counter` persists

4. **CACHE SURVIVES MULTIPLE REQUIRES IN SAME SCOPE**
   - Cache is consistent in the same scope
