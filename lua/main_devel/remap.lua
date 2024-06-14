vim.keymap.set("n", "<Space>", "<Nop>", { silent = true, remap = false })

vim.g.mapleader = " "
vim.keymap.set("n", "<leader>vv", vim.cmd.Ex)
-- Yank into system clipboard
vim.keymap.set({'n', 'v'}, '<leader>y', '"+y') -- yank motion
vim.keymap.set({'n', 'v'}, '<leader>Y', '"+Y') -- yank line

-- Delete into system clipboard
vim.keymap.set({'n', 'v'}, '<leader>d', '"+d') -- delete motion
vim.keymap.set({'n', 'v'}, '<leader>D', '"+D') -- delete line

-- Paste from system clipboard
vim.keymap.set('n', '<leader>p', '"+p')  -- paste after cursor
vim.keymap.set('n', '<leader>P', '"+P')  -- paste before cursor

-- Python stuff
vim.keymap.set('n', '<leader>py', ":update<bar>!python %<CR>")

-- Copilot Panel
vim.keymap.set('n', '<leader>cc', ":Copilot panel<CR>")

-- Close Buffer
vim.keymap.set('n', '<leader>vc', ":bd<CR>")

-- Powershell Runner
vim.keymap.set('n', '<leader>ps', ':update<bar>!powershell %<CR>')

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>")

-- Ruff Checks
vim.keymap.set("n", "<leader>rc", ":update<bar>!ruff check %<CR>")
vim.keymap.set("n", "<leader>rf", ":update<bar>!ruff check % --fix<CR>")
-- Ruff check but ignore unused import rule
vim.keymap.set("n", "<leader>rfi", ":update<bar>!ruff check % --fix --ignore=F401<CR>")

-- Black Formatter
vim.keymap.set("n", "<leader>bf", ":update<bar>!black %<CR>")

-- Pytest
vim.keymap.set("n", "<leader>pt", ":update<bar>!pytest %<CR>")
-- Pytest no warnings
vim.keymap.set("n", "<leader>pnw", ":update<bar>!pytest -p no:warnings %<CR>")

-- Poetry add
vim.keymap.set("n", "<leader>poa", ":update<bar>!poetry add ")

-- Poetry remove
vim.keymap.set("n", "<leader>por", ":update<bar>!poetry remove ")

-- Poetry update
vim.keymap.set("n", "<leader>pou", ":update<bar>!poetry update<CR>")

-- Copy Filepaths
vim.keymap.set("n", "<leader>fin", ":let @+ = expand('%')<CR>")
vim.keymap.set("n", "<leader>fip", ":let @+ = expand('%:p')<CR>") 
