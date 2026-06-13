local M = {}

M.defaults = {
  data_dir = nil,
  db_name = "xmark.sqlite3",
  root_markers = { ".git" },
  default_list_name = "main",
  signs = {
    enabled = true,
    icon = "",
    hl = "XmarkSign",
    desc_hl = "XmarkDesc",
    line_hl = "XmarkLine",
    current_line_hl = "XmarkCurrentLine",
    current_prefix = ">>",
    show_desc = true,
  },
  picker = {
    limit = 5000,
  },
  keymaps = {
    enabled = true,
    add = "<Leader>mm",
    toggle = "<Leader>mt",
    delete = "<Leader>md",
    desc = "<Leader>mc",
    current = { "<Leader>mg", "<M-?>" },
    set_current = "<Leader>ms",
    prev = { "<Leader>mp", "<M-{>" },
    next = { "<Leader>mn", "<M-}>" },
    first = "<Leader>mP",
    last = "<Leader>mN",
    pick = "<Leader>mf",
    quickfix = "<Leader>mq",
    lists = "<Leader>ml",
    new_list = "<Leader>ma",
    rename_list = "<Leader>mr",
    edit_list = "<Leader>me",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  if not M.options.data_dir then
    M.options.data_dir = vim.fn.stdpath("data") .. "/xmark"
  end
  return M.options
end

function M.get()
  return M.options
end

return M
