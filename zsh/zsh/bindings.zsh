# http://zshwiki.org/home/zle/bindkeys
# http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Zsh-Line-Editor
# https://grml.org/zsh/

function zrcgotwidget() {
    (( ${+widgets[$1]} ))
}

function zrcbindkey() {
    if (( ARGC )) && zrcgotwidget ${argv[-1]}; then
        bindkey "$@"
    fi
}

function bind2maps () {
    local i sequence widget
    local -a maps

    while [[ "$1" != "--" ]]; do
        maps+=( "$1" )
        shift
    done
    shift

    if [[ "$1" == "-s" ]]; then
        shift
        sequence="$1"
    else
        sequence="${key[$1]}"
    fi
    widget="$2"

    [[ -z "$sequence" ]] && return 1

    for i in "${maps[@]}"; do
        zrcbindkey -M "$i" "$sequence" "$widget"
    done
}

# Make sure the terminal is in application mode, when zle is
# active. Only then the values from $terminfo are valid.
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
    function zle-line-init () {
        emulate -L zsh
        printf '%s' ${terminfo[smkx]}
    }
    function zle-line-finish () {
        emulate -L zsh
        printf '%s' ${terminfo[rmkx]}
    }
    zle -N zle-line-init
    zle -N zle-line-finish
else
    echo "Terminal missing smkx and rmkx"
fi

# add a command line to the shells history without executing it
commit-to-history() {
    if [[ -n "$BUFFER" ]]; then
        print -s ${(z)BUFFER}
        # zle send-break
    fi
    return 0
}
zle -N commit-to-history

# IRC-like history behavior
# http://zshwiki.org/home/zle/ircclientlikeinput
# add line to history if we can't go down; go down or browse history otherwise
commit-or-down-line-or-history() {
    if (( HISTNO == HISTCMD )) && [[ "$RBUFFER" != *$'\n'* ]]; then
        zle commit-to-history
    fi
    zle .down-line-or-history "$@"
}
zle -N commit-or-down-line-or-history

# only slash should be considered as a word separator
slash-backward-kill-word() {
    local WORDCHARS="${WORDCHARS:s@/@}"
    # zle backward-word
    zle backward-kill-word
}
zle -N slash-backward-kill-word

# run current or last command line via sudo
# https://github.com/robbyrussell/oh-my-zsh/blob/master/plugins/sudo/sudo.plugin.zsh
sudo-command-line() {
    [[ -z $BUFFER ]] && zle up-history
    if [[ $BUFFER == sudo\ * ]]; then
        LBUFFER="${LBUFFER#sudo }"
    elif [[ $BUFFER == $EDITOR\ * ]]; then
        LBUFFER="${LBUFFER#$EDITOR }"
        LBUFFER="sudoedit $LBUFFER"
    elif [[ $BUFFER == sudoedit\ * ]]; then
        LBUFFER="${LBUFFER#sudoedit }"
        LBUFFER="$EDITOR $LBUFFER"
    else
        LBUFFER="sudo $LBUFFER"
    fi
}
zle -N sudo-command-line

