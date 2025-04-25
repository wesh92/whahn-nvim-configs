return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require'nvim-treesitter.configs'.setup {
      ensure_installed = { "python", "r" ,"c", "lua", "vim", "vimdoc", "query", "bash", "markdown", "json", "yaml", "toml", "html", "css", "javascript", "typescript" }, -- Added more common ones

      sync_install = false,

      auto_install = true,

      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
      -- Add other modules as needed
      -- indent = { enable = true },
      -- rainbow = { enable = true }, 
    }
  end
}
