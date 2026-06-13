if vim.g.loaded_xmark == 1 then
  return
end
vim.g.loaded_xmark = 1

local function run(fn)
  return function(opts)
    local ok, err = pcall(fn, opts)
    if not ok then
      vim.notify(err, vim.log.levels.ERROR, { title = "xmark.nvim" })
    end
  end
end

vim.api.nvim_create_user_command("XmarkAdd", run(function()
  require("xmark").add()
end), { desc = "Add or update xmark at current line" })

vim.api.nvim_create_user_command("XmarkToggle", run(function()
  require("xmark").toggle()
end), { desc = "Toggle xmark at current line" })

vim.api.nvim_create_user_command("XmarkDelete", run(function()
  require("xmark").delete()
end), { desc = "Delete xmark at current line" })

vim.api.nvim_create_user_command("XmarkDesc", run(function()
  require("xmark").desc()
end), { desc = "Edit xmark desc at current line" })

vim.api.nvim_create_user_command("XmarkNext", run(function()
  require("xmark").next()
end), { desc = "Go to next item in active xmark list" })

vim.api.nvim_create_user_command("XmarkPrev", run(function()
  require("xmark").prev()
end), { desc = "Go to previous item in active xmark list" })

vim.api.nvim_create_user_command("XmarkFirst", run(function()
  require("xmark").first()
end), { desc = "Go to first item in active xmark list" })

vim.api.nvim_create_user_command("XmarkLast", run(function()
  require("xmark").last()
end), { desc = "Go to last item in active xmark list" })

vim.api.nvim_create_user_command("XmarkPick", run(function()
  require("xmark").pick()
end), { desc = "Pick an item from active xmark list" })

vim.api.nvim_create_user_command("XmarkLists", run(function()
  require("xmark").lists()
end), { desc = "Pick active xmark list" })

vim.api.nvim_create_user_command("XmarkNewList", run(function()
  require("xmark").new_list()
end), { desc = "Create and activate a new xmark list" })

vim.api.nvim_create_user_command("XmarkRenameList", run(function()
  require("xmark").rename_list()
end), { desc = "Rename active xmark list" })

vim.api.nvim_create_user_command("XmarkEditList", run(function()
  require("xmark").edit_list()
end), { desc = "Edit active xmark list order" })

vim.api.nvim_create_user_command("XmarkImport", run(function(opts)
  require("xmark").import_file(opts.args, { new_list = opts.bang })
end), { bang = true, nargs = 1, complete = "file", desc = "Import agent JSON xmarks" })

vim.api.nvim_create_user_command("XmarkExport", run(function(opts)
  require("xmark").export_file(opts.args)
end), { nargs = 1, complete = "file", desc = "Export active xmark list as JSON" })
