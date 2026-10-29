"""追補の限定差分と、後続の比較へ渡す入力を照合する。"""
from pathlib import Path
import ast
import hashlib
import json
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def current(path):
    return (ROOT / path).read_bytes()


def original(path):
    return subprocess.check_output(['git', 'show', 'HEAD:' + path], cwd=ROOT)


def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


paths = ['CHANGELOG.md', 'crates/benitoite/src/modules/text.rs',
         'crates/benitoite/src/modules/package.rs', 'crates/benitoite/src/modules/tests.rs',
         'crates/benitoite/testdata/packages/older-language.diag.json',
         'docs/design/06-tooling/06-09-packages.md',
         'docs/design/02-impl/02-10-diagnostics.md', 'crates/benitoite/src/diag/codes.rs',
         'crates/benitoite/skill/references/diagnostics.md',
         str((OUT.parent / 'decisions.md').relative_to(ROOT))]
previous = {r['path']: r['newSha256'] for r in json.loads((OUT / 'changed-files.json').read_text())['files']}
edits = json.loads((OUT / 'ab-edit-inputs.json').read_text())
previous.update({r['path']: r['beforeSha256'] for r in edits})
rows = []
for path in paths:
    before = previous.get(path, sha(original(path)))
    after = sha(current(path))
    assert before != after, path
    rows.append(dict(path=path, beforeSha256=before, afterSha256=after))
for row in edits:
    row['afterSha256'] = sha(current(row['path']))
save('ab-edit-inputs.json', edits)

# 先行作業が保存した全ファイルのうち、追補の対象以外は保持する。
preserved = []
for path, expected in previous.items():
    if path not in paths:
        assert sha(current(path)) == expected, path
        preserved.append(path)
env = json.loads((OUT / 'environment.json').read_text())
for row in env['unchangedInputs']:
    assert sha(current(row['path'])) == row['sha256'], row['path']
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == env['head']
assert subprocess.check_output(['git', 'diff', '--cached'], cwd=ROOT).decode() == env['indexDiff']
assert current('CHANGELOG.md').split(b'## 0.0.12 (San Benito)', 1)[1] == original('CHANGELOG.md').split(b'## 0.0.12 (San Benito)', 1)[1]
inventory = json.loads((OUT.parent / 'v10.1b/j2-rewrite-inventory.json').read_text())
for row in inventory['testdata']:
    path = row['path']
    assert current(path) == original(path).replace(b'language "0.0.12"', b'language "0.0.13"')
for path in OUT.glob('*.py'):
    ast.parse(path.read_text())

# 古い登録文言の記録は、追補前の値として保持する。
handoff = json.loads((OUT / 'comparison-inputs.json').read_text())
by_path = {r['path']: r for r in handoff}
updated = []
for path in ['crates/benitoite/src/modules/package.rs',
             'crates/benitoite/src/modules/text.rs',
             'crates/benitoite/testdata/packages/older-language.diag.json']:
    row = by_path[path]
    row.setdefault('beforeSupplementSha256', row['newSha256'])
    row['newSha256'] = sha(current(path))
    row['supplement'] = '三エフェクトの事実へ案内と期待値を同期。登録境界・受理規則は不変'
    updated.append(path)
for path, explanation in [
    ('crates/benitoite/src/diag/codes.rs', 'E0908 の説明の migration guidance を guidance へ変更。通常の診断主文・位置・受理判定を変えない'),
    ('crates/benitoite/skill/references/diagnostics.md', 'G が生成する E0908 の説明だけを同期。埋め込む文書であり、corpus へ収集されない')]:
    if path not in by_path:
        row = dict(path=path, oldSha256=sha(original(path)),
                   newSha256=sha(current(path)), exchangeInput=False,
                   loaderOrBuildInput=True,
                   impactRow='.diag.json の現在版の文と E0908 の note/help',
                   consumers=['候補の実 CLI のビルド'], supplement=explanation)
        handoff.append(row)
        by_path[path] = row
    else:
        by_path[path]['newSha256'] = sha(current(path))
for row in handoff:
    assert sha(current(row['path'])) == row['newSha256'], row['path']
save('comparison-inputs.json', handoff)

save('ab-change-audit.json', dict(files=rows, preservedEarlierFiles=preserved,
     earlierTestdataHeadersPreserved=len(inventory['testdata']),
     oldChangelogSectionsPreserved=True, unchangedEnvironmentInputsPreserved=True,
     headAndIndexUnchanged=True, comparisonInputs=len(handoff),
     comparisonInputsUpdated=updated,
     comparisonInputsAdded=['crates/benitoite/src/diag/codes.rs',
                            'crates/benitoite/skill/references/diagnostics.md']))
print(json.dumps(dict(supplementFiles=len(rows), comparisonInputs=len(handoff),
                      preservedEarlierFiles=len(preserved)), ensure_ascii=False))
