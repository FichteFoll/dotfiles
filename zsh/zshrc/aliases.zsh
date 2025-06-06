# random
alias pls='sudo $(fc -ln -1)'
alias ipy='ipython'
alias ci='xsel -ib'
alias co='xsel -ob'
# alias sudo='killall screenkey 2>/dev/null; sudo'
alias lrc='source ~/.zshrc'
alias rm='rm -i'
alias xen='xe -N0'
alias wcl='wc -l'
#alias vim='kak'
alias cat='bat -pp'
alias dragon='dragon-drop'
alias gdiff='git diff --no-index'
alias hx='helix'
alias jest='npx jest -w 50%' # don't use 100% of cores

alias t2s='python ~/tools/trackma2syncplay/t2s'
alias t2si="python ~/tools/trackma2syncplay/trackma2syncplay.py --include"

# atop with a focus on memory usage analysis
# -l: reduzed header size
# -R: collect proportional memory size
# -m: memory view (and order by memory)
# -p: aggregate by process name
# -1: show per second where reasonable
alias atopm='sudo atop -lRmp1'

# Needed when ssh-ing to servers without my terminal's terminfo (alacritty and termite)
alias ssh="TERM=xterm-256color ssh"

# File/dir listing
alias ls='eza --time-style=long-iso'
alias lst='eza --tree --level=3'
alias ols='command ls --color=auto'

# All entries in table mode
alias ll="eza -la"
# All entries
alias lsa='eza -a'
# Only show directories
alias lsd='eza -d *(/)'
# Only show empty directories
alias lsed='eza -d *(/^F)'
# Only show dot-directories
alias lsad='eza -d .*(/)'
# Only show dot-files
alias lsa='eza -a .*(.)'
# Only files with setgid/setuid/sticky flag
alias lss='eza -l *(s,S,t)'
# Only show symlinks
alias lsl='eza -l *(@)'
# Display only executables
alias lsx='eza -l *(*)'
# Display world-{readable,writable,executable} files
alias lsw='eza -ld *(R,W,X.^ND/)'
# Display the ten biggest files
alias lsbig='eza -lr --sort=size | head -n10'

# Shorthands for directory navigation
alias ..='cd ../'
alias ...='cd ../..'
alias ....='cd ../../..'

# cd to directoy and list files
cl() {
    cd $1 && ls -a
}

# Create Directoy and cd to it
mkcd() {
    if (( ARGC != 1 )); then
        printf 'usage: mkcd <new-directory>\n'
        return 1;
    fi
    if [[ ! -d "$1" ]]; then
        command mkdir -p "$1"
    else
        printf '`%s'\'' already exists: cd-ing.\n' "$1"
    fi
    builtin cd "$1"
}

# Create temporary directory and cd to it
mktcd() {
    builtin cd "$(mktemp -d)"
    builtin pwd
}

# Remove current empty directory.
rmcdir () {
    builtin cd ..
    command rmdir $OLDPWD || builtin cd $OLDPWD
}

# OpenSSL cert shorthands
ssl_hashes=( sha512 sha256 sha1 md5 )

for sh in ${ssl_hashes}; do
    eval 'ssl-cert-'${sh}'() {
        emulate -L zsh
        if [[ -z $1 ]] ; then
            printf '\''usage: %s <file>\n'\'' "ssh-cert-'${sh}'"
            return 1
        fi
        openssl x509 -noout -fingerprint -'${sh}' -in $1
    }'
done; unset sh

ssl-cert-fingerprints() {
    emulate -L zsh
    local i
    if [[ -z $1 ]] ; then
        printf 'usage: ssl-cert-fingerprints <file>\n'
        return 1
    fi
    for i in ${ssl_hashes}
        do ssl-cert-$i $1;
    done
}

ssl-cert-info() {
    emulate -L zsh
    if [[ -z $1 ]] ; then
        printf 'usage: ssl-cert-info <file>\n'
        return 1
    fi
    openssl x509 -noout -text -in $1
    ssl-cert-fingerprints $1
}

# insecure ssh and scp
alias insecssh='ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"'
alias insecscp='scp -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null"'

