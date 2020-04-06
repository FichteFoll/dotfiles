#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

# Launch bars, based on xrandr output
xrandr | grep '\bconnected\b' | \
    while read -r output state rest; do
        if [[ $rest == *primary* ]]; then
            bar=primary
        else
            bar=secondary
        fi
        MONITOR=$output polybar $bar &
    done

echo "Bars launched..."
