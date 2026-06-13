local config = require("xmark.config")

local M = {}
local initialized = false

local function normalize_keys(value)
  if value == false or value == nil then
    return {}
  end
  if type(value) == "string" then
    return value ~= "" and { value } or {}
  end
  if vim.islist(value) then
    return value
  end
  return {}
end

local function setup_keymaps()
  local keymaps = config.get().keymaps
  if not keymaps or keymaps.enabled == false then
    return
  end

  local mappings = {
    add = { rhs = function() require("xmark").add() end, desc = "Xmark add item" },
    toggle = { rhs = function() require("xmark").toggle() end, desc = "Xmark toggle item" },
    delete = { rhs = function() require("xmark").delete() end, desc = "Xmark delete item" },
    desc = { rhs = function() require("xmark").desc() end, desc = "Xmark edit desc" },
    current = { rhs = function() require("xmark").current() end, desc = "Xmark goto current item" },
    set_current = { rhs = function() require("xmark").set_current() end, desc = "Xmark set current item" },
    prev = { rhs = function() require("xmark").prev() end, desc = "Xmark previous item" },
    next = { rhs = function() require("xmark").next() end, desc = "Xmark next item" },
    first = { rhs = function() require("xmark").first() end, desc = "Xmark first item" },
    last = { rhs = function() require("xmark").last() end, desc = "Xmark last item" },
    pick = { rhs = function() require("xmark").pick() end, desc = "Xmark pick item" },
    quickfix = { rhs = function() require("xmark").quickfix() end, desc = "Xmark list to quickfix" },
    lists = { rhs = function() require("xmark").lists() end, desc = "Xmark pick list" },
    new_list = { rhs = function() require("xmark").new_list() end, desc = "Xmark new list" },
    rename_list = { rhs = function() require("xmark").rename_list() end, desc = "Xmark rename list" },
    edit_list = { rhs = function() require("xmark").edit_list() end, desc = "Xmark edit list order" },
  }

  for name, mapping in pairs(mappings) do
    for _, lhs in ipairs(normalize_keys(keymaps[name])) do
      vim.keymap.set("n", lhs, mapping.rhs, { desc = mapping.desc, silent = true })
    end
  end
end

function M.setup(opts)
  config.setup(opts)
  require("xmark.db").setup()
  require("xmark.sign").setup()
  require("xmark.sign").setup_autocmds()
  setup_keymaps()
  initialized = true
end

local function ensure()
  if not initialized then
    M.setup({})
  end
end

local function input(prompt, default, callback)
  vim.ui.input({ prompt = prompt, default = default }, function(value)
    if value ~= nil then
      callback(value)
    end
  end)
end

function M.add()
  ensure()
  input("Xmark desc: ", "", function(desc)
    require("xmark.core").add(desc)
  end)
end

function M.toggle()
  ensure()
  require("xmark.core").toggle()
end

function M.delete()
  ensure()
  require("xmark.core").delete_current()
end

function M.desc()
  ensure()
  local item = require("xmark.core").current_item()
  input("Xmark desc: ", item and item.desc or "", function(desc)
    require("xmark.core").update_desc(desc)
  end)
end

function M.current()
  ensure()
  require("xmark.core").goto_current()
end

function M.set_current()
  ensure()
  require("xmark.core").set_current_item()
end

function M.next()
  ensure()
  require("xmark.core").next()
end

function M.prev()
  ensure()
  require("xmark.core").prev()
end

function M.first()
  ensure()
  require("xmark.core").first()
end

function M.last()
  ensure()
  require("xmark.core").last()
end

function M.pick()
  ensure()
  require("xmark.picker").items()
end

function M.quickfix()
  ensure()
  require("xmark.core").quickfix()
end

function M.lists()
  ensure()
  require("xmark.picker").lists()
end

function M.new_list()
  ensure()
  input("Xmark list name: ", "", function(name)
    require("xmark.core").create_list(name)
  end)
end

function M.rename_list()
  ensure()
  local list = require("xmark.core").active_list()
  input("Xmark list name: ", list.name, function(name)
    require("xmark.core").rename_active_list(name)
  end)
end

function M.edit_list()
  ensure()
  require("xmark.editor").open()
end

function M.import_file(path, opts)
  ensure()
  return require("xmark.import").import_file(path, opts)
end

function M.export_file(path)
  ensure()
  return require("xmark.import").export_file(path)
end

return M
