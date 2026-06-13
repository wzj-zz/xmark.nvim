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
| `:XmarkNext` / `:XmarkPrev` | Jump through items in active list order without wrap-around |
| `:XmarkFirst` / `:XmarkLast` | Jump to first or last item in active list |
| `:XmarkPick` | Search active list with snacks and jump to an item |
| `:XmarkLists` | Switch the active list with snacks |
| `:XmarkNewList` | Create and activate a list |
| `:XmarkRenameList` | Rename the active list |
| `:XmarkEditList` | Open a Harpoon-style list editor for ordering and desc edits |
| `:XmarkImport path.json` | Import agent JSON into the active list |
| `:XmarkImport! path.json` | Import agent JSON into a new list |
| `:XmarkExport path.json` | Export the active list as agent-friendly JSON |

`XmarkNext` and `XmarkPrev` stop at the list boundaries and do not wrap around.

## Keymaps

Default keymaps:

- `<Leader>mm`: add or update current line.
- `<Leader>mt`: toggle current line.
- `<Leader>md`: delete current line.
- `<Leader>mc`: edit current line desc.
- `<Leader>mp` / `<M-{>`: previous item without wrap-around.
- `<Leader>mn` / `<M-}>`: next item without wrap-around.
- `<Leader>mP` / `<Leader>mN`: first / last item.
- `<Leader>mf`: pick item from active list.
- `<Leader>ml`: pick active list.
- `<Leader>ma`: create and activate a new list.
- `<Leader>mr`: rename active list.
- `<Leader>me`: edit active list order.

Every keymap can be overridden or disabled:

```lua
require("xmark").setup({
  keymaps = {
    enabled = true,
    add = "<Leader>mm",
    toggle = "<Leader>mt",
    delete = "<Leader>md",
    desc = "<Leader>mc",
    prev = { "<Leader>mp", "<M-{>" },
    next = { "<Leader>mn", "<M-}>" },
    first = "<Leader>mP",
    last = "<Leader>mN",
    pick = "<Leader>mf",
    lists = "<Leader>ml",
    new_list = "<Leader>ma",
    rename_list = "<Leader>mr",
    edit_list = "<Leader>me",
  },
})
```

Each entry accepts a string, a string list, or `false` to disable it.

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

Each line keeps a hidden-stable `#id` prefix so the editor can reorder items, update desc, and detect deletions by removed lines.

## Data Model

Runtime data is stored in SQLite under `stdpath("data") .. "/xmark/xmark.sqlite3"` by default.

- `projects`: one row per project root.
- `lists`: multiple lists per project.
- `items`: ordered bookmark entries with `path`, `line`, `col`, `desc`, and `meta`.

Paths are stored relative to the project root, so exported data is easy for agents to read and portable across machines.

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

Use `:XmarkImport! findings.json` to create a new active list from the agent output.

## Performance

`xmark.nvim` does not scan the codebase. Common operations use SQLite indexes:

- active list item order: `list_id, item_order`
- current buffer signs: `project_id, list_id, path`
- current line lookup: `project_id, list_id, path, line`

This keeps large repositories responsive; performance is tied to bookmark count, not repository size.
