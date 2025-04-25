return {
  'maxmx03/fluoromachine.nvim',
  lazy = false,    -- Load early for theme
  priority = 1000, -- Ensure it loads before other plugins
  config = function()
    local fm = require 'fluoromachine'
    fm.setup {
        glow = false,
        theme = 'retrowave',
        transparent = true
    }
    -- Set the colorscheme after setup
    vim.cmd.colorscheme 'fluoromachine' 
  end
}
