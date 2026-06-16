if vim.g.loaded_xmark == 1 then
  return
end
vim.g.loaded_xmark = 1

require("xmark.commands").setup()
require("xmark").setup_keymaps()
