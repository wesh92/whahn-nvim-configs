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

-- Terminal (visual mode only)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Terminal (Selects highlighted text for replacement)
vim.keymap.set("n", "<leader>s", ":%s/\\<<C-r><C-w>\\>/<C-r><C-w>/gI<Left><Left><Left>")

-- Ruff Checks
vim.keymap.set("n", "<leader>rc", ":update<bar>!ruff check %<CR>")
vim.keymap.set("n", "<leader>rf", ":update<bar>!ruff check % --fix<CR>")
-- Ruff check but ignore unused import rule
vim.keymap.set("n", "<leader>rfi", ":update<bar>!ruff check % --fix --ignore=F401<CR>")

-- Copy Filepaths
vim.keymap.set("n", "<leader>fin", ":let @+ = expand('%')<CR>")
vim.keymap.set("n", "<leader>fip", ":let @+ = expand('%:p')<CR>")

-- UV (for python)
vim.keymap.set("n", "<leader>ua", ":update<bar>!uv add ")
vim.keymap.set("n", "<leader>ui", ":update<bar>!uv init<CR>")
vim.keymap.set("n", "<leader>ur", ":update<bar>!uv remove ")
vim.keymap.set("n", "<leader>up", ":update<bar>!uv python ")

-- Git
-- Note: uses my custom git wrappers and expanders in Fish
vim.keymap.set("n", "<leader>ga", ":update<bar>!git add ")
vim.keymap.set("n", "<leader>gc", ":update<bar>!git commit -m -S ")
vim.keymap.set("n", "<leader>gp", ":update<bar>!git push ")
vim.keymap.set("n", "<leader>gpl", ":update<bar>!git pull ")
vim.keymap.set("n", "<leader>gb", ":update<bar>!git branch ")
vim.keymap.set("n", "<leader>gco", ":update<bar>!git checkout ")
vim.keymap.set("n", "<leader>gcb", ":update<bar>!git checkout -b ")
vim.keymap.set("n", "<leader>gcm", function()
    vim.cmd("update")
    local branch = vim.fn.input("Checkout branch (main/master): ")
    if branch == "main" or branch == "master" then
        vim.cmd("!git checkout " .. branch)
    else
        print("Invalid branch choice. Use 'main' or 'master'")
    end
end)

-- DBT
vim.api.nvim_create_autocmd("Filetype",{
    pattern = {"sql"},
    callback = function()
        vim.schedule(function()
            vim.keymap.set("n", "<leader>gd", "<CMD>DBTGoToDefinition<CR>", { desc = "Go to definition DBT" })
        end)
    end,
})
