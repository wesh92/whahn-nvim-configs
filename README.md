# whahn-nvim-config

Personal Neovim configuration for the Arch/CachyOS dev container. Configuration
APIs require **Neovim 0.12+** and **tree-sitter-cli 0.26.1+**; the frozen
Treesitter `master` branch is not compatible with this environment. The reviewed
container/editor pin is **Neovim 0.12.6**, recorded in `.neovim-version`.

On 2026-11-17, [upstream's latest stable release was v0.12.6](https://github.com/neovim/neovim/releases/tag/v0.12.6),
already installed in `wes-dev`. There is no newer stable version to upgrade to;
nightly is deliberately not used. Pinning the official release prevents a later
Arch rolling upgrade from silently changing this tested editor.

## Dependencies

The existing `arch-dev/Containerfile` already supplies the editor's build and
runtime tools: `neovim`, `tree-sitter-cli`, `base-devel` (C compiler and make),
`git`, `curl`, `tar`, `unzip`, `fish`, `ripgrep`, `fd`, `python`, and `uv`.
`tar`, Bash and coreutils (`sha256sum`, `install`, etc.) are supplied by the base
image. The distro Neovim can remain in the shareable base; the personal stage
uses the pinned upstream executable described below. No AUR packages, global
pip installs, Node version manager changes, or system language-server packages
are required.

Mason installs `lua-language-server`, native `ruff`, and `python-lsp-server`
into Neovim's data directory. These are **Mason package names**; their LSP
configuration names are `lua_ls`, `ruff`, and `pylsp`. Neovim prepends Mason's
`bin` directory to its own PATH; these executables are not automatically
available in a separate fish terminal.

Clipboard integration needs a terminal/provider that supports it. For a remote
container without an X/Wayland clipboard, use a terminal supporting Neovim's
built-in OSC 52 provider (`:help clipboard-osc52`). Installing `xclip` inside a
headless container alone does not provide access to the host clipboard. Icons
also require a Nerd Font in the **host terminal**, not in the image.

## Install / container build

Clone this repository into `$HOME/.config/nvim` as the non-root dev user, then
run these **separate processes**:

```sh
bash "$HOME/.config/nvim/scripts/install-neovim.sh"
"$HOME/.local/bin/nvim" --headless "+Lazy! restore" +qa
"$HOME/.local/bin/nvim" --headless "+lua dofile(vim.fn.stdpath('config') .. '/scripts/install.lua')"
"$HOME/.local/bin/nvim" --headless "+lua vim.schedule(function() dofile(vim.fn.stdpath('config') .. '/tests/smoke.lua') end)"
```

The Linux installer downloads the exact official x86_64/aarch64 tarball, verifies
its committed SHA-256 from `neovim-sha256.txt` **before extraction**, and checks
that the binary reports the pinned stable version. It installs under
`$HOME/.local/opt/nvim-v<VERSION>-linux-<ARCH>` and points
`$HOME/.local/bin/nvim` at it, without replacing `/usr/bin/nvim` or using pacman
partial upgrades/`IgnorePkg`. The Containerfile already puts `.local/bin` before
`/usr/bin` in PATH; restart an existing shell (or clear its command cache) after
switching. Other Linux installs need the same PATH precedence. Only the x86_64
runtime has been exercised here; the arm64 archive pin is supplied by upstream.

A verified existing version is reused without downloading; old version
directories remain available for rollback. The installer refuses to overwrite a
regular `.local/bin/nvim` or an unverified existing version directory: inspect or
move those explicitly first. The install marker records archive provenance; it
is not an integrity audit of a subsequently modified installation.

The restore process loads the committed plugin revisions. The Lua installer
waits for parser installation/update and Mason installs (up to five minutes per
phase) and exits nonzero on failure. The last process verifies a fresh startup,
including the exact stable editor pin and LuaSnip's native regex module.
Do not use `+MasonInstall ... +qa` to bake servers: installation is asynchronous
and can be interrupted by `+qa`. Parsers/queries are also verified after install;
restarting after a Treesitter update is required when an older grammar was
already loaded in that process.

For the personal stage of `arch-dev/Containerfile`, keep the existing clone and
pinned checkout, replacing its Neovim RUN stanza with:

```dockerfile
RUN git clone --quiet https://github.com/wesh92/whahn-nvim-configs "$HOME/.config/nvim" \
 && git -C "$HOME/.config/nvim" checkout --quiet --detach "${NVIM_CONFIG_REF}" \
 && bash "$HOME/.config/nvim/scripts/install-neovim.sh" \
 && "$HOME/.local/bin/nvim" --headless "+Lazy! restore" +qa \
 && "$HOME/.local/bin/nvim" --headless "+lua dofile(vim.fn.stdpath('config') .. '/scripts/install.lua')" \
 && "$HOME/.local/bin/nvim" --headless "+lua vim.schedule(function() dofile(vim.fn.stdpath('config') .. '/tests/smoke.lua') end)"
```

After publishing this branch, update `NVIM_CONFIG_REF` (or pass the build arg)
to its reviewed **published commit SHA**. The Containerfile's old
`21afd5957629ba319b451733a7c34dc7f63bd9a5` pin will keep fetching the old config;
rebuilding without changing that pin does not pick up these fixes. The
Containerfile is outside this Git repository, so the versioned instructions
above keep all configuration changes on this repository's branch.

For an existing installation moving from Treesitter `master` to `main` or
Harpoon 1 to `harpoon2`, run `:Lazy restore`, **exit**, and run the install/check
commands above. A one-time API error during restore/exit can come from modules
loaded from the old checkout; evaluate the next fresh process, not the updater.
Harpoon 2 keeps the existing add/menu/1–4 navigation keymaps, but its persistent
list format differs: old Harpoon 1 marks are not auto-imported or deleted;
re-add bookmarks in the new menu. Menu edits are persisted with `:w` or when
selecting with Enter; Harpoon 1's built-in split/tab menu shortcuts need explicit
Harpoon 2 extensions if desired. The bootstrap pins lazy.nvim itself to
`lazy-lock.json` on a clean install and fails promptly if Git cannot
clone/checkout it (no keyboard prompt in builds).

Plugin revisions and parser revisions are pinned by the lockfile/Treesitter
registry. Mason's registry and language-server releases remain rolling; this is
not a fully reproducible lock of external binaries. The installer does not
upgrade an already installed Mason server. Use `:Mason` for deliberate updates.

## Deliberate version updates

- Verify the newest **stable** Neovim release on the upstream releases page/API;
  do not use the moving `stable` alias or `nightly` as a version pin. Change
  `.neovim-version` and **both** Linux SHA-256 values together using the release
  assets' `digest` fields, then test the actual downloaded executable.
- Run `:Lazy update` only in an isolated checkout/data directory. Commit the
  resulting `lazy-lock.json` after the provisioning and regression checks pass;
  builds must use `restore`, not `update`. Unchanged entries are already current
  under their configured branch/compatible release constraints. The disabled
  neoconf entry is inert, not an installed plugin.
- Telescope now follows the reviewed `^0.2.2` stable series rather than the stale
  `0.1.8` tag. Harpoon follows upstream's maintained `harpoon2` branch with its
  matching setup/list/UI API. mini.surround uses its canonical `nvim-mini` owner.
  Mason/LuaSnip/Barbar retain their existing compatible-major constraints.
- Re-run the checks below and the real-terminal UI probe before publishing a new
  config SHA and rebuilding. Only the editor archive and plugin/parser sources
  are locked; Arch packages and Mason server releases are still rolling.

## Behavior and intentional choices

- LSP uses `vim.lsp.config` and Mason v2, not removed Mason `handlers` or the
  deprecated `require('lspconfig').SERVER.setup` interface. LuaLS gets Neovim
  types through lazydev; the archived neodev plugin is removed.
- Ruff handles Python linting and formatting; pylsp supplies completion,
  definitions, and hover. Invalid Pyright-only and Ruff-extension-only settings
  were removed. Ruff's settings are sent in `init_options.settings`.
- A single save callback selects one formatting-capable client, preferring
  Ruff, so multiple server attachments do not format the same buffer twice.
  `gd`, `K`, and `<leader>rn` are set buffer-locally on every LSP attachment.
- Treesitter uses its supported `main` API. Highlighting/indentation are enabled
  explicitly, and a missing parser falls back without throwing. Interactive
  first use installs the configured languages and reattaches when done;
  headless startup does not fire-and-forget downloads. Companion parsers cover
  Markdown inline content, Lua docs, TSX, and fish. TypeSpec is a **valid** parser
  and is retained. JSONC uses the JSON grammar, not the removed `jsonc` parser.
- `<leader>vv` opens NvimTree because netrw is deliberately disabled. Barbar's
  commands are initialized explicitly; lualine uses GUI hex colors for icons.
- SQL's `<leader>gd` DBT mapping is buffer-local. Python/Ruff runner mappings
  shell-quote the filename. Git commit's `-S` precedes `-m` so it is not consumed
  as the commit message. Signing still needs the user's signing-key setup.
- The orphaned Copilot mapping is removed; no Copilot plugin was configured.
  `<leader>ps` is defined only when `pwsh` or `powershell` is actually installed.
- neoconf is explicitly disabled: its configured revision (and current upstream
  integration) hooks the legacy lspconfig setup API, not native LSP clients.
  The old spec never called its setup function, so it was not applying project
  settings either. Project-native files such as `.luarc.json`, `pyproject.toml`,
  and `ruff.toml` continue to work; no replacement project-settings system or
  automatic project Lua execution is enabled.
- Undo history is created under `stdpath('state')/undo`, not inside this Git
  checkout. Noice is installed in builds but only attaches to an actual UI, so
  errors from headless checks remain visible.

## Verification

`tests/smoke.lua` exercises the reviewed stable editor version, actual
startup/plugin APIs, snippet expansion and native regex transforms, native
LSP settings, single-formatter selection, supported parser names, bufferline and
file-explorer commands, SQL mapping scope, undo storage, and icon color values.
It exits nonzero if any check fails. It inspects emitted errors rather than
`v:errmsg`, which third-party `silent!` cleanup can set even on a clean startup.

For live server/formatting tests after provisioning:

```sh
"$HOME/.local/bin/nvim" --headless "+lua vim.schedule(function() dofile(vim.fn.stdpath('config') .. '/tests/integration.lua') end)"
```

The live suite also exercises the Harpoon 2 add/select/menu mappings and
mini.surround's default mapping. Offline Linux tests cover installer failures,
version checks, safe reuse/paths with spaces, and PTY protocol/process cleanup.
They use generated archives or mocked transport/process calls; actual binaries
and UI behavior are verified separately by the runtime checks:

```sh
python -m unittest discover -s "$HOME/.config/nvim/tests" -p 'test_*.py' -v
```

Run the UI-only checks in a separate process (Linux). The real-PTY harness
keeps JSON results and a raw transcript in the XDG cache directory:

```sh
python "$HOME/.config/nvim/tests/ui_terminal.py" --nvim "$HOME/.local/bin/nvim"
```

Run tests against an isolated copy by setting `XDG_CONFIG_HOME`,
`XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME`; tests must not replace
an active user's configuration or installed plugins.
