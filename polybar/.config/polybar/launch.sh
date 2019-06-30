#!/usr/bin/env bash

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

# Launch bars
MONITOR=HDMI-A-0 polybar primary &
MONITOR_2=DVI-I-1 polybar secondary &

echo "Bars launched..."
