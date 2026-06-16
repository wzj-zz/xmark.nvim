local core = require("xmark.core")
local config = require("xmark.config")
local db = require("xmark.db")
local project = require("xmark.project")

local M = {}

local function decode_file(path)
  local lines = vim.fn.readfile(path)
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok then
    error("xmark: invalid JSON import file: " .. decoded)
  end
  return decoded
end

local function encode_meta(meta)
  if type(meta) == "table" then
    return vim.json.encode(meta)
  end
  return meta or ""
end

local function normalize_item(item)
  if not item.path and item.file then
    item.path = item.file
  end
  if not item.line and item.lnum then
    item.line = item.lnum
  end
  if not item.col and item.column then
    item.col = item.column
  end

  if not item.path or not item.line then
    return nil
  end

  return {
    path = project.relative(item.path),
    line = tonumber(item.line),
    col = tonumber(item.col or 1),
    desc = item.desc or item.comment or item.title or "",
    meta = encode_meta(item.meta),
  }
end

local function import_items(items)
  local count = 0
  for _, raw in ipairs(items or {}) do
    local item = normalize_item(raw)
    if item then
      local existing = db.item_at(item.path, item.line)
      if existing then
        existing.col = item.col
        existing.desc = item.desc ~= "" and item.desc or existing.desc
        existing.meta = item.meta ~= "" and item.meta or existing.meta
        db.update_item(existing)
      else
        db.insert_item(item)
      end
      count = count + 1
    end
  end
  return count
end

function M.import_file(path, opts)
  opts = opts or {}
  if not path or path == "" then
    error("xmark: import path is required")
  end

  local decoded = decode_file(path)
  local items = decoded.items or decoded
  local list_name = opts.list_name or decoded.list or decoded.name

  core.create_list(list_name or config.get().default_list_name)

  local count = import_items(items)
  require("xmark.sign").refresh()
  return count
end

function M.export_file(path)
  if not path or path == "" then
    error("xmark: export path is required")
  end

  local list = core.active_list()
  local items = {}
  for _, item in ipairs(core.items(list.id)) do
    local meta = item.meta or ""
    if meta ~= "" then
      local ok, decoded = pcall(vim.json.decode, meta)
      if ok then
        meta = decoded
      end
    end
    table.insert(items, {
      path = item.path,
      line = item.line,
      col = item.col,
      desc = item.desc,
      meta = meta,
    })
  end

  local payload = {
    version = 1,
    list = list.name,
    project = project.root(),
    items = items,
  }

  vim.fn.writefile(vim.split(vim.json.encode(payload), "\n"), path)
end

return M
