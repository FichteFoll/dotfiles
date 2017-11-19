#
# DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$HOME/zsh/completions.zsh"

source "$HOME/zsh/bindings.zsh"


###########################################################
# options

HISTFILE=${ZDOTDIR:-${HOME}}/.zsh_history
HISTSIZE=5000
SAVEHIST=10000

# append history list to the history file; this is the default but we make sure
# because it's required for share_history.
setopt append_history
# import new commands from the history file also in other zsh-session
setopt share_history
# save each command's beginning timestamp and the duration to the history file
setopt extended_history
# If a new command line being added to the history list duplicates an older
# one, the older command is removed from the list
setopt histignorealldups
# remove command lines from the history list when the first character on the
# line is a space
setopt histignorespace
# display PID when suspending processes as well
setopt longlistjobs
# not just at the end
setopt completeinword
# make cd push the old directory onto the directory stack.
setopt auto_pushd
# report the status of backgrounds jobs immediately
setopt notify
# avoid "beep"ing
setopt nobeep

setopt nomatch
unsetopt autocd


###########################################################
# prompt
#
# https://wiki.archlinux.org/index.php/Zsh#Prompts
# http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html

autoload -Uz promptinit
promptinit
prompt walters

# secondary prompt, printed when the shell needs more information to complete a
# command.
PS2='\`%_> '
# selection prompt used within a select loop.
PS3='?# '
# the execution trace prompt (setopt xtrace). default: '+%N:%i>'
PS4='+%N:%i:%_> '

# title bar prompt
precmd () { print -Pn "\e]2;%n@%M | %~\a" }


###########################################################
# color stuff

alias diff='diff --color=auto'
alias grep='grep --color=auto'

# support colors in less
export LESS_TERMCAP_mb=$'\E[01;31m'    # begin bold
export LESS_TERMCAP_md=$'\E[01;31m'    # begin blink
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m' # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[01;32m'    # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

# requires 'source-highlight' package
export LESSOPEN='| /usr/bin/source-highlight-esc.sh %s'
export LESS='-R '

export COLORTERM="yes" # ???

# color setup for ls:
eval $(dircolors -b)


###########################################################
# other stuff

# "command not found" hook to search package list
source /usr/share/doc/pkgfile/command-not-found.zsh


# fish-like syntax highlighting
# requires 'zsh-syntax-highlighting' package
syntax_file=/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -e "${syntax_file}" ]] && source "${syntax_file}"
unset syntax_file


# termite: Launch new terminal in current dir
if [[ $TERM == xterm-termite ]]; then
  . /etc/profile.d/vte.sh
  __vte_osc7
fi


# use zsh's run-help (<M-h> to invoke on current line)
# (( ${+aliases[run-help]} )) && unalias run-help
alias run-help >&/dev/null && unalias run-help
for rh in run-help{,-git,-openssl,-sudo}; do
    autoload -Uz $rh
done; unset rh
alias help=run-help


###########################################################
# aliases and functions (mostly)

# pls
alias pls='sudo !!'

# ls: exa
alias ls='exa --time-style=long-iso'
alias exat='exa --tree --level=3'
alias ols='command ls --color=auto'

# alias la="ls -la ${ls_options:+${ls_options[*]}}"
# alias ll="ls -l ${ls_options:+${ls_options[*]}}"
# alias lh="ls -hAl ${ls_options:+${ls_options[*]}}"
# alias l="ls -l ${ls_options:+${ls_options[*]}}"
alias dir="exa -la"
# All entries
alias lsa='ls -a'
# Only show dot-files
alias lsa='ls -a .*(.)'
# Only show dot-directories
alias lsad='ls -d .*(/)'
# Only files with setgid/setuid/sticky flag
alias lss='ls -l *(s,S,t)'
# Only show symlinks
alias lsl='ls -l *(@)'
# Display only executables
alias lsx='ls -l *(*)'
# Display world-{readable,writable,executable} files
alias lsw='ls -ld *(R,W,X.^ND/)'
# Display the ten biggest files
alias lsbig="exa -lr --sort=size *(.OL[1,10])"
# Only show directories
alias lsd='ls -d *(/)'
# Only show empty directories
alias lsed='ls -d *(/^F)'


# Shorthands for directory navigation
alias ..='cd ../'

# cd to directoy and list files
cl() {
    cd $1 && ls -a
}

# Create Directoy and cd to it
mkcd() {
    if (( ARGC != 1 )); then
        printf 'usage: mkcd <new-directory>\n'
        return 1;
    fi
    if [[ ! -d "$1" ]]; then
        command mkdir -p "$1"
    else
        printf '`%s'\'' already exists: cd-ing.\n' "$1"
    fi
    builtin cd "$1"
}

