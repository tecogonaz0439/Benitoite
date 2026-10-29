#!/usr/bin/env python3
"""関係する入力・差分・最終manifestのハッシュと、許可範囲の照合を保存する。"""
import ast
import datetime
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = 'd35557f93ca65e73a841a17d6f19f1b79cf04464'


def require(value, message):
    if not value:
        raise AssertionError(message)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    initial = json.loads((OUT / 'initial-state.json').read_text())
    head = git('rev-parse', 'HEAD').decode().strip()
    require(head == BASE, 'HEAD changed')
    require(git('branch', '--show-current').decode().strip() == 'm013/k10.3', 'branch changed')
    require(not git('diff', '--cached', '--name-only'), 'index differs from HEAD')
    paths = git('diff', '--name-only', BASE).decode().splitlines()
    allowed = {
        'crates/benitoite/tests/desugar_export.rs',
        'crates/benitoite/tests/desugar_export/check_named.py',
        'scripts/check/test_policy.py',
        'docs/design/07-quality/07-03-compiler-testing.md',
        'docs/design/07-quality/07-04-formal-semantics.md',
    }
    require(set(paths) == allowed, 'unexpected changed paths: ' + str(paths))
    for name in paths:
        if name.startswith('docs/design/'):
            before = git('show', BASE + ':' + name).decode()
            after = (ROOT / name).read_text()
            require(re.findall(r'^#{1,6} .*', before, re.M) == re.findall(r'^#{1,6} .*', after, re.M),
                    'design headings changed')
            require(re.findall(r'^```.*?^```[^\n]*', before, re.M | re.S) ==
                    re.findall(r'^```.*?^```[^\n]*', after, re.M | re.S), 'design code examples changed')
    patch = git('diff', '--binary', BASE)
    require(str(ROOT).encode() not in patch and str(Path.home()).encode() not in patch, 'absolute path in patch')
    (OUT / 'source-diff.patch').write_bytes(patch)
    hashes = {name: digest(ROOT / name) for name in initial['inputsAfterInitialFix']}
    changed = [name for name, sha in hashes.items() if sha != initial['inputsAfterInitialFix'][name]]
    # 初期の一覧は書き出し元と読者の修正直後、policy追加前に採った。
    require(changed == ['scripts/check/test_policy.py'], 'unexpected semantic input change: ' + str(changed))
    hashes.update({name: digest(ROOT / name) for name in paths})
    baseline = dict(hashes)
    for name in paths:
        baseline[name] = hashlib.sha256(git('show', BASE + ':' + name)).hexdigest()
    source_state = dict(head=head, base=BASE, recordedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        changed=paths, diffSha256=hashlib.sha256(patch).hexdigest(),
                        sourceHashes=hashes, reconstructedBaseHashes=baseline,
                        untrackedSourceInputs=git('ls-files', '--others', '--exclude-standard', '--',
                                                 'crates/benitoite', 'formal', 'scripts').decode().splitlines(),
                        leanSourcesSettingsAndExecutablesUnchanged=True,
                        initialSnapshotTiming='一回目F終了後、入口失敗とNoMainFileの二修正直後。実行前採取とはしない')
    require(not source_state['untrackedSourceInputs'], 'unexpected untracked source')
    raw = json.dumps(source_state, ensure_ascii=False, sort_keys=True).encode()
    (OUT / 'source-state.json.gz').write_bytes(gzip.compress(raw, mtime=0))
    manifests = {}
    for name in ['target/interval-diff/k10.3/input-manifest.json',
                 'target/interval-diff/k10.3/manifest.json',
                 'target/interval-diff/k10.3/manifest-comparison.json']:
        p = ROOT / name
        manifests[name] = dict(bytes=p.stat().st_size, sha256=digest(p))
    checked_python = []
    for p in [ROOT / 'crates/benitoite/tests/desugar_export/check_named.py',
              ROOT / 'scripts/check/test_policy.py', *OUT.glob('*.py')]:
        ast.parse(p.read_text(), filename=str(p.relative_to(ROOT)))
        checked_python.append(str(p.relative_to(ROOT)))
    for p in OUT.rglob('*'):
        if p.is_file() and p.suffix in ('.md', '.json', '.log', '.txt', '.py', '.patch'):
            text = p.read_text()
            require(str(ROOT) not in text and str(Path.home()) not in text, 'absolute location: ' + p.name)
            if p.suffix == '.md':
                for target in re.findall(r'\]\(([^)]+)\)', text):
                    if not target.startswith(('https:', 'http:', '#')):
                        require((p.parent / target.split('#')[0]).exists(), 'broken link: ' + target)
    result = dict(exit=0, head=head, changed=paths, sourceFiles=len(hashes),
                  changedSinceInitialFix=changed, pythonSyntaxChecked=checked_python,
                  manifests=manifests, sourceStateSha256=digest(OUT / 'source-state.json.gz'),
                  initialStateSha256=digest(OUT / 'initial-state.json'),
                  recordScripts={p.name: digest(p) for p in OUT.glob('*.py')},
                  absoluteLocationsAbsent=True, relativeFileLinksResolved=True,
                  designHeadingsAndCodeExamplesUnchanged=True,
                  indexAndBranchUnchanged=True)
    (OUT / 'final-verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('manifests', 'pythonSyntaxChecked')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
