# Dotfiles

Personal dotfiles managed with [chezmoi](https://chezmoi.io/).

## Quick Start

### Install chezmoi and dotfiles on a new machine

```bash
# One-liner install (replace with your repo)
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply carosellaja1

# Or with Homebrew
brew install chezmoi
chezmoi init --apply https://github.com/carosellaja1/dotfiles.git
```

### Install on a machine with existing dotfiles

```bash
chezmoi init https://github.com/carosellaja1/dotfiles.git
chezmoi diff    # Review changes before applying
chezmoi apply   # Apply changes
```

## Daily Usage

| Command | Description |
|---------|-------------|
| `chezmoi add ~/.config/foo` | Add a new dotfile to be managed |
| `chezmoi edit ~/.zshrc` | Edit a managed file (opens in source dir) |
| `chezmoi diff` | Preview pending changes |
| `chezmoi apply` | Apply changes to home directory |
| `chezmoi update` | Pull latest from remote and apply |
| `chezmoi cd` | cd into the chezmoi source directory |
| `chezmoi managed` | List all managed files |
| `chezmoi unmanaged` | List files in home not managed by chezmoi |

## Common Workflows

### Edit a dotfile

```bash
# Option 1: Edit source and apply
chezmoi edit ~/.zshrc
chezmoi apply

# Option 2: Edit in place, then re-add
vim ~/.zshrc
chezmoi re-add
```

### Add a new config file

```bash
chezmoi add ~/.config/starship.toml
chezmoi cd
git add -A && git commit -m "Add starship config"
git push
```

### Add a private/secret file

```bash
# Files with sensitive data (permissions set to 0600)
chezmoi add --encrypt ~/.ssh/config
# Or add to private directory
chezmoi add ~/.config/gh/config.yml  # Stored as private_dot_config/gh/
```

### Preview changes before applying

```bash
chezmoi diff
chezmoi diff ~/.zshrc  # Diff specific file
```

### Pull and apply updates from remote

```bash
chezmoi update        # git pull + apply
chezmoi update -n     # Dry run (preview only)
```

### Discard local changes

```bash
chezmoi apply --force  # Overwrite home files with source
```

## File Naming Convention

chezmoi uses special prefixes in the source directory:

| Prefix | Meaning | Example |
|--------|---------|---------|
| `dot_` | Becomes `.` | `dot_zshrc` → `.zshrc` |
| `private_` | Mode 0600 | `private_dot_ssh/` → `.ssh/` (private) |
| `executable_` | Mode +x | `executable_script.sh` → `script.sh` |
| `empty_` | Create empty file | `empty_dot_gitkeep` → `.gitkeep` |
| `symlink_` | Create symlink | `symlink_dot_vim` → `.vim` (symlink) |
| `modify_` | Modify existing file | Runs script to modify target |
| `.tmpl` | Template file | Processed with Go templates |

## What's Included

### Shell
- `.zshrc` - Zsh configuration with aliases, functions, completions
- `.zprofile` - Login shell environment
- `.p10k.zsh` - Powerlevel10k prompt theme
- `.inputrc` - Readline configuration

### Git
- `.gitconfig` - Git settings, aliases, and global gitignore
- `.gitignore_global` - Global ignore patterns

### Editor/Formatting
- `.editorconfig` - Universal editor settings
- `.prettierrc` - Prettier formatter config

### CLI Tools
- `.config/bat/config` - bat (cat replacement) theme
- `.config/starship.toml` - Starship prompt (alternative to p10k)
- `.ripgreprc` - ripgrep search defaults
- `.fdignore` - fd (find replacement) ignore patterns
- `.wgetrc` / `.curlrc` - Download tool defaults

### Languages
- `.config/pip/pip.conf` - Python pip configuration
- `.config/uv/uv.toml` - uv (Python) configuration
- `.config/ruff/ruff.toml` - Python linter/formatter
- `.config/go/env` - Go environment variables
- `.npmrc` - npm configuration
- `.condarc` - Conda configuration

### Other
- `.config/direnv/direnvrc` - direnv helpers (layout_uv, etc.)
- `.config/gh/config.yml` - GitHub CLI configuration
- `.config/fish/config.fish` - Fish shell config

### AI/Coding Agents
- `.claude/settings.json` - Claude Code plugin settings
- `.claude/CLAUDE.md` - Claude Code memory/instructions
- `.cursor/mcp.json` - Cursor MCP server configuration (templated)
- `.config/zed/settings.json` - Zed editor settings (templated)
- `.config/goose/config.yaml` - Goose AI configuration

## API Keys & Secrets Setup

IDE configs like Cursor and Zed use MCP servers that require API keys. These are managed via environment variables to avoid committing secrets to git.

### 1. Copy the secrets template

```bash
mkdir -p ~/.config/secrets
cp ~/.config/secrets/api-keys.env.tmpl ~/.config/secrets/api-keys.env
chmod 600 ~/.config/secrets/api-keys.env
```

### 2. Fill in your API keys

Edit `~/.config/secrets/api-keys.env` and add your keys:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export CONTEXT7_API_KEY="ctx7sk-..."
# ... etc
```

### 3. Source the secrets file

Add to your `.zshrc` (or it's already there if you use this repo):

```bash
[[ -f ~/.config/secrets/api-keys.env ]] && source ~/.config/secrets/api-keys.env
```

### 4. Apply chezmoi templates

```bash
source ~/.config/secrets/api-keys.env
chezmoi apply
```

The templated configs (`.tmpl` files) will be populated with your environment variables.

### Important: Never commit secrets!

The actual `api-keys.env` file is gitignored. Only the `.tmpl` template is committed.

## MCP Servers Included

| Server | Purpose |
|--------|---------|
| `context7` | Documentation lookup |
| `fetch` | Web fetching |
| `sequential-thinking` | Structured reasoning |
| `memory` | Persistent memory |
| `playwright` | Browser automation |
| `supabase` | Database operations |
| `vercel` | Deployment |
| `sentry` | Error tracking |
| `eslint` | Linting |
| `shadcn` | UI components |
| `google-maps` | Maps API |
| `perplexity` | AI search |

## Templates

For machine-specific configuration, use `.tmpl` files:

```bash
# Create a template
chezmoi add --template ~/.gitconfig
chezmoi edit ~/.gitconfig
```

Example template (`dot_gitconfig.tmpl`):
```toml
[user]
    name = {{ .name }}
    email = {{ .email }}
```

Configure variables in `~/.config/chezmoi/chezmoi.toml`:
```toml
[data]
    name = "Joe Carosella"
    email = "joe@example.com"
```

## Ignoring Files

Edit `.chezmoiignore` to exclude files from management:

```
README.md
LICENSE
*.md

# Ignore on specific OS
{{- if ne .chezmoi.os "darwin" }}
.config/karabiner/
{{- end }}
```

## Troubleshooting

### See what chezmoi would do

```bash
chezmoi apply -n -v  # Dry run with verbose output
```

### Check for errors

```bash
chezmoi doctor       # Diagnose common issues
chezmoi verify       # Verify target state matches source
```

### Reset a file to source state

```bash
chezmoi apply ~/.zshrc --force
```

### Re-add a file after manual edits

```bash
chezmoi re-add ~/.zshrc
```

## Resources

- [chezmoi Documentation](https://chezmoi.io/user-guide/command-overview/)
- [chezmoi GitHub](https://github.com/twpayne/chezmoi)
- [Quick Start Guide](https://chezmoi.io/quick-start/)
