"""局所検査の入力・報告をハッシュ付きで保管し、重複する展開物を片付ける。"""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
directories = [OUT/name for name in ('tests-first', 'tests-second', 'tests-expanded',
                                    'tests-context', 'tests-complete', 'tests-final')]
final = OUT/'tests-final'
summary = []
for label in ('base-analyze-0', 'base-eval', 'flow-analyze-0', 'flow-eval', 'fuel-selected', 'fuel-selected-eval'):
    r = json.loads((final/(label+'.report.json')).read_text())
    summary.append(dict(case=label, matched=r['matched'], accepted=r['accepted'],
                        compared=r['comparedCount'], excluded=r['excludedCount'],
                        phaseDepth=r.get('phaseDepthCount'), informative=r.get('informativeCount')))
(OUT/'comparison-summary.json').write_text(json.dumps(summary, indent=2)+'\n')
shutil.copyfile(final/'fuel-selection.json', OUT/'fuel-selection.json')
index = []
with zipfile.ZipFile(OUT/'test-records.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for directory in directories:
        for path in sorted(directory.rglob('*')):
            if not path.is_file():
                continue
            data = path.read_bytes()
            assert str(ROOT).encode() not in data and str(Path.home()).encode() not in data
            name = str(path.relative_to(OUT))
            index.append(dict(path=name, sha256=hashlib.sha256(data).hexdigest(), bytes=len(data)))
            z.writestr(name, data)
with zipfile.ZipFile(OUT/'test-records.zip') as z:
    for item in index:
        assert hashlib.sha256(z.read(item['path'])).hexdigest() == item['sha256']
(OUT/'test-records-index.json').write_text(json.dumps(index, indent=2)+'\n')
for directory in directories:
    shutil.rmtree(directory)
print(json.dumps(dict(archivedFiles=len(index), zipBytes=(OUT/'test-records.zip').stat().st_size)))
