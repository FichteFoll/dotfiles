# default applications
export TERMINAL=alacritty
export TERM=alacritty
export EDITOR=vim  # "subl -nw"
export PAGER=less

# prepend user scripts
# and append executables from python, cargo and ruby to PATH
export PATH="$HOME/bin:$PATH:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.gem/ruby/2.5.0/bin"

# make systemd aware of our "new" PATH
systemctl --user import-environment PATH

# enable aliasing for java (JDownloader)
# https://wiki.archlinux.org/index.php/Java_Runtime_Environment_fonts#Anti-aliasing
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=gasp'

# start ssh-agent
eval "$(ssh-agent -s)"
if [ -f "/usr/lib/seahorse/ssh-askpass" ] ; then
  export SSH_ASKPASS="/usr/lib/seahorse/ssh-askpass"
elif [ -f "/usr/lib/ssh/ssh-askpass" ] ; then
  export SSH_ASKPASS="/usr/lib/ssh/ssh-askpass"
fi

# start Xorg if there is no session and we're on tty1
if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
    echo "Starting X server"
    exec startx
fi
