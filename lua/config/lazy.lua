-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
  local commit = assert(lock["lazy.nvim"], "lazy.nvim must be pinned in lazy-lock.json").commit
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", lazyrepo, lazypath })
  if vim.v.shell_error == 0 then
    out = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", commit })
  end
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to bootstrap the pinned lazy.nvim revision:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    -- Container builds have no keyboard: fail instead of waiting indefinitely.
    vim.cmd("cquit 1")
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = #vim.api.nvim_list_uis() > 0 },
})
