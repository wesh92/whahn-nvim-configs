require("config.lazy")
require("config/remap")
require("config/set")
require("lazy").setup("plugins")
vim.cmd(":Copilot disable")
vim.cmd.colorscheme "catppuccin-macchiato"
