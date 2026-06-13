local M = {}

function M.parse_path_and_rest(raw)
  raw = vim.trim(raw or "")
  if raw == "" then
    return nil, nil
  end

  local path, rest
  if raw:sub(1, 1) == '"' then
    local index = 2
    while index <= #raw do
      local char = raw:sub(index, index)
      if char == '"' and raw:sub(index - 1, index - 1) ~= "\\" then
        path = raw:sub(2, index - 1):gsub('\\"', '"')
        rest = vim.trim(raw:sub(index + 1))
        break
      end
      index = index + 1
    end
  end

  if not path then
    local match = raw:find("%s")
    if match then
      path = raw:sub(1, match - 1)
      rest = vim.trim(raw:sub(match + 1))
    else
      path = raw
      rest = ""
    end
  end

  if rest ~= "" and rest:sub(1, 1) == '"' and rest:sub(-1) == '"' then
    rest = rest:sub(2, -2):gsub('\\"', '"')
  end

  return path, rest ~= "" and rest or nil
end

return M
