"""差分・保存物・相対参照・圧縮入力と結果のリンクを最後に照合する。"""
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def sha(data):
    return hashlib.sha256(data).hexdigest()

base = 'ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c'
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
assert head == base
branch = subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT, text=True).strip()
assert branch == 'mod012/X05R'
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
changed = subprocess.check_output(['git', 'diff', '--name-only', base], cwd=ROOT, text=True).splitlines()
assert not any(p.startswith('crates/benitoite/src/') or p.endswith('.lean') for p in changed)
assert not any(p.endswith('Cargo.lock') or p.endswith('Cargo.toml') for p in changed)
assert 'formal/lakefile.toml' not in changed
source_files = changed + ['scripts/check/interval_artifacts.py']
sources = [dict(path=name, bytes=(ROOT/name).stat().st_size, sha256=sha((ROOT/name).read_bytes()))
           for name in source_files]
(HERE/'implementation-hashes.json').write_text(json.dumps(dict(base=base, head=head, branch=branch,
    files=sources, diffSha256=sha(subprocess.check_output(['git','diff',base], cwd=ROOT))), indent=2)+'\n')
index = json.loads((HERE/'local-records-index.json').read_text())
archive_path = HERE/'local-records.zip'
assert sha(archive_path.read_bytes()) == index['zipSha256']
checked_gzip = indexes = input_hashes = 0
with zipfile.ZipFile(archive_path) as archive:
    names = set(archive.namelist())
    assert len(names) == len(index['files']) == index['count']
    for row in index['files']:
        data = archive.read(row['path'])
        assert len(data) == row['bytes'] and sha(data) == row['sha256']
        if row['path'].endswith('.gz'):
            data = gzip.decompress(data)
            json.loads(data)
            checked_gzip += 1
        assert str(ROOT).encode() not in data and str(Path.home()).encode() not in data, row['path']
        if row['path'].endswith('.json'):
            value = json.loads(data)
            if isinstance(value, dict) and value.get('kind') == 'interval-source-index':
                for source in value['sources']:
                    target = posixpath.normpath(str(PurePosixPath(row['path']).parent/source))
                    assert target in names, target
                    json.loads(archive.read(target))
                indexes += 1
    manifest = json.loads(archive.read('target/interval-diff/x05r-indexed-final/input-manifest.json'))
    roots = dict(interval='target/interval-diff/x05r-indexed-final',
                 desugar='target/desugar-diff/x05r-local', coverage='target/coverage-diff/x05r-local')
    for row in manifest['artifacts']:
        data = archive.read(roots[row['root']]+'/'+row['path'])
        assert len(data) == row['bytes'] and sha(data) == row['sha256']
        input_hashes += 1
for path in HERE.iterdir():
    if path.suffix in ('.py', '.md', '.log', '.json'):
        data = path.read_bytes()
        assert str(ROOT).encode() not in data and str(Path.home()).encode() not in data, path.name
        if path.suffix == '.py':
            compile(data, path.name, 'exec')
links = re.findall(r'\]\(([^)]+)\)', (HERE/'results.md').read_text())
for link in links:
    assert (HERE/link.split('#',1)[0]).is_file(), link
body = json.loads((HERE/'work-body.json').read_text())
outer = json.loads((HERE/'work.json').read_text())
assert body['exit'] == 0 and outer['exit'] == 1
assert 'selected checks passed' in (HERE/'work.log').read_text()
assert 'sysctl kern.clockrate: Operation not permitted' in (HERE/'work.log').read_text()
summary = dict(base=base, head=head, branch=branch, sourceFiles=len(source_files),
              leanDefinitionsUnchanged=True, productionRustUnchanged=True,
              archiveFiles=index['count'], gzipInputs=checked_gzip,
              sharedIndexes=indexes, archivedInputHashes=input_hashes,
              resultLinks=len(links), workBodyExit=body['exit'], timeExit=outer['exit'],
              maximumResidentSetSize='unavailable: sandbox sysctl denial')
(HERE/'self-review.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(summary, ensure_ascii=False))
