#!/usr/bin/env bash

echo "Stopping running units …"
systemctl --user stop polybar-\*

# Launch bars, based on xrandr output
i=0
inputs=$(xrandr | grep '\bconnected\b')
printf "Starting %d polybar units …\n" $(wc -l <<< $inputs)
while read -r output state rest; do
    ((i = i+1))
    if [[ $rest == *primary* ]]; then
        bar=primary
    else
        bar=secondary
    fi
    systemd-run --user \
         -u "polybar-$bar-$output" \
         -E POLY_MONITOR="$output" \
         polybar $bar
done <<< $inputs

echo "Bars launched"
