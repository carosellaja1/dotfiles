# ZSH Toolset Loader
# =============================================
# Load tool bundles on-demand to keep shell fast
#
# Usage:
#   toolset load aws k8s      # load multiple toolsets
#   toolset unload gcloud     # unload a toolset
#   toolset list              # show available toolsets
#   toolset active            # show loaded toolsets
#   toolset auto              # auto-detect from project files

typeset -gA TOOLSET_LOADED  # track loaded toolsets

# =============================================
# TOOLSET DEFINITIONS
# =============================================

_toolset_aws() {
    export AWS_PAGER=""
    export PATH="$HOME/.local/bin:$PATH"

    # AWS CLI completions
    if command -v aws_completer &>/dev/null; then
        complete -C aws_completer aws
    fi

    # Aliases
    alias awswho='aws sts get-caller-identity'
    alias awsregions='aws ec2 describe-regions --output table'
}

_toolset_gcloud() {
    # Google Cloud SDK
    if [[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]]; then
        source "$HOME/google-cloud-sdk/path.zsh.inc"
    fi
    if [[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]]; then
        source "$HOME/google-cloud-sdk/completion.zsh.inc"
    fi

    # Aliases
    alias gcauth='gcloud auth login'
    alias gcproj='gcloud config get-value project'
    alias gcprojs='gcloud projects list'
}

_toolset_k8s() {
    # kubectl - check common locations
    for kpath in /usr/local/bin/kubectl /opt/homebrew/bin/kubectl "$HOME/.local/bin/kubectl"; do
        [[ -x "$kpath" ]] && export PATH="${kpath%/*}:$PATH" && break
    done

    # Helm
    [[ -x /opt/homebrew/bin/helm ]] && export PATH="/opt/homebrew/bin:$PATH"

    # Completions
    if command -v kubectl &>/dev/null; then
        source <(kubectl completion zsh)
    fi
    if command -v helm &>/dev/null; then
        source <(helm completion zsh)
    fi

    # Aliases
    alias k='kubectl'
    alias kx='kubectx'
    alias kn='kubens'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get svc'
    alias kgd='kubectl get deployments'
    alias kga='kubectl get all'
    alias kaf='kubectl apply -f'
    alias kdel='kubectl delete'
    alias klogs='kubectl logs -f'
    alias kexec='kubectl exec -it'
}

_toolset_docker() {
    # Docker completions
    if [[ -d "$HOME/.docker/completions" ]]; then
        fpath=("$HOME/.docker/completions" $fpath)
    fi

    # Aliases
    alias d='docker'
    alias dc='docker compose'
    alias dps='docker ps'
    alias dpsa='docker ps -a'
    alias dimg='docker images'
    alias drm='docker rm'
    alias drmi='docker rmi'
    alias dprune='docker system prune -af'
    alias dlogs='docker logs -f'
    alias dexec='docker exec -it'
}

_toolset_network() {
    # Aliases for network debugging
    alias myip='curl -s ifconfig.me'
    alias localip='ipconfig getifaddr en0'
    alias ports='lsof -i -P -n | grep LISTEN'
    alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
    alias ping='ping -c 5'
    alias httpdump='sudo tcpdump -i en0 -n -s 0 -w - | grep -a -o -E "Host\: .*|GET \/.*"'

    # HTTPie aliases if installed
    if command -v http &>/dev/null; then
        alias GET='http GET'
        alias POST='http POST'
        alias PUT='http PUT'
        alias DELETE='http DELETE'
    fi
}

_toolset_media() {
    # FFmpeg aliases
    if command -v ffmpeg &>/dev/null; then
        # Convert video to gif
        togif() {
            local input="$1"
            local output="${2:-${input%.*}.gif}"
            ffmpeg -i "$input" -vf "fps=10,scale=480:-1:flags=lanczos" -c:v gif "$output"
        }

        # Extract audio from video
        toaudio() {
            local input="$1"
            local output="${2:-${input%.*}.mp3}"
            ffmpeg -i "$input" -vn -acodec libmp3lame -q:a 2 "$output"
        }

        # Compress video
        compressvid() {
            local input="$1"
            local output="${2:-${input%.*}_compressed.mp4}"
            ffmpeg -i "$input" -vcodec libx264 -crf 28 "$output"
        }

        # Get video info
        vidinfo() {
            ffprobe -v quiet -print_format json -show_format -show_streams "$1" | jq
        }
    fi

    # ImageMagick aliases
    if command -v convert &>/dev/null; then
        # Resize image
        imgresize() {
            local input="$1"
            local size="${2:-50%}"
            local output="${3:-${input%.*}_resized.${input##*.}}"
            convert "$input" -resize "$size" "$output"
        }

        # Convert image format
        imgconvert() {
            local input="$1"
            local format="$2"
            convert "$input" "${input%.*}.${format}"
        }
    fi
}

_toolset_python() {
    # Python tooling (beyond language detection plugins)
    export PYTHONDONTWRITEBYTECODE=1

    # pyenv
    if [[ -d "$HOME/.pyenv" ]]; then
        export PYENV_ROOT="$HOME/.pyenv"
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
    fi

    # pipx
    export PATH="$HOME/.local/bin:$PATH"

    # Aliases
    alias py='python3'
    alias pip='pip3'
    alias venv='python3 -m venv'
    alias activate='source .venv/bin/activate 2>/dev/null || source venv/bin/activate'
    alias pipreq='pip freeze > requirements.txt'
    alias pipup='pip install --upgrade pip'
}

