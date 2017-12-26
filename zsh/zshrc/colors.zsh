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
