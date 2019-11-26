#!/usr/bin/python3

import argparse
import os
import re
import subprocess
import sys


def get_pointer_info():
    # X=1471
    # Y=925
    # SCREEN=0
    # WINDOW=88080389
    output = subprocess.check_output(["xdotool", "getmouselocation", "--shell"], encoding='ascii')
    mouse = dict(pair.split('=') for pair in output.splitlines())

    # WINDOW=75497474
    # X=1920
    # Y=0
    # WIDTH=2560
    # HEIGHT=27
    # SCREEN=0
    output = subprocess.check_output(["xdotool", "getwindowgeometry", "--shell", mouse['WINDOW']],
                                     encoding='ascii')
    geometry = dict(pair.split('=') for pair in output.splitlines())
    return mouse, geometry


def get_screen_size():
    if (
        (display := os.environ.get('DISPLAY', ":0"))
        and (m := re.search(r":(\d+)(\.\d+)?$", display))
    ):
        screen = m.group(1)
    else:
        screen = "0"
    # Screen 0: minimum 320 x 200, current 4480 x 1440, maximum 16384 x 16384
    output = subprocess.check_output(["xrandr", "-q"], encoding='ascii')
    for line in output.splitlines():
        if line.startswith(f"Screen {screen}:"):
            groups = re.search(r"current (\d+) x (\d+)", line).groups()
            return tuple(map(int, groups))
    else:
        return None


def main():
    parser = argparse.ArgumentParser()
    # TODO argument for window border size?
    parser.add_argument("--width", type=int, default=200)
    parser.add_argument("--height", type=int, default=200)
    parser.add_argument("--bottom", action='store_true', default=False)
    # TODO add 'auto' feature,
    # but cannot figure out how to determine position and resolution
    # of currently displayed output
    # without manually parsing xrandr.
    params, rest = parser.parse_known_args()

    mouse, geometry = get_pointer_info()
    print(f"{mouse=}")
    print(f"{geometry=}")
    screen_size = get_screen_size()
    print(f"{screen_size=}")

    if params.bottom:
        # TODO this logic doesn't make sense
        y = int(geometry['Y']) - params.height
    else:
        y = int(geometry['HEIGHT'])

    width = params.width
    height = params.height
    if screen_size:
        width = min(width, screen_size[0])
        height = min(height, screen_size[1] - y)
    
    x = int(mouse['X']) - width / 2

    print(f"{x=}, {y=}")
    print(f"{params.width=}, {params.height=}")
    print(f"{width=}, {height=}")

    cmd = ["yad",
           f"--width={width}", f"--height={height}",
           f"--posx={x}", f"--posy={y}", "--fixed",
           *rest]
    subprocess.call(cmd, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr)


if __name__ == '__main__':
    main()
