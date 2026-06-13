local config = require("xmark.config")
local db = require("xmark.db")
local project = require("xmark.project")

local M = {}

local group = "XmarkSigns"
local ns = vim.api.nvim_create_namespace("xmark.nvim")

function M.setup()
  local opts = config.get().signs
  if not opts.enabled then
    return
  end

  vim.fn.sign_define(group, { text = opts.icon, texthl = opts.hl })
  vim.api.nvim_set_hl(0, opts.hl, { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, opts.desc_hl, { fg = "#111111", bg = "#ffcf40", bold = true, default = true })
  vim.api.nvim_set_hl(0, opts.line_hl, { link = "CursorLine", default = true })
  vim.api.nvim_set_hl(0, opts.current_line_hl, { link = "Visual", default = true })
end

function M.clear(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  pcall(vim.fn.sign_unplace, group, { buffer = bufnr })
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
end

function M.refresh(bufnr)
  local opts = config.get().signs
  if not opts.enabled then
    return
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return
  end

  M.clear(bufnr)

  local relpath = project.relative(path)
  local ok, items = pcall(db.items_by_path, relpath)
  if not ok then
    return
  end
  local current = db.current_list_item()

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for _, item in ipairs(items) do
    if item.line >= 1 and item.line <= line_count then
      local is_current = current and current.id == item.id
      local prefix = is_current and (opts.current_prefix or ">>") or ""
      pcall(vim.fn.sign_place, item.id, group, group, bufnr, {
        lnum = item.line,
        priority = is_current and 11 or 10,
        linehl = is_current and opts.current_line_hl or opts.line_hl,
      })
      if opts.show_desc then
        local text = require("xmark.core").display(item)
        vim.api.nvim_buf_set_extmark(bufnr, ns, item.line - 1, 0, {
          virt_text = { { string.format("  %s %d. %s", prefix, item.item_order or 0, text):gsub("^%s+", "  "), opts.desc_hl } },
          virt_text_pos = "eol",
        })
      end
    end
  end
end

function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("XmarkRefresh", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = augroup,
    callback = function(args)
      require("xmark.sign").refresh(args.buf)
    end,
  })
end

return M
