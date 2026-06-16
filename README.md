# xmark.nvim

A SQLite-backed bookmark system for large codebases and security auditing workflows.

`xmark.nvim` is intentionally small: it stores project-scoped bookmark lists, keeps one active list per project, integrates with `snacks.nvim` for picking, and exposes JSON import/export for AI agents.

## Requirements

- Neovim 0.9+
- [kkharji/sqlite.lua](https://github.com/kkharji/sqlite.lua)
- [folke/snacks.nvim](https://github.com/folke/snacks.nvim) for picker commands

If `sqlite.lua` is lazy-loaded, declare it in `dependencies` so it is available when `xmark.nvim` calls `require("sqlite")`.

## Install

```lua
{
  "wzj-zz/xmark.nvim",
  dependencies = {
    "kkharji/sqlite.lua",
    "folke/snacks.nvim",
  },
  config = function()
    require("xmark").setup()
  end,
}
```

## Commands

| Command | Description |
| --- | --- |
| `:XmarkAdd` | Add or update current line in the active list, prompting for desc |
| `:XmarkToggle` | Toggle current line in the active list |
| `:XmarkDesc` | Edit desc for current line |
| `:XmarkDelete` | Delete current line from active list |
| `:XmarkCurrent` | Jump to the current item tracked for the active list |
| `:XmarkSetCurrent` | Set the active list current item from the current line |
| `:XmarkNext` / `:XmarkPrev` | Jump through items in active list order without wrap-around |
| `:XmarkFirst` / `:XmarkLast` | Jump to first or last item in active list |
| `:XmarkPick` | Search active list with snacks and jump to an item |
| `:XmarkQuickfix` | Load the active list into the quickfix list |
| `:XmarkLists` | Switch the active list with snacks |
| `:XmarkNewList` | Create and activate a list |
| `:XmarkRenameList` | Rename the active list |
| `:XmarkEditList` | Open a Harpoon-style list editor for ordering and desc edits |
| `:XmarkImport path.json [list_name]` | Import agent JSON into a new list |
| `:XmarkExport path.json` | Export the active list as JSON |

`XmarkNext` and `XmarkPrev` stop at the list boundaries and do not wrap around. They advance from the active list current item, which is updated by jumps and can be set explicitly with `:XmarkSetCurrent`.

## Keymaps

Default keymaps:

- `<Leader>mm`: add or update current line.
- `<Leader>mt`: toggle current line.
- `<Leader>md`: delete current line.
- `<Leader>mc`: edit current line desc.
- `<Leader>mg` / `<M-?>`: jump to the current item for the active list.
- `<Leader>ms`: set the current item for the active list from the current line.
- `<Leader>mp` / `<C-[>`: previous item without wrap-around.
- `<Leader>mn` / `<C-]>`: next item without wrap-around.
- `<Leader>mP` / `<Leader>mN`: first / last item.
- `<Leader>mf`: pick item from active list.
- `<Leader>mq`: load the active list into quickfix.
- `<Leader>ml`: pick active list.
- `<Leader>ma`: create and activate a new list.
- `<Leader>mr`: rename active list.
- `<Leader>me`: edit active list order.
- `<Leader>mi`: import JSON with `vim.ui.input` prompts.
- `<Leader>mo`: export JSON with `vim.ui.input` prompts.

Every keymap can be overridden or disabled:

```lua
require("xmark").setup({
  keymaps = {
    enabled = true,
    add = "<Leader>mm",
    toggle = "<Leader>mt",
    delete = "<Leader>md",
    desc = "<Leader>mc",
    current = { "<Leader>mg", "<M-?>" },
    set_current = "<Leader>ms",
    prev = { "<Leader>mp", "<C-[>" },
    next = { "<Leader>mn", "<C-]>" },
    first = "<Leader>mP",
    last = "<Leader>mN",
    pick = "<Leader>mf",
    quickfix = "<Leader>mq",
    lists = "<Leader>ml",
    new_list = "<Leader>ma",
    rename_list = "<Leader>mr",
    edit_list = "<Leader>me",
    import = "<Leader>mi",
    export = "<Leader>mo",
  },
})
```

Each entry accepts a string, a string list, or `false` to disable it.

Each list also keeps its own current item. `:XmarkCurrent` jumps to it, `:XmarkSetCurrent` pins it from the current line, and jumps like `:XmarkNext`, `:XmarkPrev`, and picker-based navigation keep it updated.

The current item is also highlighted in the source buffer with a stronger line highlight and a `>>` prefix in the virtual text.

You can tune that marker styling through `signs`:

```lua
require("xmark").setup({
  signs = {
    desc_hl = "XmarkDesc",
    line_hl = "XmarkLine",
    current_line_hl = "XmarkCurrentLine",
    current_prefix = ">>",
  },
})
```

## Picker Shortcuts

Inside `:XmarkPick`:

- `<CR>`: jump to the selected item.
- `<C-d>`: delete the selected item and reopen the picker.

Inside `:XmarkLists`:

- `<CR>`: switch the active list.
- `<C-d>`: delete the selected list.
- `<C-e>`: switch to the selected list and open its editor.

Deleting the active list is safe: `xmark.nvim` switches to another list first, or creates a fresh default list if needed.

## Edit Panel

`:XmarkEditList` opens in a centered floating window, so it does not resize the rest of your layout.

- `<C-j>` / `<C-k>`: move the current item down or up.
- `<CR>`: close the panel without saving and jump to the selected item.
- `<C-s>`: save changes and close the panel.
- `q`: close the panel without saving.

Inside the `:XmarkEditList` panel, each line starts with its current list order as `N.`. Moving items with `<C-j>` / `<C-k>` renumbers that panel immediately, and saving writes the new order plus any desc edits or deleted lines back to the list.

## Data Model

Runtime data is stored in SQLite under `stdpath("data") .. "/xmark/xmark.sqlite3"` by default.

- `projects`: one row per project root.
- `lists`: multiple lists per project.
- `items`: ordered bookmark entries with `path`, `line`, `col`, `desc`, and `meta`.

Paths are stored relative to the project root, so exported data is easy for agents to read and portable across machines.

## Import And Export

`XmarkImport` always creates and activates a new list.

- If you pass `list_name`, that name wins.
- If you omit `list_name`, `xmark.nvim` uses the JSON `list` or `name` field.
- If the JSON also omits a name, `xmark.nvim` falls back to `default_list_name` from config.
- `XmarkImport` and `XmarkExport` both support quoted paths, so files with spaces work as expected.

Examples:

- `:XmarkImport findings.json`
- `:XmarkImport findings.json review-notes`
- `:XmarkImport findings.json "review notes"`
- `:XmarkImport "findings with spaces.json" "review notes"`
- `:XmarkExport findings.json`
- `:XmarkExport "findings with spaces.json"`

## Agent JSON

Agents can output either a plain array:

```json
[
  {
    "path": "src/auth/login.lua",
    "line": 42,
    "col": 7,
    "desc": "possible auth bypass: empty token accepted",
    "meta": {
      "severity": "high",
      "cwe": "CWE-287"
    }
  }
]
```

Or a named list:

```json
{
  "list": "agent-auth-audit",
  "items": [
    {
      "path": "src/auth/login.lua",
      "line": 42,
      "desc": "possible auth bypass"
    }
  ]
}
```

## Performance

`xmark.nvim` does not scan the codebase. Common operations use SQLite indexes:

- active list item order: `list_id, item_order`
- current buffer signs: `project_id, list_id, path`
- current line lookup: `project_id, list_id, path, line`

This keeps large repositories responsive; performance is tied to bookmark count, not repository size.
