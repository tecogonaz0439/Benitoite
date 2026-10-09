#!/usr/bin/env python3
"""Run exactly one child and report its resource.getrusage maximum RSS."""

import resource
import subprocess
import sys


def main():
    command = sys.argv[1:]
    if not command:
        raise SystemExit("usage: rss.py COMMAND [ARG ...]")
    result = subprocess.run(command, check=False)
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    # macOS reports bytes, Linux reports KiB. No other children run in this wrapper.
    multiplier = 1 if sys.platform == "darwin" else 1024
    print(f"bench-rss: {int(usage.ru_maxrss) * multiplier}", file=sys.stderr)
    return result.returncode if result.returncode >= 0 else 128 - result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
