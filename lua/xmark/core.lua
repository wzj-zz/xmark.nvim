local db = require("xmark.db")
local config = require("xmark.config")
local project = require("xmark.project")

local M = {}

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "xmark.nvim" })
end

local function current_location()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    error("xmark: current buffer has no file path")
  end
  local cursor = vim.api.nvim_win_get_cursor(0)
  return {
    path = project.relative(path),
    line = cursor[1],
    col = cursor[2] + 1,
  }
end

local function display(item)
  if item.desc and item.desc ~= "" then
    return item.desc
  end
  return string.format("%s:%d", item.path, item.line)
end

function M.active_list()
  return db.active_list()
end

function M.lists()
  return db.lists()
end

function M.items(list_id)
  return db.items(list_id)
end

function M.current_item()
  local loc = current_location()
  return db.item_at(loc.path, loc.line)
end

function M.add(desc, meta)
  local loc = current_location()
  local item = db.item_at(loc.path, loc.line)

  if item then
    item.col = loc.col
    item.desc = desc or item.desc or ""
    if meta then
      item.meta = meta
    end
    item = db.update_item(item)
    notify("Updated xmark: " .. display(item))
  else
    local item_id = db.insert_item({
      path = loc.path,
      line = loc.line,
      col = loc.col,
      desc = desc or "",
      meta = meta or "",
    })
    item = db.item(item_id)
    notify("Added xmark: " .. display(item))
  end

  require("xmark.sign").refresh()
  return item
end

function M.toggle(desc)
  local item = M.current_item()
  if item then
    db.delete_item(item.id)
    notify("Deleted xmark: " .. display(item))
  else
    M.add(desc)
  end
  require("xmark.sign").refresh()
end

function M.delete_current()
  local item = M.current_item()
  if not item then
    notify("No xmark at current line", vim.log.levels.WARN)
    return
  end
  db.delete_item(item.id)
  require("xmark.sign").refresh()
  notify("Deleted xmark: " .. display(item))
end

function M.update_desc(desc)
  local item = M.current_item()
  if not item then
    return M.add(desc)
  end
  item.desc = desc or ""
  db.update_item(item)
  require("xmark.sign").refresh()
  notify("Updated xmark desc")
end

function M.goto(item)
  if not item then
    return
  end

  local path = project.absolute(item.path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))

  local line_count = vim.api.nvim_buf_line_count(0)
  local line = math.max(1, math.min(item.line, line_count))
  local col = math.max(0, (item.col or 1) - 1)
  vim.api.nvim_win_set_cursor(0, { line, col })
  vim.cmd("normal! zz")

  item.visited_at = os.time()
  db.update_item(item)
  require("xmark.sign").refresh()
end

local function current_index(items)
  local ok, loc = pcall(current_location)
  if ok then
    for index, item in ipairs(items) do
      if item.path == loc.path and item.line == loc.line then
        return index
      end
    end
  end

  local best_index, best_time = nil, -1
  for index, item in ipairs(items) do
    local visited_at = item.visited_at or 0
    if visited_at > best_time then
      best_index = index
      best_time = visited_at
    end
  end
  return best_index or 1
end

function M.jump(delta)
  local items = db.items(db.active_list().id)
  if #items == 0 then
    notify("Current xmark list is empty", vim.log.levels.WARN)
    return
  end

  local index = current_index(items)
  local target = index + delta
  if target < 1 then
    notify("Already at first xmark item", vim.log.levels.WARN)
    return
  end
  if target > #items then
    notify("Already at last xmark item", vim.log.levels.WARN)
    return
  end
  M.goto(items[target])
end

function M.next()
  M.jump(1)
end

function M.prev()
  M.jump(-1)
end

function M.first()
  local items = db.items(db.active_list().id)
  if #items == 0 then
    notify("Current xmark list is empty", vim.log.levels.WARN)
    return
  end
  M.goto(items[1])
end

function M.last()
  local items = db.items(db.active_list().id)
  if #items == 0 then
    notify("Current xmark list is empty", vim.log.levels.WARN)
    return
  end
  M.goto(items[#items])
end

function M.create_list(name, desc)
  if not name or name == "" then
    notify("List name is required", vim.log.levels.WARN)
    return
  end
  local list = db.create_list(name, desc)
  require("xmark.sign").refresh()
  notify("Active xmark list: " .. list.name)
  return list
end

function M.rename_active_list(name)
  if not name or name == "" then
    return
  end
  local list = db.active_list()
  list.name = name
  db.update_list(list)
  notify("Renamed active xmark list: " .. name)
end

function M.delete_list(list_id)
  local list = db.list(list_id)
  if not list then
    notify("Xmark list not found", vim.log.levels.WARN)
    return
  end

  local active = db.active_list()
  if list.id == active.id then
    local fallback = nil
    for _, candidate in ipairs(db.lists()) do
      if candidate.id ~= list.id then
        fallback = candidate
        break
      end
    end

    if fallback then
      db.set_active_list(fallback.id)
    else
      db.create_list(config.get().default_list_name)
    end
  end

  db.delete_list(list.id)
  require("xmark.sign").refresh()
  notify("Deleted xmark list: " .. list.name)
  return db.active_list()
end

function M.set_active_list(list_id)
  local list = db.set_active_list(list_id)
  require("xmark.sign").refresh()
  notify("Active xmark list: " .. list.name)
  return list
end

function M.display(item)
  return display(item)
end

return M
