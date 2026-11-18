-- Run after normal startup; see README.md for the headless command.
local failures = {}
local checks = 0
local function check(name, fn)
    checks = checks + 1
    local ok, err = pcall(fn)
    io.stdout:write((ok and "PASS " or "FAIL ") .. name .. "\n")
    if not ok then
        failures[#failures + 1] = name .. ": " .. tostring(err)
        io.stdout:write("  " .. tostring(err) .. "\n")
    end
    io.stdout:flush()
end

check("runtime matches the reviewed stable editor pin", function()
    local expected = vim.fn.readfile(vim.fn.stdpath("config") .. "/.neovim-version")[1]
    local version = vim.version()
    local actual = string.format("%d.%d.%d", version.major, version.minor, version.patch)
    assert(actual == expected and not version.prerelease, "expected stable " .. expected .. ", got " .. tostring(version))
end)

check("all configuration Lua files parse", function()
    local root = vim.fn.stdpath("config")
    local files = vim.fn.glob(root .. "/lua/**/*.lua", false, true)
    files[#files + 1] = root .. "/init.lua"
    for _, file in ipairs(files) do
        assert(loadfile(file))
    end
end)

check("startup has no errors or duplicate lazy setup", function()
    -- v:errmsg also records deliberately suppressed :silent! cleanup errors
    -- in third-party plugins. Inspect emitted messages, not that stale value.
    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    assert(not messages:find("Re%-sourcing your config"), messages)
    assert(not messages:find("Failed to run"), messages)
    assert(not messages:find("stack traceback", 1, true), messages)
    assert(not messages:find("Error in ", 1, true), messages)
end)

check("completion can expand an LSP snippet", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    require("cmp").get_config().snippet.expand({ body = "snippet_${1:value}$0" })
    assert(vim.api.nvim_get_current_line() == "snippet_value")
    require("luasnip").unlink_current()
    vim.api.nvim_buf_delete(buf, { force = true })
end)

check("LuaSnip native regex transformations work", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    local luasnip = require("luasnip")
    luasnip.lsp_expand("${1:hello} ${1/hello/world/}")
    assert(vim.api.nvim_get_current_line() == "hello world", vim.api.nvim_get_current_line())
    luasnip.unlink_current()
    vim.api.nvim_buf_delete(buf, { force = true })
end)

check("updated plugin specifications match their maintained APIs", function()
    local plugins = require("lazy.core.config").plugins
    assert(plugins.harpoon.branch == "harpoon2")
    assert(type(require("harpoon").list) == "function")
    assert(plugins["telescope.nvim"].version == "^0.2.2")
    assert(plugins["mini.surround"].url:find("nvim-mini/mini.surround", 1, true))
end)

check("native LuaLS settings and completion capabilities are applied", function()
    local config = vim.lsp.config.lua_ls
    assert(config.settings.Lua.workspace.checkThirdParty == false)
    assert(vim.tbl_contains(config.settings.Lua.diagnostics.globals, "vim"))
    assert(config.capabilities.textDocument.completion.completionItem.snippetSupport)
end)

check("native Ruff settings use initialization options", function()
    local settings = vim.lsp.config.ruff.init_options.settings
    assert(settings.organizeImports == true)
    assert(settings.fixAll == false)
    assert(settings.lint.enable == true)
    assert(settings.lint.run == nil, "lint.run belongs to the VS Code extension, not ruff server")
    assert(settings.enable == nil, "enable belongs to the VS Code extension, not ruff server")
end)

check("pylsp leaves linting and formatting to Ruff", function()
    local config = vim.lsp.config.pylsp
    assert(config.settings.python == nil, "python.analysis is a Pyright setting, not a pylsp setting")
    for _, name in ipairs({ "autopep8", "flake8", "yapf", "mccabe", "pycodestyle", "pyflakes", "pylint" }) do
        assert(config.settings.pylsp.plugins[name].enabled == false, name .. " must be disabled")
    end
    assert(config.settings.pylsp.plugins.jedi_completion.enabled)
end)

check("format-on-save selects exactly one formatter and prefers Ruff", function()
    local get_clients, format = vim.lsp.get_clients, vim.lsp.buf.format
    local calls = {}
    local buf = vim.api.nvim_create_buf(false, true)
    vim.lsp.get_clients = function(opts)
        assert(opts.bufnr == buf and opts.method == "textDocument/formatting")
        return { { id = 1001, name = "pylsp" }, { id = 1002, name = "ruff" } }
    end
    vim.lsp.buf.format = function(opts)
        calls[#calls + 1] = opts
    end
    local ok, err = pcall(vim.api.nvim_exec_autocmds, "BufWritePre", { buffer = buf })
    vim.lsp.get_clients, vim.lsp.buf.format = get_clients, format
    vim.api.nvim_buf_delete(buf, { force = true })
    assert(ok, err)
    assert(#calls == 1, "expected one format request, got " .. #calls)
    assert(calls[1].id == 1002 and calls[1].bufnr == buf and calls[1].async == false)
end)

check("Treesitter uses the supported main API and valid parser names", function()
    local plugin = require("lazy.core.config").plugins["nvim-treesitter"]
    assert(plugin.branch == "main", "master does not support Neovim 0.12 / CLI 0.26")
    assert(type(require("nvim-treesitter").install) == "function")
    local parsers = require("nvim-treesitter.parsers")
    for _, lang in ipairs(require("config.treesitter").parsers) do
        assert(parsers[lang], "unknown parser: " .. lang)
    end
end)

check("configured parsers load with matching queries", function()
    for _, lang in ipairs(require("config.treesitter").parsers) do
        assert(vim.treesitter.language.add(lang), "parser unavailable: " .. lang)
        for _, query in ipairs({ "highlights", "injections", "indents" }) do
            vim.treesitter.query.get(lang, query)
        end
    end
end)

check("missing parsers fall back without starting a highlighter", function()
    local add, start = vim.treesitter.language.add, vim.treesitter.start
    local started = false
    local buf = vim.api.nvim_create_buf(false, true)
    -- Set the filetype without running built-in ftplugins, then exercise only
    -- our callback. Neovim 0.12 returns nil, not an exception, for missing parsers.
    vim.api.nvim_buf_call(buf, function() vim.cmd("noautocmd setlocal filetype=python") end)
    vim.treesitter.language.add = function() return nil, "No parser" end
    vim.treesitter.start = function() started = true end
    local ok, err = pcall(vim.api.nvim_exec_autocmds, "FileType", { buffer = buf, group = "NvimTreesitter" })
    vim.treesitter.language.add, vim.treesitter.start = add, start
    vim.api.nvim_buf_delete(buf, { force = true })
    assert(ok, err)
    assert(not started, "missing parser should retain the default highlighter")
end)

check("optional tools and shell-runner mappings match the environment", function()
    assert(vim.fn.maparg("<leader>cc", "n") == "", "Copilot is not installed")
    if vim.fn.executable("pwsh") == 0 and vim.fn.executable("powershell") == 0 then
        assert(vim.fn.maparg("<leader>ps", "n") == "")
    end
    assert(vim.fn.maparg("<leader>gc", "n"):find("git commit -S -m ", 1, true))
    for _, key in ipairs({ "py", "rc", "rf", "rfi" }) do
        assert(vim.fn.maparg("<leader>" .. key, "n"):find("%:S", 1, true), key .. " must quote the filename")
    end
end)

check("Barbar commands are initialized", function()
    assert(vim.fn.exists(":BufferNext") == 2, "Barbar auto-setup is disabled without a manual setup")
end)

check("file explorer mapping does not target disabled netrw", function()
    local map = vim.fn.maparg("<leader>vv", "n", false, true)
    assert(map.rhs and map.rhs:find("NvimTree"), "mapping must use the configured file explorer")
    assert(vim.fn.exists(":NvimTreeToggle") == 2)
end)

check("undo history lives in the writable state directory", function()
    assert(vim.o.undodir == vim.fn.stdpath("state") .. "/undo")
    assert(vim.fn.isdirectory(vim.o.undodir) == 1)
end)

check("DBT mapping is SQL-buffer-local", function()
    local sql = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(sql)
    vim.bo[sql].filetype = "sql"
    local map = vim.fn.maparg("<leader>gd", "n", false, true)
    assert(map.buffer == 1 and map.rhs:find("DBTGoToDefinition"))
    local text = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(text)
    assert(vim.fn.maparg("<leader>gd", "n") == "")
    vim.api.nvim_buf_delete(sql, { force = true })
    vim.api.nvim_buf_delete(text, { force = true })
end)

check("lualine icon colors use GUI hex values", function()
    local component = require("lualine").get_config().sections.lualine_x[1]
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "lua"
    local color = component.color()
    assert(color and type(color.fg) == "string" and color.fg:match("^#%x%x%x%x%x%x$"))
    vim.api.nvim_buf_delete(buf, { force = true })
end)

check("buffer/filetype callbacks emitted no runtime errors", function()
    vim.wait(100)
    local messages = vim.api.nvim_exec2("messages", { output = true }).output
    assert(not messages:find("stack traceback", 1, true), messages)
    assert(not messages:find("Error in ", 1, true), messages)
    assert(not messages:find("Error detected", 1, true), messages)
end)

io.stdout:write(string.format("\n%d checks, %d failures\n", checks, #failures))
io.stdout:flush()
if #failures > 0 then
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
