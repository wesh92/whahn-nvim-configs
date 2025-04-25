return {
  'github/copilot.vim',
  config = function()
    vim.cmd("Copilot disable") 
    -- You can add other Copilot settings here if needed
    -- Example: vim.g.copilot_filetypes = { markdown = true }
  end
}
