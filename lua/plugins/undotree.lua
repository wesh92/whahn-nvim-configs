return {
  'mbbill/undotree',
  config = function()
    vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle)
    -- Add any other undotree settings here
    vim.g.undotree_WindowLayout = 2
  end
}
