# default applications
export TERMINAL=alacritty
export TERM=alacritty
export EDITOR="subl -nw"
export PAGER=less

# add user scripts and cargo binaries to PATH
export PATH="$HOME/bin:$HOME/.cargo/bin:$PATH"

# make systemd aware of our "new" PATH
systemctl --user import-environment PATH

# enable aliasing for java
# https://wiki.archlinux.org/index.php/Java_Runtime_Environment_fonts#Anti-aliasing
export _JAVA_OPTIONS='-Dawt.useSystemAAFontSettings=gasp'

# start ssh-agent
eval $(ssh-agent -s)

# start Xorg if there is no session and we're on tty1
if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
    echo "Starting X server"
    exec startx
fi
