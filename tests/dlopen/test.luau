print("\n--- Testing Module (Table) ---")
local ok_mod, mymodule_or_err = pcall(function()
    return dlopen("../../target/release/testmodule")
end)
if ok_mod and type(mymodule_or_err) == "table" then
    local mymodule = mymodule_or_err
    print("Module version: " .. tostring(mymodule.version))
    print("Received from hello(): " .. mymodule.hello())
else
    print("dlopen failed: " .. tostring(mymodule_or_err))
end

print("\n--- Testing @self Alias ---")
local ok_self, self_mod_or_err = pcall(function()
    return dlopen("@self/../../target/release/testmodule")
end)
if ok_self and type(self_mod_or_err) == "table" then
    local self_mod = self_mod_or_err
    print("@self module version: " .. tostring(self_mod.version))
else
    print("@self dlopen failed: " .. tostring(self_mod_or_err))
end
