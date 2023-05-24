# nvtags
A extension for elescope integrate with gun global.

## Prequirements

- nvim-telescope/telescope.nvim
- folke/lazy.nvim

## Install

With lazy.nvim💤
```lua
local telescope = require('telescope')

return {
  "hallestar/nvgtags.nvim",
  dependencies = "nvim-telescope/telescope.nvim",
  config = function()
    telescope.load_extension('nvgtags')
  end,
}
```
## Using
## cmd

```lua
:Telescope nvgtags find_definition
:Telescope nvgtags find_definition_under_cursor
:Telescope nvgtags find_reference
:Telescope nvgtags find_reference_under_cursor
```

# Setting

## key mapping

```lua
vim.api.nvim_set_keymap('n', '<leader>fx', [[<cmd>Telescope nvgtags find_definition<CR>]], {noremap=true, silent=true})
vim.api.nvim_set_keymap('n', '<leader>fz', [[<cmd>Telescope nvgtags find_definition_under_cursor<CR>]], {noremap=true, silent=true})
vim.api.nvim_set_keymap('n', '<leader>fp', [[<cmd>Telescope nvgtags find_reference<CR>]], {noremap=true, silent=true})
vim.api.nvim_set_keymap('n', '<leader>fq', [[<cmd>Telescope nvgtags find_reference_under_cursor<CR>]], {noremap=true, silent=true})
```

