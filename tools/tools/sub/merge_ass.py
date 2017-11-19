#!/usr/bin/env python3

import argparse
import logging
import sys
# from pathlib import Path

import ass

logger = logging.getLogger(__name__)


def parse_args():
    parser = argparse.ArgumentParser(description="Merge multiple ASS scripts into one.")
    parser.add_argument("input", nargs='+', type=argparse.FileType('r'),
                        help="File(s) to merge. Supports stdin (`-`, once).")
    parser.add_argument("-o", dest="output", type=argparse.FileType('w'),
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
    # docs = [ass.parse(file) for file in params.input]

    for file in params.input:
        doc = ass.parse(file)

        # Merge fields
        if not merged_doc.fields:
            merged_doc.fields = doc.fields
        else:
            if merged_doc.fields != doc.fields:
                logger.error("Fields of files to merge don't match."
                             "\nCurrent fields: %r"
                             "\nFields of %r: %r",
                             merged_doc.fields, file.name, doc.fields)
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
                                 style.name, file.name)
                    # TODO offer to choose
                    return 2

            styles_seen[style.name] = style
            merged_doc.styles.append(style)
        # merged_doc.styles.extend(doc.styles)

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

    merged_doc.dump_file(params.output)


if __name__ == '__main__':
    sys.exit(main())
