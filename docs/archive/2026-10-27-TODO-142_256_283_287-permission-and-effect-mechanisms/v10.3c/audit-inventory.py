"""版・訳・生成物・許諾一覧・ソース配布の読取り照合。生成器は起動しない。"""
from pathlib import Path
import ast
import datetime
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
CHANGE = OUT.parent
ROOT = CHANGE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


rows = []


def add(category, name, detail):
    path = ROOT / name
    rows.append(dict(category=category, path=name, bytes=path.stat().st_size,
                     sha256=sha(path), detail=detail))


for name in ['crates/benitoite/Cargo.toml', 'Cargo.lock', 'fuzz/Cargo.lock']:
    text = (ROOT / name).read_text()
    if name.endswith('Cargo.lock'):
        versions = [re.search(r'^version = "([^"]+)"', s, re.M).group(1)
                    for s in text.split('[[package]]')
                    if re.search(r'^name = "benitoite"$', s, re.M)]
        assert versions == ['0.0.13'], versions
    else:
        assert re.search(r'^version = "0.0.13"$', text, re.M)
    add('版と lock', name, 'benitoite 0.0.13')

documents = ['README.md', 'CHANGELOG.md', 'docs/reference/benitoite.md',
             'docs/reference/install.md', 'docs/ja/reference/benitoite.md',
             'docs/ja/reference/install.md', 'docs/ja/skill/SKILL.md']
documents += ['docs/ja/skill/references/' + n + '.md'
              for n in ['inspection', 'idioms', 'common-mistakes', 'language-comparison']]
for name in documents:
    assert '0.0.13' in (ROOT / name).read_text()[:2400], name
    add('文書', name, '現在版または翻訳元 0.0.13。旧版の履歴と既存の固定参照を保つ')

translation = json.loads((CHANGE / 'v10.3a/translation-audit.json').read_text())
pairs = []
for row in translation['pairs']:
    pair = {k: row[k] for k in ['english', 'japanese', 'codeFences']}
    pair['englishMatches'] = sha(ROOT / row['english']) == row['englishSha256']
    pair['japaneseMatches'] = sha(ROOT / row['japanese']) == row['japaneseSha256']
    assert pair['englishMatches'] and pair['japaneseMatches'], pair
    pairs.append(pair)

generated = []
for row in json.loads((CHANGE / 'v10.3a/ab-generated-audit.json').read_text())['files']:
    assert sha(ROOT / row['path']) == row['afterSha256'], row['path']
    generated.append(dict(path=row['path'], sha256=row['afterSha256']))

about = (ROOT / 'scripts/release/about.toml').read_text()
deny = (ROOT / 'deny.toml').read_text()
accepted = ast.literal_eval(re.search(r'^accepted = (\[[^\n]+\])', about, re.M).group(1))
allow = ast.literal_eval(re.search(r'^allow = (\[[^\n]+\])', deny, re.M).group(1))
assert accepted == allow
for name in ['scripts/release/about.toml', 'deny.toml', 'LICENSE-MIT', 'LICENSE-APACHE',
             'crates/benitoite/build.rs', 'crates/benitoite/src/cli/tools/skill/bundle.rs']:
    add('許諾と同梱', name, '候補ソースと同梱本文を照合。許諾一覧は版番号に依存しない')

changelog = (ROOT / 'CHANGELOG.md').read_text().split('## 0.0.13 (San Benito)\n', 1)[1].split('## 0.0.12 (San Benito)', 1)[0]
assert 'no executables are provided' in changelog
assert not re.search(r'performance|benchmark|migration|how to migrate', changelog, re.I)
counts = {}
for name, effects in [('crates/benitoite/src/prelude/stdlib/IO/File.bnt', ['Read', 'Write']),
                      ('crates/benitoite/src/prelude/stdlib/Network/Http.bnt', ['Connect'])]:
    text = (ROOT / name).read_text()
    for effect in effects:
        block = re.search(r'^public effect ' + effect + r'\b[^\n]*\n(.*?)^end effect', text, re.M | re.S).group(1)
        counts[effect] = re.findall(r'^\s*function\s+(\w+)', block, re.M)
assert {k: len(v) for k, v in counts.items()} == dict(Read=13, Write=16, Connect=2)

tree = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', 'HEAD'], cwd=ROOT, text=True)
names = tree.splitlines()
excluded = [n for n in names if n.startswith(('private/', 'docs/todo/', 'reference/', 'work/', 'target/'))]
assert not excluded
result = dict(checkedAt=datetime.datetime.now().astimezone().isoformat(), version='0.0.13',
              files=rows, translationPairs=pairs, translationCodeFences=translation['codeFences'],
              generated=generated, acceptedLicenses=accepted, licenseListsEqual=True,
              operationNames=counts,
              sourceDistribution=dict(trackedFiles=len(names),
                  treeListSha256=hashlib.sha256(tree.encode()).hexdigest(), excludedEntries=excluded,
                  archiveCreated=False,
                  reason='ソースだけの配布の記述と候補の追跡木を照合。正式 archive は集約・タグ後の V10.3e で作る'),
              changeEvidence='../v10.1c/results.md#三回目の-change取りまとめ2026-10-30')
(OUT / 'inventory-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(dict(files=len(rows), translationPairs=len(pairs), generated=len(generated),
                      trackedFiles=len(names)), ensure_ascii=False))