# Create temporary directory and cd to it
mktcd() {
    builtin cd "$(mktemp -d)"
    builtin pwd
}

# Remove current empty directory.
alias rmcdir='cd ..; rmdir $OLDPWD || cd $OLDPWD'


# OpenSSL cert shorthands
ssl_hashes=( sha512 sha256 sha1 md5 )

for sh in ${ssl_hashes}; do
    eval 'ssl-cert-'${sh}'() {
        emulate -L zsh
        if [[ -z $1 ]] ; then
            printf '\''usage: %s <file>\n'\'' "ssh-cert-'${sh}'"
            return 1
        fi
        openssl x509 -noout -fingerprint -'${sh}' -in $1
    }'
done; unset sh

ssl-cert-fingerprints() {
    emulate -L zsh
    local i
    if [[ -z $1 ]] ; then
        printf 'usage: ssl-cert-fingerprints <file>\n'
        return 1
    fi
    for i in ${ssl_hashes}
        do ssl-cert-$i $1;
    done
}

ssl-cert-info() {
    emulate -L zsh
    if [[ -z $1 ]] ; then
        printf 'usage: ssl-cert-info <file>\n'
        return 1
    fi
    openssl x509 -noout -text -in $1
    ssl-cert-fingerprints $1
}

# insecure ssh and scp
alias insecssh='ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"'
alias insecscp='scp -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"'


# Find history events by search pattern and list them by date.
whatwhen()  {
    emulate -L zsh
    local usage help ident format_l format_s first_char remain first last
    usage='USAGE: whatwhen [options] <searchstring> <search range>'
    help='Use `whatwhen -h'\'' for further explanations.'
    ident=${(l,${#${:-Usage: }},, ,)}
    format_l="${ident}%s\t\t\t%s\n"
    format_s="${format_l//(\\t)##/\\t}"
    # Make the first char of the word to search for case
    # insensitive; e.g. [aA]
    first_char=[${(L)1[1]}${(U)1[1]}]
    remain=${1[2,-1]}
    # Default search range is `-100'.
    first=${2:-\-100}
    # Optional, just used for `<first> <last>' given.
    last=$3
    case $1 in
        ("")
            printf '%s\n\n' 'ERROR: No search string specified. Aborting.'
            printf '%s\n%s\n\n' ${usage} ${help} && return 1
        ;;
        (-h)
            printf '%s\n\n' ${usage}
            print 'OPTIONS:'
            printf $format_l '-h' 'show help text'
            print '\f'
            print 'SEARCH RANGE:'
            printf $format_l "'0'" 'the whole history,'
            printf $format_l '-<n>' 'offset to the current history number; (default: -100)'
            printf $format_s '<[-]first> [<last>]' 'just searching within a give range'
            printf '\n%s\n' 'EXAMPLES:'
            printf ${format_l/(\\t)/} 'whatwhen grml' '# Range is set to -100 by default.'
            printf $format_l 'whatwhen zsh -250'
            printf $format_l 'whatwhen foo 1 99'
        ;;
        (\?)
            printf '%s\n%s\n\n' ${usage} ${help} && return 1
        ;;
        (*)
            # -l list results on stout rather than invoking $EDITOR.
            # -i Print dates as in YYYY-MM-DD.
            # -m Search for a - quoted - pattern within the history.
            fc -li -m "*${first_char}${remain}*" $first $last
        ;;
    esac
}


# mpv/ytdl
twitch() {
    local channel=$1
    shift
    mpv $@ -- "https://twitch.tv/$channel"
}

alias mpa="mpv --profile=audio"
alias ytdl="youtube-dl"


# check for system updates
cu () {
    checkupdates
    pacaur -k
}
cu2 () {
    # include updates for --devel packages (*-git)
    # takes longer to run because all git repos need to be updated
    checkupdates
    pacaur -k --devel --needed
}

# systemd aliases
alias sc='systemctl'
alias jc='journalctl'
alias nc='netctl'


# wine stuff
alias wine32='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32" wine'
alias winecfg32='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32" winecfg'
alias winetricks32='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32" winetricks'

alias wine_tmp='env WINEPREFIX="$HOME/.wine_tmp" wine'
alias winecfg_tmp='env WINEPREFIX="$HOME/.wine_tmp" winecfg'
alias winetricks_tmp='env WINEPREFIX="$HOME/.wine_tmp" winetricks'


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
source /usr/bin/virtualenvwrapper_lazy.sh

alias venv="source .venv/bin/activate"
