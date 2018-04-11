#!/usr/bin/env python

import re
import sys

import ass


def main():
    file_path = sys.argv[1]
    with open(file_path, 'r') as fp:
        doc = ass.parse(fp)

    for i, event in enumerate(doc.events[:]):
        if event.TYPE == 'Dialogue' and event.effect == "fx":
            doc.events[i] = None  # set to None to remove later
            continue

        if (
            event.TYPE == 'Comment' and event.effect == "karaoke"
            or event.TYPE == 'Dialogue' and not event.effect
        ):
            if "Kanji" in event.style:
                comment_event = ass.document.Comment(**event.fields)
                comment_event.effect = "karaoke"
                new_event = ass.document.Dialogue(**event.fields)
                new_event.effect = "fx"

                # Cannot use str.join because tags might be inbetween text
                parts = re.split(r"(\{[^\}]*\})", new_event.text)
                parts = (f"{c}\\N" if not part.startswith("{") else c
                         for part in parts
                         for c in part)
                new_event.text = "".join(parts)[:-2]

                doc.events[i] = comment_event
                doc.events.append(new_event)

    # remove events flagged for deletion
    doc.events = filter(None, doc.events)

    with open(file_path + "_", 'w') as fp:
        doc.dump_file(fp)


if __name__ == '__main__':
    main()
