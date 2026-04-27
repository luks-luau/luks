local M = {}

-- Safe wrapper: expects dlopen to return (module, nil) on success or (nil, err) on failure
function M.safe_dlopen(path)
  local mod, err = dlopen(path)
  if mod == nil then
    error(err or "dlopen failed without error message")
  end
  return mod
end

return M
