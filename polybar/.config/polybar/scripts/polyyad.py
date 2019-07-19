#!/usr/bin/python3

import argparse
import subprocess
import sys


def get_pointer_info():
    # X=1471
    # Y=925
    # SCREEN=0
    # WINDOW=88080389
    output = subprocess.check_output(["xdotool", "getmouselocation", "--shell"], encoding='ascii')
    mouse = dict(pair.split('=') for pair in output.splitlines())
    print("mouse", mouse)

    # WINDOW=75497474
    # X=1920
    # Y=0
    # WIDTH=2560
    # HEIGHT=27
    # SCREEN=0
    output = subprocess.check_output(["xdotool", "getwindowgeometry", "--shell", mouse['WINDOW']],
                                     encoding='ascii')
    geometry = dict(pair.split('=') for pair in output.splitlines())
    print("geometry", geometry)
    return mouse, geometry


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

    x = int(mouse['X']) - params.width / 2
    if params.bottom:
        y = int(geometry['Y']) - params.height
    else:
        y = int(geometry['HEIGHT'])

    cmd = ["yad",
           f"--width={params.width}", f"--height={params.height}",
           f"--posx={x}", f"--posy={y}", "--fixed",
           *rest]
    subprocess.call(cmd, stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr)


if __name__ == '__main__':
    main()
