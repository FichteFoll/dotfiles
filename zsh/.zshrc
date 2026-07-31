# source all .zsh files in that folder
# order shouldn't matter
sources=($HOME/zshrc/*.zsh)
for src in $sources; do
    source "$src"
done
unset sources src


# "command not found" hook to search package list
[[ -e /usr/share/doc/pkgfile/command-not-found.zsh ]] && source /usr/share/doc/pkgfile/command-not-found.zsh

# automatically quote URLs
# autoload -U url-quote-magic
# zle -N self-insert url-quote-magic
# autoload -Uz bracketed-paste-magic
# zle -N bracketed-paste bracketed-paste-magic


# stat command as built-in # http://zsh.sourceforge.net/Doc/Release/Zsh-Modules.html#The-zsh_002fstat-Module
# autoload -Uz stat


# fish-like syntax highlighting
# requires 'zsh-syntax-highlighting' package
sources=(/usr/share/{,zsh/plugins}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh)
for src in $sources; do
    [[ -e "$src" ]] && source "$src"
done
unset sources src


# use zsh's run-help (<M-h> to invoke on current line)
# (( ${+aliases[run-help]} )) && unalias run-help
alias run-help >&/dev/null && unalias run-help
for rh in run-help{,-git,-openssl,-sudo,-aur}; do
    autoload -Uz $rh
done; unset rh
alias help=run-help


# mise-en-place (toolchain manager)
if command -v mise >/dev/null; then
    eval "$(mise activate zsh)"
fi

# quick directory jumping and file access (completions) through zoxide(1)
# z: jump to directory
# zi: open interactive move (via fzf)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Env settings for tools
export AUR_PAGER="ranger --cmd aur"
export AUR_REPO="aur"  # default for aur packages
export AUR_SYNC_USE_NINJA="1"

export FZF_DEFAULT_COMMAND="fd --type file --follow --hidden --exclude .git --color=always"
export FZF_DEFAULT_OPTS="--ansi"

# Allow Gcloud to use numpy of site-packages
# https://cloud.google.com/iap/docs/using-tcp-forwarding#increasing_the_tcp_upload_bandwidth
export CLOUDSDK_PYTHON_SITEPACKAGES=1

# UV cannot hardlink because it crosses btrfs sub-volumes.
export UV_LINK_MODE=copy

# .claude.json moved into ~/.claude so the podman sandbox can ro-bind
# the whole config dir in one piece (see safe_claude.py NAMED_DIRS).
export CLAUDE_CONFIG_DIR="$HOME/.claude"

# Load file with confidential information
[[ -e $HOME/.zshrc-private ]] && source ~/.zshrc-private
