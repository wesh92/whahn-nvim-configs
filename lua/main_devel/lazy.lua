-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({"git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath})
    if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({{"Failed to clone lazy.nvim:\n", "ErrorMsg"}, {out, "WarningMsg"},
                           {"\nPress any key to exit..."}}, true, {})
        vim.fn.getchar()
        os.exit(1)
    end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("lazy").setup({"folke/which-key.nvim", {
    "folke/neoconf.nvim",
    cmd = "Neoconf"
}, "folke/neodev.nvim", {{
    'maxmx03/fluoromachine.nvim',
    lazy = false,
    priority = 1000,
    config = function()
        local fm = require 'fluoromachine'

        fm.setup {
            glow = false,
            theme = 'retrowave',
            transparent = true
        }

        vim.cmd.colorscheme 'fluoromachine'
    end
}}, {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.4',
    -- or                              , branch = '0.1.x',
    dependencies = {'nvim-lua/plenary.nvim'}
}, {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate"
}, {"ThePrimeagen/harpoon"}, {"mbbill/undotree"}, {
    'VonHeikemen/lsp-zero.nvim',
    branch = 'v3.x',
    lazy = true,
    config = false
}, {"williamboman/mason.nvim"}, 'williamboman/mason-lspconfig.nvim', {
    'neovim/nvim-lspconfig',
    dependencies = {{'hrsh7th/cmp-nvim-lsp'}}
}, -- Autocompletion
{
    'hrsh7th/nvim-cmp',
    dependencies = {{'L3MON4D3/LuaSnip'}}
}, {'echasnovski/mini.surround'}, {'nvim-tree/nvim-web-devicons'}, {'lewis6991/gitsigns.nvim'}, {'romgrk/barbar.nvim'},
                       {'github/copilot.vim'}, {
    'goolord/alpha-nvim',
    config = function()
        require'alpha'.setup(require'alpha.themes.dashboard'.config)
    end
}, {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {}
}, {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
        opt = true
    },
    lazy = false
}})
