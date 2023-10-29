#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$DIR/scripts"
cd "$DIR/shaders"
wget -N https://gist.githubusercontent.com/igv/a015fc885d5c22e6891820ad89555637/raw/KrigBilateral.glsl
wget -N https://pastebin.com/raw/yacMe6EZ -O noise_static_luma.hook

mkdir -p "$DIR/scripts"
cd "$DIR/scripts"
# wget -N https://gist.githubusercontent.com/CyberShadow/2f71a97fb85ed42146f6d9f522bc34ef/raw/autosave.lua
wget -N https://github.com/ekisu/mpv-webm/releases/download/latest/webm.lua
wget -N https://raw.githubusercontent.com/4e6/mpv-reload/master/reload.lua
wget -N https://raw.githubusercontent.com/jgreco/mpv-youtube-quality/master/youtube-quality.lua
wget -N https://raw.githubusercontent.com/jonniek/mpv-playlistmanager/master/playlistmanager.lua
wget -N https://raw.githubusercontent.com/jonniek/mpv-scripts/master/appendURL.lua
wget -N https://raw.githubusercontent.com/mpv-player/mpv/master/TOOLS/lua/autocrop.lua
wget -N https://raw.githubusercontent.com/occivink/mpv-scripts/master/scripts/seek-to.lua
wget -N https://raw.githubusercontent.com/po5/memo/master/memo.lua
wget -N https://raw.githubusercontent.com/po5/thumbfast/master/thumbfast.lua
wget -N https://raw.githubusercontent.com/VideoPlayerCode/mpv-tools/master/scripts/cycle-video-rotate.lua
wget -N https://raw.githubusercontent.com/christoph-heinrich/mpv-quality-menu/master/quality-menu.lua
wget -N https://raw.githubusercontent.com/christoph-heinrich/mpv-subtitle-lines/master/subtitle-lines.lua

wget -N https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock.lua
mkdir -p sponsorblock_shared
cd sponsorblock_shared
wget -N https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock_shared/main.lua
wget -N https://raw.githubusercontent.com/po5/mpv_sponsorblock/master/sponsorblock_shared/sponsorblock.py

# will probably need to be updated once 0.5.0 is released
cd "$DIR"
rm -rf fonts/uosc_* scripts/uosc*
wget -N https://github.com/tomasklaen/uosc/releases/latest/download/uosc.zip
unzip -o uosc.zip
rm -v uosc.zip
