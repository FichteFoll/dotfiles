#!/usr/bin/env python

"""Extract playtime from lutris and archive it daily.

Writes data into multiple CSV files, one per game,
for later analysis.
The date written is the one of the day of execution of the script.
When using a systemd timer to schedule it
when the machine is first started for the day,
this will then *generally* record the playtime
of the day before (when creating a difference).
More precisely, it will be the day
of the previously recorded entry
in case there is a gap.
"""

import sqlite3
from typing import NamedTuple
import time
import csv
from pathlib import Path

DB_PATH = Path("~/.local/share/lutris/pga.db").expanduser()
DATA_PATH = Path(__file__).parent / "data"


class GameInfo(NamedTuple):
    id: int
    name: str
    playtime: int


def main():
    rows = load()
    dump(rows)


def load() -> list[GameInfo]:
    with sqlite3.connect(DB_PATH) as sql:
        rows = sql.execute("SELECT id, name, playtime FROM games WHERE playtime > 0").fetchall()
    return [GameInfo(*row) for row in rows]


def dump(rows: list[GameInfo]) -> None:
    today = time.strftime("%Y-%m-%d")
    print(f"Saving data for {today}")
    DATA_PATH.mkdir(parents=True, exist_ok=True)
    for row in rows:
        dump_row(today, row)
    print(f"Saved data for {len(rows)} games")


def dump_row(date: str, row: GameInfo) -> None:
    out_path = None
    write_header = False
    for path in DATA_PATH.iterdir():
        if path.name.startswith(f"{row.id}_"):
            out_path = path
            break
    else:
        out_path = DATA_PATH / f"{row.id}_{row.name}.csv"
        write_header = True
        print(f"Creating new file: {out_path.name}")

    playtime = row.playtime if row.playtime is not None else 0.0
    with out_path.open('a') as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(["date", "playtime"])
        writer.writerow([date, playtime])
        print(f"{row.name}: {playtime}")


if __name__ == '__main__':
    main()
