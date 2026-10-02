# dotfiles

My shell, git, editor and CLI configuration, synced between machines with
[chezmoi](https://chezmoi.io).

## The mental model

chezmoi keeps **two copies** of every config file:

| Copy | Where | Role |
|------|-------|------|
| Source | `~/.local/share/chezmoi` (this repo, cloned) | What's in git. Filenames use prefixes: `dot_zshrc` becomes `~/.zshrc`, `private_` means mode 0600, `.tmpl` means "fill in per machine". |
| Target | `~/.zshrc`, `~/.config/...` | The real files your tools read. |

You never edit the source copy by hand-cloning this repo into `~`. Instead:

```
   edit  ──>  chezmoi apply  ──>  ~ (target)
 source                            ▲
   ▲                               │
   └── git push ─── other machine ── chezmoi update
```

* `chezmoi edit ~/.zshrc` opens the source copy; `chezmoi apply` writes it to `~`.
* `git push` from the source dir (`chezmoi cd`) publishes it.
* `chezmoi update` on another machine pulls and applies.

## New machine

```bash
# macOS: install Xcode CLT and Homebrew first (https://brew.sh)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply carosellaja1
```

That one command:

1. Installs chezmoi and clones this repo to `~/.local/share/chezmoi`.
2. Asks for your **name** and **email** once (used in `.gitconfig`) and stores
   them in `~/.config/chezmoi/chezmoi.toml`, which stays local.
3. Downloads oh-my-zsh, powerlevel10k and zsh-autosuggestions
   (`.chezmoiexternal.toml`).
4. On macOS, installs the CLI tools the configs depend on via Homebrew
   (`run_onchange_darwin-install-packages.sh.tmpl`).
5. Writes every managed file into `~`.

Then set up API keys, which are the only thing not synced:

```bash
cp ~/.config/secrets/api-keys.env.example ~/.config/secrets/api-keys.env
chmod 600 ~/.config/secrets/api-keys.env
$EDITOR ~/.config/secrets/api-keys.env   # fill in what you use
exec zsh && chezmoi apply                # re-render ~/.cursor/mcp.json and Zed settings
```

If the machine already has dotfiles, use `chezmoi init carosellaja1` (no
`--apply`), then `chezmoi diff` to review and `chezmoi apply` when happy.
An existing `~/.oh-my-zsh` git clone is replaced by the chezmoi-managed copy.

## Day to day

| Task | Command |
|------|---------|
| Change a managed file | `chezmoi edit ~/.zshrc` then `chezmoi apply` |
| Edited the real file directly? Pull the change back in | `chezmoi re-add ~/.zshrc` |
| Start managing a new file | `chezmoi add ~/.config/foo/config` |
| Stop managing a file (keeps the real one) | `chezmoi forget ~/.config/foo/config` |
| See what `apply` would change | `chezmoi diff` |
| Push to GitHub | `chezmoi cd` then `git add -A && git commit && git push` |
| Pull from GitHub and apply | `chezmoi update` |
| What is managed / not managed | `chezmoi managed` / `chezmoi unmanaged` |
| Refresh oh-my-zsh and plugins now | `chezmoi apply --refresh-externals` |
| Something looks wrong | `chezmoi doctor`, `chezmoi apply -n -v`, `chezmoi verify --exclude scripts` |

Keep the source and the target in sync in your head: if `chezmoi diff` shows
output, one side has changes the other doesn't.

## Per-machine differences

* **Identity and profile**: `.gitconfig` is a template; name, email and the
  machine profile come from the answers given at `chezmoi init`. A plain
  `chezmoi init` keeps the saved answers; to change them run
  `chezmoi init --prompt` or edit `~/.config/chezmoi/chezmoi.toml`.
* **OS**: `.chezmoiignore` skips macOS-only files (iTerm2, Raycast,
  `.zprofile`) on Linux. `.gitconfig` picks `osxkeychain` on macOS and the
  cache helper elsewhere.
* **Paths**: nothing hardcodes a username. Templates use
  `{{ .chezmoi.homeDir }}`; shell files use `$HOME`.

To add another per-machine value, put a `promptStringOnce` line in
`.chezmoi.toml.tmpl` and use `{{ .thatValue }}` in a `.tmpl` file.

## Secrets

* Real keys live in `~/.config/secrets/api-keys.env`, sourced by `.zshrc`.
  Templates read them with `{{ env "NAME" }}` at `chezmoi apply` time, so run
  `apply` from a shell that has sourced the file.
* That file, `~/.config/gh/hosts.yml`, Raycast's `config.json` and Claude's
  credentials are listed in both `.chezmoiignore` and this repo's `.gitignore`,
  so neither `chezmoi add` nor `git add` can sync them.
* If you want to sync secrets too, chezmoi supports encrypting files with
  `age` or pulling from a password manager; see
  <https://www.chezmoi.io/user-guide/password-managers/>.

## IDE settings

Cursor, VS Code and JetBrains (PyCharm first) share one source of truth with
a machine profile (`personal` / `work`, chosen at `chezmoi init`) and
switchable workload profiles (`python`, `web`) inside Cursor and VS Code.
JetBrains settings are relinked by every `chezmoi apply`, so a cleanup app
deleting `PyCharm2025.x` costs nothing. See [docs/ide.md](docs/ide.md) for
the layout, the first-time capture step and the day-to-day commands.

## What's managed

| Area | Files |
|------|-------|
| Shell | `.zshrc`, `.zprofile`, `.p10k.zsh`, `.inputrc`, `.zsh/plugin-loader.zsh`, `.zsh/toolsets.zsh`, `.config/fish/config.fish`, `.config/starship.toml` |
| Git | `.gitconfig` (template), `.gitignore_global` |
| CLI tools | `.config/bat/config`, `.ripgreprc`, `.fdignore`, `.curlrc`, `.wgetrc`, `.config/gh/config.yml`, `.config/direnv/direnvrc` |
| Languages | `.config/pip/pip.conf`, `.config/uv/uv.toml`, `.config/ruff/ruff.toml`, `.config/go/env`, `.npmrc`, `.condarc`, `.editorconfig`, `.prettierrc` |
| AI tooling | `.claude/settings.json`, `.claude/CLAUDE.md`, `.cursor/mcp.json` (template), `.config/zed/settings.json` (template), `.config/goose/config.yaml`, `.serena/serena_config.yml` |
| IDEs | `.config/ide/vscode/` (rendered Cursor + VS Code settings, keybindings, snippets, profile exports), `.config/jetbrains/` (shared PyCharm/JetBrains settings), `.local/bin/ide-capture` |
| macOS only | `.config/iterm2/`, `.config/raycast/` (settings only, never tokens) |

## Layout of this repo

| Entry | Purpose |
|-------|---------|
| `.chezmoi.toml.tmpl` | Generates the local chezmoi config; asks for name/email once |
| `.chezmoiignore` | What not to write to `~`, including OS-specific skips |
| `.chezmoiexternal.toml` | Third-party downloads (oh-my-zsh and plugins) |
| `run_onchange_darwin-install-packages.sh.tmpl` | Homebrew package list; re-runs when the list changes |
| `run_before_ide-backup.sh.tmpl` | Backs up real Cursor/VS Code settings before they become symlinks |
| `run_onchange_after_ide-extensions.sh.tmpl` | Installs the extension lists; re-runs when a list changes |
| `run_after_jetbrains-link.sh.tmpl` | Links every JetBrains config folder to `~/.config/jetbrains` |
| `.chezmoitemplates/ide/` | Settings data files and the templates that merge them |
| `docs/` | Longer guides, not applied to `~` |
| `dot_*`, `private_dot_*` | The dotfiles themselves |
| `*.tmpl` | Files rendered with Go templates per machine |
| `.gitignore` | Safety net against committing secrets |

Reference: [chezmoi source state attributes](https://www.chezmoi.io/reference/source-state-attributes/).
