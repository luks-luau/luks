local my_module = dlopen("testmodule")
print("Before calling the DLL")
task.spawn(function()
    print("Executing native module...")
    -- The native module yields/uses the scheduler internally if calling a yieldable function,
    -- and must safely interact with the initialized state without crashing.
    print("hello returns:", my_module.hello())
    print("Returned from native module successfully!")
end)
print("End of main script, scheduler will continue...")
