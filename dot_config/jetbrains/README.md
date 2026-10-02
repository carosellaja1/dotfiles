Shared JetBrains settings (PyCharm first; any other JetBrains IDE found is
linked the same way).

On every `chezmoi apply`, run_after_jetbrains-link.sh replaces these entries
inside each JetBrains config folder with symlinks into this directory:

  keymaps/  codestyles/  colors/  templates/  fileTemplates/  inspection/
  options/<a fixed list of portable xml files>

The first time, whatever the IDE already has is moved in here, so nothing is
lost. Then run `chezmoi add ~/.config/jetbrains` to start syncing it.

If a cleaner app deletes `~/Library/Application Support/JetBrains/PyCharm*`,
the real settings are still here; `chezmoi apply` recreates the folder with
the links (it remembers folder names in ~/.local/state/jetbrains-link/).
