local args = {...}
print("VARARG_COUNT=" .. #args)
for i, arg in ipairs(args) do
    print("ARG_" .. i .. "=" .. arg)
end
