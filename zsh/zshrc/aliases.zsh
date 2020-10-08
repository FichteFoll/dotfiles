# random
alias pls='sudo $(fc -ln -1)'
alias ipy='ipython'
# alias sudo='killall screenkey 2>/dev/null; sudo'
alias lrc='source ~/.zshrc'
alias rm='rm -i'
alias xen='xe -N0'
alias wcl='wc -l'
alias vim='kak'
alias cat='bat -pp'

# Needed when ssh-ing to servers without my terminal's terminfo (alacritty and termite)
alias ssh="TERM=xterm-256color ssh"

# File/dir listing
alias ls='exa --time-style=long-iso'
alias lst='exa --tree --level=3'
alias exat='exa --tree --level=3'
alias ols='command ls --color=auto'

# All entries in table mode
alias ll="exa -la"
# All entries
alias lsa='exa -a'
# Only show dot-files
alias lsa='exa -a .*(.)'
# Only show dot-directories
alias lsad='exa -d .*(/)'
# Only files with setgid/setuid/sticky flag
alias lss='exa -l *(s,S,t)'
# Only show symlinks
alias lsl='exa -l *(@)'
# Display only executables
alias lsx='exa -l *(*)'
# Display world-{readable,writable,executable} files
alias lsw='exa -ld *(R,W,X.^ND/)'
# Display the ten biggest files
alias lsbig='exa -lr --sort=size | head -n10'
# Only show directories
alias lsd='exa -d *(/)'
# Only show empty directories
alias lsed='exa -d *(/^F)'


# Shorthands for directory navigation
alias ..='cd ../'

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
alias ytdl="youtube-dl"

twitch() {
    local channel=$1
    shift
    mpv $@ -- "https://twitch.tv/$channel"
}

alias nanaone="mpv https://live1.brb.re:8082/html5/hls/nanaone.m3u8" # 30s delay
alias nanaone2="mpv rtmp://live1.brb.re/live/nanaone_720p"
alias nanaone3="mpv rtmp://live2.brb.re/live/nanaone"
alias yt_favs="mpa 'https://www.youtube.com/playlist?list=PLbVK3lh2yB7RznbL1IUeA7PYXE9YL11oR'"
alias doujinstyle="mpa https://doujinstyle.com/listen.m3u"

beet_mpa () {
    beet list $@ -f'$path' | xargs -d'\n' mpv --profile=audio
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
alias ds='sudo -g docker -s'
function dc() {
    # detach by default
    if [ "$1" = "up" -a "$#" = 1 ]; then
        docker-compose up -d
        # docker-compose logs -f
    else
        docker-compose "$@"
    fi
}


# python source venv
alias venv="source .venv/bin/activate"

# run locally installed npm scripts
function npm-do {
    (PATH=$(npm bin):$PATH; eval $@;)
}

alias aurb="aur build -d custom"


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
