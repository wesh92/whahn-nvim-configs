return {
  "folke/neoconf.nvim",
  -- Its legacy lspconfig.setup hooks do not configure vim.lsp.config clients.
  -- This spec previously never called setup, so no project settings were applied.
  enabled = false,
}
