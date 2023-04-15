# general prompt docs
#   https://wiki.archlinux.org/index.php/Zsh#Prompts
#   http://zsh.sourceforge.net/Doc/Release/Prompt-Expansion.html
#   man zshmisc ; section: SIMPLE PROMPT ESCAPES f.
#
# vcs_info stuff
#   http://arjanvandergaag.nl/blog/customize-zsh-prompt-with-vcs-info.html
#   http://zsh.sourceforge.net/Doc/Release/User-Contributions.html#Version-Control-Information
#
# example configs
#   https://github.com/nojhan/liquidprompt/blob/9c80396021a8106bfaeade9a1ea51b85152e951d/liquidprompt
#   PROMPT="%F{11}%n%F{9}@%F{14}%m %F{13}%c %(?/%F{10}/%F{red})Σ%f "
#   https://github.com/Rouji/dotfiles/blob/master/.zsh/powerline-prompt.zsh
#
# COLOR MAP
#           black red green yellow blue magenta cyan white
#   normal:     0   1     2      3    4       5    6     7
#   bright:     8   9    10     11   12      13   14    15

# perform variable substitution in prompt
setopt prompt_subst
# hide rprompt after accepting a command (for better copy-pasing)
setopt transient_rprompt

autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git svn hg
zstyle ':vcs_info:*' check-for-changes true

# "(vcs:reponame@branch)" "[action]"
zstyle ':vcs_info:*' actionformats "%m(%u%c%s%%f%%b:%F{14}%r%F{9}@%F{10}%b%f)" " %F{3}[%F{1}%a%F{3}]%f"
zstyle ':vcs_info:*' formats       "%m(%u%c%s%%f%%b:%F{14}%r%F{9}@%F{10}%b%f)\${the_groups_:+ (%F{6\}\${the_groups_}%f)}"
zstyle ':vcs_info:*' branchformat  "%b%F{1}:%F{3}%r"
# fallback: "[user(special groups)@host]"
zstyle ':vcs_info:*' nvcsformats   "[%(!/%F{1}/%F{14})%n%f\${the_groups_:+(%F{6\}\${the_groups_}%f)}@%F{4}%m%f]"

# change color of "vcs" part if (un-)staged
zstyle ':vcs_info:*' unstagedstr   "%B%F{11}"
zstyle ':vcs_info:*' stagedstr     "%B%F{10}"

# since I can't decide on a symbol, pick one at random
symbol_candidates_=(▚ ▞ Σ ∀ ∃ Δ ∇ Λ λ $ \> ¬ ↻ ♦ ж Ξ ▶)
# more, but look bad-ish with my font: ε ⛼ ϟ ᐅ
# even more: https://unicode-table.com

# disable Python's standard virtualenv prompt modifications
export VIRTUAL_ENV_DISABLE_PROMPT=1

virtualenv_prompt_info_() {
    if [ -n "$VIRTUAL_ENV" ]; then
        if [ -f "$VIRTUAL_ENV/__name__" ]; then
            local name=`cat $VIRTUAL_ENV/__name__`
        elif [ `basename $VIRTUAL_ENV` = "__" ]; then
            local name=$(basename $(dirname $VIRTUAL_ENV))
        else
            local name=$(basename $VIRTUAL_ENV)
        fi
        echo -n " (%F{3}$name%f)"
    fi
}

# Show a list of special groups if the current user is part of them.
# Useful for groups that are explicitly requested e.g. using `sudo -g docker -s`.
special_groups_=(docker)

groups_format_() {
    # cannot use `%(${}gid}g..)`` check because `g` checks only for the effective group.
    # instead, we fetch the groups in `precmd`
    local all_groups
    all_groups=($(groups))

    # print the intersection of the two arrays
    echo -n ${all_groups:*special_groups_}
}

precmd() {
    vcs_info
    the_symbol_="$symbol_candidates_[$((RANDOM % $#symbol_candidates_ + 1))]"
    the_groups_=$(groups_format_)

    # title bar: "user@host | cwd"
    print -Pn "\e]2;%n@%M | %~\a"
}

prompt_() {
    # return code, iff non-zero, and a line break
    echo -n "%(?// %B%F{9}?=%f%K{9}%?%k%f%b)\n"
    # name in red iff privileged
    echo -n "%(!/%F{1}%n%f /)"
    # cwd; show most of path if terminal wide enough
    echo -n "%F{13}%-100(l.%(6~#%-3~/…/%2~#%~).%c)%f"
    # current virtualenv (Python)
    echo -n "\$(virtualenv_prompt_info_)"
    # VCS action, if any; other VCS info => RPROMPT
    echo -n "\${vcs_info_msg_1_}"
    # prompt symbol
    echo -n " \${the_symbol_} "
}

rprompt_() {
    # VCS stuff or fallback (expanding recusively for the groups)
    echo -n "\${(e)vcs_info_msg_0_}"
    # number of background jobs
    echo -n "%(1j/ [%j bg]/)"
    # shell level
    echo -n "%(3L/ [lvl $((SHLVL - 1))]/)"
}

PROMPT=$(prompt_)
RPROMPT=$(rprompt_)
unset -f prompt_ rprompt_

# secondary prompt, printed when the shell needs more information to complete a command.
PS2='\`%_> '
# selection prompt used within a select loop.
PS3='?# '
# the execution trace prompt (setopt xtrace). default: '+%N:%i>'
PS4='+%N:%i:%_> '
