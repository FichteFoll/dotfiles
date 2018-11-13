# The following lines were added by compinstall

zstyle ':completion:*' completer _complete _ignored _approximate
zstyle ':completion:*' completions 1
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' glob 1
zstyle ':completion:*' group-name ''
zstyle ':completion:*' insert-unambiguous true
zstyle ':completion:*' list-prompt "%SAt %p: Hit TAB for more, or the character to insert%s"
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' 'r:|[._-]=** r:|=**'
zstyle ':completion:*' max-errors 2
zstyle ':completion:*' menu select #=long
zstyle ':completion:*' prompt 'correct %e errors'
zstyle ':completion:*' select-prompt "%SScrolling active: current selection at %p/%l~%s"
zstyle ':completion:*' substitute 1
zstyle :compinstall filename '/home/fichte/.zshrc'

# autoload -Uz compinit
# compinit
# End of lines added by compinstall

# http://zshwiki.org/home/examples/compquickstart
zstyle ':completion:*:corrections'     format $'%{\e[0;31m%}%d (errors: %e)%{\e[0m%}'
zstyle ':completion:*:descriptions'    format $'%{\e[0;31m%}completing %B%d%b%{\e[0m%}'
# zstyle ':completion:*:descriptions' format "- %d -"
# zstyle ':completion:*:corrections' format "- %d - (errors %e})"
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
# highlight current prefix and next characters to press
# http://www.smallbulb.net/2018/797-zsh-completion-with-visual-hints
zstyle -e ':completion:*:default' list-colors 'reply=("${PREFIX:+=(#bi)($PREFIX:t)(?)*==90=01}:${(s.:.)LS_COLORS}")'
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections true
zstyle ':completion:*' verbose yes
zstyle -e ':completion:*:approximate:*' max-errors 'reply=( $(( ($#PREFIX + $#SUFFIX) / 3 )) )'
zstyle ':completion::approximate*:*' prefix-needed false
zstyle ':completion:*:processes'       command 'ps -au$USER'

# complete manual by their section
zstyle ':completion:*:manuals'    separate-sections true
zstyle ':completion:*:manuals.*'  insert-sections   true
zstyle ':completion:*:man:*'      menu yes select

autoload -Uz compinit
compinit

# fish-like auto completions
# requires 'zsh-autosuggestions' package
sources=(/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
         $HOME/zshrc/zsh-autosuggestions/zsh-autosuggestions.zsh)
for src in $sources; do
    [[ -e "$src" ]] && source "$src"
done
unset sources src
# ZSH_AUTOSUGGEST_USE_ASYNC=1
