local core = require("xmark.core")
local db = require("xmark.db")

local M = {}

local function location_key(path, line, col)
  return table.concat({ path, tostring(line), tostring(col or 1) }, ":")
end

local function line_for(item, index)
  return string.format("%d. %s:%d:%d %s", index, item.path, item.line, item.col or 1, item.desc or "")
end

local function parse_line(line)
  local _, path, lnum, col, desc = line:match("^(%d+)%.%s+(.+):(%d+):(%d+)%s*(.*)$")
  if not path then
    return nil
  end
  return {
    path = path,
    line = tonumber(lnum),
    col = tonumber(col),
    desc = desc or "",
  }
end

local function move_line(delta)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local target = row + delta
  local last = vim.api.nvim_buf_line_count(0)
  if target < 1 or target > last then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {})
  vim.api.nvim_buf_set_lines(0, target - 1, target - 1, false, lines)
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

local function render_lines(items)
  local lines = {}
  for index, item in ipairs(items) do
    table.insert(lines, line_for(item, index))
  end
  return lines
end

local function renumber_lines(buf)
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local updated = {}

  for index, line in ipairs(current_lines) do
    if line == "" then
      table.insert(updated, line)
    else
      local parsed = parse_line(line)
      if parsed then
        table.insert(updated, string.format("%d. %s:%d:%d %s", index, parsed.path, parsed.line, parsed.col or 1, parsed.desc or ""))
      else
        table.insert(updated, line)
      end
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, updated)
end

function M.open()
  local list = core.active_list()
  local items = core.items(list.id)
  local known = {}
  local lines = {}
  local origin_win = vim.api.nvim_get_current_win()

  for _, item in ipairs(items) do
    known[location_key(item.path, item.line, item.col)] = item
  end

  lines = render_lines(items)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "xmark://" .. list.name)
  vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "xmark")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = math.max(math.floor(vim.o.columns * 0.75), 60)
  local height = math.max(math.floor(vim.o.lines * 0.7), 12)
  local row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0)
  local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
  })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  local function save()
    local ordered = {}
    local seen = {}
    local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for index, line in ipairs(current_lines) do
      if line ~= "" then
        local parsed = parse_line(line)
        local key = parsed and location_key(parsed.path, parsed.line, parsed.col)
        if not key or not known[key] then
          vim.notify("Invalid xmark editor line " .. index .. ": " .. line, vim.log.levels.ERROR)
          return false
        end
        local item = known[key]
        item.desc = parsed.desc
        table.insert(ordered, item)
        seen[item.id] = true
      end
    end

    for _, item in pairs(known) do
      if not seen[item.id] then
        db.delete_item(item.id)
      end
    end

    db.reorder_items(ordered)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, render_lines(ordered))
    vim.api.nvim_buf_set_option(buf, "modified", false)
    require("xmark.sign").refresh()
    vim.notify("Saved xmark list order", vim.log.levels.INFO, { title = "xmark.nvim" })
    return true
  end

  local function save_and_close()
    if save() and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function discard_and_close()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_set_option(buf, "modified", false)
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = save,
  })

  vim.keymap.set("n", "<C-j>", function()
    move_line(1)
    renumber_lines(buf)
  end, { buffer = buf, desc = "Move xmark down" })
  vim.keymap.set("n", "<C-k>", function()
    move_line(-1)
    renumber_lines(buf)
  end, { buffer = buf, desc = "Move xmark up" })
  vim.keymap.set("n", "<CR>", function()
    local parsed = parse_line(vim.api.nvim_get_current_line())
    if parsed then
      local target = known[location_key(parsed.path, parsed.line, parsed.col)]
      if vim.api.nvim_win_is_valid(origin_win) then
        vim.api.nvim_set_current_win(origin_win)
      end
      discard_and_close()
      core.goto(target)
    end
  end, { buffer = buf, desc = "Go to xmark" })
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    vim.cmd("stopinsert")
    save_and_close()
  end, { buffer = buf, desc = "Save and close xmark editor" })
  vim.keymap.set("n", "q", discard_and_close, { buffer = buf, desc = "Close xmark editor without saving" })
end

return M
