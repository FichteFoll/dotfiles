curl -L https://github.com/mpv-player/mpv/raw/master/etc/input.conf -o default-input_.conf
perl -pe 's/^#(?!#|\s)//g' < default-input_.conf > default-input.conf
rm default-input_.conf
