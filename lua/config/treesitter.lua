local M = {}

-- Keep the original languages; include the companion/injection parsers and fish
-- needed by the configured editor and the Arch container.
M.parsers = {
    "python", "typescript", "typespec", "tsx", "r", "c", "lua", "luadoc",
    "vim", "vimdoc", "query", "bash", "fish", "markdown", "markdown_inline",
    "json", "yaml", "toml", "html", "css", "javascript",
}

local function attach(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    -- Unknown/uninstalled parsers should keep normal syntax and indentation.
    if not lang or not vim.tbl_contains(M.parsers, lang) then
        return
    end
    local ok, loaded = pcall(vim.treesitter.language.add, lang)
    if not ok or not loaded then
        return
    end
    vim.treesitter.start(buf, lang)
    vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
end

function M.setup()
    local treesitter = require("nvim-treesitter")
    treesitter.setup({})
    -- The main branch's JSON grammar also handles JSON with comments.
    vim.treesitter.language.register("json", "jsonc")
    vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true }),
        callback = function(event) attach(event.buf) end,
    })
    if #vim.api.nvim_list_uis() > 0 then
        treesitter.install(M.parsers):await(function(err, success)
            if err or not success then
                vim.schedule(function() vim.notify("Treesitter installation failed; see :messages", vim.log.levels.ERROR) end)
                return
            end
            vim.schedule(function()
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                    if vim.api.nvim_buf_is_loaded(buf) then
                        attach(buf)
                    end
                end
            end)
        end)
    end
end

return M
