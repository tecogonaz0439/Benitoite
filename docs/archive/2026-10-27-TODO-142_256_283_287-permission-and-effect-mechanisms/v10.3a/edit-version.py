"""確認済み一覧に従い、登録案と正常な版宣言を同時に適用する。"""
from pathlib import Path
import hashlib
import json
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
INV = json.loads((OUT.parent / 'v10.1b/j2-rewrite-inventory.json').read_text())

def write(path, old, new):
    p = ROOT / path
    source = p.read_bytes()
    assert old in source, path
    p.write_bytes(source.replace(old, new))

def sha(data):
    return hashlib.sha256(data).hexdigest()

def digest(files):
    summary = b''.join((sha(data) + '  ' + path + '\n').encode()
                       for path, data in sorted(files.items(), key=lambda x: x[0].encode()))
    return 'sha256:' + sha(summary)

assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT).decode().strip() == '92f9ac80f81d2299978d2051ddcdfdeea1843e6d'
assert not subprocess.check_output(['git', 'diff', '--name-only'], cwd=ROOT).strip()
old_files = {r['path']: (ROOT / r['path']).read_bytes() for r in INV['testdata'] + INV['testFiles']}
for row in INV['testdata'] + INV['testFiles']:
    assert sha(old_files[row['path']]) == row['sha256'], row['path']

subprocess.run(['patch', '-p1', '-i', str(OUT.parent / 'v10.1b/j2-registration-proposal.patch')], cwd=ROOT, check=True)
write('crates/benitoite/Cargo.toml', b'version = "0.0.12"', b'version = "0.0.13"')
counts = []
for row in INV['testdata'] + INV['testFiles']:
    p = ROOT / row['path']
    source = p.read_bytes()
    changed = source.replace(b'language "0.0.12"', b'language "0.0.13"').replace(b'language \\"0.0.12\\"', b'language \\"0.0.13\\"')
    assert source != changed, row['path']
    p.write_bytes(changed)
    counts.append({'path': row['path'], 'oldSha256': sha(old_files[row['path']]), 'newSha256': sha(changed)})

for row in INV['diagnostics']:
    if row['path'].endswith('older-language.diag.json'):
        p = ROOT / row['path']
        data = json.loads(p.read_text())
        data['notes'].append('0.0.13: handlers with only an Http.send clause are partial handlers; Http.Connect remains unhandled')
        data['helps'].append({'message': 'Http.Connect declares send and sendIn; a handler that handles only Http.send leaves Http.Connect in the effect contract', 'edits': []})
        p.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
    else:
        write(row['path'], b'this is Benitoite 0.0.12', b'this is Benitoite 0.0.13')

hashkit = ROOT / 'crates/benitoite/testdata/packages/hash-match/deps/hashkit'
hashkit_files = {p.name: p.read_bytes() for p in hashkit.iterdir() if p.is_file()}
module_files = {'package.bnt': b'language "0.0.13"\npackage Textkit\nend package\n', 'Z.bnt': b'abc\r\n', 'A/Sub.bnt': b'abc\n', 'License.md': b'MIT\n', 'readme.md': b'example\n', 'COPYING': b'copy\n', 'wasm/x.wasm': bytes([0, 97, 115, 109, 255])}
package_files = {'package.bnt': b'language "0.0.13"\n\npackage Words\nend package\n', 'Value.bnt': b'import Benitoite.Unofficial.IO.File\n\npublic function read() -> Unit uses File.Read\n  ()\nend function\n'}
hash_rows = []
for row, files in zip(INV['hashProposals'], [hashkit_files, module_files, package_files]):
    previous = {p: b.replace(b'language "0.0.13"', b'language "0.0.12"') for p, b in files.items()}
    assert digest(previous) == row['old'], row['name']
    value = digest(files)
    assert value == row['proposed'], row['name']
    for target in row['targets']:
        write(target.split('::')[0], row['old'].encode(), value.encode())
    hash_rows.append({'name': row['name'], 'old': row['old'], 'new': value, 'targets': row['targets'], 'inputs': [{'path': p, 'sha256': sha(b)} for p, b in files.items()]})
(OUT / 'hash-updates.json').write_text(json.dumps(hash_rows, ensure_ascii=False, indent=2) + '\n')
(OUT / 'version-inputs.json').write_text(json.dumps(counts, ensure_ascii=False, indent=2) + '\n')

for path in ['docs/design/01-spec/01-02-syntax.md', 'docs/design/06-tooling/06-09-packages.md']:
    write(path, b'language "0.0.12"', b'language "0.0.13"')

p = ROOT / 'docs/reference/benitoite.md'
lines = p.read_text().splitlines(keepends=True)
for i, line in enumerate(lines):
    if ('This reference describes' in line or 'benitoite 0.0.12' in line
        or '"version": "0.0.12"' in line or 'through `0.0.12`' in line
        or line.startswith('For Benitoite `0.0.12`') or line.startswith('`language "MAJOR.MINOR.PATCH"`')
        or line.strip() == 'language "0.0.12"'):
        lines[i] = line.replace('0.0.12', '0.0.13')
p.write_text(''.join(lines))
p = ROOT / 'docs/reference/install.md'
lines = p.read_text().splitlines(keepends=True)
for i in range(6):
    lines[i] = lines[i].replace('0.0.12', '0.0.13')
p.write_text(''.join(lines))
write('README.md', b'`0.0.12` ([changes and migration](CHANGELOG.md#0012-san-benito))', b'`0.0.13` ([changes](CHANGELOG.md#0013-san-benito))')

p = ROOT / 'CHANGELOG.md'
source = p.read_text()
source = source.replace('Every incompatible change is listed with how to migrate.', 'Incompatible changes are listed in each release section.')
release = '''## 0.0.13 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.13`.

### Scoped effects and checked targets

- Add scoped effect bounds for file paths and HTTP endpoints, with checked `Scope.PathIn` and `Http.RequestIn` values. Bounds describe static upper limits; they do not enforce runtime permissions or information-flow control.
- Add `File.readTextIn`, `File.readBytesIn`, `File.writeTextIn`, `File.appendTextIn`, `File.writeBytesIn`, `File.appendBytesIn`, and `Http.sendIn`. These operations retain checked targets and carry their input types' target scopes in their effects.
- A handler with only an `Http.send` clause is a partial handler; `Http.Connect` remains unhandled because the effect also contains `Http.sendIn`.
- Add declared target `bounds` to inspection reports alongside expanded effect names. Unknown or incomplete contracts remain distinct from empty effect sets.
- Update development derive declaration inventories and semantic hashes to version 4. Old manifests and receipts cannot approve new inputs.
- Register the language compatibility boundary at `0.0.13`: earlier declarations report E0908, `0.0.13` passes, and later declarations report E0907.

'''
assert '## 0.0.13' not in source
p.write_text(source.replace('## 0.0.12 (San Benito)', release + '## 0.0.12 (San Benito)', 1))
print('版・登録・60ファイルの正常な宣言・診断・ハッシュ・公開文書を同期した')