# Find history events by search pattern and list them by date.
whatwhen()  {
    emulate -L zsh
    local usage help ident format_l format_s first_char remain first last
    usage='USAGE: whatwhen [options] <searchstring> <search range>'
    help='Use `whatwhen -h'\'' for further explanations.'
    ident=${(l,${#${:-Usage: }},, ,)}
    format_l="${ident}%s\t\t\t%s\n"
    format_s="${format_l//(\\t)##/\\t}"
    # Make the first char of the word to search for case
    # insensitive; e.g. [aA]
    first_char=[${(L)1[1]}${(U)1[1]}]
    remain=${1[2,-1]}
    # Default search range is `-100'.
    first=${2:-\-100}
    # Optional, just used for `<first> <last>' given.
    last=$3
    case $1 in
        ("")
            printf '%s\n\n' 'ERROR: No search string specified. Aborting.'
            printf '%s\n%s\n\n' ${usage} ${help} && return 1
        ;;
        (-h)
            printf '%s\n\n' ${usage}
            print 'OPTIONS:'
            printf $format_l '-h' 'show help text'
            print '\f'
            print 'SEARCH RANGE:'
            printf $format_l "'0'" 'the whole history,'
            printf $format_l '-<n>' 'offset to the current history number; (default: -100)'
            printf $format_s '<[-]first> [<last>]' 'just searching within a give range'
            printf '\n%s\n' 'EXAMPLES:'
            printf ${format_l/(\\t)/} 'whatwhen grml' '# Range is set to -100 by default.'
            printf $format_l 'whatwhen zsh -250'
            printf $format_l 'whatwhen foo 1 99'
        ;;
        (\?)
            printf '%s\n%s\n\n' ${usage} ${help} && return 1
        ;;
        (*)
            # -l list results on stout rather than invoking $EDITOR.
            # -i Print dates as in YYYY-MM-DD.
            # -m Search for a - quoted - pattern within the history.
            fc -li -m "*${first_char}${remain}*" $first $last
        ;;
    esac
}


# mpv/ytdl
alias mpa="command mpv --profile=audio"
alias mpv="command mpv --profile=terminal"
alias ytdl="yt-dlp"

twitch() {
    local channel=$1
    shift
    mpv $@ -- "https://twitch.tv/$channel"
}

alias nanaone=nanaone1080
alias nanaone720="mpv rtmp://nolive.brb.re/live/nanaone_720p"
alias nanaone1080="mpv rtmp://nolive.brb.re/live/nanaone_1080p"
alias yt_favs="mpa 'https://www.youtube.com/playlist?list=PLbVK3lh2yB7RznbL1IUeA7PYXE9YL11oR'"
alias doujinstyle="mpa https://doujinstyle.com/listen.m3u"

# German TV
alias 3sat="mpv https://www.3sat.de/programm/3sat-livestream-100.html"
alias zdf="mpv https://www.zdf.de/sender/zdf/zdf-live-beitrag-100.html"
alias ard="mpv https://daserste-live.ard-mcdn.de/daserste/live/hls/de/master.m3u8"
alias t24="mpv https://tagesschau.akamaized.net/hls/live/2020115/tagesschau/tagesschau_1/master.m3u8"
alias phoenix="mpv https://zdf-hls-19.akamaized.net/hls/live/2016502/de/high/master.m3u8"

ffmpeg_grab() {
    local size_params
    # double-click to select the hovered window
    size_params=($(slop -f "-video_size %wx%h -i $DISPLAY+%x,%y"))
    if (( $? )); then return; fi
    ffmpeg -f x11grab \
        -framerate 30 \
        "${size_params[@]}" \
        -c:v libx264 \
        -tune film \
        -preset slow \
        -crf 22 \
        -x264opts fast_pskip=0 \
        -aq 4 \
        /home/mhm/screenshots/recordings/$(date +"%Y-%m-%d_%H-%M-%S").mp4
}

beet_mpa () {
    beet list $@ -f'$path' | xargs -d'\n' mpv --profile=audio
}

hologra() {
    yt-dlp --flat-playlist "https://www.youtube.com/channel/UCJFZiqLMntJufDCHc6bQixg/videos" -j \
        | grep Anime \
        | jq -r .url \
        | head -n $1 \
        | tac \
        | tee >(xsel -ib)
}

staco() {
    yt-dlp --flat-playlist "https://www.youtube.com/playlist?list=PLNQov5ZpSSWclbG0Rvs-CDWqybmOKNbhO" -j \
        | jq -r .url \
        | head -n $1 \
        | tac \
        | tee >(xsel -ib)
}

# check for and perform system updates
cu () {
    checkupdates
    echo ''
    aur repo -ld aur | aur vercmp
}

cu2 () {
    # like cu but include updates for VCS packages
    checkupdates
    echo ''

    # https://github.com/AladW/aurutils/issues/299#issuecomment-366807331
    # until a "native" flag is added: https://github.com/AladW/aurutils/pull/283
    local vcs_info
    mktemp | read -r vcs_info
    aur srcver ~/.cache/aurutils/sync/*-git > "$vcs_info"
    aur vercmp -d aur -p "$vcs_info"
    rm "$vcs_info"
}

Syu () {
    # Check for special upgrade steps
    news="$(arch-news)"
    if [[ -n "$news" ]]; then
        echo "$news"
        read -q "?continue? [y/n]" || return
    fi

    # the actual upgrade
    sudo pacman -Syu $@
}

# systemd aliases
alias sc='sudo systemctl'
alias scu='systemctl --user'
alias jc='journalctl'
alias jcu='journalctl --user'
alias nc='netctl'

# java
alias java8='sudo archlinux-java set java-8-openjdk'
alias java11='sudo archlinux-java set java-11-openjdk'
alias java14='sudo archlinux-java set java-14-openjdk'

# wine stuff
alias wine32='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32" wine'
alias winecfg32='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32" winecfg'
alias winetricks32='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32" winetricks'

alias wine_games_env='export WINEARCH=win32; export WINEPREFIX="$HOME/.wine32_games"'
alias wine_games='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32_games" wine'
alias winecfg_games='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32_games" winecfg'
alias winetricks_games='env WINEARCH=win32 WINEPREFIX="$HOME/.wine32_games" winetricks'

alias wine_tmp='env WINEPREFIX="$HOME/.wine_tmp" wine'
alias winecfg_tmp='env WINEPREFIX="$HOME/.wine_tmp" winecfg'
alias winetricks_tmp='env WINEPREFIX="$HOME/.wine_tmp" winetricks'

# docker
alias ds='sudo -g docker DOCKER_HOST=unix:///var/run/docker.sock -s'

function dc() {
    # Wrap `docker compose`.
    # Additionally, always detach when using `up` subcommand.
    if [ "$1" = "up" ]; then
        shift
        docker compose up --detach "$@"
    else
        docker compose "$@"
    fi
}

# python source venv
alias venv="source .venv/bin/activate"

# aurutils
alias aurb="aur build -d custom -c"
alias aurr="python /usr/share/doc/aurutils/examples/sync-rebuild"
alias aurvcd="bash /usr/share/doc/aurutils/examples/vercmp-devel"
alias aursd="bash /usr/share/doc/aurutils/examples/sync-devel"
alias aurs="sudo ~/bin/sync-asroot -d aur"
alias aurs_="aur sync -d aur -c"

# utilities
colorpicker () {
    maim -st 0 | convert - -resize 1x1\! -format '%[pixel:p{0,0}]' info:-
}

flasher() {
    # doesn't work with alacritty
    while true; do
        printf "\\e[?5h"
        sleep 1
        printf "\\e[?5l"
        read -s -k1 -t1 && break
    done;
}

cheat() {
    # https://github.com/chubin/cheat.sh
    # `cheat tool` or `cheat language/term+with+pluses[/1..]` (append number for next result)
    # ?Q to strip comments, ?T to strip syntax hl, …
    curl cht.sh/"$@"
}

how_in() {
  where="$1"; shift
  IFS=+ curl "https://cht\.sh/$where/$*"
}

mkvattachments() {
    infile="$1"; shift
    ffmpeg -i "$infile" -dump_attachment:t "" -i $@
}

wttr() {
    local request="https://wttr.in/${1-$_WTTR}?mQF"
    [ "$COLUMNS" -lt 125 ] && request+='n'
    # ${LANG%_*}
    curl -H "Accept-Language: de,en" --compressed "$request"
}

copympd() {
    local source target
    source=/data/audio/music/"$(mpc -f '%file%' current)"
    if [[ "$source" == "${source%.*}".flac ]]; then
        target="/tmp/$(basename "${source%.*}").ogg"
        echo "converting to .ogg…"
        ffmpeg -v warning -i "$source" -acodec libopus -b:a 128k -vbr on -compression_level 10 -vn "$target"
    else
        target="$source"
    fi
    echo -n "$target" | xsel -b
    xclip-copyfile "$target"
    notify-send "copied: $(basename "$target")"
    # dragon "$target" --and-exit &
}

kreboot() {
    sudo kexec -l /boot/vmlinuz-linux --initrd=/boot/initramfs-linux.img --reuse-cmdline \
        && sudo systemctl kexec
}
