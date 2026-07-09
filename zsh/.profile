# default applications
export TERMINAL=alacritty
# export TERM=alacritty  # set by the terminal
export EDITOR=helix
export PAGER=less

# prepend user scripts (for overrides)
export PATH="$HOME/bin:$PATH"
# append executables from python, cargo and ruby
export PATH="$PATH:$HOME/.local/bin:$HOME/.cargo/bin"

# docker rootless
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock

# Disable gtk scrolling overlays.
# This is supposed to also work via
# `gsettings set org.gnome.desktop.interface overlay-scrolling false`
# but it did not for me.
export GTK_OVERLAY_SCROLLING=0

# Launched via ssh-agent.socket user unit.
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

if [ -f "/usr/lib/seahorse/ssh-askpass" ] ; then
  export SSH_ASKPASS="/usr/lib/seahorse/ssh-askpass"
elif [ -f "/usr/lib/ssh/ssh-askpass" ] ; then
  export SSH_ASKPASS="/usr/lib/ssh/ssh-askpass"
fi

# load .profile-private
[ -f ~/.profile-private ] && source ~/.profile-private

# Import environment variables into systemd (e.g. for systemd-run)
systemctl --user import-environment

# start Xorg if there is no session and we're on tty1
if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
    #echo "Starting X server"
    #exec startx
fi
# if [ "$(tty)" = "/dev/tty1" ]; then
    # echo "Starting Sway"
#     exec sway
# fi
