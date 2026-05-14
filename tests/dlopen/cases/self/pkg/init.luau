local ok, native_or_err = pcall(function()
    return dlopen("@self/../../../../../target/debug/testmodule")
end)
if not ok then
    ok, native_or_err = pcall(function()
        return dlopen("@self/../../../../../target/release/testmodule")
    end)
end

return {
    load_ok = ok,
    load_err = if ok then nil else native_or_err,
    native = if ok then native_or_err else nil,
}
