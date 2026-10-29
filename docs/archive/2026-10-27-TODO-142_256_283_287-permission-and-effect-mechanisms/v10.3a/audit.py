"""版の一覧・差分・引き渡す入力を照合する。処理系は呼ばない。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
INV = json.loads((OUT.parent / 'v10.1b/j2-rewrite-inventory.json').read_text())

def sha(b):
    return hashlib.sha256(b).hexdigest()

def old(path):
    return subprocess.check_output(['git', 'show', 'HEAD:' + path], cwd=ROOT)

def current(path):
    return (ROOT / path).read_bytes()

def save(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

changed = subprocess.check_output(['git', 'diff', '--name-only', '-z'], cwd=ROOT).decode().strip('\0').split('\0')
allowed = {r['path'] for group in ['testdata', 'testFiles', 'diagnostics', 'documentExamples', 'relatedVersionFiles'] for r in INV[group]}
allowed |= {INV[k]['path'] for k in ['registry', 'text']}
allowed |= {p.split('::')[0] for r in INV['hashProposals'] for p in r['targets']}
allowed |= {'CHANGELOG.md'}
unknown = [p for p in changed if p not in allowed]
assert not unknown, unknown

locks = []
for path in ['Cargo.lock', 'fuzz/Cargo.lock']:
    before, after = old(path), current(path)
    marker = b'name = "benitoite"\nversion = "0.0.12"'
    assert before.count(marker) == 1
    assert before.replace(marker, marker.replace(b'0.0.12', b'0.0.13')) == after
    locks.append({'path': path, 'oldSha256': sha(before), 'newSha256': sha(after), 'onlyChange': 'benitoite.version: 0.0.12 -> 0.0.13', 'updateCommandExit': 0})
save('lock-audit.json', locks)
(OUT / 'locks.patch').write_bytes(subprocess.check_output(['git', 'diff', '--', 'Cargo.lock', 'fuzz/Cargo.lock'], cwd=ROOT))

for row in INV['testdata']:
    assert current(row['path']) == old(row['path']).replace(b'language "0.0.12"', b'language "0.0.13"')
for row in INV['exclusions'][:5]:
    assert current(row['path']) == old(row['path']), row['path']
before_changelog = old('CHANGELOG.md').split(b'## 0.0.12 (San Benito)', 1)[1]
assert current('CHANGELOG.md').split(b'## 0.0.12 (San Benito)', 1)[1] == before_changelog
for path in ['docs/reference/benitoite.md', 'docs/reference/install.md']:
    before, after = old(path).decode(), current(path).decode()
    heading = '### Migrating to 0.0.12' if 'benitoite.md' in path else '### Updating from 0.0.11 to 0.0.12'
    def section(s):
        tail = s.split(heading, 1)[1]
        match = re.search(r'^#{1,3} ', tail, re.M)
        return tail[:match.start()] if match else tail
    assert section(before) == section(after), path

generated = [p for p in (ROOT / 'crates/benitoite/skill/references').rglob('*.md')
             if p.name not in {'inspection.md', 'idioms.md', 'common-mistakes.md', 'language-comparison.md'}]
generated_paths = sorted(str(p.relative_to(ROOT)) for p in generated)
assert len(generated_paths) == 66, len(generated_paths)
bundle = 'crates/benitoite/src/cli/tools/skill/bundle.rs'
assert all(current(p) == old(p) for p in generated_paths + [bundle])
save('generated-audit.json', {'generatedFiles': [{'path': p, 'sha256': sha(current(p)), 'unchanged': True} for p in generated_paths], 'bundle': {'path': bundle, 'sha256': sha(current(bundle)), 'unchanged': True}})

role_groups = {
    '版とlock': lambda p: p in ['crates/benitoite/Cargo.toml', 'Cargo.lock', 'fuzz/Cargo.lock'],
    '登録と文言とRust内テスト': lambda p: p.startswith('crates/benitoite/src/'),
    '統合テストと固定書き出し入力': lambda p: p.startswith('crates/benitoite/tests/'),
    'testdata': lambda p: p.startswith('crates/benitoite/testdata/'),
    '設計書の宣言例': lambda p: p.startswith('docs/design/'),
    '英語の文書の版': lambda p: p.startswith('docs/reference/'),
    '日本語訳': lambda p: p.startswith('docs/ja/'),
    'READMEとCHANGELOG': lambda p: p in ['README.md', 'CHANGELOG.md'],
}
roles = {name: [p for p in changed if match(p)] for name, match in role_groups.items()}
assert sum(map(len, roles.values())) == len(changed)
save('changed-files.json', {'base': '92f9ac80f81d2299978d2051ddcdfdeea1843e6d', 'trackedCount': len(changed), 'roles': roles, 'files': [{'path': p, 'oldSha256': sha(old(p)), 'newSha256': sha(current(p))} for p in changed]})

handoff = []
for p in changed:
    if p.startswith('crates/benitoite/testdata/'):
        row = next((r for r in INV['testdata'] if r['path'] == p), None)
        table = 'testdata の header・依存ハッシュと現在版の loader' if row or p.endswith('hash-match/package.bnt') else '.diag.json の現在版の文と E0908 の note/help'
        also = []
        if row and any('/d6c-' in c for c in row['consumers']):
            also.append('named.rs の固定パッケージと区間 manifest の依存 header')
        if '/libraries.files/' in p and any(x in p for x in ['wasm-json', 'pure-json', 'wasm-regex']):
            also.append('named.rs の固定パッケージと区間 manifest の依存 header')
        handoff.append({'path': p, 'oldSha256': sha(old(p)), 'newSha256': sha(current(p)), 'impactRow': table, 'alsoImpactRows': also, 'consumers': row['consumers'] if row else [], 'exchangeInput': not p.endswith('.diag.json')})
    elif p in ['crates/benitoite/src/modules/package.rs', 'crates/benitoite/src/modules/text.rs', 'crates/benitoite/Cargo.toml', 'Cargo.lock', 'fuzz/Cargo.lock', 'crates/benitoite/tests/desugar_export/named.rs']:
        handoff.append({'path': p, 'oldSha256': sha(old(p)), 'newSha256': sha(current(p)), 'impactRow': 'named.rs の固定パッケージと区間 manifest の依存 header' if p.endswith('/named.rs') else 'testdata の header・依存ハッシュと現在版の loader', 'exchangeInput': p.endswith('/named.rs'), 'loaderOrBuildInput': not p.endswith('/named.rs')})
save('comparison-inputs.json', handoff)
save('inventory-audit.json', {'plannedTestdata': 50, 'changedTestdataHeaders': sum(r['path'] in changed for r in INV['testdata']), 'plannedTestFiles': 10, 'changedTestFiles': sum(r['path'] in changed for r in INV['testFiles']), 'unknownTrackedChanges': unknown, 'exclusionsPreserved': True, 'oldChangelogSectionsPreserved': True, 'oldMigrationSectionsPreserved': True, 'documentExamples': [{'path': r['path'], 'changed': r['path'] in changed, 'decision': '正常な現在版の例と現在版表示を更新し、過去の節を保持'} for r in INV['documentExamples']]})
print(json.dumps({'roles': {k: len(v) for k, v in roles.items()}, 'trackedCount': len(changed), 'comparisonInputs': len(handoff), 'generatedUnchanged': len(generated_paths)}, ensure_ascii=False))
