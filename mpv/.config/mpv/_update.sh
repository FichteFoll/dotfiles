#!/usr/bin/env bash

# TODO show diffs

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$DIR/shaders"
wget -N https://github.com/bjin/mpv-prescalers/raw/master/nnedi3-nns16-win8x4.hook
wget -N https://github.com/bjin/mpv-prescalers/raw/master/nnedi3-nns32-win8x4.hook
wget -N https://gist.github.com/igv/a015fc885d5c22e6891820ad89555637/raw/d993a9294725f04812f2759a47438d95eb26f3b5/KrigBilateral.glsl
wget -N https://pastebin.com/raw/yacMe6EZ -O noise_static_luma.hook

cd "$DIR/scripts"
wget -N https://raw.githubusercontent.com/donmaiq/mpv-scripts/master/appendURL.lua
wget -N https://raw.githubusercontent.com/SteveJobzniak/mpv-tools/master/scripts/cycle-video-rotate.lua
wget -N https://raw.githubusercontent.com/jonniek/mpv-playlistmanager/master/playlistmanager.lua
wget -N https://raw.githubusercontent.com/torque/mpv-progressbar/build/progressbar.lua
wget -N https://raw.githubusercontent.com/rossy/mpv-repl/master/repl.lua
wget -N https://raw.githubusercontent.com/occivink/mpv-scripts/master/scripts/seek-to.lua
wget -N https://raw.githubusercontent.com/ElegantMonkey/mpv-webm/master/build/webm.lua
