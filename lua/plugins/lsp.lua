return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/cmp-nvim-lsp", -- For LSP capabilities
        },
        config = function()
            local lspconfig = require("lspconfig")
            local mason = require("mason")
            local mason_lspconfig = require("mason-lspconfig")
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            mason.setup()

            mason_lspconfig.setup({
                ensure_installed = { "lua_ls", "ruff" },
                handlers = {
                    function(server_name)
                        lspconfig[server_name].setup({
                            capabilities = capabilities,
                            on_attach = function(client, bufnr)
                                local opts = { buffer = bufnr, silent = true, noremap = true }

                                vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                                vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                                vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

                                -- Format on Save
                                if client.server_capabilities.documentFormattingProvider then
                                    vim.api.nvim_create_autocmd("BufWritePre", {
                                        buffer = bufnr,
                                        callback = function()
                                            vim.lsp.buf.format({ async = false })
                                        end,
                                    })
                                end
                            end
                        })
                    end,

                    ["lua_ls"] = function()
                        lspconfig.lua_ls.setup({
                            capabilities = capabilities,
                            settings = {
                                Lua = {
                                    diagnostics = { globals = { "vim" } },
                                    workspace = { checkThirdParty = false },
                                },
                            },
                        })
                    end,

                    ["ruff"] = function()
                        lspconfig.ruff.setup({
                            capabilities = capabilities,
                            settings = {
                                enable = true,
                                organizeImports = true,
                                fixAll = false,
                                lint = {
                                    enable = true,
                                    run = "onSave",
                                },
                            },
                        })
                    end,
                },
            })
        end,
    },
}
