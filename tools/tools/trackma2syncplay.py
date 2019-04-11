#!/usr/bin/env python3

from functools import partial
import os
import re
from typing import NamedTuple


class LibraryEntry(NamedTuple):
    show: dict
    ep: int
    path: str


def get_library_entries(accountnum=None):
    import trackma.engine
    import trackma.accounts

    if not accountnum:
        manager = trackma.accounts.AccountManager()
        accountnum = manager.accounts['default']

    account = manager.get_account(accountnum)
    engine = trackma.engine.Engine(account=account)
    engine.start()

    # Not necessary but we'll re-scan the library just in case something has changed
    # TODO argument
    engine.scan_library()

    # {showid: {ep: path}}
    library = engine.library()

    for showid, eps in library.items():
        # We need to know meta info on a show,
        # e.g. the last episode watched, watching status and title,
        # so we query the engine for details.
        show = engine.get_show_info(showid)
        for ep, path in eps.items():
            yield LibraryEntry(show, ep, path)


def unwatched_filter(entry):
    last_episode_watched = entry.show['my_progress']
    return entry.ep > last_episode_watched


def watching_filter(entry):
    # https://github.com/z411/trackma/blob/1888bbdcc1db0f81f5446d43d5d4dddc7bbedb85/trackma/lib/libanilist.py#L53
    return entry.show['my_status'] in {'CURRENT', 'REPEATING'}


def string_filter(entry, patterns=(), negative=True):
    titles = [entry.show['title'], *entry.show['aliases']]
    matched = any(re.search(p, title) for p in patterns for title in titles)
    return matched ^ negative


def filter_chain(filters, iterable):
    for filter_ in filters:
        iterable = filter(filter_, iterable)
    return iterable


def to_syncplay(filenames):
    import sys
    sys.path.append('/usr/lib/syncplay')  # TODO make configurable

    # load syncplay config
    from syncplay.ui.ConfigurationGetter import ConfigurationGetter
    config_getter = ConfigurationGetter()
    config_getter._config['noGui'] = True
    config = config_getter.getConfiguration()
    config['name'] += "_trackma"

    # load syncplay client
    from syncplay.client import SyncplayClient  # Imported after config
    from syncplay.ui.consoleUI import ConsoleUI
    # interface = syncplay.ui.getUi(graphical=False)
    from unittest import mock
    interface = mock.MagicMock(ConsoleUI)
    client = SyncplayClient(config["playerClass"], interface, config)
    if not client:
        print("Error opening syncplay")

    def connected():
        client._old_connected()
        print(interface)
        print(interface.method_calls)
        playlist = client.playlist
        print("old playlist", playlist._playlist)
        new_files = [*playlist._playlist, *filenames]
        playlist.changePlaylist(new_files)
        print("new playlist", new_files)
        # TODO terminate

    client._old_connected = client.connected
    client.connected = connected

    def abort():
        pass  # TODO

    from twisted.internet import reactor
    reactor.callLater(5, abort)
    client.start(config['host'], config['port'])
    # TODO prevent player from opening


def main():
    entries = get_library_entries()
    # TODO logging
    blacklist_patterns = [r"Starlight", r"Zombie", r"Shinsekai"]
    filters = [
        watching_filter,
        unwatched_filter,
        # partial(string_filter, patterns=[r"."], negative=False),  # whitelist
        partial(string_filter, patterns=blacklist_patterns, negative=True),  # blacklist
    ]
    filtered_entries = filter_chain(filters, entries)

    paths = [entry.path for entry in filtered_entries]
    for path in paths:
        print(path)

    # TODO may need to extract basenames
    to_syncplay([os.path.basename(path) for path in paths])


if __name__ == '__main__':
    # TODO argparse for trackma account and rescan, syncplay settings, filtering
    main()
