#!/usr/bin/env python3
"""長いテストまたは測定済みスタックのテストを一括実行し、成功件数を確かめる。"""

import argparse
from pathlib import Path
import re
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CONFIGURATIONS = {
    'heap': ['--no-default-features', '--features', 'gc-mark-sweep,heap-verify'],
    'stress': ['--no-default-features', '--features', 'gc-mark-sweep,heap-verify,gc-stress'],
    'release': ['--release'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind', choices=['long', 'release-stack'], required=True)
    parser.add_argument('--configuration', choices=CONFIGURATIONS, required=True)
    args = parser.parse_args()
    if not ((args.kind == 'long' and args.configuration in ('heap', 'stress'))
            or (args.kind == 'release-stack' and args.configuration == 'release')):
        print('FAILED: execution requires long with heap/stress or release-stack with release',
              file=sys.stderr)
        return 1
    if args.kind == 'long':
        command = ['cargo', 'test', '--workspace', *CONFIGURATIONS[args.configuration],
                   '--lib', '--tests', '--', '--ignored',
                   '--skip', 'export_coverage', '--skip', 'export_desugar_corpus']
    else:
        command = ['cargo', 'test', '--release', '-p', 'benitoite', '--lib', '--',
                   'pipeline::tests::stages_fit_the_measured_stack_', '--include-ignored']
    print('+ ' + shlex.join(command), flush=True)
    passed = summaries = 0
    invalid = False
    # ビルドの進捗を含むstderrをそのまま流し、stdoutも行ごとに表示する。
    with subprocess.Popen(command, cwd=ROOT, text=True, stdout=subprocess.PIPE) as process:
        for line in process.stdout:
            print(line, end='', flush=True)
            match = re.fullmatch(
                r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored; '
                r'(\d+) measured; \d+ filtered out;.*\n?', line)
            if match:
                summaries += 1
                passed += int(match[1])
                invalid |= any(int(match[i]) for i in (2, 3, 4))
        status = process.wait()
    if status:
        print(f'FAILED: external command exited {status}', file=sys.stderr)
        return 1
    if not summaries or invalid or (passed != 10 if args.kind == 'release-stack' else passed == 0):
        expected = 'exactly 10' if args.kind == 'release-stack' else 'at least one'
        print(f'FAILED: expected {expected} successful tests with valid summaries; got {passed}',
              file=sys.stderr)
        return 1
    print(f'completed {passed} {args.kind} tests')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except OSError as error:
        sys.exit(f'FAILED: {error}')
