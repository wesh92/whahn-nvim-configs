-- Requires scripts/install.lua and a fresh, normally initialized Neovim.
local failures, checks = {}, 0
local function check(name, fn)
    checks = checks + 1
    local ok, err = xpcall(fn, debug.traceback)
    io.stdout:write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failures[#failures + 1] = name
        io.stdout:write(tostring(err) .. "\n")
    end
    io.stdout:flush()
end

local root = vim.fn.stdpath("cache") .. "/nvim-integration"
vim.fn.mkdir(root, "p")
vim.fn.writefile({ '[project]', 'name = "nvim-integration"', 'version = "0.0.0"' }, root .. "/pyproject.toml")
vim.fn.writefile({ '{}' }, root .. "/.luarc.json")
local python_file = root .. "/file with spaces & 'quote' %.py"
vim.fn.writefile({ "import os", "", "value=1+2", "print(value)" }, python_file)
local lua_file = root .. "/sample.lua"
vim.fn.writefile({ "local value=1", "return value" }, lua_file)
local python_buf, ruff, pylsp

check("FileType callbacks enable highlighting and indentation", function()
    for _, filetype in ipairs({ "python", "lua", "fish", "markdown", "jsonc", "typescriptreact", "typespec" }) do
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.bo[buf].filetype = filetype
        assert(vim.treesitter.highlighter.active[buf], "no highlighter for " .. filetype)
        assert(vim.treesitter.get_parser(buf):parse(), "parser failed for " .. filetype)
        assert(vim.bo[buf].indentexpr == "v:lua.require'nvim-treesitter'.indentexpr()")
        vim.api.nvim_buf_delete(buf, { force = true })
    end
end)

check("Ruff and pylsp both initialize with the configured settings", function()
    vim.cmd("edit " .. vim.fn.fnameescape(python_file))
    python_buf = vim.api.nvim_get_current_buf()
    assert(vim.wait(30000, function()
        local clients = vim.lsp.get_clients({ bufnr = python_buf })
        if #clients ~= 2 then return false end
        for _, client in ipairs(clients) do
            if not client.initialized then return false end
            if client.name == "ruff" then ruff = client end
            if client.name == "pylsp" then pylsp = client end
        end
        return ruff ~= nil and pylsp ~= nil
    end, 100), "Python language servers did not initialize")
    assert(ruff.config.init_options.settings.fixAll == false)
    assert(pylsp.config.settings.pylsp.plugins.pyflakes.enabled == false)
    assert(pylsp.config.capabilities.textDocument.completion.completionItem.snippetSupport)
    for _, key in ipairs({ "gd", "K", "<leader>rn" }) do
        assert(vim.fn.maparg(key, "n", false, true).buffer == 1, key .. " is not buffer-local")
    end
end)

check("save formats once with Ruff, including after repeated attachments", function()
    assert(ruff and pylsp, "Python servers unavailable")
    for _, client in ipairs({ ruff, pylsp, ruff }) do
        vim.api.nvim_exec_autocmds("LspAttach", { buffer = python_buf, data = { client_id = client.id } })
    end
    assert(#vim.api.nvim_get_autocmds({ event = "BufWritePre", group = "NvimLsp" }) == 1)
    local format = vim.lsp.buf.format
    local calls = {}
    vim.lsp.buf.format = function(opts)
        calls[#calls + 1] = opts
        return format(opts)
    end
    local ok, err = pcall(vim.cmd, "write")
    vim.lsp.buf.format = format
    assert(ok, err)
    assert(#calls == 1 and calls[1].id == ruff.id, "expected exactly one request to Ruff")
    local contents = table.concat(vim.api.nvim_buf_get_lines(python_buf, 0, -1, false), "\n")
    assert(contents:find("value = 1 + 2", 1, true), "Ruff did not format the file")
end)

check("Ruff reports lint diagnostics without duplicate pylsp linting", function()
    assert(ruff and pylsp, "Python servers unavailable")
    assert(vim.wait(15000, function()
        for _, diagnostic in ipairs(vim.diagnostic.get(python_buf)) do
            if diagnostic.code == "F401" then return true end
        end
        return false
    end, 100), "Ruff did not report the unused import")
    for _, diagnostic in ipairs(vim.diagnostic.get(python_buf)) do
        assert(not (diagnostic.source or ""):lower():find("pyflakes"), "duplicate pylsp diagnostic")
        assert(not (diagnostic.source or ""):lower():find("pycodestyle"), "duplicate pylsp diagnostic")
    end
end)

check("pylsp serves real Python completions", function()
    assert(pylsp, "pylsp unavailable")
    vim.api.nvim_buf_set_lines(python_buf, 0, -1, false, { "import os", "", "os.pa" })
    local response, err = pylsp:request_sync("textDocument/completion", {
        textDocument = { uri = vim.uri_from_bufnr(python_buf) },
        position = { line = 2, character = 5 },
        context = { triggerKind = 1 },
    }, 10000, python_buf)
    assert(response and not response.err, vim.inspect(err or response))
    local items = response.result and (response.result.items or response.result) or {}
    local found = false
    for _, item in ipairs(items) do
        if item.label:find("path", 1, true) then found = true end
    end
    assert(found, "missing os.path completion")
    vim.bo[python_buf].modified = false
end)

check("LuaLS initializes and formats a Lua file", function()
    vim.cmd("edit " .. vim.fn.fnameescape(lua_file))
    local buf = vim.api.nvim_get_current_buf()
    local lua_ls
    assert(vim.wait(30000, function()
        local clients = vim.lsp.get_clients({ bufnr = buf, name = "lua_ls" })
        lua_ls = clients[1]
        return #clients == 1 and lua_ls.initialized
    end, 100), "LuaLS did not initialize")
    assert(lua_ls.config.settings.Lua.workspace.checkThirdParty == false)
    assert(lua_ls:supports_method("textDocument/formatting", buf))
    vim.cmd("write")
    assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "local value = 1", "LuaLS did not format")
end)

check("Telescope find_files opens its picker", function()
    require("telescope.builtin").find_files({ cwd = root, hidden = true, previewer = false })
    vim.wait(200)
    local buf = vim.api.nvim_get_current_buf()
    assert(vim.bo[buf].filetype == "TelescopePrompt", "picker did not open")
    assert(require("telescope.actions.state").get_current_picker(buf))
    require("telescope.actions").close(buf)
end)

check("NvimTree opens and closes the fixture directory", function()
    local api = require("nvim-tree.api")
    api.tree.open({ path = root })
    assert(api.tree.is_visible())
    api.tree.close()
    assert(not api.tree.is_visible())
end)

check("callbacks and asynchronous jobs emitted no runtime errors", function()
    vim.wait(200)
    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    assert(not messages:find("stack traceback", 1, true), messages)
    assert(not messages:find("Error in ", 1, true), messages)
    assert(not messages:find("Error detected", 1, true), messages)
end)

for _, client in ipairs(vim.lsp.get_clients()) do client:stop(true) end
io.stdout:write(string.format("\n%d integration checks, %d failures\n", checks, #failures))
io.stdout:flush()
if #failures > 0 then
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
