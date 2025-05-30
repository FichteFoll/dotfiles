#!/usr/bin/env python3

import argparse
from collections import defaultdict
from configparser import ConfigParser
from dataclasses import dataclass
from functools import partial
import itertools
import logging
import json
import os
import random
import re
import sys
import socket
from typing import Any, NamedTuple
from pathlib import Path


SYNCPLAY_CONFIG_PATH = Path("~/.syncplay").expanduser()
DEFAULT_SERVER = "syncplay.pl:8999"
DEFAULT_DIVIDER = "-" * 50
DIVIDER_REGEX = re.compile(r"^-{10}.*$")

logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Find unwatched episodes through trackma and add them to a syncplay playlist. "
    )
    parser.add_argument("-v", "--verbose", action='store_true', default=False,
                        help="Increase verbosity.")
    parser.add_argument("--accountnum",
                        help=("For overriding the trackma account number to use."
                              " You can look this up in trackma's account switcher."
                              " Will use your default otherwise."))
    parser.add_argument("--force-sync", action='store_true', default=False,
                        help="Resync trackma cache with remote.")
    parser.add_argument("--force-rescan", action='store_true', default=False,
                        help="Rescan local trackma library.")
    parser.add_argument("-f", "--force-all", action='store_true', default=False,
                        help="Force all refreshes.")
    parser.add_argument("--include", type=str, action='append',
                        help="Regular expression for titles to include. Repeatable.")
    parser.add_argument("--exclude", type=str, action='append',
                        help="Regular expression for titles to exclude. Repeatable.")
    parser.add_argument("--server", type=str,
                        help="Syncplay server with port. Overrides configuration.")
    parser.add_argument("--room", type=str,
                        help="Syncplay room. Overrides configuration.")
    parser.add_argument("--name", type=str,
                        help="Syncplay name. Overrides configuration.")
    parser.add_argument("-c", "--clear", action='store_true', default=False,
                        help="Clear the playlist before appending.")
    parser.add_argument("--dry-run", action='store_true', default=False,
                        help="Just print out the names without adding them to syncplay.")
    parser.add_argument("-r", "--randomize", action='store_true', default=False,
                        help="Randomize the playlist (without violating episode order).")
    parser.add_argument("-e", "--episodes", type=EpisodeRange, default=EpisodeRange(),
                        help=("Query for episodes to be selected."
                              " Comma-separate and supports open ranges, e.g. '1,4-6,10-'."))
    parser.add_argument("-b", "--batch", type=int, default=0,
                        help="Number of episodes to select per show in random mode (0 means all).")
    parser.add_argument("--min-score", type=float, default=None,
                        help="Minimum score for show.")
    parser.add_argument("--max-score", type=float, default=None,
                        help="Maximum score for show.")
    parser.add_argument("-q", "--queue-next", action='store_true', default=False,
                        help="Insert the matched episodes directly before the divider.")
    parser.add_argument("-l", "--limit", type=int, default=None,
                        help="Limit to n results per show.")
    parser.add_argument("-L", "--global-limit", type=int, default=None,
                        help="Limit to n results total.")
    parser.add_argument("--min-progress", type=int, default=None,
                        help="Only include shows with a progress of at least n.")

    params, syncplay_args = parser.parse_known_args()
    params.syncplay_args = syncplay_args
    if params.force_all:
        params.force_sync = params.force_rescan = True
    params.include = params.include or [r"^"]  # match everything
    params.exclude = params.exclude or []

    return params


