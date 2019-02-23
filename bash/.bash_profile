#
# ~/.bash_profile
#

[[ -f ~/.profile ]] && . ~/.profile
# apparently .bashrc is only sourced in non-login (and interactive) shells
[[ -f ~/.bashrc ]] && . ~/.bashrc
