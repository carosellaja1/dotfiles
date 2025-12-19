# ZSH Plugin Loader with Environment Detection
# =============================================

# Set plugin directory
ZPLUGINDIR="${HOME}/.zsh/plugins"
[[ -d "$ZPLUGINDIR" ]] || mkdir -p "$ZPLUGINDIR"

# Detect current IDE/terminal
detect_ide() {
    case "$TERM_PROGRAM" in
        vscode)      echo "vscode" ;;
        cursor)      echo "cursor" ;;
        iTerm.app)   echo "iterm" ;;
        Apple_Terminal) echo "terminal" ;;
        *)
            # Check for JetBrains IDEs via env vars
            if [[ -n "$JETBRAINS_IDE" || -n "$TERMINAL_EMULATOR" && "$TERMINAL_EMULATOR" == *"JetBrains"* ]]; then
                echo "jetbrains"
            elif [[ -n "$PYCHARM_HOSTED" ]]; then
                echo "pycharm"
            elif [[ -n "$INTELLIJ_ENVIRONMENT_READER" ]]; then
                echo "intellij"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Detect project language from current directory
detect_language() {
    local dir="${1:-$PWD}"

    # Python
    [[ -f "$dir/pyproject.toml" || -f "$dir/requirements.txt" || -f "$dir/setup.py" || -f "$dir/Pipfile" || -f "$dir/poetry.lock" ]] && echo "python" && return

    # Node/JavaScript/TypeScript
    [[ -f "$dir/package.json" ]] && echo "node" && return

    # Go
    [[ -f "$dir/go.mod" ]] && echo "go" && return

    # Rust
    [[ -f "$dir/Cargo.toml" ]] && echo "rust" && return

    # Ruby
    [[ -f "$dir/Gemfile" ]] && echo "ruby" && return

    # PHP
    [[ -f "$dir/composer.json" ]] && echo "php" && return

    # Swift
    [[ -f "$dir/Package.swift" || -d "$dir/*.xcodeproj" || -d "$dir/*.xcworkspace" ]] && echo "swift" && return

    # Java/Kotlin
    [[ -f "$dir/pom.xml" || -f "$dir/build.gradle" || -f "$dir/build.gradle.kts" ]] && echo "java" && return

    # C#/.NET
    [[ -n "$(find "$dir" -maxdepth 1 -name '*.csproj' -o -name '*.sln' 2>/dev/null | head -1)" ]] && echo "dotnet" && return

    # C/C++
    [[ -f "$dir/CMakeLists.txt" || -f "$dir/Makefile" ]] && echo "cpp" && return

    echo "generic"
}

# Plugin load function (with bug fixes)
_pluginload_() {
    local giturl="$1"
    local plugin_name="${${1##*/}%.git}"
    local plugindir="${ZPLUGINDIR}/${plugin_name}"

    # Clone if not present
    if [[ ! -d "$plugindir" ]]; then
        command git clone --depth 1 --recursive --shallow-submodules "$giturl" "$plugindir" 2>/dev/null
        [[ $? -eq 0 ]] || { >&2 echo "plugin-load: git clone failed; $1" && return 1; }
    fi

    # Symlink init.zsh if missing
    if [[ ! -f "$plugindir/init.zsh" ]]; then
        local initfiles=(
            ${plugindir}/${plugin_name}.plugin.zsh(N)
            ${plugindir}/${plugin_name}.zsh(N)
            ${plugindir}/${plugin_name}(N)
            ${plugindir}/${plugin_name}.zsh-theme(N)
            ${plugindir}/*.plugin.zsh(N)
            ${plugindir}/*.zsh(N)
            ${plugindir}/*.zsh-theme(N)
            ${plugindir}/*.sh(N)
        )
        [[ ${#initfiles[@]} -gt 0 ]] || { >&2 echo "plugin-load: no init file found for $plugin_name" && return 1; }
        command ln -sf "${initfiles[1]}" "${plugindir}/init.zsh"
    fi

    # Source the plugin
    source "${plugindir}/init.zsh"

    # Add to fpath
    fpath+="$plugindir"
    [[ -d "${plugindir}/functions" ]] && fpath+="${plugindir}/functions"
}

# =============================================
# PLUGIN DEFINITIONS
# =============================================

# Core plugins (always loaded)
core_plugins=(
    peterhurford/up.zsh                   # cd to parent dirs (up 3)
    marlonrichert/zsh-hist                # hist -h for help
    MichaelAquilina/zsh-you-should-use    # alias suggestions
)

# macOS-specific plugins
mac_plugins=(
    ellie/atuin                           # sqlite-based history
)

# Python project plugins
python_plugins=(
    darvid/zsh-poetry                     # poetry completions
)

# Node/JS project plugins
node_plugins=(
    lukechilds/zsh-nvm                    # lazy nvm loading
)

# Go project plugins
go_plugins=(
    # Add go-specific plugins here
)

# Rust project plugins
rust_plugins=(
    # Add rust-specific plugins here
)

# Swift/iOS project plugins
swift_plugins=(
    # Add swift-specific plugins here
)

# Syntax highlighting (load last)
final_plugins=(
    zdharma-continuum/fast-syntax-highlighting
    zsh-users/zsh-history-substring-search
)

# =============================================
# LOAD PLUGINS
# =============================================

# Load core plugins
for repo in ${core_plugins[@]}; do
    _pluginload_ "https://github.com/${repo}.git"
done

# Load macOS plugins
if [[ "$OSTYPE" == darwin* ]]; then
    for repo in ${mac_plugins[@]}; do
        _pluginload_ "https://github.com/${repo}.git"
    done
fi

# Load language-specific plugins based on current directory
_load_lang_plugins_() {
    local lang=$(detect_language)
    local -a lang_plugins

    case "$lang" in
        python) lang_plugins=("${python_plugins[@]}") ;;
        node)   lang_plugins=("${node_plugins[@]}") ;;
        go)     lang_plugins=("${go_plugins[@]}") ;;
        rust)   lang_plugins=("${rust_plugins[@]}") ;;
        swift)  lang_plugins=("${swift_plugins[@]}") ;;
    esac

    for repo in ${lang_plugins[@]}; do
        _pluginload_ "https://github.com/${repo}.git"
    done
}

# Load language plugins on directory change
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _load_lang_plugins_

# Initial load for current directory
_load_lang_plugins_

# Load final plugins (syntax highlighting etc)
for repo in ${final_plugins[@]}; do
    _pluginload_ "https://github.com/${repo}.git"
done

# =============================================
# PLUGIN CONFIGURATION
# =============================================

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
ZSH_AUTOSUGGEST_MAX_BUFFER_SIZE="20"
FAST_HIGHLIGHT[use_brackets]=1

# =============================================
# UTILITIES
# =============================================

# Update all plugins
zshup() {
    for d in $ZPLUGINDIR/*/.git(/); do
        echo "Updating ${d:h:t}..."
        command git -C "${d:h}" pull --ff --recurse-submodules --depth 1 --rebase --autostash
    done
}

# Show detected environment
zshenv() {
    echo "IDE:      $(detect_ide)"
    echo "Language: $(detect_language)"
    echo "OS:       $OSTYPE"
}