inplaceMkDirs() {
    # Press ctrl-xM to create the directory under the cursor or the selected area.
    # To select an area press ctrl-@ or ctrl-space and use the cursor.
    # Use case: you type "mv abc ~/testa/testb/testc/" and remember that the
    # directory does not exist yet -> press ctrl-XM and problem solved
    local PATHTOMKDIR
    if ((REGION_ACTIVE==1)); then
        local F=$MARK T=$CURSOR
        if [[ $F -gt $T ]]; then
            F=${CURSOR}
            T=${MARK}
        fi
        # get marked area from buffer and eliminate whitespace
        PATHTOMKDIR=${BUFFER[F+1,T]%%[[:space:]]##}
        PATHTOMKDIR=${PATHTOMKDIR##[[:space:]]##}
    else
        local bufwords iword
        bufwords=(${(z)LBUFFER})
        iword=${#bufwords}
        bufwords=(${(z)BUFFER})
        PATHTOMKDIR="${(Q)bufwords[iword]}"
    fi
    [[ -z "${PATHTOMKDIR}" ]] && return 1
    PATHTOMKDIR=${~PATHTOMKDIR}
    if [[ -e "${PATHTOMKDIR}" ]]; then
        zle -M " path already exists, doing nothing"
    else
        zle -M "$(mkdir -p -v "${PATHTOMKDIR}")"
        zle end-of-line
    fi
}
zle -N inplaceMkDirs

insert-datestamp() {
    LBUFFER+=${(%):-'%D{%Y-%m-%d}'};
}
zle -N insert-datestamp

# https://anonscm.debian.org/cgit/pkg-zsh/zsh.git/tree/debian/zshrc
typeset -A key
key=(
    BackSpace  "${terminfo[kbs]}"
    Home       "${terminfo[khome]}"
    End        "${terminfo[kend]}"
    Insert     "${terminfo[kich1]}"
    Delete     "${terminfo[kdch1]}"
    Up         "${terminfo[kcuu1]}"
    Down       "${terminfo[kcud1]}"
    Left       "${terminfo[kcub1]}"
    Right      "${terminfo[kcuf1]}"
    PageUp     "${terminfo[kpp]}"
    PageDown   "${terminfo[knp]}"
    BackTab    "${terminfo[kcbt]}"
)

# default to emacs mode
bindkey -e

bind2maps emacs             -- BackSpace    backward-delete-char
bind2maps       viins       -- BackSpace    vi-backward-delete-char
bind2maps             vicmd -- BackSpace    vi-backward-char
bind2maps emacs             -- Home         beginning-of-line
bind2maps       viins vicmd -- Home         vi-beginning-of-line
bind2maps emacs             -- End          end-of-line
bind2maps       viins vicmd -- End          vi-end-of-line
bind2maps emacs viins       -- Insert       overwrite-mode
bind2maps             vicmd -- Insert       vi-insert
bind2maps emacs             -- Delete       delete-char
bind2maps       viins vicmd -- Delete       vi-delete-char
bind2maps emacs viins vicmd -- Up           up-line-or-history
bind2maps emacs viins vicmd -- Down         commit-or-down-line-or-history
bind2maps emacs             -- Left         backward-char
bind2maps       viins vicmd -- Left         vi-backward-char
bind2maps emacs             -- Right        forward-char
bind2maps       viins vicmd -- Right        vi-forward-char
# bind2maps menuselect        -- BackTab      reverse-menu-complete

# search history for entry beginning with typed text
bind2maps emacs viins       -- PageUp       history-beginning-search-backward-end
bind2maps emacs viins       -- PageDown     history-beginning-search-forward-end
# <C-Up> and <C-Down> in termite
bind2maps emacs viins       -- -s "\e[1;5A" history-beginning-search-backward-end
bind2maps emacs viins       -- -s "\e[1;5B" history-beginning-search-foward-end

# Bind <C-Left> and <C-Right> for word-wise caret movement
# $TERM == rxvt-unicode-256color
bind2maps emacs viins       -- -s "\e0d"    backward-word
bind2maps emacs viins       -- -s "\e0c"    forward-word
# $TERM == xterm-termite
bind2maps emacs viins       -- -s "\e[1;5D" backward-word
bind2maps emacs viins       -- -s "\e[1;5C" forward-word
# $TERM == linux
bind2maps emacs viins       -- -s "\e[[D"   backward-word
bind2maps emacs viins       -- -s "\e[[C"   forward-word

# $TERM == xterm-termite
bind2maps emacs viins       -- -s "\C-H"    slash-backward-kill-word # backward-delete-word
bind2maps emacs viins       -- -s "\e[3;5~" delete-word # <C-Delete>
bind2maps emacs viins       -- -s "\eOM"    accept-line # <Enter>

# <C-x, s> run current previous or previous line as sudo
bind2maps emacs viins       -- -s "^Xs" sudo-command-line

# mkdir -p <dir> from string under cursor or marked area
bind2maps emacs viins       -- -s '^xM' inplaceMkDirs

# <f5> Insert a timestamp on the command line (yyyy-mm-dd)
bind2maps emacs viins       -- -s "\e[15~" insert-datestamp


unfunction bind2maps
