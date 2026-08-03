"""Filename completions after `@` in Markdown files.

Typing `@` followed by a (partial) path offers the matching directory entries,
relative to the current file's directory.
Absolute paths and `~` are supported,
and selecting a directory re-triggers completions
so paths can be walked segment by segment.
"""

import os
import re
from pathlib import Path

import sublime
import sublime_plugin

SELECTOR = "text.html.markdown - markup.raw"

# A path fragment is everything after an `@` up to the caret.
# Whitespace and a second `@` end the fragment,
# so plain email addresses and mentions do not turn into path lookups.
FRAGMENT_RE = re.compile(r"@([^\s@]*)\Z")

KIND_DIRECTORY = (sublime.KindId.NAVIGATION, "d", "Directory")
KIND_FILE = (sublime.KindId.MARKUP, "f", "File")


def fragment_before(view: sublime.View, point: int) -> str | None:
    """Return the `@`-fragment ending at ``point``, without the `@` itself."""
    line_start = view.line(point).begin()
    text = view.substr(sublime.Region(line_start, point))
    if match := FRAGMENT_RE.search(text):
        return match.group(1)
    return None


def base_dir(view: sublime.View) -> Path | None:
    if file_name := view.file_name():
        return Path(file_name).parent
    if (window := view.window()) and (folders := window.folders()):
        return Path(folders[0])
    return None


def search_dir(view: sublime.View, dir_part: str) -> Path | None:
    if dir_part.startswith("~"):
        return Path(dir_part).expanduser()
    if dir_part.startswith("/"):
        return Path(dir_part)
    base = base_dir(view)
    return base / dir_part if base else None


def matching_entries(directory: Path, name_part: str) -> list[os.DirEntry]:
    try:
        with os.scandir(directory) as scan:
            entries = list(scan)
    except OSError:
        return []

    prefix = name_part.casefold()
    entries = [
        entry
        for entry in entries
        if entry.name.casefold().startswith(prefix)
        # Dotfiles only show up once the user asks for them explicitly.
        and (prefix.startswith(".") or not entry.name.startswith("."))
    ]
    entries.sort(key=lambda entry: (not entry.is_dir(), entry.name.casefold()))
    return entries


def completion_item(entry: os.DirEntry) -> sublime.CompletionItem:
    is_dir = entry.is_dir()
    return sublime.CompletionItem.command_completion(
        trigger=entry.name,
        command="insert_markdown_path",
        args={"name": entry.name + ("/" if is_dir else "")},
        annotation="dir" if is_dir else Path(entry.name).suffix.lstrip("."),
        kind=KIND_DIRECTORY if is_dir else KIND_FILE,
    )


class MarkdownPathCompletionListener(sublime_plugin.EventListener):
    def on_query_completions(
        self,
        view: sublime.View,
        prefix: str,
        locations: list[int],
    ) -> sublime.CompletionList | None:
        if len(locations) != 1 or not view.match_selector(locations[0], SELECTOR):
            return None

        point = locations[0]
        fragment = fragment_before(view, point)
        if fragment is None:
            return None

        dir_part, _, name_part = fragment.rpartition("/")
        directory = search_dir(view, dir_part)
        if directory is None:
            return None

        items = [completion_item(entry) for entry in matching_entries(directory, name_part)]
        return sublime.CompletionList(
            items,
            flags=sublime.INHIBIT_WORD_COMPLETIONS | sublime.INHIBIT_EXPLICIT_COMPLETIONS,
        )


class InsertMarkdownPathCommand(sublime_plugin.TextCommand):
    """Replace the last path segment of the `@`-fragment at each caret."""

    def run(self, edit: sublime.Edit, name: str) -> None:
        view = self.view
        for region in reversed(view.sel()):
            point = region.begin()
            fragment = fragment_before(view, point)
            if fragment is None:
                continue
            name_part = fragment.rpartition("/")[2]
            start = point - len(name_part)
            # `replace` would leave the inserted text selected,
            # so a follow-up completion for the next path segment
            # would overwrite the segment just inserted.
            view.erase(edit, sublime.Region(start, region.end()))
            view.insert(edit, start, name)

        if name.endswith("/"):
            # Let the edit settle before asking for the next path segment.
            sublime.set_timeout(lambda: view.run_command("auto_complete"), 0)
