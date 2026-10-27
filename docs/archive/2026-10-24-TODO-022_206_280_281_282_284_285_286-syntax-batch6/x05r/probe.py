"""K1 全体を起動せず、外部型四入力と幅付き警告を通常予算で比較する。"""
from pathlib import Path
import json
import runpy
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'formal/tests'))
import test_interval_exchange as exchange
import interval_source_compare as source

BASE = ROOT/'target/interval-diff/x05r-local'
output = BASE/'final-comparison'
output.mkdir()
runner = exchange.Runner(output, ROOT/'formal/.lake/build/bin/intervalDiff')
summary = source.exercise(runner, BASE/'manifest/manifest-interval')
checks = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/interval/check-manifest.py'))
manifest = checks['check_source'](BASE/'manifest/manifest-interval', output, runner.executable)
print(json.dumps(dict(summary=summary, manifest=manifest, calls=runner.calls), ensure_ascii=False))
