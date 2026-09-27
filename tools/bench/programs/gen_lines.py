#!/usr/bin/env python3
"""Generate deterministic UTF-8 input for the `lines` benchmark."""

import argparse
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="path of the generated UTF-8 file")
    parser.add_argument("--lines", type=int, required=True, help="number of lines to write")
    args = parser.parse_args()
    if args.lines < 0:
        parser.error("--lines must be non-negative")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output:
        for number in range(args.lines):
            output.write(f"line-{number:08d}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
