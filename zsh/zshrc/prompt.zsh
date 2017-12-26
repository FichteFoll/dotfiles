# https://wiki.archlinux.org/index.php/Zsh#Prompts
# http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html
# https://github.com/nojhan/liquidprompt/blob/9c80396021a8106bfaeade9a1ea51b85152e951d/liquidprompt#L535
# https://gist.github.com/Tehnix/382d630a1aceac8a56ff8d88fdd378c6#file--zshrc

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
