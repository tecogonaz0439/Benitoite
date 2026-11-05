"""全環境を再監査し、保存済みの一回分の宣言・実署名との差だけを記録する。"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
from inventory import HERE, digest, write
from composition_inventory import read_pages


def collect(tmp):
    path = tmp / 'resume4-audit-final.log'
    text = path.read_text()
    execution = json.loads((HERE / 'resume4-audit-final.json').read_text())
    assert execution['exit'] == 0 and execution['raw'] == digest(path)
    assert not re.search(r'error:|warning:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)', text)
    names = re.findall(r'^AUDIT_TARGET (.+)$', text, re.M)
    count = int(re.search(r'^AUDIT_COUNT (\d+)$', text, re.M)[1])
    assert len(set(names)) == len(names) == count
    axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", text, re.M | re.S)
    assert Counter(names) == Counter(n for n, _ in axioms)
    sets = Counter(tuple(sorted(a.strip() for a in deps.split(',') if a.strip())) for _, deps in axioms)
    assert all(set(s) <= {'propext', 'Quot.sound', 'Classical.choice'} for s in sets)
    modules = {m: int(n) for m, n in re.findall(r'^AUDIT_MODULE (\S+) (\d+)$', text, re.M)}
    assert sum(modules.values()) == count
    declarations = [{'module': m, 'kind': k, 'line': int(line), 'name': n}
        for m, k, line, n in re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', text, re.M)]
    baseline = json.loads((HERE / 'resume3-audit-summary.json').read_text())
    old = {r['name']: r for r in read_pages(baseline, 'declaration_pages')}
    current = {r['name']: r for r in declarations}
    assert len(current) == len(declarations)
    assert set(old) <= set(current), sorted(set(old) - set(current))
    added = [r for n, r in current.items() if n not in old]
    moved = [{'name': n, 'line': r['line']} for n, r in current.items() if n in old and r['line'] != old[n]['line']]
    for n, r in current.items():
        if n in old:
            assert (r['module'], r['kind']) == (old[n]['module'], old[n]['kind'])
    stored = defaultdict(list)
    for row in read_pages(baseline, 'signature_pages'):
        stored[row['name']].append(row)
    old_types = {}
    for n, rs in stored.items():
        if 'type' in rs[0]:
            assert len(rs) == 1
            old_types[n] = rs[0]['type']
        else:
            rs.sort(key=lambda r: r['type_fragment'])
            assert [r['type_fragment'] for r in rs] == list(range(rs[0]['type_fragments']))
            full = ''.join(r['type_piece'] for r in rs)
            assert len(full.encode()) == rs[0]['type_bytes']
            assert hashlib.sha256(full.encode()).hexdigest() == rs[0]['type_sha256']
            old_types[n] = full
    signatures = {n: typ.strip() for _, n, _, typ in re.findall(
        r'^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$', text, re.M | re.S)}
    assert old_types == signatures, '既存の実署名が変わった'
    changed = json.loads((HERE / 'changed-modules.json').read_text())
    assert len(declarations) == sum(modules[m] for m in changed)
    result = {'targets': count, 'group_a_declarations': len(declarations),
        'private_declarations': sum(n.startswith('_private.') for n in current),
        'new_modules': {m: modules[m] for m in changed},
        'new_axioms': 0, 'sorryAx': 0,
        'axiom_sets': [{'axioms': list(s), 'count': c} for s, c in sorted(sets.items())],
        'retained_snapshot': {'file': 'resume3-audit-summary.json', **digest(HERE / 'resume3-audit-summary.json')},
        'snapshot_note': '宣言と実署名の写しは再開3の一回分を保持し、現在の監査との追加・行番号の差だけをここへ記録する。全署名の断片を復元して現在の生出力と一致させた',
        'added_declarations': added, 'moved_declarations': moved,
        'unchanged_signature_declarations': len(signatures),
        'input': digest(HERE / 'axioms.lean'), 'execution': execution}
    write(HERE / 'resume4-audit-summary.json', result)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tmp', type=Path, required=True)
    result = collect(parser.parse_args().tmp)
    print(json.dumps({k: result[k] for k in ['targets', 'group_a_declarations', 'private_declarations', 'new_axioms', 'sorryAx', 'unchanged_signature_declarations']}, ensure_ascii=False))
