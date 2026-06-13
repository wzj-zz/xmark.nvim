local config = require("xmark.config")
local project = require("xmark.project")

local M = {}

---@class XmarkDB: sqlite_db
---@field projects sqlite_tbl
---@field lists sqlite_tbl
---@field items sqlite_tbl
local DB
local sqlite
local raw_db
local sqlite_load_error

M._DB = nil

local function ensure_sqlite()
  if sqlite and raw_db then
    return
  end

  local has_sqlite, sqlite_mod = pcall(require, "sqlite")
  if not has_sqlite then
    pcall(function()
      require("lazy").load({ plugins = { "sqlite.lua" } })
    end)
    has_sqlite, sqlite_mod = pcall(require, "sqlite")
  end
  if not has_sqlite then
    pcall(vim.cmd.packadd, "sqlite.lua")
    has_sqlite, sqlite_mod = pcall(require, "sqlite")
  end
  if not has_sqlite then
    sqlite_load_error = sqlite_mod
    error(
      "xmark.nvim requires sqlite.lua, but `require('sqlite')` failed. "
        .. "Install `kkharji/sqlite.lua` and make sure it loads before xmark.nvim. Original error: "
        .. tostring(sqlite_load_error)
    )
  end

  sqlite = sqlite_mod
  local has_raw_db, raw_db_mod = pcall(require, "sqlite.db")
  if not has_raw_db then
    error("xmark.nvim loaded sqlite.lua, but `require('sqlite.db')` failed: " .. tostring(raw_db_mod))
  end
  raw_db = raw_db_mod
end

local function build_schema()
  local tbl = require("sqlite.tbl")

  local projects_tbl = tbl("projects", {
    id = true,
    root = { "text", required = true },
    name = { "text", required = true },
    active_list_id = "integer",
    created_at = { "integer", required = true },
    updated_at = { "integer", required = true },
  })

  local lists_tbl = tbl("lists", {
    id = true,
    project_id = { "integer", required = true },
    name = { "text", required = true },
    description = "text",
    created_at = { "integer", required = true },
    updated_at = { "integer", required = true },
  })

  local items_tbl = tbl("items", {
    id = true,
    project_id = { "integer", required = true },
    list_id = { "integer", required = true },
    path = { "text", required = true },
    line = { "integer", required = true },
    col = { "integer", required = true },
    description = "text",
    meta = "text",
    item_order = { "integer", required = true },
    created_at = { "integer", required = true },
    updated_at = { "integer", required = true },
    visited_at = "integer",
  })

  return projects_tbl, lists_tbl, items_tbl
end

local function db_path()
  local opts = config.get()
  if vim.fn.isdirectory(opts.data_dir) == 0 then
    assert(vim.fn.mkdir(opts.data_dir, "p") == 1, "failed to create xmark data_dir")
  end
  return vim.fn.fnamemodify(opts.data_dir .. "/" .. opts.db_name, ":p")
end

local function eval(sql, params)
  local db = raw_db:open(DB.uri)
  return db:eval(sql, params)
end

local function create_indexes()
  DB.projects:schema()
  DB.lists:schema()
  DB.items:schema()

  eval("CREATE UNIQUE INDEX IF NOT EXISTS idx_xmark_projects_root ON projects(root)")
  eval("CREATE INDEX IF NOT EXISTS idx_xmark_lists_project ON lists(project_id)")
  eval("CREATE INDEX IF NOT EXISTS idx_xmark_items_list_order ON items(list_id, item_order)")
  eval("CREATE INDEX IF NOT EXISTS idx_xmark_items_location ON items(project_id, list_id, path, line)")
  eval("CREATE INDEX IF NOT EXISTS idx_xmark_items_path ON items(project_id, path)")
end

function M.setup()
  ensure_sqlite()
  local projects_tbl, lists_tbl, items_tbl = build_schema()
  DB = sqlite({
    uri = db_path(),
    projects = projects_tbl,
    lists = lists_tbl,
    items = items_tbl,
  })
  M._DB = DB
  create_indexes()
end

local function now()
  return os.time()
end

local function item_from_row(row)
  if not row then
    return nil
  end
  row.desc = row.description or ""
  row.description = nil
  return row
end

local function items_from_rows(rows)
  for _, row in ipairs(rows or {}) do
    item_from_row(row)
  end
  return rows
end

local function list_from_row(row)
  if not row then
    return nil
  end
  row.desc = row.description or ""
  row.description = nil
  return row
end

local function lists_from_rows(rows)
  for _, row in ipairs(rows or {}) do
    list_from_row(row)
  end
  return rows
end

