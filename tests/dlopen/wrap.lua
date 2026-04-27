local M = {}

-- Safe wrapper: calls dlopen wrapped in pcall and surfaces proper Luau errors with location
function M.safe_dlopen(path)
  local ok, mod, err = pcall(function() return dlopen(path) end)
  if not ok then
    -- propagate the inner error as a Luau error
    error(mod or (err or "dlopen call failed"))
  end
  if mod == nil then
    local info = debug.getinfo(2, "Snl")
    local loc_src = (info and info.short_src) or "<unknown>"
    local loc_line = (info and info.currentline) or 0
    error((err or "dlopen failed") .. (" at %s:%d"):format(loc_src, loc_line))
  end
  return mod
end

return M
