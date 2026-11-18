-- Run in a separate real terminal UI, never with --headless. See README.md.
local result = { ui_count = #vim.api.nvim_list_uis(), checks = {}, failures = {} }
local function check(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    result.checks[#result.checks + 1] = { name = name, passed = ok }
    if not ok then
        result.failures[#result.failures + 1] = { name = name, error = tostring(err) }
    end
end

check("a real terminal UI is attached", function()
    assert(result.ui_count == 1, vim.inspect(vim.api.nvim_list_uis()))
end)
check("Noice attaches to the actual UI", function()
    assert(vim.wait(5000, function() return require("noice.config").is_running() end, 50))
end)
check("Barbar switches real buffers", function()
    local first = vim.api.nvim_create_buf(true, false)
    local second = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(first)
    vim.api.nvim_set_current_buf(second)
    vim.cmd("BufferPrevious")
    assert(vim.api.nvim_get_current_buf() ~= second)
end)
check("NvimTree opens and closes", function()
    local api = require("nvim-tree.api")
    api.tree.open({ path = vim.fn.stdpath("config") })
    assert(api.tree.is_visible())
    api.tree.close()
    assert(not api.tree.is_visible())
end)
check("lualine renders its status line", function()
    require("lualine").refresh({ force = true })
    assert(vim.o.statusline:find("lualine", 1, true), vim.o.statusline)
    local rendered = vim.api.nvim_eval_statusline(vim.o.statusline, { winid = 0, maxwidth = 100 })
    assert(rendered.str and #rendered.str > 0)
end)
check("Harpoon 2 opens its quick menu in a real UI", function()
    local harpoon = require("harpoon")
    local list = harpoon:list("nvim-ui-test")
    list:clear()
    list:add({ value = vim.fn.stdpath("config") .. "/init.lua", context = { row = 1, col = 0 } })
    harpoon.ui:toggle_quick_menu(list)
    assert(harpoon.ui.win_id and vim.api.nvim_win_is_valid(harpoon.ui.win_id))
    harpoon.ui:toggle_quick_menu(list)
    list:clear()
end)
check("UI callbacks emitted no uncaught runtime errors", function()
    vim.wait(250)
    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    result.messages = messages
    for _, fragment in ipairs({ "stack traceback", "Error in ", "Error detected", "Failed to run", "E1568" }) do
        assert(not messages:find(fragment, 1, true), messages)
    end
end)
result.passed = #result.failures == 0
local path = vim.env.NVIM_UI_RESULT or (vim.fn.stdpath("cache") .. "/ui-result.json")
vim.fn.writefile({ vim.json.encode(result) }, path)
if result.passed then vim.cmd("qa!") else vim.cmd("cquit 1") end
