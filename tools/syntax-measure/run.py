# -*- coding: utf-8 -*-
"""構文だけの測定（OPEN-012、ADR 0246 の第一段階）の道具。使い方は README.md を参照。

サブコマンド:
  check     案の文法でファイルを検査し、最初の誤りの診断を示す（誤りがあれば終了状態 1）
  build     雛形から各案の参照の文書（variants/<ID>/reference.md）を作り直す
  selftest  参照の文書の例と、案ごとの単体の検査を確かめる
  run       エージェントに課題を解かせ、構文の誤りの率と 1 回で直せた率を記録する
  report    結果（JSON Lines）を Markdown の表に集計する
  archive   生の記録（作業場所）と結果を一つの tar.gz にまとめる
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from bntmeasure import harness, refgen, report, selftest  # noqa: E402
from bntmeasure import variants as V  # noqa: E402
from bntmeasure.checker import check_source  # noqa: E402


def cmd_check(args):
    src = open(args.file, encoding='utf-8').read()
    r = check_source(args.variant, src, filename=os.path.basename(args.file))
    print(r.text)
    return 0 if r.ok else 1


def cmd_build(args):
    for p in refgen.write_all():
        print(p)
    return 0


def cmd_selftest(args):
    return 0 if selftest.run(verbose=args.verbose) else 1


def cmd_run(args):
    harness.run(args)
    return 0


def cmd_report(args):
    report.report(args)
    return 0


def cmd_archive(args):
    harness.archive(args)
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='command', required=True)

    p = sub.add_parser('check', help='check a script with the grammar of a variant')
    p.add_argument('--variant', default='V00', choices=V.VARIANT_IDS)
    p.add_argument('file')
    p.set_defaults(func=cmd_check)

    p = sub.add_parser('build', help='regenerate variants/<ID>/reference.md from the template')
    p.set_defaults(func=cmd_build)

    p = sub.add_parser('selftest', help='check the reference documents and the checkers')
    p.add_argument('--verbose', action='store_true')
    p.set_defaults(func=cmd_selftest)

    p = sub.add_parser('run', help='run the measurement with a coding agent')
    p.add_argument('--agent', required=True, help='codex, opencode or fake (see bntmeasure/agents.py)')
    p.add_argument('--variants', default='all', help='comma-separated variant IDs, or all')
    p.add_argument('--tasks', default='all', help='comma-separated task IDs, or all')
    p.add_argument('--trials', type=int, default=1)
    p.add_argument('--out', default=harness.DEFAULT_RESULTS, help='directory for the JSON Lines results')
    p.add_argument('--workspace-root', default=harness.DEFAULT_WORKSPACE_ROOT,
                   help='directory for the raw workspaces (outside the repository)')
    p.add_argument('--run-id', default=None, help='run ID (default: UTC time and agent)')
    p.add_argument('--resume', action='store_true', help='skip combinations already recorded for --run-id')
    p.add_argument('--parallel', type=int, default=1)
    p.add_argument('--timeout', type=int, default=900, help='timeout of one agent call in seconds')
    p.add_argument('--order', choices=('shuffle', 'sequential'), default='shuffle')
    p.add_argument('--seed', type=int, default=None, help='seed for --order shuffle (default: random, recorded)')
    p.set_defaults(func=cmd_run)

    p = sub.add_parser('report', help='summarize results as Markdown tables')
    p.add_argument('--results', nargs='+', required=True, help='JSON Lines files written by run')
    p.add_argument('--include-outside', action='store_true',
                   help='include trials that accessed paths outside their workspace')
    p.add_argument('--by-task', action='store_true', help='add per-task tables')
    p.add_argument('--output', default=None, help='write the report to this file')
    p.set_defaults(func=cmd_report)

    p = sub.add_parser('archive', help='pack the raw records of a run into a tar.gz')
    p.add_argument('--run-id', required=True)
    p.add_argument('--workspace-root', default=harness.DEFAULT_WORKSPACE_ROOT)
    p.add_argument('--out', default=harness.DEFAULT_RESULTS, help='directory of the results of the run')
    p.add_argument('--archive-dir', default=None, help='where to put the archive (default: <workspace-root>/archives)')
    p.set_defaults(func=cmd_archive)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == '__main__':
    sys.exit(main())
