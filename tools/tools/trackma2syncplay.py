#!/usr/bin/env python3

import argparse
from functools import partial
import logging
import os
import re
import sys
from typing import NamedTuple


logger = logging.getLogger(__name__)


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
        engine.config['autoretrieve'] == 'always'
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


def to_syncplay(params, filenames):
    # modify environment to make syncplay pick up the remaining args
    sys.argv = ["syncplay", *params.syncplay_args]
    sys.path.append(params.syncplay_path)

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
        logger.error("Error opening syncplay, somewhere…")

    _old_connected = client.connected
    done = False

    # override the client's `connected` method
    def connected():
        nonlocal done
        _old_connected()
        logger.debug("interface mock calls: %s", interface.method_calls)
        playlist = client.playlist
        logger.debug("old playlist: %s", playlist._playlist)
        # We could dedupe here, but it doesn't matter.
        new_files = [*playlist._playlist, *filenames]
        playlist.changePlaylist(new_files)
        logger.debug("new playlist: %s", new_files)
        done = True
        # TODO terminate

    # add a timeout handler in case connection fails
    def abort():
        if done:
            return
        logger.error("Syncplay timeout!")
        # TODO terminate

    client.connected = connected
    from twisted.internet import reactor
    reactor.callLater(5, abort)

    # TODO prevent player from opening
    client.start(config['host'], config['port'])


def main(params):
    # blacklist_patterns = [r"Starlight|Zombie|Shinsekai"]

    entries = get_library_entries(params)
    filters = [
        # (filter, reason)
        (watching_filter, "not watching"),
        (unwatched_filter, "watched"),
        (partial(string_filter, patterns=params.include or [r"^"], negative=False), "not on whitelist"),
        (partial(string_filter, patterns=params.exclude or [], negative=True), "blacklisted"),
    ]
    filtered_entries = list(filter_chain(filters, entries))
    for entry in filtered_entries:
        logger.info("collected: %s - %02d", entry.show['title'], entry.ep)

    sorted_entries = sorted(filtered_entries, key=lambda entry: (entry.show['title'], entry.ep))
    filenames = [os.path.basename(entry.path) for entry in sorted_entries]
    to_syncplay(params, filenames)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Find unwatched episodes trough trackma and add them to a syncplay playlist. "
                    " Any unmatched arguments are forwarded to syncplay."
                    " Refer to `syncplay --help`."
    )
    parser.add_argument("-v", "--verbose", action='store_true', default=False,
                        help="Increase verbosity.")
    parser.add_argument("--accountnum", help="For overriding the trackma account number to use."
                        " You can look this up in trackma's account switcher."
                        " Will use your default otherwise.")
    parser.add_argument("--force-sync", action='store_true', default=False,
                        help="Resync trackma cache with remote.")
    parser.add_argument("--force-rescan", action='store_true', default=False,
                        help="Rescan local trackma library.")
    parser.add_argument("-f", "--force-all", action='store_true', default=False,
                        help="Force all refreshes.")
    parser.add_argument("--include", action='append',
                        help="Regular expression for titles to include. Repeatable.")
    parser.add_argument("--exclude", action='append',
                        help="Regular expression for titles to exclude. Repeatable.")
    parser.add_argument("--syncplay-path", default="/usr/lib/syncplay",
                        help="Path to syncplay's install location.")

    params, syncplay_args = parser.parse_known_args()
    params.syncplay_args = syncplay_args
    if params.force_all:
        params.force_sync = params.force_rescan = True

    return params


if __name__ == '__main__':
    params = parse_args()
    log_level = logging.DEBUG if params.verbose else logging.INFO
    logging.basicConfig(level=log_level, format="%(message)s")
    logger.debug("params: %r", params)
    main(params)
