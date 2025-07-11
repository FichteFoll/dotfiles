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


# Set up virtualenvwrapper
# https://virtualenvwrapper.readthedocs.io/en/latest/index.html
#
# Provides:
#   mkvirtualenv [-a project_path] [-i package] [-r requirements_file] [virtualenv options] ENVNAME
#   mktmpenv [(-c|--cd)|(-n|--no-cd)] [VIRTUALENV_OPTIONS]
#   lsvirtualenv [-b] [-l] [-h]
#   showvirtualenv [env]
#   rmvirtualenv ENVNAME
#   cpvirtualenv ENVNAME [TARGETENVNAME]
#   allvirtualenv command with arguments
#   workon [(-c|--cd)|(-n|--no-cd)] [environment_name|"."]
#   deactivate
#   cdvirtualenv [subdir]
#   cdsitepackages [subdir]
#   lssitepackages
#   add2virtualenv directory1 directory2 ...
#   toggleglobalsitepackages [-q]
#   mkproject
#   setvirtualenvproject
#   cdproject
#   wipeenv
#   virtualenvwrapper
export WORKON_HOME=${HOME}/.virtualenvs
# source /usr/bin/virtualenvwrapper.sh
[[ -e /usr/bin/virtualenvwrapper_lazy.sh ]] && source /usr/bin/virtualenvwrapper_lazy.sh

# fnm/nvm
if command -v fnm >/dev/null; then
    eval "$(fnm env --use-on-cd --shell zsh)"
elif [[ -e /usr/share/nvm/init-nvm.sh ]]; then
    source /usr/share/nvm/init-nvm.sh
fi

# quick directory jumping and file access (completions) through zoxide(1)
# z: jump to directory
# zi: open interactive move (via fzf)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Java environment management
command -v jenv >/dev/null && eval "$(jenv init -)"

# fzf key bindings
[[ -e /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh

# Env settings for tools
export AUR_PAGER="ranger --cmd aur"
export AUR_REPO="aur"  # default for aur packages
export AUR_SYNC_USE_NINJA="1"

export FZF_DEFAULT_COMMAND="fd --type file --follow --hidden --exclude .git --color=always"
export FZF_DEFAULT_OPTS="--ansi"

# Allow Gcloud to use numpy of site-packages
# https://cloud.google.com/iap/docs/using-tcp-forwarding#increasing_the_tcp_upload_bandwidth
export CLOUDSDK_PYTHON_SITEPACKAGES=1


# Load file with confidential information
[[ -e $HOME/.zshrc-private ]] && source ~/.zshrc-private
