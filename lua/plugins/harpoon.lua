return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2', -- upstream's maintained API; Harpoon 1 is frozen
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require("harpoon")
    harpoon:setup()

    vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end)
    vim.keymap.set("n", "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)
    vim.keymap.set("n", "<leader>hy", function() harpoon:list():select(1) end)
    vim.keymap.set("n", "<leader>hu", function() harpoon:list():select(2) end)
    vim.keymap.set("n", "<leader>hi", function() harpoon:list():select(3) end)
    vim.keymap.set("n", "<leader>ho", function() harpoon:list():select(4) end)
  end
}
