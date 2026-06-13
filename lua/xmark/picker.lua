local config = require("xmark.config")
local core = require("xmark.core")

local M = {}

local function snacks()
  if _G.Snacks and _G.Snacks.picker then
    return _G.Snacks
  end

  local ok, mod = pcall(require, "snacks")
  if ok and mod.picker then
    return mod
  end

  error("xmark.nvim requires snacks.nvim for picker commands")
end

local function item_text(item)
  local desc = core.display(item)
  return string.format("%-48s %s:%d", desc, item.path, item.line)
end

local function item_format(item)
  local desc = core.display(item.item)
  local location = string.format("%s:%d", item.item.path, item.item.line)

  return {
    { desc, item.item.desc ~= "" and "SnacksPickerComment" or "SnacksPickerFile" },
    { "  " },
    { location, "SnacksPickerDir" },
  }
end

function M.items()
  local list = core.active_list()
  local items = core.items(list.id)
  local picker_items = {}

  for _, item in ipairs(items) do
    local search = table.concat({ item.desc or "", item.path, tostring(item.line), item.meta or "" }, " ")
    table.insert(picker_items, {
      text = item_text(item),
      file = require("xmark.project").absolute(item.path),
      pos = { item.line, math.max((item.col or 1) - 1, 0) },
      search = search,
      item = item,
    })
  end

  snacks().picker({
    title = "Xmark: " .. list.name,
    items = picker_items,
    format = item_format,
    preview = "file",
    limit = config.get().picker.limit,
    confirm = function(picker, selected)
      picker:close()
      if selected and selected.item then
        core.goto(selected.item)
      end
    end,
    actions = {
      delete_xmark = function(picker, selected)
        if selected and selected.item then
          require("xmark.db").delete_item(selected.item.id)
          require("xmark.sign").refresh()
          picker:close()
          vim.schedule(M.items)
        end
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-d>"] = { "delete_xmark", mode = { "i", "n" }, desc = "Delete xmark" },
        },
      },
    },
  })
end

function M.lists()
  local active = core.active_list()
  local lists = core.lists()

  snacks().picker.select(lists, {
    prompt = "Xmark Lists",
    format_item = function(list)
      local count = require("xmark.db").item_count(list.id)
      return string.format("%s%s (%d)", list.id == active.id and "* " or "  ", list.name, count)
    end,
    snacks = {
      preview = false,
      limit = config.get().picker.limit,
      actions = {
        delete_xmark_list = function(picker, selected)
          if selected and selected.item then
            core.delete_list(selected.item.id)
            picker:close()
            vim.schedule(M.lists)
          end
        end,
        edit_xmark_list = function(picker, selected)
          if selected and selected.item then
            core.set_active_list(selected.item.id)
            picker:close()
            vim.schedule(function()
              require("xmark.editor").open()
            end)
          end
        end,
      },
      win = {
        input = {
          keys = {
            ["<C-d>"] = { "delete_xmark_list", mode = { "i", "n" }, desc = "Delete xmark list" },
            ["<C-e>"] = { "edit_xmark_list", mode = { "i", "n" }, desc = "Edit xmark list" },
          },
        },
      },
    },
  }, function(list)
    if list then
      core.set_active_list(list.id)
    end
  end)
end

return M