_toolset_node() {
    # Node.js tooling
    export PATH="$HOME/.npm-global/bin:$PATH"

    # nvm (lazy load)
    export NVM_DIR="$HOME/.nvm"
    nvm() {
        unfunction nvm
        [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
        nvm "$@"
    }

    # pnpm
    export PNPM_HOME="$HOME/Library/pnpm"
    export PATH="$PNPM_HOME:$PATH"

    # Aliases
    alias nr='npm run'
    alias ni='npm install'
    alias nid='npm install --save-dev'
    alias nig='npm install -g'
    alias pn='pnpm'
    alias pnr='pnpm run'
    alias pni='pnpm install'
}

_toolset_go() {
    export GOPATH="$HOME/go"
    export PATH="$GOPATH/bin:$PATH"

    # Aliases
    alias gor='go run'
    alias gob='go build'
    alias got='go test'
    alias goget='go get -u'
    alias gomod='go mod tidy'
}

_toolset_ruby() {
    # rbenv
    if command -v rbenv &>/dev/null; then
        eval "$(rbenv init -)"
    fi

    # Aliases
    alias be='bundle exec'
    alias bi='bundle install'
    alias bu='bundle update'
}

_toolset_php() {
    # Composer
    export PATH="$HOME/.composer/vendor/bin:$PATH"

    # Laravel
    alias art='php artisan'
    alias sail='./vendor/bin/sail'
    alias pint='./vendor/bin/pint'

    # Aliases
    alias composer='php -d memory_limit=-1 /usr/local/bin/composer'
}

_toolset_terraform() {
    # Terraform completions
    if command -v terraform &>/dev/null; then
        complete -o nospace -C terraform terraform
    fi

    # Aliases
    alias tf='terraform'
    alias tfi='terraform init'
    alias tfp='terraform plan'
    alias tfa='terraform apply'
    alias tfd='terraform destroy'
    alias tff='terraform fmt'
    alias tfv='terraform validate'
}

# =============================================
# TOOLSET MANAGER
# =============================================

toolset() {
    local cmd="$1"
    shift

    case "$cmd" in
        load)
            for ts in "$@"; do
                if typeset -f "_toolset_$ts" &>/dev/null; then
                    if [[ -z "${TOOLSET_LOADED[$ts]}" ]]; then
                        "_toolset_$ts"
                        TOOLSET_LOADED[$ts]=1
                        echo "Loaded: $ts"
                    else
                        echo "Already loaded: $ts"
                    fi
                else
                    echo "Unknown toolset: $ts"
                    echo "Run 'toolset list' to see available toolsets"
                fi
            done
            ;;
        unload)
            for ts in "$@"; do
                if [[ -n "${TOOLSET_LOADED[$ts]}" ]]; then
                    unset "TOOLSET_LOADED[$ts]"
                    echo "Marked unloaded: $ts (restart shell for full effect)"
                else
                    echo "Not loaded: $ts"
                fi
            done
            ;;
        list)
            echo "Available toolsets:"
            echo "  aws        - AWS CLI, completions, aliases"
            echo "  gcloud     - Google Cloud SDK, completions"
            echo "  k8s        - kubectl, helm, completions, aliases"
            echo "  docker     - Docker completions, aliases"
            echo "  network    - Network debugging tools, aliases"
            echo "  media      - FFmpeg, ImageMagick helpers"
            echo "  python     - pyenv, pip, venv aliases"
            echo "  node       - nvm, pnpm, npm aliases"
            echo "  go         - Go environment, aliases"
            echo "  ruby       - rbenv, bundler aliases"
            echo "  php        - Composer, Laravel aliases"
            echo "  terraform  - Terraform completions, aliases"
            ;;
        active)
            if [[ ${#TOOLSET_LOADED[@]} -eq 0 ]]; then
                echo "No toolsets loaded"
            else
                echo "Active toolsets: ${(k)TOOLSET_LOADED}"
            fi
            ;;
        auto)
            # Auto-detect based on project files
            [[ -f "Dockerfile" || -f "docker-compose.yml" ]] && toolset load docker
            [[ -f "Makefile" && -d ".kube" ]] || [[ -f "k8s.yaml" || -d "k8s" || -f "helmfile.yaml" ]] && toolset load k8s
            [[ -f "serverless.yml" || -d ".aws" || -f "samconfig.toml" ]] && toolset load aws
            [[ -f "app.yaml" || -f ".gcloudignore" ]] && toolset load gcloud
            [[ -f "main.tf" || -f "terraform.tf" ]] && toolset load terraform
            ;;
        *)
            echo "Usage: toolset <command> [toolsets...]"
            echo ""
            echo "Commands:"
            echo "  load <toolsets...>    Load one or more toolsets"
            echo "  unload <toolsets...>  Mark toolsets as unloaded"
            echo "  list                  Show available toolsets"
            echo "  active                Show currently loaded toolsets"
            echo "  auto                  Auto-detect toolsets from project"
            ;;
    esac
}

# Auto-complete for toolset command
_toolset_completions() {
    local -a toolsets
    toolsets=(aws gcloud k8s docker network media python node go ruby php terraform)

    case "$words[2]" in
        load|unload)
            _describe 'toolset' toolsets
            ;;
        *)
            local -a commands
            commands=(load unload list active auto)
            _describe 'command' commands
            ;;
    esac
}
compdef _toolset_completions toolset
