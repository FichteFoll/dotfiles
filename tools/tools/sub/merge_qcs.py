#!/usr/bin/env python3

"""Merge multiple QC documents, as created by kSub and mpvQC, into one.

Sorts lines and attributes them with their reporter
(sourced from the filename).
"""

# TODO option/mode to merge into ASS file

import argparse
from collections import namedtuple
import io
import logging
import os
import sys
from typing import Generator


l = logging.getLogger(__name__)


QCLine = namedtuple('QCLine', 'line source')


def extract_qc_lines(f: io.TextIOWrapper) -> Generator[str, None, None]:
    line_iter = iter(f)

    # go to data section
    # while "[DATA]\n" != next(line_iter, None) is not None:
    #     pass
    for line in line_iter:
        if line == "[DATA]\n":
            break

    for line in line_iter:
        if not line.startswith("#"):
            yield line.strip()


def get_subber_name(fname: str) -> str:
    stem, _ = os.path.splitext(fname)
    qc, *fragments, name = stem.split('_')
    assert qc == "[QC]"
    return name


def main():
    l.addHandler(logging.StreamHandler(sys.stderr))
    l.setLevel(logging.INFO)

    parser = argparse.ArgumentParser()
    parser.add_argument('in_files', nargs="+",  # dest='in_files', action='append',
                        type=argparse.FileType('r', encoding='utf-8-sig'),
                        default='-')
    parser.add_argument('-o', dest='out_file',
                        type=argparse.FileType('w', encoding='utf-8-sig'),
                        default='-')
    params = parser.parse_args()
    l.debug("Params: %s", params)

    # read input
    qc_lines = set()
    for file in params.in_files:
        fpath = getattr(file, 'name', "<no_name>")
        l.info("reading %r", fpath)
        fname = os.path.basename(fpath)
        name = get_subber_name(fname)

        local_qc_lines = {QCLine(line, name) for line in extract_qc_lines(file)}
        if not local_qc_lines:
            l.warn("File from %s (%r) contained no lines!", name, fpath)
        else:
            qc_lines |= local_qc_lines
        file.close()

    # write output
    params.out_file.write("[DATA]\n")
    for qc_line in sorted(qc_lines):
        params.out_file.write(f"{qc_line.line} {{{qc_line.source}}}\n")
    params.out_file.write(f"# Total lines: {len(qc_lines)}\n")
    params.out_file.close()


if __name__ == '__main__':
    main()
