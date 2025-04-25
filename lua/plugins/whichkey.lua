return {
    "folke/which-key.nvim",
    event = "VeryLazy", -- Load WhichKey very lazily
    config = function()
        require("which-key").setup({
        })
    end
}
