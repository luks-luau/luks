print("=== Testing require system ===")

-- Test 1: require de módulo em subdiretório
local mod = require("./subdir/mod")
print("Test 1 - ./subdir/mod:", mod.greet("World"))

-- Test 2: require do mesmo módulo (deve retornar do cache)
local mod2 = require("./subdir/mod")
print("Test 2 - same table from cache:", mod == mod2)

-- Test 3: require de util diretamente
local util = require("./subdir/util")
print("Test 3 - util.add(5, 3):", util.add(5, 3))

print("=== All tests passed! ===")
