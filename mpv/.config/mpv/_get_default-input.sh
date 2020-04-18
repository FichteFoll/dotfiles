#!/usr/bin/env bash

perl -pe 's/^#(?!#|\s)//g' < /usr/share/doc/mpv/input.conf > default-input.conf
