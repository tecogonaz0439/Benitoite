"""保存済み K1 と引用先の状態を読む。解析・評価・ビルドは実行しない。"""
import ast
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import zipfile

HERE = Path(__file__).resolve().parent
BATCH = HERE.parent
ROOT = HERE.parents[2]
ORIGINAL = BATCH / 'x05a/run3'
BASE = '732b29255e2de0a7116c4fc1dc056944cc5ac860'
RELATION = 'd62dbaa1c9293bd32e3dbb1b65b1efbc90a6d44b'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_hash(path):
    assert 'private' not in path.relative_to(ROOT).parts
    assert not path.is_symlink()
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def read(path):
    return json.loads(path.read_text())


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def save(name, value):
    (HERE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def evidence():
    index = read(ORIGINAL / 'k1-records-index.json')
    archive = ROOT / 'work/m012/records/x05a-run3-k1-records.zip'
    assert file_hash(archive) == index['zipSha256']
    entries = {item['path']: item for item in index['files']}
    assert len(entries) == index['count'] == 12064
    with zipfile.ZipFile(archive) as bundle:
        assert set(bundle.namelist()) == {n for n, f in entries.items() if f['persisted']}
        for name in bundle.namelist():
            assert digest(bundle.read(name)) == entries[name]['sha256'], name
        manifest_bytes = bundle.read('interval/manifest.json')
        manifest = json.loads(manifest_bytes)
        inputs = json.loads(bundle.read('interval/input-manifest.json'))
        summary = read(ORIGINAL / 'evidence-summary.json')
        assert digest(manifest_bytes) == summary['manifestSha256']
        assert len(manifest['artifacts']) == 12063
        assert len(inputs['artifacts']) == 1220
        for item in manifest['artifacts'] + inputs['artifacts']:
            entry = entries[item['root'] + '/' + item['path']]
            assert item['sha256'] == entry['originalSha256']
            if entry.get('sha256', entry['originalSha256']) == entry['originalSha256']:
                assert item['bytes'] == entry['bytes']
            else:
                # 伏せたパスの長さにより、保存後のバイト数だけが異なる。
                assert entry['path'] == 'desugar/named-programs-interval/interval-summary.json'
        counts = manifest['counts']
        assert counts == summary['manifest']['counts']
        assert counts['realSources'] == summary['sources']
        assert json.loads(bundle.read('interval/comparison/real-source-summary.json')) == summary['sources']
        assert len(counts['sourceDirectories']) == len(counts['realSources']) == 10
        sources = []
        for name, item in zip(counts['sourceDirectories'], counts['realSources']):
            assert item['rustLeanMatched']
            assert int(item['comparedBodies']) > 0
            assert int(item['informativeBodies']) > 0
            assert int(item['depthExcluded']) == int(item['phaseDepth']) == 0
            sources.append(dict(directory=name, **item))
        profiles = json.loads(bundle.read('interval/comparison/profile-manifest.json'))
        assert profiles['profiles'] == counts['profiles']
        assert len(counts['profiles']) == 10
        assert counts['vm']['arithmetic'] == 39
        assert counts['vm']['range'] == 37
        assert counts['vm']['shifts'] == 46
        assert counts['vm']['shiftsIndependentOnly'] == 62
        assert len(counts['log']['entries']) == 6
    save('evidence-check.json', dict(
        archiveSha256=index['zipSha256'], archiveBytes=archive.stat().st_size,
        indexedFiles=index['count'], persistedFiles=index['persistedCount'],
        hashOnlyFiles=index['hashOnlyCount'], redactedFiles=index['redactedCount'],
        allPersistedHashesMatched=True, manifestArtifacts=12063, inputArtifacts=1220,
        manifestSha256=digest(manifest_bytes), sources=sources,
        profiles=counts['profiles'], vm=counts['vm'], log=counts['log'],
        hashOnly=[f for f in index['files'] if not f['persisted']]))


def snapshot(name):
    assert git('rev-parse', 'HEAD').decode().strip() == BASE
    assert git('branch', '--show-current').decode().strip() == 'mod012/X05b'
    before = read(ORIGINAL / 'source-state-before.json')
    after = read(ORIGINAL / 'source-state-after.json')
    assert before['files'] == after['files']
    changed_sources = [p for p, h in before['files'].items() if file_hash(ROOT / p) != h]
    assert not changed_sources, changed_sources
    committed = git('diff', '--name-only', RELATION, 'HEAD').decode().splitlines()
    prefix = str(BATCH.relative_to(ROOT)) + '/'
    assert len(committed) == 52
    assert all(p.startswith(prefix + 'x05a/') or p == prefix + 'time-policy.md' for p in committed)
    tracked = git('diff', '--name-only', BASE).decode().splitlines()
    untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')
    untracked = [p for p in untracked if p]
    assert all(p == prefix + 'results.md' or p.startswith(prefix + 'x05/') or
               p.startswith(prefix + 'x05b/') for p in tracked + untracked)
    patch = git('diff', '--binary', BASE)
    executables = read(ORIGINAL / 'executables.json')
    assert all(file_hash(ROOT / p) == h for p, h in executables.items())
    stat = git('diff', '--stat', RELATION, 'HEAD').decode()
    (HERE / 'relation-diff-stat.log').write_text(stat)
    (HERE / 'relation-diff-files.log').write_bytes(git('diff', '--name-status', RELATION, 'HEAD'))
    save(name, dict(time=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        base=BASE, head=git('rev-parse', 'HEAD').decode().strip(), relation=RELATION,
        sourceSnapshot='x05a/run3/source-state-before.json', sourceFilesChecked=len(before['files']),
        sourceFilesChanged=changed_sources, committedRecordFiles=committed,
        trackedChanges=tracked, untrackedFiles=untracked, trackedDiffSha256=digest(patch),
        workingFileSha256={p: file_hash(ROOT / p) for p in tracked + untracked
                           if ROOT / p != HERE / name},
        snapshotExcludesSelf=True, executableHashesUnchanged=executables,
        explanation='保存時に存在する全差分と未追跡ファイルを記録する。この JSON 自身は保存後に存在するため除く。'))


def document_check():
    links = 0
    files = [BATCH / 'results.md', BATCH / 'x05/results.md', HERE / 'results.md']
    old_results = git('show', BASE + ':' + str(files[0].relative_to(ROOT))).decode()
    assert files[0].read_text().startswith(old_results)
    for path in files:
        body = path.read_text()
        for target in re.findall(r'\]\(([^)]+)\)', body):
            if '://' in target or target.startswith('#'):
                continue
            assert (path.parent / target.split('#')[0]).exists(), target
            links += 1
    with zipfile.ZipFile(ROOT / 'work/m012/records/x05a-run3-k1-records.zip') as bundle:
        actual_sources = json.loads(bundle.read('interval/comparison/real-source-summary.json'))
        assert actual_sources == read(ORIGINAL / 'evidence-summary.json')['sources']
    for path in HERE.iterdir():
        if path.suffix == '.py':
            ast.parse(path.read_text())
        elif path.suffix == '.json':
            read(path)
    for path in files + list(HERE.iterdir()):
        if path.is_file():
            assert path.stat().st_size <= 1000000
            text = path.read_text()
            for forbidden in [str(ROOT), str(Path.home()), tempfile.gettempdir()]:
                assert forbidden not in text, path.name
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    save('document-check.json', dict(linksChecked=links, pythonSyntax=True,
        jsonSyntax=True, localPathsRedacted=True, gitDiffCheck=0,
        archivedSourceSummaryMatched=True, priorStageTextPreserved=True))


if __name__ == '__main__':
    if sys.argv[1] == 'evidence':
        evidence()
    elif sys.argv[1] == 'snapshot':
        snapshot(sys.argv[2])
    elif sys.argv[1] == 'documents':
        document_check()
    else:
        raise SystemExit('unknown mode')
