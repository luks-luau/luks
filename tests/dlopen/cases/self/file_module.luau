local ok, native_or_err = pcall(function()
    return dlopen("@self/../../../../target/release/testmodule")
end)

return {
    load_ok = ok,
    load_err = ok and nil or native_or_err,
    native = ok and native_or_err or nil,
}
