local config = require("xmark.config")

local M = {}

local function normalize(path)
  if vim.fs and vim.fs.normalize then
    return vim.fs.normalize(path)
  end
  return vim.fn.fnamemodify(path, ":p"):gsub("\\", "/"):gsub("/$", "")
end

function M.root()
  local opts = config.get()
  local cwd = normalize(vim.fn.getcwd())
  local markers = vim.fs.find(opts.root_markers, { path = cwd, upward = true })

  if #markers > 0 then
    local marker = markers[1]
    if vim.fn.fnamemodify(marker, ":t") == ".git" then
      return normalize(vim.fn.fnamemodify(marker, ":h"))
    end
    return normalize(vim.fn.fnamemodify(marker, ":h"))
  end

  return cwd
end

function M.name(root)
  return vim.fn.fnamemodify(root or M.root(), ":t")
end

function M.relative(path, root)
  root = normalize(root or M.root())
  path = normalize(path)

  if vim.fs and vim.fs.relpath then
    local rel = vim.fs.relpath(root, path)
    if rel then
      return rel
    end
  end

  local prefix = root .. "/"
  if path:sub(1, #prefix) == prefix then
    return path:sub(#prefix + 1)
  end
  return path
end

function M.absolute(path, root)
  if path:match("^%a:[/\\]") or path:sub(1, 1) == "/" then
    return normalize(path)
  end
  return normalize((root or M.root()) .. "/" .. path)
end

return M
