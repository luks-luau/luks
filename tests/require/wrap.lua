local M = {}

-- Safe wrapper that surfaces a Luau error with location when require fails
function M.safe_require(path)
  local ok, mod, err = pcall(function() return require(path) end)
  if not ok then
    -- Underlying error (err) or default message
    error(err or "require call failed")
  end
  if mod == nil then
    local info = debug.getinfo(2, "Sln")
    local loc_src = (info and info.short_src) or "<unknown>"
    local loc_line = (info and info.currentline) or 0
    error((err or "require failed") .. (" at %s:%d"):format(loc_src, loc_line))
  end
  return mod
end

return M
