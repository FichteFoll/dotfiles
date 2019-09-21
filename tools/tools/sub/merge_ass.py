#!/usr/bin/env python3

"""Merge multiple ASS files into one.

Supports a couple options to strip stuff
and complains about style conflicts.
Dialog lines are simply appended.

Requires https://github.com/rfw/python-ass.
"""

import argparse
import logging
import sys
from pathlib import Path

import ass

IGNORED_FIELDS = {
    # irrelevant
    'Title',
    # Aegisub Project Garbage
    'Last Style Storage',
    'Video Aspect Ratio',
    'Video Zoom',
    'Video Position',
    'Collisions',
    'Video Zoom Percent',
    'Audio File',
    'Video File',
    # other
    'GradientFactory',
}

logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description="Merge multiple ASS scripts into one.")
    parser.add_argument("input", nargs='+', type=Path,
                        help="File(s) to merge. Supports stdin (`-`, once).")
    parser.add_argument("-o", dest="output", type=Path,
                        help="File to write to. Supports stdout (`-`).")
    parser.add_argument("--skip-comments", action='store_true',
                        help="Skips comments for the merged file.")
    parser.add_argument("--skip-templates", action='store_true',
                        help="Skips template lines for the merged file.")
    parser.add_argument("--no-skip-furigana", action='store_true',
                        help="Does not skip furigana styles.")

    return parser.parse_args()


def main():
    params = parse_args()

    merged_doc = ass.document.Document()

    for path in params.input:
        if path == Path('-'):
            doc = ass.parse(sys.stdin)
        else:
            with path.open('r', encoding='utf_8_sig') as f:
                doc = ass.parse(f)
        stripped_fields = doc.fields.copy()
        for key in IGNORED_FIELDS:
            stripped_fields.pop(key, None)

        # Merge fields
        if not merged_doc.fields:
            merged_doc.fields = stripped_fields
        else:
            if merged_doc.fields != stripped_fields:
                logger.error("Fields of files to merge don't match."
                             "\nCurrent fields:\n%r"
                             "\nFields of %r:\n%r",
                             merged_doc.fields, path.name, stripped_fields)
                # TODO offer to choose
                return 1

        # Merge styles (with filters)
        styles_seen = {}
        for style in doc.styles:
            if not params.no_skip_furigana:
                if style.name.endswith("-furigana"):
                    continue

            if style.name in styles_seen:
                previous_style = styles_seen[style.name]
                if previous_style != style:
                    logger.error("Style %r differs in at least two source files,"
                                 " one of which is %r.",
                                 style.name, path.name)
                    # TODO offer to choose
                    return 2
                continue

            styles_seen[style.name] = style
            merged_doc.styles.append(style)

        # Merge events with filters
        events = doc.events
        if params.skip_comments:
            events = [ev for ev in events if ev.TYPE != "Comment"]
        elif params.skip_templates:
            # Templates are always comments
            events = [ev for ev in events
                      if not (ev.TYPE == "Comment"
                              and any(ev.effect.startswith(s) for s in ("template", "code")))]

        merged_doc.events.extend(doc.events)

    if params.output == Path('-'):
        merged_doc.dump_file(sys.stdout)
    else:
        with params.output.open('w', encoding='utf_8_sig') as f:
            merged_doc.dump_file(f)


if __name__ == '__main__':
    sys.exit(main())
