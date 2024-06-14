vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.opt.smartindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false  
vim.opt.undodir = vim.fn.stdpath('config')..'/undodir'
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 10
vim.opt.signcolumn = 'yes'
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50

vim.opt.colorcolumn = '124'
vim.g.mapleader = ' '

vim.opt.clipboard="unnamedplus"

-- Set the terminal emulator to Zsh
vim.g.terminal_emulator='zsh'

-- Set the shell to Zsh
vim.opt.shell = '/usr/bin/zsh'

-- Adjust shell-related options for Zsh
vim.o.shellxquote = ''
vim.o.shellcmdflag = '-c'
vim.o.shellquote = ''
vim.o.shellpipe = '2>&1| tee %s'
vim.o.shellredir = '>%s 2>&1'

