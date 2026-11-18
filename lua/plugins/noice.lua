return {
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        -- Install the UI plugins in headless builds, but leave their messages
        -- on stderr instead of attaching a UI that nobody can see.
        config = function(_, opts)
            if #vim.api.nvim_list_uis() > 0 then
                require("noice").setup(opts)
            end
        end,
        dependencies = {
            { "MunifTanjim/nui.nvim" },
            { "rcarriga/nvim-notify" },
        },
        opts = {
            lsp = {
                -- override markdown rendering so that **cmp** and other plugins use **Treesitter**
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                    ["cmp.entry.get_documentation"] = true,
                },
            },
            -- you can enable a preset for easier configuration
            presets = {
                bottom_search = true, -- use a classic bottom cmdline for search
                command_palette = true, -- position the cmdline and popupmenu together
                long_message_to_split = true, -- long messages will be sent to a split
                inc_rename = false, -- enables an input dialog for inc-rename.nvim
                lsp_doc_border = false, -- add a border to hover docs and signature help
            },
            views = {
                cmdline_popup = {
                    position = {
                        row = "35%",
                        col = "50%",
                    },
                    size = {
                        width = 60,
                        height = "auto",
                    },
                },
            },
            routes = {
                {
                    view = "mini",
                    filter = { event = "msg_showmode"},
                },
            },
        }
    },
}
