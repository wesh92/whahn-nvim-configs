return {
  'nvim-telescope/telescope.nvim',
  version = '^0.2.2', -- latest reviewed stable series; exact revision is locked
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()

    -- Define keymaps inside the config function
    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
    vim.keymap.set('n', '<C-S-p>', builtin.git_files, {})
    vim.keymap.set('n', '<leader>fs', builtin.live_grep, { desc = 'Telescope live grep' })
    
  end
}
