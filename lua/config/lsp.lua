local M = {}

-- Mason package names differ from nvim-lspconfig's server names.
M.packages = { "lua-language-server", "ruff", "python-lsp-server" }
M.servers = { "lua_ls", "ruff", "pylsp" }

function M.setup()
    require("mason").setup()

    vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
    })
    vim.lsp.config("lua_ls", {
        settings = {
            Lua = {
                diagnostics = { globals = { "vim" } },
                workspace = { checkThirdParty = false },
            },
        },
    })
    vim.lsp.config("ruff", {
        -- Native ruff server settings belong in initializationOptions.
        -- enable/lint.run are VS Code extension settings, not server settings.
        init_options = {
            settings = {
                organizeImports = true,
                fixAll = false,
                lint = { enable = true },
            },
        },
    })
    vim.lsp.config("pylsp", {
        settings = {
            pylsp = {
                configurationSources = {},
                plugins = {
                    autopep8 = { enabled = false },
                    flake8 = { enabled = false },
                    yapf = { enabled = false },
                    mccabe = { enabled = false },
                    pycodestyle = { enabled = false },
                    preload = { enabled = false },
                    pyflakes = { enabled = false },
                    pylint = { enabled = false },
                    jedi_completion = { enabled = true },
                },
            },
        },
    })

    local group = vim.api.nvim_create_augroup("NvimLsp", { clear = true })
    vim.api.nvim_create_autocmd("LspAttach", {
        group = group,
        callback = function(event)
            local opts = { buffer = event.buf, silent = true }
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
            vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        end,
    })
    vim.api.nvim_create_autocmd("BufWritePre", {
        group = group,
        desc = "Format once with a supported LSP client (prefer Ruff)",
        callback = function(event)
            local formatter
            for _, client in ipairs(vim.lsp.get_clients({ bufnr = event.buf, method = "textDocument/formatting" })) do
                if not formatter or client.name == "ruff" then
                    formatter = client
                end
            end
            if formatter then
                vim.lsp.buf.format({ bufnr = event.buf, id = formatter.id, async = false, timeout_ms = 3000 })
            end
        end,
    })

    require("mason-lspconfig").setup({
        -- Headless provisioning explicitly waits in scripts/install.lua instead
        -- of starting background downloads that +qa can interrupt.
        ensure_installed = #vim.api.nvim_list_uis() > 0 and M.servers or {},
        automatic_enable = M.servers,
    })
end

return M