def main(params):
    entries = get_library_entries(params)
    filters = [
        # (filter, reason)
        (watching_filter, "not watching"),
        (unwatched_filter, "watched"),
        (partial(string_filter, patterns=params.include, negative=False), "not on whitelist"),
        (partial(string_filter, patterns=params.exclude, negative=True), "blacklisted"),
        (partial(episode_filter, ep_range=params.episodes), "not in episode list"),
        (partial(min_score_filter, min_score=params.min_score), "below minimum score"),
        (partial(max_score_filter, max_score=params.max_score), "above maximum score"),
        (partial(min_progress_filter, min_progress=params.min_progress), "below minimum score"),
    ]
    filtered_entries = list(filter_chain(filters, entries))
    sorted_entries = sorted(filtered_entries, key=lambda entry: (entry.show['title'], entry.ep))
    for entry in sorted_entries:
        logger.info("collected: %s - %02d", entry.show['title'], entry.ep)

    entries_by_show = defaultdict(list)
    for entry in sorted_entries:
        entries_by_show[entry.show['id']].append(entry)

    if params.limit:
        for entries in entries_by_show.values():
            entries[params.limit:] = []

    if params.randomize:
        final_entries = randomize(entries_by_show, params.batch)
    else:
        final_entries = list(itertools.chain(*entries_by_show.values()))

    filenames = [os.path.basename(entry.path) for entry in final_entries]
    if params.dry_run:
        for filename in filenames:
            print(filename)
    else:
        return to_syncplay(params, filenames)


def _int_or_none(s: str) -> int | None:
    return int(s) if s else None


@dataclass
class EpisodeRange():

    slices: list[slice]

    def __init__(self, string: str = ""):
        self.slices = [self._parse_slice(term) for term in string.split(",")]

    def __contains__(self, num: Any) -> bool:
        if not isinstance(num, int):
            return False
        elif not self.slices:
            return True

        return any(
            not s.start or num >= s.start
            and not s.stop or num <= s.stop
            for s in self.slices
        )

    @staticmethod
    def _parse_slice(term: str) -> slice:
        start_s, sep, stop_s = term.partition("-")
        start, stop = _int_or_none(start_s), _int_or_none(stop_s)
        if not sep:
            return slice(start, start)
        else:
            return slice(start, stop)


class LibraryEntry(NamedTuple):
    show: dict
    ep: int
    path: str


def get_library_entries(params):
    import trackma.engine
    import trackma.accounts

    accountnum = params.accountnum
    if not accountnum:
        manager = trackma.accounts.AccountManager()
        accountnum = manager.accounts['default']

    account = manager.get_account(accountnum)
    engine = trackma.engine.Engine(account=account)
    engine.config['tracker_enabled'] = False  # don't need this
    engine.config['library_autoscan'] = False  # prevent double scanning
    if params.force_sync:
        engine.config['autoretrieve'] = 'always'
    engine.start()

    # Not necessary but we'll re-scan the library just in case something has changed
    engine.scan_library(rescan=params.force_rescan)

    # {showid: {ep: path}}
    library = engine.library()

    for showid, eps in library.items():
        # We need to know meta info on a show,
        # e.g. the last episode watched, watching status and title,
        # so we query the engine for details.
        try:
            show = engine.get_show_info(showid)
        except trackma.utils.EngineError as e:
            logger.error("Couldn't retrieve info for %d: %s", showid, e)
        for ep, path in eps.items():
            yield LibraryEntry(show, ep, path)

    engine.unload()


def episode_filter(entry: LibraryEntry, ep_range: EpisodeRange) -> bool:
    return entry.ep in ep_range


def min_score_filter(entry: LibraryEntry, min_score: float) -> bool:
    return not min_score or entry.show['my_score'] >= min_score


def max_score_filter(entry: LibraryEntry, max_score: float) -> bool:
    return not max_score or entry.show['my_score'] <= max_score


def min_progress_filter(entry: LibraryEntry, min_progress: int) -> bool:
    return not min_progress or entry.show['my_progress'] >= min_progress


def unwatched_filter(entry):
    last_episode_watched = entry.show['my_progress']
    return entry.ep > last_episode_watched


def watching_filter(entry):
    # https://github.com/z411/trackma/blob/1888bbdcc1db0f81f5446d43d5d4dddc7bbedb85/trackma/lib/libanilist.py#L53
    return entry.show['my_status'] in {'CURRENT', 'REPEATING'}


def string_filter(entry, patterns=(), negative=True):
    titles = [entry.show['title'], *entry.show['aliases']]
    matched = any(re.search(p, title, re.IGNORECASE) for p in patterns for title in titles)
    return matched ^ negative


def filter_with_logging(func, iterable, reason=None):
    for item in iterable:
        if func(item):
            yield item
        else:
            logger.debug("filtered: %s - %02d [reason: %s]", item.show['title'], item.ep, reason)


