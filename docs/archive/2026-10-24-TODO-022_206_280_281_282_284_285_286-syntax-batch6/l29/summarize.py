"""比較件数と除外理由を要約し、局所検査の全入力・出力を検証付きで保存する。"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import shutil
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
FINAL = OUT/'tests-final'
rows = []
for profile in ['base', 'flow', 'width', 'range', 'domain']:
    analyze = json.loads((FINAL/(profile+'-analyze-0.report.json')).read_text())
    evaluation = json.loads((FINAL/(profile+'-eval.report.json')).read_text())
    reasons = Counter()
    for item in evaluation['inputs']:
        for body in item['bodies']:
            if not body['comparisonEligible']:
                reasons[body['actual']['excluded']] += 1
        for body in item['embeddedExcluded']:
            reasons[body['reason']] += 1
    rows.append(dict(profile=profile, analysis=analyze['profileManifest'],
        informativeCount=analyze['informativeCount'], phaseDepthCount=analyze['phaseDepthCount'],
        eval=evaluation['profileManifest'], excludedReasons=dict(reasons),
        analysisMatched=analyze['matched'], analysisAccepted=analyze['accepted'],
        evalMatched=evaluation['matched'], evalAccepted=evaluation['accepted']))
(OUT/'comparison-summary.json').write_text(json.dumps(rows, indent=2)+'\n')
for name in ['profile-manifest.json', 'fuel-selection.json']:
    shutil.copyfile(FINAL/name, OUT/name)
# 所有する検査出力だけを対象とする。既存のビルド生成物には触れない。
files = sorted(p for directory in OUT.glob('tests-*') if directory.is_dir()
               for p in directory.rglob('*') if p.is_file())
index = []
with zipfile.ZipFile(OUT/'test-records.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        raw = path.read_bytes()
        assert str(ROOT).encode() not in raw and str(Path.home()).encode() not in raw, path.name
        name = path.relative_to(OUT).as_posix()
        archive.writestr(name, raw)
        index.append(dict(file=name, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest()))
with zipfile.ZipFile(OUT/'test-records.zip') as archive:
    for entry in index:
        raw = archive.read(entry['file'])
        assert hashlib.sha256(raw).hexdigest() == entry['sha256']
        assert raw == (OUT/entry['file']).read_bytes()
(OUT/'test-records-index.json').write_text(json.dumps(index, indent=2)+'\n')
for directory in OUT.glob('tests-*'):
    if directory.is_dir():
        shutil.rmtree(directory)
print(json.dumps(dict(archivedFiles=len(index), profiles=[dict(profile=r['profile'],
    analyze=r['analysis']['comparedCount'], informative=r['informativeCount'],
    eval=r['eval']['comparedCount'], excluded=r['excludedReasons']) for r in rows])))
