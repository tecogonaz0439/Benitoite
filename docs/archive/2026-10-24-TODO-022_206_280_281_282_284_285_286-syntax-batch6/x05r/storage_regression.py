"""同じ実ファイルの関門が基準版の複写では失敗することを確認する。"""
import json
from pathlib import Path
import runpy
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
base = 'ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c'
path = ROOT/'scripts/check/formal_interval.py'
old = subprocess.check_output(['git', 'show', base+':scripts/check/formal_interval.py'], cwd=ROOT, text=True)
previous = dict(__file__=str(path), __name__='baseline')
exec(compile(old, 'baseline-formal_interval.py', 'exec'), previous)
current = runpy.run_path(str(path))
results = []
for name, helper in [('baseline', previous), ('current', current)]:
    with tempfile.TemporaryDirectory(prefix='benitoite-storage-regression-') as temporary:
        roots = {kind: Path(temporary).resolve()/kind for kind in ('interval', 'desugar', 'coverage')}
        for directory in roots.values():
            directory.mkdir()
        for stem in ('named-programs', 'independent-program'):
            directory = roots['desugar']/(stem+'-interval')
            directory.mkdir()
            row = dict(group='golden', name=stem, payload='x'*32768)
            helper['write'](roots['desugar']/(stem+'-corpus.json'), dict(inputs=[row]))
            for filename in helper['SOURCE_FILES']:
                helper['write'](directory/filename, dict(kind=filename, inputs=[row]))
        helper['collect'](roots)
        sizes = [(roots['interval']/'programs'/f).stat().st_size for f in helper['SOURCE_FILES']]
        results.append(dict(version=name, sizes=sizes, passes=all(size<1024 for size in sizes)))
assert results[0]['passes'] is False and results[1]['passes'] is True, results
(HERE/'storage-regression-summary.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps(results))
