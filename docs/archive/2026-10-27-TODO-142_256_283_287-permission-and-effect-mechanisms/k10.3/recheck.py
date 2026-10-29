#!/usr/bin/env python3
"""一回目に失敗・未到達だった段だけを、固定した出力先で順に確認する。"""
from pathlib import Path
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def main():
    desugar = ROOT / 'target/desugar-diff/k10.3'
    coverage = ROOT / 'target/coverage-diff/k10.3'
    interval = ROOT / 'target/interval-diff/k10.3'
    corpus = desugar / 'named-programs-corpus.json'
    builtins = desugar / 'named-programs-builtins.json'
    stdlib = desugar / 'named-programs-stdlib.json'
    bin_dir = ROOT / 'formal/.lake/build/bin'
    dirs = ['--interval-dir', interval, '--desugar-dir', desugar, '--coverage-dir', coverage]
    steps = [
        ('reexport-audit', ['python3', '-B', OUT / 'audit-exports.py', 'compare']),
        ('desugar', [bin_dir / 'desugarDiff', corpus, desugar / 'report.json']),
        ('builtin', [bin_dir / 'builtinCheck', corpus, builtins, desugar / 'builtin-report.json']),
        ('surface-all', [bin_dir / 'surfaceCheckAll', corpus, builtins, stdlib,
                         desugar / 'surface-check/report.json']),
        ('named', ['python3', '-I', ROOT / 'crates/benitoite/tests/desugar_export/check_named.py',
                   desugar, coverage]),
        ('manifest', ['python3', '-B', ROOT / 'scripts/check/formal_interval.py', 'manifest', *dirs]),
        ('verify', ['python3', '-B', ROOT / 'scripts/check/formal_interval.py', 'verify', *dirs]),
    ]
    for name, command in steps:
        process = subprocess.run(['python3', '-B', str(OUT / 'run-record.py'), name, '--',
                                  *map(str, command)], cwd=ROOT)
        if process.returncode:
            return process.returncode
    return 0


if __name__ == '__main__':
    sys.exit(main())
