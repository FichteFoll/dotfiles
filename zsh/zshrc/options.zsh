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
# complete common prefix AND open comp list when hitting tab instead of only the former
unsetopt list_ambiguous

setopt nomatch
unsetopt autocd
