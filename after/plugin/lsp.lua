local lsp = require('lsp-zero').preset({})
require('mason').setup({})
require('mason-lspconfig').setup({
    ensure_installed = {
        'pylsp',
        'lua_ls',
    },
})
lsp.on_attach(function(client, bufnr)
    -- see :help lsp-zero-keybindings
    -- to learn the available actions
    lsp.default_keymaps({buffer = bufnr})
end)

lsp.setup()





local lspconfig = require('lspconfig')

lspconfig.lua_ls.setup({
    settings = {
        Lua = {
            completion = {
                callSnippet = "Replace"
            }
        }
    }
})

lspconfig.pylsp.setup {
    settings = {
        pylsp = {
            plugins = {
                ruff = {
                    enabled = true,
                },
                black = {
                    enabled = true
                },
                autopep8 = {
                    enabled = false
                },
                yapf = {
                    enabled = false
                },
                pylint = {
                    enabled = false
                },
                pyflakes = {
                    enabled = false
                },
                pycodestyle = {
                    enabled = false
                },
                pylsp_mypy = {
                    enabled = false
                },
                jedi_completion = {
                    fuzzy = true,
                    enabled = true
                },
                pyls_isort = {
                    enabled = true
                },

            }
        }
    }
}

local cmp = require('cmp')

local cmp_action = require('lsp-zero').cmp_action()

cmp.setup({
    mapping = {
        ['<CR>'] = cmp.mapping.confirm({select = false}),
        ['<C-S-z>'] = cmp_action.tab_complete(),
        ['<C-S-x>'] = cmp_action.select_prev_or_fallback(),
    },
    preselect = 'item',
    completion = {
        completeopt = 'menu,menuone,noinsert',

    },

})
