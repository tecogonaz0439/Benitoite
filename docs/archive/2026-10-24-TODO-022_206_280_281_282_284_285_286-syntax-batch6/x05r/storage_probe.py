"""全件の代わりに実書き出しの部分集合で索引・容量・manifest を照合する。"""
import json
from pathlib import Path
import runpy
import shutil
import sys

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'formal/tests'))
import test_interval_exchange as exchange
import interval_source_compare as source

helper = runpy.run_path(str(ROOT/'scripts/check/formal_interval.py'))
INPUT_BASE = ROOT/'target/interval-diff/x05r-local'
BASE = ROOT/'target/interval-diff/x05r-indexed-final'
BASE.mkdir()
DESUGAR = ROOT/'target/desugar-diff/x05r-local'
COVERAGE = ROOT/'target/coverage-diff/x05r-local'
COVERAGE.mkdir(parents=True, exist_ok=True)
legacy = helper['read'](INPUT_BASE/'manifest/manifest-corpus.json')
helper['write'](DESUGAR/'named-programs-corpus.json', legacy)
source_dir = INPUT_BASE/'manifest/manifest-interval'
selected = DESUGAR/'named-programs-interval'
selected.mkdir(exist_ok=True)
for filename in helper['SOURCE_FILES']:
    document = helper['read'](source_dir/filename)
    def keep(row):
        return row.get('group') != 'interval-budget' and not row.get('name', '').startswith('interval-budget:')
    document['inputs'] = [row for row in document['inputs'] if keep(row)]
    helper['write'](selected/filename, document)
roots = dict(interval=BASE.resolve(), desugar=DESUGAR.resolve(), coverage=COVERAGE.resolve())
programs = BASE/'programs'
assert not programs.exists(), 'use a fresh programs output'
helper['collect'](roots)
helper['verify_inputs'](roots)
index_bytes = sum((programs/f).stat().st_size for f in helper['SOURCE_FILES'])
original_bytes = sum((DESUGAR/(stem+'-interval')/f).stat().st_size for stem in
                     ('named-programs', 'independent-program') for f in helper['SOURCE_FILES'])
assert index_bytes < 4096 and original_bytes > index_bytes
for filename in helper['SOURCE_FILES']:
    expected = [row for stem in ('named-programs', 'independent-program')
                for row in helper['read'](DESUGAR/(stem+'-interval')/filename)['inputs']]
    assert helper['read'](programs/filename)['inputs'] == expected
output = BASE/'indexed-comparison'
output.mkdir()
runner = exchange.Runner(output, ROOT/'formal/.lake/build/bin/intervalDiff')
summary = source.exercise(runner, programs)
checks = runpy.run_path(str(ROOT/'crates/benitoite/tests/desugar_export/interval/check-manifest.py'))
manifest = checks['check_source'](programs, output, runner.executable)
helper['verify_inputs'](roots)
result = dict(indexBytes=index_bytes, sharedOriginalBytes=original_bytes, summary=summary,
              manifest=manifest, calls=runner.calls)
(HERE/'storage-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(result, ensure_ascii=False))
