#!/usr/bin/env python3
"""Replace weather glyphs from wttr.in with fontawesome glyphs."""

import sys
import requests

BASE_URI = "https://wttr.in/"

# https://github.com/chubin/wttr.in/blob/master/lib/constants.py
# https://fontawesome.com/icons?d=gallery&q=weather
GLYPH_MAP = {
    "✨": ("", "#E9E314"),   # Unknown
    "☀️": ("", "#E9E314"),  # Sunny
    "☁️": ("", "#555"),  # Cloudy
    "🌫": ("", None),   # Fog
    "🌦": ("", "#1773DA"),   # LightRain
    "🌧": ("", "#1773DA"),   # HeavyRain
    "🌩": ("", "#CE3C24"),   # ThunderyHeavyRain
    "⛈": ("", "#CE3C24"),   # ThunderyShowers
    "🌨": ("", "#BDC7D3"),   # LightSnow
    "🌨": ("", "#BDC7D3"),   # LightSnowShowers
    "❄️": ("", "#CE3C24"),  # HeavySnow
    "❄️": ("", "#CE3C24"),  # HeavySnowShowers
    "⛅️": ("", "#E5C764"),  # PartlyCloudy
}


def main():
    uri_path = sys.argv[1] if len(sys.argv) > 1 else '?format=%c+%t'
    resp = requests.get(BASE_URI + uri_path)
    if resp.status_code != 200:
        return ""
    text = resp.text.strip()

    for glyph, (repl, color) in GLYPH_MAP.items():
        if color:
            text = text.replace(glyph, f"%{{F{color}}}{repl}%{{F-}}")
        else:
            text = text.replace(glyph, repl)

    prefix, _, rest = text.partition(" ")
    return text


if __name__ == '__main__':
    print(main())
