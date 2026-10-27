"""保存物・入力状態・旧記録・パスの伏せ方を点検する。検査本体は起動しない。"""
import gzip
import hashlib
import json
from pathlib import Path
import re
import runpy
import subprocess
import tempfile
import zipfile
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
redact = runpy.run_path(str(HERE/'run.py'))['redact']

def digest(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()

def scan(stream):
    needles = [str(p).encode() for p in [ROOT,Path.home(),Path(tempfile.gettempdir())]]
    carry = b''
    while True:
        block = stream.read(1024*1024)
        if not block:
            break
        value = carry+block
        assert not any(n in value for n in needles), 'local path persisted'
        carry = value[-max(map(len,needles)):]

def main():
    before = json.loads((HERE/'source-state-before.json').read_text())
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip() == before['head']
    assert all(digest(ROOT/name)==wanted for name,wanted in before['files'].items())
    old = json.loads((HERE/'first-run-files.json').read_text())
    assert all(digest(HERE.parent/name)==wanted for name,wanted in old.items() if name!='results.md')
    original = subprocess.check_output(['git','show',before['head']+':'+str((HERE.parent/'results.md').relative_to(ROOT))],cwd=ROOT,text=True)
    results = (HERE.parent/'results.md').read_text()
    assert original.split('\n',1)[1] in results, 'first run text changed'
    index = json.loads((HERE/'k1-records-index.json').read_text())
    assert digest(HERE/'k1-records.zip') == index['zipSha256']
    gzip_count = 0
    with zipfile.ZipFile(HERE/'k1-records.zip') as archive:
        assert set(archive.namelist())=={r['path'] for r in index['files'] if r['persisted']}
        for row in index['files']:
            if not row['persisted']:
                assert not row['path'].endswith(('.log','.report.json','-report.json'))
                continue
            with archive.open(row['path']) as stream:
                scan(stream)
            if row['path'].endswith('.gz'):
                with archive.open(row['path']) as stream:
                    with gzip.GzipFile(fileobj=stream) as uncompressed:
                        scan(uncompressed)
                gzip_count+=1
    for path in HERE.iterdir():
        if path.suffix == '.zip' or not path.is_file():
            continue
        with path.open('rb') as stream:
            scan(stream)
        if path.suffix=='.py': compile(path.read_text(),path.name,'exec')
        if path.suffix=='.json': json.loads(path.read_text())
    assert not any(v in results for v in [str(ROOT),str(Path.home()),tempfile.gettempdir()])
    links=[]
    for match in re.finditer(r'\[[^\]]*\]\(([^)]+)\)',results):
        link=match.group(1).split('#')[0]
        if not link or '://' in link: continue
        assert (HERE.parent/link).exists(), link
        links.append(link)
    check=subprocess.run(['git','diff','--check'],cwd=ROOT,capture_output=True,text=True)
    assert check.returncode==0,check.stdout+check.stderr
    record=dict(sourceInputCount=len(before['files']),sourceInputsUnchanged=True,
         firstRunFilesUnchanged=len(old)-1,firstRunTextPreserved=True,archiveCount=index['count'],
         persistedCount=index['persistedCount'],hashOnlyCount=index['hashOnlyCount'],gzipScanned=gzip_count,
         pathsRedacted=True,linksChecked=len(links),gitDiffCheck=check.returncode)
    (HERE/'self-review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(record,ensure_ascii=False))

if __name__ == '__main__': main()
