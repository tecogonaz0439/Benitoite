"""開始時の指紋と全言明から監査対象と差の表を作る。Gitは呼ばない。"""
import argparse
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
CHANGE = HERE.parents[2]
EXTRACT = {'__file__': str(HERE.parent / 'verify.py')}
exec((HERE.parent / 'verify.py').read_text().split('parser = argparse.ArgumentParser')[0], EXTRACT)

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def save(p, value):
    p.write_text(json.dumps(value, ensure_ascii=False, indent=1) + '\n')

def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()

def files():
    return {str(p.relative_to(ROOT)): digest(p)
            for pre in ['formal', 'docs/design', 'crates', 'scripts']
            for p in (ROOT / pre).rglob('*') if p.is_file()
            and not set(p.parts) & {'.lake', 'target', '.git', '__pycache__'}}

def sources():
    return {p: h for p, h in files().items() if p.startswith('formal/') or p in {
        'docs/design/01-spec/01-12-core-calculus.md',
        'docs/design/07-quality/07-04-formal-semantics.md'}}

def reachable():
    visited = set()
    pending = ['Benitoite']
    while pending:
        name = pending.pop()
        if name in visited:
            continue
        visited.add(name)
        path = ROOT / 'formal' / (name.replace('.', '/') + '.lean')
        pending.extend(re.findall(r'^import (Benitoite(?:\.[\w]+)*)$', path.read_text(), re.M))
    return visited

def new_signatures(source):
    """新規ファイルは別namespaceの同じ短名も保持する。全宣言の正式名はLean監査で別に得る。"""
    code = EXTRACT['code_only'](source)
    pattern = EXTRACT['PATTERN']
    matches = list(pattern.finditer(code))
    counts = {m[1]: sum(n[1] == m[1] for n in matches) for m in matches}
    headers = {}
    for match in matches:
        stack = []
        i = match.end()
        while i < len(code):
            c = code[i]
            if not stack and (code.startswith(':=', i) or
                              (c == '|' and not code[code.rfind('\n', 0, i) + 1:i].strip())):
                break
            if c in '([{⟨':
                stack.append(c)
            elif c in ')]}⟩':
                assert stack and stack.pop() == dict(zip(')]}⟩', '([{⟨'))[c]
            i += 1
        assert i < len(code) and not stack
        name = match[1]
        key = name if counts[name] == 1 else name + '@' + str(code.count('\n', 0, match.start()) + 1)
        header = ' '.join((name + source[match.end():i]).split())
        headers[key] = hashlib.sha256(header.encode()).hexdigest()
    return headers

def inventory(tmp):
    assert EXTRACT['signature_selftest']() == 8
    before = json.loads((tmp / 'baseline-files.json').read_text())
    current = files()
    assert not (before.keys() - current.keys()), '開始時のファイルが消えている'
    changed = sorted(p for p in before if before[p] != current[p])
    added = sorted(current.keys() - before.keys())
    allowed = {'formal/Benitoite.lean',
               'docs/design/01-spec/01-12-core-calculus.md',
               'docs/design/07-quality/07-04-formal-semantics.md'}
    prefix = 'formal/Benitoite/Release/Refinement/Surface/'
    assert all(p in allowed or p.startswith(prefix) for p in changed + added), changed + added
    modules = sorted(p[7:-5].replace('/', '.') for p in changed + added
                     if p.startswith('formal/') and p.endswith('.lean'))
    save(HERE / 'audit-modules.json', modules)
    old = json.loads((tmp / 'baseline-signatures.json').read_text())
    signatures = EXTRACT['signature_hashes']
    new = {str(p.relative_to(ROOT)):
           (signatures(p.read_text()) if str(p.relative_to(ROOT)) in old else new_signatures(p.read_text()))
           for p in (ROOT / prefix).glob('*.lean')}
    differences = {}
    for p, rows in old.items():
        after = new.get(p, {})
        assert not (rows.keys() - after.keys()), ('言明の削除', p)
        diffs = {n: {'before': h, 'after': after[n]} for n, h in rows.items() if h != after[n]}
        if diffs:
            differences[p] = diffs
    save(HERE / 'statement-differences.json', differences)
    save(tmp / 'current-signatures.json', new)
    save(HERE / 'inventory-summary.json', {
        'b_work': '73585979113c7acf25b38673f9c2c52d1d38dfaf',
        'changed': changed, 'added': added, 'modules': len(modules),
        'baseline': {n: {'bytes': (tmp / n).stat().st_size, 'sha256': digest(tmp / n)}
                     for n in ['baseline-files.json', 'baseline-signatures.json', 'baseline-root.lean']},
        'statements_before': sum(map(len, old.values())),
        'current_signature_bytes': (tmp / 'current-signatures.json').stat().st_size,
        'current_signature_sha256': digest(tmp / 'current-signatures.json'),
        'source_fingerprint': fingerprint(sources()),
    })
    return modules, differences

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmp', type=Path, required=True)
    args = parser.parse_args()
    modules, differences = inventory(args.tmp)
    print(json.dumps({'modules': len(modules), 'changed_statements': sum(map(len, differences.values()))}))
