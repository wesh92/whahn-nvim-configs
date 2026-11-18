-- Run in a separate Neovim process AFTER :Lazy! restore (see README.md).
-- Async installers must finish before the image layer / headless process exits.
local ok, err = xpcall(function()
    assert(vim.fn.has("nvim-0.12") == 1, "This config requires Neovim 0.12+")
    local timeout = 300000
    local config = require("lazy.core.config")
    local lock = vim.json.decode(table.concat(vim.fn.readfile(config.options.lockfile), "\n"))
    local plugin_count = 0
    for name, plugin in pairs(config.plugins) do
        local pin = assert(lock[name], "Missing plugin pin: " .. name)
        local result = vim.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }, { text = true }):wait()
        assert(result.code == 0, "Plugin missing: " .. name .. "; run :Lazy! restore first")
        assert(vim.trim(result.stdout) == pin.commit, "Plugin not at its locked commit: " .. name)
        plugin_count = plugin_count + 1
    end
    io.stdout:write(string.format("Verified %d plugin pins\n", plugin_count))
    io.stdout:flush()

    local treesitter = require("nvim-treesitter")
    local parsers = require("config.treesitter").parsers
    assert(treesitter.install(parsers, { max_jobs = 4, summary = true }):wait(timeout), "Parser installation failed")
    assert(treesitter.update(parsers, { max_jobs = 4, summary = true }):wait(timeout), "Parser update failed")
    local installed = treesitter.get_installed()
    for _, lang in ipairs(parsers) do
        assert(vim.tbl_contains(installed, lang), "Parser missing after installation: " .. lang)
    end
    -- Neovim cannot replace a grammar already loaded by this process. Query/ABI
    -- checks therefore run in the fresh tests/smoke.lua process, not here.
    io.stdout:write(string.format("Installed/updated %d configured parsers\n", #parsers))
    io.stdout:flush()

    local registry = require("mason-registry")
    local refreshed, refresh_ok, refresh_err = false, false, nil
    registry.refresh(function(success, result)
        refreshed, refresh_ok, refresh_err = true, success, result
    end)
    assert(vim.wait(timeout, function() return refreshed end, 100), "Mason registry refresh timed out")
    assert(refresh_ok, "Mason registry refresh failed: " .. vim.inspect(refresh_err))

    local pending, errors = 0, {}
    local packages = require("config.lsp").packages
    for _, name in ipairs(packages) do
        local package = registry.get_package(name)
        if not package:is_installed() then
            pending = pending + 1
            package:install({}, function(success, result)
                if not success then
                    errors[#errors + 1] = name .. ": " .. tostring(result)
                end
                pending = pending - 1
            end)
        end
    end
    assert(vim.wait(timeout, function() return pending == 0 end, 100), "Mason package installation timed out")
    assert(#errors == 0, table.concat(errors, "\n"))
    for _, name in ipairs(packages) do
        assert(registry.is_installed(name), "Mason package missing: " .. name)
    end
    for _, executable in ipairs({ "lua-language-server", "ruff", "pylsp" }) do
        assert(vim.fn.executable(executable) == 1, "LSP executable missing from Neovim's PATH: " .. executable)
    end
    io.stdout:write(string.format("Verified %d Mason language servers\n", #packages))
    io.stdout:flush()
end, debug.traceback)

if not ok then
    io.stderr:write(tostring(err) .. "\n")
    io.stderr:flush()
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
