print("\n--- Testing Module (Table) ---")
local mymodule = dlopen("../../target/release/testmodule.dll")
if type(mymodule) == "table" then
    print("Module version: " .. tostring(mymodule.version))
    print("Received from hello(): " .. mymodule.hello())
end

print("\n--- Testing @self Alias ---")
local self_mod = dlopen("@self/../../target/release/testmodule.dll")
if type(self_mod) == "table" then
    print("@self module version: " .. tostring(self_mod.version))
end