def filter_chain(filters, iterable):
    for filter_, reason in filters:
        iterable = filter_with_logging(filter_, iterable, reason=reason)
    return iterable


def randomize(entries_by_show: dict[int, list[LibraryEntry]], batch: int) -> list[LibraryEntry]:
    randomized_entries: list[LibraryEntry] = []
    while entries_by_show:
        show_id = random.choice(list(entries_by_show.keys()))
        if not batch:
            randomized_entries.extend(entries_by_show.pop(show_id))
            continue

        for _ in range(batch):
            entry = entries_by_show[show_id].pop(0)
            randomized_entries.append(entry)
            if not entries_by_show[show_id]:
                del entries_by_show[show_id]
                break

    return randomized_entries


def to_syncplay(params, filenames):
    server = params.server
    room = params.room
    name = params.name

    parser = ConfigParser(strict=False)
    if SYNCPLAY_CONFIG_PATH.exists():
        with SYNCPLAY_CONFIG_PATH.open(encoding='utf_8_sig') as fp:
            parser.read_file(fp)
        host = parser.get('server_data', 'host')
        port = parser.get('server_data', 'port')
        server = server or f"{host}:{port}" if host and port else None or DEFAULT_SERVER
        room = room or parser.get('client_settings', 'room')
        name = name or (parser.get('client_settings', 'name', fallback="") + "_trackma")

    if not server or not room or not name:
        logger.error(f"Syncplay configuration incomplete; {server=}, {room=}, {name=}")
        return 1

    if params.global_limit and len(filenames) > params.global_limit:
        logger.info('Truncating %d filenames to %d', len(filenames), params.global_limit)
        filenames = filenames[:params.global_limit]

    return put_syncplay(server, room, name, filenames, params)


def put_syncplay(server, room, name, filenames, params):
    logger.info("Appending %d filenames to syncplay; server=%s, room=%s, name=%s",
                len(filenames), server, room, name)

    class JsonProtocolConnection:
        def __init__(self, server):
            host, port = server.split(":")
            port = int(port)
            self.recvbuf = b""
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.sock.connect((host, port))

        def send(self, obj):
            obj = json.dumps(obj).encode("utf-8") + b"\r\n"
            self.sock.sendall(obj)

        def read_msg(self):
            if b"\n" not in self.recvbuf:
                return
            msg, self.recvbuf = self.recvbuf.split(b"\n", maxsplit=1)
            return json.loads(msg)

        def recv(self):
            o = self.read_msg()
            if o:
                return o
            self.recvbuf += self.sock.recv(1024)
            return self.read_msg()

        def __del__(self):
            self.sock.close()

    con = JsonProtocolConnection(server)
    con.send({"Hello": {"username": name, "room": {"name": room}, "version": "1.6.7"}})
    playlist, hello = None, False
    while playlist is None or not hello:
        if (msg := con.recv()) is None:
            continue

        logger.debug("received syncplay message: %s", msg)
        if "Hello" in msg:
            hello = True
        if "Set" in msg:
            playlist = msg['Set'].get('playlistChange', {}).get('files', playlist)

    new_playlist = build_new_playlist(playlist, filenames, params)

    con.send({'Set': {'playlistChange': {'user': name, 'files': new_playlist}}})
    logger.debug("playlistChange event sent")
    del con


def build_new_playlist(playlist: list[str], new_files: list[str], params) -> list[str]:
    new_playlist = [] if params.clear else playlist[:]
    div_index = 0
    for div_index, item in enumerate(playlist):
        if DIVIDER_REGEX.match(item):
            break
    else:
        new_playlist.append(DEFAULT_DIVIDER)
        div_index += 1

    if params.queue_next:
        logger.info("Inserting files at position %d of %d", div_index, len(playlist))
        new_playlist[div_index:div_index] = new_files
    else:
        new_playlist.extend(new_files)

    return new_playlist


if __name__ == '__main__':
    params = parse_args()
    log_level = logging.DEBUG if params.verbose else logging.INFO
    logging.basicConfig(level=log_level, format="%(message)s")
    logger.debug("params: %r", params)
    try:
        sys.exit(main(params))
    except KeyboardInterrupt:
        sys.exit(1)