function M.project()
  local root = project.root()
  local row = DB.projects:where({ root = root })
  if row then
    return row
  end

  local time = now()
  local project_id = DB.projects:insert({
    root = root,
    name = project.name(root),
    created_at = time,
    updated_at = time,
  })

  local list_id = DB.lists:insert({
    project_id = project_id,
    name = config.get().default_list_name,
    description = "",
    created_at = time,
    updated_at = time,
  })

  DB.projects:update({ where = { id = project_id }, set = { active_list_id = list_id, updated_at = time } })
  return DB.projects:where({ id = project_id })
end

function M.active_list()
  local current = M.project()
  local list = current.active_list_id and list_from_row(DB.lists:where({ id = current.active_list_id })) or nil
  if list then
    return list
  end

  local rows = lists_from_rows(DB.lists:get({ where = { project_id = current.id }, order = { { column = "created_at", dir = "asc" } } }))
  if rows[1] then
    M.set_active_list(rows[1].id)
    return rows[1]
  end

  local time = now()
  local list_id = DB.lists:insert({
    project_id = current.id,
    name = config.get().default_list_name,
    description = "",
    created_at = time,
    updated_at = time,
  })
  M.set_active_list(list_id)
  return list_from_row(DB.lists:where({ id = list_id }))
end

function M.set_active_list(list_id)
  local current = M.project()
  local list = list_from_row(DB.lists:where({ id = list_id, project_id = current.id }))
  if not list then
    error("xmark: list not found in current project")
  end
  DB.projects:update({ where = { id = current.id }, set = { active_list_id = list_id, updated_at = now() } })
  return list
end

function M.create_list(name, desc)
  local current = M.project()
  local time = now()
  local list_id = DB.lists:insert({
    project_id = current.id,
    name = name,
    description = desc or "",
    created_at = time,
    updated_at = time,
  })
  return M.set_active_list(list_id)
end

function M.update_list(list)
  list.updated_at = now()
  DB.lists:update({ where = { id = list.id }, set = { name = list.name, description = list.desc or "", updated_at = list.updated_at } })
  return list_from_row(DB.lists:where({ id = list.id }))
end

function M.delete_list(list_id)
  local current = M.project()
  local active = M.active_list()
  if list_id == active.id then
    error("xmark: cannot delete active list")
  end
  DB.items:remove({ where = { project_id = current.id, list_id = list_id } })
  DB.lists:remove({ where = { project_id = current.id, id = list_id } })
end

function M.lists()
  return lists_from_rows(DB.lists:get({ where = { project_id = M.project().id }, order = { { column = "updated_at", dir = "desc" } } }))
end

function M.list(list_id)
  return list_from_row(DB.lists:where({ id = list_id, project_id = M.project().id }))
end

function M.items(list_id, limit)
  list_id = list_id or M.active_list().id
  local opts = { where = { list_id = list_id }, order = { { column = "item_order", dir = "asc" } } }
  if limit then
    opts.limit = limit
  end
  return items_from_rows(DB.items:get(opts))
end

function M.items_by_path(path, list_id)
  local current = M.project()
  list_id = list_id or M.active_list().id
  return items_from_rows(DB.items:get({
    where = { project_id = current.id, list_id = list_id, path = path },
    order = { { column = "line", dir = "asc" } },
  }))
end

function M.item_count(list_id)
  local rows = eval("SELECT COUNT(*) AS count FROM items WHERE list_id = :list_id", { list_id = list_id })
  return tonumber(rows and rows[1] and rows[1].count) or 0
end

function M.item_at(path, line, list_id)
  local current = M.project()
  list_id = list_id or M.active_list().id
  return item_from_row(DB.items:where({ project_id = current.id, list_id = list_id, path = path, line = line }))
end

function M.insert_item(item)
  local current = M.project()
  local list = M.active_list()
  local rows = M.items(list.id)
  local time = now()
  return DB.items:insert({
    project_id = current.id,
    list_id = list.id,
    path = item.path,
    line = item.line,
    col = item.col or 0,
    description = item.desc or "",
    meta = item.meta or "",
    item_order = item.item_order or #rows + 1,
    created_at = time,
    updated_at = time,
    visited_at = time,
  })
end

function M.update_item(item)
  local time = now()
  DB.items:update({
    where = { id = item.id },
    set = {
      path = item.path,
      line = item.line,
      col = item.col or 1,
      description = item.desc or "",
      meta = item.meta or "",
      item_order = item.item_order,
      updated_at = time,
      visited_at = item.visited_at,
    },
  })
  return item_from_row(DB.items:where({ id = item.id }))
end

function M.delete_item(item_id)
  DB.items:remove({ where = { id = item_id } })
end

function M.item(item_id)
  return item_from_row(DB.items:where({ id = item_id }))
end

function M.reorder_items(items)
  local time = now()
  for order, item in ipairs(items) do
    DB.items:update({ where = { id = item.id }, set = { item_order = order, description = item.desc or "", updated_at = time } })
  end
end

return M
