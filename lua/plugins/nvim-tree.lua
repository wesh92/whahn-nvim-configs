return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
    require("nvim-tree").setup({
      renderer = {
        -- defaults include Git decorator; make it explicit if desired
        highlight_git = "name",
        icons = { show = { git = true } },
      },
      filters = { git_ignored = false }, -- show ignored rows; toggle with I
    })
  end,
}
