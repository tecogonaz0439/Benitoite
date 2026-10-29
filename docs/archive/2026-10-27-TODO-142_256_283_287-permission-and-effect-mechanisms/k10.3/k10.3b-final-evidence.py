#!/usr/bin/env python3
"""先行の証拠を保持し、変更範囲と引用する形式化入力の不変を確認する。"""
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


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()


def main():
    initial = json.loads((OUT / 'k10.3b-initial-state.json').read_text())
    previous = json.loads(gzip.decompress((OUT / 'source-state.json.gz').read_bytes()))
    head = git('rev-parse', 'HEAD')
    branch = git('branch', '--show-current')
    assert head == initial['head'] and branch == initial['branch']
    assert digest(Path(git('rev-parse', '--git-path', 'index'))) == initial['indexSha256']
    for name, sha in initial['files'].items():
        if name.endswith(('plan-r10-r40.md', 'reviews/RV-K10.3.md')):
            assert digest(ROOT / name) == sha, name
    expected = {'scripts/check/test_policy.py', 'crates/benitoite/tests/desugar_export.rs',
                'docs/design/07-quality/07-04-formal-semantics.md'}
    hashes = {}
    for name in previous['sourceHashes']:
        assert 'private' not in Path(name).parts
        assert not name.startswith('docs/todo/')
        resolved = (ROOT / name).resolve()
        assert not resolved.is_relative_to(ROOT / 'private')
        assert not resolved.is_relative_to(ROOT / 'docs/todo')
        hashes[name] = digest(ROOT / name)
    changed = {name for name, sha in hashes.items() if sha != previous['sourceHashes'][name]}
    assert changed == expected, sorted(changed)
    assert not git('ls-files', '--others', '--exclude-standard', '--', 'crates/benitoite', 'formal', 'scripts')
    patch = subprocess.check_output(['git', 'diff', '--binary', head, '--',
                                     *previous['changed']], cwd=ROOT)
    (OUT / 'k10.3b-source-diff.patch').write_bytes(patch)
    for p in [ROOT / 'scripts/check/test_policy.py', *OUT.glob('k10.3b-*.py')]:
        ast.parse(p.read_text())
    for p in OUT.glob('k10.3b-*'):
        if p.suffix in ('.log', '.json', '.py', '.patch'):
            text = p.read_text()
            assert str(ROOT) not in text and str(Path.home()) not in text, p.name
    for target in re.findall(r'\]\(([^)]+)\)', (OUT / 'results.md').read_text()):
        if not target.startswith(('https:', 'http:', '#')):
            assert (OUT / target.split('#')[0]).exists(), target
    state = dict(head=head, branch=branch, indexUnchanged=True,
                 protectedReviewAndPlanUnchanged=True,
                 previousSourceStateSha256=digest(OUT / 'source-state.json.gz'),
                 comparedSourceFiles=len(hashes), changedSinceK103=sorted(changed),
                 sourceHashes=hashes, diffSha256=digest(OUT / 'k10.3b-source-diff.patch'),
                 recordScripts={p.name: digest(p) for p in OUT.glob('k10.3b-*.py')},
                 resultsSha256=digest(OUT / 'results.md'),
                 checkedAt=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (OUT / 'k10.3b-final-state.json.gz').write_bytes(gzip.compress(
        json.dumps(state, ensure_ascii=False, sort_keys=True).encode(), mtime=0))
    print(json.dumps({k: v for k, v in state.items() if k != 'sourceHashes'},
                     ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
