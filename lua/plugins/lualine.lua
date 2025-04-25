return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local branch_max_width = 40
    local branch_min_width = 10
    require('lualine').setup {
        options = {
            icons_enabled = true,
            theme = 'delta', -- Make sure this theme is available
            component_separators = { left = '', right = ''},
            section_separators = { left = '', right = ''},
            disabled_filetypes = {
                statusline = {},
                winbar = {},
            },
            ignore_focus = {},
            always_divide_middle = true,
            globalstatus = false,
            refresh = {
                statusline = 1000,
                tabline = 1000,
                winbar = 1000,
            }
        },
        sections = {
            lualine_a = {'mode'},
            lualine_b = {'diff', {'diagnostics', update_in_insert = true},{'branch',
            fmt = function(output)
                local win_width = vim.o.columns
                local max = branch_max_width
                if win_width * 0.25 < max then
                    max = math.floor(win_width * 0.25)
                end
                if max < branch_min_width then
                    max = branch_min_width
                end
                if max % 2 ~= 0 then
                    max = max + 1
                end
                if output:len() >= max then
                    return output:sub(1, (max / 2) - 1)
                    .. "..."
                    .. output:sub( -1 * ((max / 2) - 1), -1)
                end
                return output
            end,} },
            lualine_c = {{'filename', file_status = true, path = 1}},
            lualine_x = {
                 -- LSP Client display function (ensure nvim-web-devicons is loaded)
                {
                    function()
                        local icon = require("nvim-web-devicons").get_icon_by_filetype(
                            vim.api.nvim_get_option_value("filetype", { buf = 0 })
                        ) or ""
                        local lsps = vim.lsp.get_clients({ bufnr = 0 })
                        if not lsps or #lsps == 0 then return icon end
                        local names = {}
                        for _, lsp in ipairs(lsps) do
                            table.insert(names, lsp.name)
                        end
                        return string.format("%s | %s", icon, table.concat(names, ", "))
                    end,
                    on_click = function() vim.cmd("LspInfo") end,
                    color = function()
                      local _, color = require("nvim-web-devicons").get_icon_cterm_color_by_filetype(
                        vim.api.nvim_get_option_value("filetype", { buf = 0 })
                      )
                      -- Return fg color if found, otherwise nil (default)
                      return color and { fg = color } or nil
                    end,
                },
                "encoding",
                "progress",
            },
            lualine_y = {'filetype'},
            lualine_z = {
                "location",
                { -- Visual mode selection count
                    function()
                        local starts = vim.fn.line("v")
                        local ends = vim.fn.line(".")
                        local count = starts <= ends and ends - starts + 1 or starts - ends + 1
                        return count .. "V"
                    end,
                    cond = function() return vim.fn.mode():find("[Vv]") ~= nil end,
                },
            },
        },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {'filename'},
        lualine_x = {'location'},
        lualine_y = {},
        lualine_z = {}
      },
      tabline = {},
      winbar = {},
      inactive_winbar = {},
      extensions = {'nvim-tree', 'telescope'}
    }
  end
}
