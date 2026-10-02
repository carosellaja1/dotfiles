# IDE settings

One source of truth for Cursor, VS Code and JetBrains (PyCharm first), with
two kinds of profile:

| Kind | Chosen | Applies to |
|------|--------|------------|
| **Machine profile**: `personal` or `work` | Once per machine, at `chezmoi init` | Everything: Cursor, VS Code and the workload profiles |
| **Workload profile**: `python`, `web` | Switchable inside Cursor / VS Code | That app's native Profiles feature |

## Where things live

```
.chezmoitemplates/ide/vscode/
  settings.base.json          shared by every app, every machine, every profile
  settings.code.json          only VS Code
  settings.cursor.json        only Cursor
  settings.personal.json      only machines that chose "personal"
  settings.work.json          only machines that chose "work"
  keybindings.base.json       + keybindings.<machine>.json
  extensions.base.txt         + extensions.<machine>.txt   (default profile)
  profiles/python/            settings.json + extensions.txt for the Python profile
  profiles/web/               same for the Web profile

dot_config/ide/vscode/
  code/, cursor/              rendered settings.json + keybindings.json per app
  snippets/                   shared snippets (both apps symlink here)
  profiles/*.code-profile     rendered workload profiles, ready to import

dot_config/jetbrains/         shared JetBrains settings (see below)
```

Rendered output goes to `~/.config/ide/vscode/<app>/`, and the real app paths
are symlinks to it:

| App | macOS | Linux |
|-----|-------|-------|
| VS Code | `~/Library/Application Support/Code/User/` | `~/.config/Code/User/` |
| Cursor | `~/Library/Application Support/Cursor/User/` | `~/.config/Cursor/User/` |

Merge order for `settings.json` is base, then app, then machine profile.
Later files win, and nested objects such as `"[python]"` merge key by key.

## First time on a machine

1. `chezmoi init` (re-run after pulling this change). It asks for the machine
   profile; `name` and `email` are remembered from before.
2. `chezmoi apply`. Before touching Cursor or VS Code it copies their current
   `settings.json`, `keybindings.json` and `snippets/` to
   `~/.config/ide/vscode/backup/<app>/<timestamp>/`, then replaces them with
   symlinks. For JetBrains it moves the portable settings into
   `~/.config/jetbrains/` and links them back (details below).
3. `ide-capture cursor` (or `ide-capture code`) reads that backup and writes
   it into the repo as `settings.base.json`, `keybindings.base.json`,
   `snippets/` and `extensions.base.txt`. It strips `//` comments and trailing
   commas so the file is strict JSON, which the templates need.
4. `chezmoi cd && git diff`. Move machine-specific keys into
   `settings.personal.json` / `settings.work.json`, workload-specific keys and
   extensions into `profiles/<name>/`, then `chezmoi apply` again.
5. `chezmoi add ~/.config/jetbrains`, commit, push.

Quit the IDEs before step 2 so they do not write over the files mid-switch.

## Day to day

| Task | How |
|------|-----|
| Change a setting for every machine | edit `settings.base.json`, `chezmoi apply` |
| Change a setting only on work machines | edit `settings.work.json`, `chezmoi apply` |
| Add an extension everywhere | add its id to `extensions.base.txt`, `chezmoi apply` (installs via the `code` / `cursor` CLI) |
| Changed something through the IDE's settings UI | `chezmoi diff` shows it; copy the key into the right JSON file, or the next `apply` reverts it |
| Add a snippet | drop it in `~/.config/ide/vscode/snippets/`, `chezmoi add ~/.config/ide/vscode/snippets` |
| Changed a JetBrains setting in the IDE | `chezmoi re-add ~/.config/jetbrains` (the IDE wrote through the symlink) |

Because `settings.json` is rendered from several files, `chezmoi re-add` is
not used for it; edit the source files instead.

## Workload profiles (Cursor / VS Code)

`chezmoi apply` renders `~/.config/ide/vscode/profiles/python.code-profile`
and `web.code-profile`. Each contains base + machine settings + that
profile's settings, the keybindings, and base + machine + profile extensions.

Import once per app: Command Palette, **Profiles: Import Profile...**, pick the
file. Switch with **Profiles: Switch Profile...** or open a folder with
`cursor --profile Python .`. When you change a profile's files in the repo,
`chezmoi apply` re-renders the export and you re-import it. Both apps offer
to overwrite the existing profile of the same name.

To add a profile, create `profiles/<name>/settings.json` and `extensions.txt`
in `.chezmoitemplates/ide/vscode/`, then add
`dot_config/ide/vscode/profiles/<name>.code-profile.tmpl` containing:

```
{{ template "ide/vscode/code-profile" (dict "root" . "name" "<name>") }}
```

## JetBrains (PyCharm)

JetBrains keeps config in a versioned folder such as
`~/Library/Application Support/JetBrains/PyCharm2025.2/`, which is exactly
what cleanup apps delete. `run_after_jetbrains-link.sh` runs on every
`chezmoi apply` and, for every JetBrains folder it finds, replaces these
entries with symlinks into `~/.config/jetbrains/`:

- directories: `keymaps`, `codestyles`, `colors`, `templates` (live
  templates), `fileTemplates`, `inspection`
- files in `options/`: `editor.xml`, `editor-font.xml`, `console-font.xml`,
  `code.style.schemes.xml`, `colors.scheme.xml`, `keymap.xml`,
  `ide.general.xml`, `laf.xml`, `ui.lnf.xml`, `vcs.xml`, `git.xml`,
  `terminal.xml`

Everything else in `options/` (recent projects, window state, SDK tables)
is machine state and stays local. Edit the two lists at the top of the
script to change what is shared.

On the first run the newest IDE folder's files are moved into
`~/.config/jetbrains/`; older folders' copies are renamed `*.bak-<timestamp>`
next to where they were. After that, if a cleaner deletes the whole
`PyCharm2025.2` folder, start PyCharm once (it recreates the folder), quit
it, and run `chezmoi apply` to relink. Nothing was lost because the real
files are in `~/.config/jetbrains/` and in git.

Other JetBrains IDEs (IntelliJ, WebStorm, DataGrip, Rider, ...) are linked
the same way when present, so they pick up the same keymap and code style.

## Tip for cleaner apps

Add `~/.config/ide`, `~/.config/jetbrains` and
`~/Library/Application Support/JetBrains` to the exclusion list in Pearcleaner
or CleanMyMac. Even if you forget, `chezmoi apply` puts everything back.
