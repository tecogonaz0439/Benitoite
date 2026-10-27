"""担当範囲・訂正の追記・保存物・文書のリンクとパスを点検する。"""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(HERE))
from state import digest


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True)


def main():
    changes = git('diff', '--name-only', 'd3f7c3e5327b7e97c57d959c46ce62997bf9f009').splitlines()
    assert not any(name.startswith('crates/benitoite/src/') for name in changes)
    assert not any(name.startswith('formal/') and not name.endswith('.py') for name in changes)
    prior = ['x05a/results.md', 'x05r/results.md', 'x05s/results.md', 'x05/results.md', 'results.md']
    for name in prior:
        path = HERE.parent/name
        old = git('show', 'd3f7c3e5327b7e97c57d959c46ce62997bf9f009:'+path.relative_to(ROOT).as_posix())
        current = path.read_text()
        assert current.startswith(old), ('original text not preserved', name)
        assert current[len(old):].startswith('\n## RV-X05 による訂正（2026-10-27）')
    records = json.loads((HERE/'local-records-index.json').read_text())
    archive = ROOT/records['archive']
    assert digest(archive) == records['zipSha256']
    with zipfile.ZipFile(archive) as saved:
        assert saved.namelist() == [e['path'] for e in records['entries']]
        for entry in records['entries']:
            data = saved.read(entry['path'])
            assert hashlib.sha256(data).hexdigest() == entry['sha256']
            if entry['path'].endswith('.json.gz'):
                json.loads(gzip.decompress(data))
            for forbidden in (str(ROOT).encode(), str(Path.home()).encode()):
                assert forbidden not in data, ('local path in archive', entry['path'])
    sys.path.insert(0, str(ROOT/'scripts/check'))
    import formal_interval as whole
    run = 'x05a-k1-run3-20261027'
    roots = {name: ROOT/'target'/(name+'-diff')/run for name in ('interval', 'desugar', 'coverage')}
    original = whole.read(roots['interval']/'manifest.json')
    assert whole.inventory(roots) == original['artifacts'], 'original K1 artifacts changed after work'
    assert digest(ROOT/'work/m012/records/x05a-run3-k1-records.zip') == '6986e19acfa40abad5507cca1583c7240f417ee96504b58b4ddd4da0e8e4aa9e'
    links = 0
    documents = [ROOT/name for name in changes if name.endswith('.md')]
    documents.append(HERE/'results.md')
    for path in documents:
        text = path.read_text()
        assert text.count('```') % 2 == 0, ('unpaired fence', path.name)
        for target in re.findall(r'\]\(([^)]+)\)', text):
            if target.startswith(('https:', 'http:', '#')):
                continue
            target = target.split('#')[0]
            assert (path.parent/target).exists(), (path.relative_to(ROOT).as_posix(), target)
            links += 1
    files = [p for p in HERE.iterdir() if p.is_file()]
    for path in files:
        assert path.stat().st_size <= 1024*1024, ('large raw record', path.name)
        text = path.read_text()
        assert str(ROOT) not in text and str(Path.home()) not in text, ('local path in record', path.name)
        if path.suffix == '.py':
            ast.parse(text, filename=path.name)
        elif path.suffix == '.json':
            json.loads(text)
    assert not re.search(r'\]\([^)]*docs/todo', (ROOT/'docs/design/07-quality/07-03-compiler-testing.md').read_text())
    assert not re.search(r'\]\([^)]*docs/todo', (ROOT/'docs/design/07-quality/07-04-formal-semantics.md').read_text())
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    record = dict(changes=changes, priorTextPreserved=prior, records=len(files), links=links,
                  localArchiveFiles=records['files'], localArchiveSha256=records['zipSha256'],
                  originalArtifactsPreserved=len(original['artifacts']), originalArchivePreserved=True,
                  productionRustAndLeanDefinitionsUnchanged=True, diffCheck=True)
    (HERE/'self-review.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    print('X05T: scope, original text, saved files, links and paths agree', flush=True)


if __name__ == '__main__':
    main()
