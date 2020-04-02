#!/usr/bin/env python3
"""Replace weather glyphs from wttr.in with fontawesome glyphs."""

import sys
from urllib.request import urlopen

BASE_URI = "https://wttr.in/"

# https://github.com/chubin/wttr.in/blob/master/lib/constants.py
GLYPH_MAP = {
    # https://erikflowers.github.io/weather-icons/
    # "✨": ("", "#E9E314"),   # Unknown
    "☀️": ("%{T5}\uf00d%{T-}", "#E9E314"),  # Sunny
    "☁️": ("%{T5}\uf013%{T-}", "#555"),  # Cloudy
    "🌫": ("%{T5}\uf014%{T-}", None),   # Fog
    "🌦": ("%{T5}\uf0b2%{T-}", "#1773DA"),   # LightRain
    "🌧": ("%{T5}\uf019%{T-}", "#1773DA"),   # HeavyRain
    "🌩": ("%{T5}\uf01e%{T-}", "#CE3C24"),   # ThunderyHeavyRain
    "⛈": ("%{T5}\uf01d%{T-}", "#CE3C24"),   # ThunderyShowers
    "🌨": ("%{T5}\uf064%{T-}", "#BDC7D3"),   # LightSnow(Showers)
    "❄️": ("%{T5}\uf076%{T-}", "#FFF"),       # HeavySnow
    "❄️": ("%{T5}\uf076%{T-}", "#FFF"),       # HeavySnowShowers
    "⛅️": ("%{T5}\uf002%{T-}", "#E5C764"),   # PartlyCloudy
    #
    # https://fontawesome.com/icons?d=gallery&q=weather
    # "✨": ("", "#E9E314"),   # Unknown <= not displayed
    # "☀️": ("", "#E9E314"),  # Sunny
    # "☁️": ("", "#555"),  # Cloudy
    # "🌫": ("", None),   # Fog
    # "🌦": ("", "#1773DA"),   # LightRain # "" is pro only
    # "🌧": ("", "#1773DA"),   # HeavyRain
    # "🌩": ("", "#CE3C24"),   # ThunderyHeavyRain <= not displayed
    # "⛈": ("", "#CE3C24"),   # ThunderyShowers <= not displayed
    # "🌨": ("", "#BDC7D3"),   # LightSnow <= not displayed
    # "🌨": ("", "#BDC7D3"),   # LightSnowShowers <= not displayed
    # "❄️": ("", "#CE3C24"),  # HeavySnow <= not displayed
    # "❄️": ("", "#CE3C24"),  # HeavySnowShowers <= not displayed
    # "⛅️": ("", "#E5C764"),  # PartlyCloudy
    # wttr outputs PartlyCloudy for "Light Rain, Rain Shower"
}

# Color codes for temperature:
# https://github.com/schachmat/wego/blob/994e4f141759a1070d7b0c8fbe5fad2cc7ee7d45/frontends/ascii-art-table.go#L51


def main():
    uri_path = sys.argv[1] if len(sys.argv) > 1 else '?format=%c+%t'
    try:
        with urlopen(BASE_URI + uri_path) as f:
            text = f.read().decode()
    except Exception as e:
        return e.__class__.__name__

    for glyph, (repl, color) in GLYPH_MAP.items():
        if color:
            text = text.replace(glyph, f"%{{F{color}}}{repl}%{{F-}}")
        else:
            text = text.replace(glyph, repl)

    # text += " |" + "|".join(x[0] for x in GLYPH_MAP.values())
    return text


if __name__ == '__main__':
    print(main())
