#!/usr/bin/env python3

# API docs: https://github.com/4chan/4chan-API

import argparse
import asyncio
import html
import itertools
import os
import pathlib
import re
import sys
import time
from typing import Any, Dict, Iterable, NamedTuple, Set, Tuple

import aiohttp


class ThreadData(NamedTuple):
    board: str
    id: int

    @property
    def api_url(self):
        return f"https://a.4cdn.org/{self.board}/thread/{self.id}.json"


PostData = Dict[str, Any]


class StatData:
    num_files: int = 0
    total_size: int = 0
    start_time: float

    def __init__(self):
        self.sizes = []
        self.start_time = time.time()

    @property
    def duration(self):
        return time.time() - self.start_time

    def add_download(self, size):
        self.num_files += 1
        self.total_size += size


def format_size(size: float) -> str:
    suffixes = ("", "Ki", "Mi", "Gi", "Ti")
    for suffix in suffixes:
        if size < 1024:
            break
        size = size / 1024
    return f"{size:.1f}{suffix}B"


def parse_args():
    parser = argparse.ArgumentParser(description="Download images from 4chan threads")
    parser.add_argument(dest='urls', metavar="URL", nargs='+', type=str)
    parser.add_argument('-i', '--parallel-downloads', type=int, default=10)
    parser.add_argument('-o', '--output-pattern', default="{thread_id}/{filename}{ext}",
                        help="Accepts format string pattern")
    # parser.add_argument('-q', '--quiet', action='store_true', default=False)
    # parser.add_argument('--no-summary', action='store_true', default=False)
    return parser.parse_args()


def parse_urls(urls) -> Iterable[ThreadData]:
    for url in urls:
        regex = re.search(r"^https?://boards\.4chan\.org/([a-z0-9]{1,4})/thread/(\d+)", url)
        if not regex:
            print(f"skipping invalid URL: {url}")
            continue
        yield ThreadData(*regex.groups())


async def fetch_thread(thread: ThreadData,
                       parallel_downloads: int,
                       out_pattern: str,
                       saved_files: Set[pathlib.Path],
                       stats: StatData) -> None:
    async with aiohttp.ClientSession(raise_for_status=True) as session:
        async with session.get(thread.api_url) as resp:
            thread_data = await resp.json()

        pending_tasks: Set[asyncio.Future] = set()
        metadata_map: Dict[asyncio.Future, PostData] = {}

        def handle_done_tasks(tasks: Set[asyncio.Future]):
            for task in tasks:
                if task.exception():
                    # TODO print traceback
                    post_ = metadata_map[task]
                    print(f"Error while downloading {post_['filename']}{post_['ext']}:"
                          f" {task.exception()}")
                elif not task.cancelled():
                    stats.add_download(task.result())
                del metadata_map[task]

        try:
            for post in thread_data['posts']:
                if 'filename' not in post:
                    continue  # not an image

                if len(pending_tasks) > parallel_downloads:
                    done, pending_tasks = await asyncio.wait(pending_tasks,
                                                             return_when=asyncio.FIRST_COMPLETED)
                    handle_done_tasks(done)

                url, path = get_image_paths(post, out_pattern, thread, saved_files)
                if not url:
                    continue
                coro = download_file(session, url, path)
                task = asyncio.ensure_future(coro)
                pending_tasks.add(task)
                metadata_map[task] = post

            if pending_tasks:
                done, pending_tasks = await asyncio.wait(pending_tasks)
                handle_done_tasks(done)
                assert not pending_tasks, "Something went wrong."

        except asyncio.CancelledError:
            # Ensure our created tasks are cancelled properly
            for task in pending_tasks:
                task.cancel()


def get_image_paths(post: PostData,
                    out_pattern: str,
                    thread: ThreadData,
                    saved_files: Set[pathlib.Path],
                    ) -> Tuple[str, pathlib.Path]:
    post['board'] = thread.board
    post['thread_id'] = thread.id
    url = f"http://i.4cdn.org/{thread.board}/src/{post['tim']}{post['ext']}"

    path_str = out_pattern.format(**post)
    path_str = re.sub(r'[<>:"\\|?*]', "_", path_str)
    path_str = html.unescape(path_str)  # For some reason, the JSON response has html entities
    path = pathlib.Path(path_str)

    if path in saved_files:
        # Pick a different file name since we downloaded one with this name already
        for i in itertools.count(1):
            new_path = path.with_suffix(f".{i}{path.suffix}")
            if new_path not in saved_files and not new_path.exists():
                path = new_path
                break
    elif path.exists():
        print(f"File {path!s} already exists. Skipping...")
        return None, None

    saved_files.add(path)
    return url, path


async def download_file(session: aiohttp.ClientSession,
                        url: str,
                        path: pathlib.Path) -> int:
    os.makedirs(path.parent, exist_ok=True)

    size = 0
    with path.open('wb') as fp:
        async with session.get(url) as resp:
            async for chunk in resp.content.iter_any():
                fp.write(chunk)
                size += len(chunk)

    print(f"Saved {url} to {path!s}")
    return size


async def async_main() -> int:
    params = parse_args()

    threads = parse_urls(params.urls)
    if not threads:
        return 1

    ret = 0
    saved_files: Set[pathlib.Path] = set()
    stats = StatData()
    for thread in threads:
        try:
            await fetch_thread(thread,
                               params.parallel_downloads,
                               params.output_pattern,
                               saved_files,
                               stats)
        except asyncio.CancelledError:
            pass
        except Exception:
            print("Uncaught exception while fetching thread {thread.id}")
            import traceback
            traceback.print_exc()
            ret |= 2

    print(f"Downloaded {stats.num_files} files ({format_size(stats.total_size)}) "
          f"over {stats.duration:.1f}s")

    return ret


def main() -> int:
    """Return values:

    1: Invalid thread URLs provided
    2: Failed to download a thread (completely or partially)
    """
    loop = asyncio.get_event_loop()
    task = asyncio.ensure_future(async_main())
    try:
        return loop.run_until_complete(task)
    except KeyboardInterrupt:
        print("Download cancelled")
        task.cancel()
        return loop.run_until_complete(task)
    finally:
        loop.close()


if __name__ == '__main__':
    sys.exit(main())
