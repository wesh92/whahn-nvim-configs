return {
    "neovim/nvim-lspconfig",
    dependencies = {
        { "mason-org/mason.nvim", version = "^2.0.0" },
        { "mason-org/mason-lspconfig.nvim", version = "^2.0.0" },
        "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
        require("config.lsp").setup()
    end,
}
