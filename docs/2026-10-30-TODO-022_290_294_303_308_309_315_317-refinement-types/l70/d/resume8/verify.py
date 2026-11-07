"""既定import、公理の全宣言、群Dの308言明、群Eの言明と作業範囲を照合する。"""
import argparse
import collections
import hashlib
import json
import re
from pathlib import Path
from inventory import HERE, ROOT, CHANGE, EXTRACT, digest, save, fingerprint, sources, reachable, inventory

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tmp', type=Path, required=True)
args = parser.parse_args()
tmp = args.tmp
modules, differences = inventory(tmp)
assert set(modules) <= reachable(), '追加・変更モジュールの既定importが不足'
copy = (ROOT / 'docs/design/07-quality/07-04-formal-semantics.md').read_text()
summary = json.loads((HERE / 'inventory-summary.json').read_text())
for p in summary['added']:
    if p.startswith('formal/') and p.endswith('.lean'):
        assert p[7:-5].replace('/', '.').removeprefix('Benitoite.Release.Refinement.') in copy, p
old_root = (tmp / 'baseline-root.lean').read_text().splitlines()
new_root = (ROOT / 'formal/Benitoite.lean').read_text().splitlines()
assert all(line in new_root for line in old_root), '既定importの除外'
imports = [line for line in new_root if line.startswith('import ')]
assert len(imports) == len(set(imports)), '既定importの重複'
code_only = EXTRACT['code_only']
for p in summary['changed'] + summary['added']:
    if p.endswith('.lean'):
        source = (ROOT / p).read_text()
        assert not re.search(r'\b(?:sorry|axiom|native_decide)\b|#eval', code_only(source)), p
        assert not re.search(r'(?:L[0-9]{2}|RV-L70|J70-[0-9])', source), p

signatures = EXTRACT['signature_hashes']
current = json.loads((tmp / 'current-signatures.json').read_text())
ledger = json.loads((HERE.parent / 'resume7-signatures.json').read_text())
assert sum(map(len, ledger.values())) == 308
approved = json.loads((HERE.parent / 'resume7-signature-differences.json').read_text())
actual = {}
for p, rows in ledger.items():
    for name, before in rows.items():
        assert name in current[p], (p, name)
        if current[p][name] != before:
            actual.setdefault(p, {})[name] = {'before': before, 'after': current[p][name]}
assert actual == approved, ('308件の承認済み二差以外の差', actual)
old = json.loads((tmp / 'baseline-signatures.json').read_text())
e_paths = {p: rows for p, rows in old.items() if Path(p).stem.startswith('Check')}
e_changes = {p: rows for p, rows in differences.items() if p in e_paths}
for p, rows in e_paths.items():
    assert rows.keys() <= current[p].keys(), ('群Eの言明の削除', p)
e_ledger = json.loads((CHANGE / 'l70/d-int/resume1-e-ledger.json').read_text())
assert sum(map(len, e_ledger.values())) == 617
e_ledger_differences = {}
for p, rows in e_ledger.items():
    for name, before in rows.items():
        assert name in current[p], (p, name)
        if current[p][name] != before:
            e_ledger_differences.setdefault(p, {})[name] = {'before': before, 'after': current[p][name]}
assert e_ledger_differences == e_changes, ('群E617件と開始時全件の差が一致しない', e_ledger_differences)
assert {name for rows in e_changes.values() for name in rows} == {'Accepted.def_body', 'Accepted.def_ranges'}
# 通常/開いた判断で同じ新規則を一つずつ保ち、既存規則を除かない。
def constructors(path):
    code = code_only(path.read_text())
    decls = list(re.finditer(r'\binductive\s+(\w+)\s', code))
    result = {}
    for i, match in enumerate(decls):
        end = decls[i+1].start() if i+1 < len(decls) else len(code)
        result[match[1]] = re.findall(r'(?m)^\s*\|\s*(\w+)\s*(?:\{|:)', code[match.end():end])
    return result
base = ROOT / 'formal/Benitoite/Release/Refinement/Surface'
regular = constructors(base / 'Rules.lean')
opened = constructors(base / 'OpenSurface.lean')
judgments = ['HasTypeQ', 'HasTypesQ', 'HasEachQ', 'HasFixedQ', 'HasArmsQ', 'HasClausesQ', 'HasBlockQ']
for name in judgments:
    assert regular[name] == [n for n in opened[name] if not (name == 'HasClausesQ' and n == 'closed')], name
legacy_rules = json.loads((CHANGE / 'l70/e/cases.json').read_text())['constructors']
for name in judgments:
    # 旧台帳は補助判断へTypes_/Each_等の表示用の前置きを付けている。
    names = legacy_rules[name] if name in {'HasTypeQ', 'HasBlockQ'} else [n.split('_', 1)[1] for n in legacy_rules[name]]
    assert [n for n in regular[name] if n not in {'E_PredicateCall', 'E_PredicateProject'}] == names, name
assert regular['HasTypeQ'].count('E_PredicateCall') == 1
assert regular['HasTypeQ'].count('E_PredicateProject') == 1
assert sum(len(regular[n]) for n in judgments) == 97

checks = {k: json.loads((HERE / (k+'-summary.json')).read_text()) for k in ['build', 'axioms']}
for kind, record in checks.items():
    log = tmp / (kind+'.log')
    assert record['exit_code'] == 0 and record['same_inputs']
    assert record['bytes'] == log.stat().st_size and record['sha256'] == digest(log)
    assert record['fingerprint'] == record['after_fingerprint'] == fingerprint(sources())
build = (tmp / 'build.log').read_text()
assert 'error:' not in build
for m in modules:
    assert not any('warning:' in line and m.replace('.', '/')+'.lean:' in line for line in build.splitlines()), m
audit = (tmp / 'axioms.log').read_text()
assert not re.search(r'error:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)', audit)
targets = re.findall(r'^AUDIT_TARGET (.+)$', audit, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$', audit, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M|re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(',') if x.strip())) for _, a in axioms)
assert all(set(s) <= {'propext', 'Classical.choice', 'Quot.sound'} for s in sets)
owned = dict((m, int(c)) for m, c in re.findall(r'^OWN_MODULE (\S+) (\d+)$', audit, re.M))
assert sorted(owned) == modules
records = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', audit, re.M)
assert len(records) == len(targets)
owned_records = [dict(module=m, kind=k, line=int(line), name=n) for m,k,line,n in records if m in owned]
assert len(owned_records) == sum(owned.values())
save(tmp / 'declarations.json', owned_records)
assert set(json.loads((HERE / 'required-names.json').read_text())) <= set(targets)
for p in HERE.parent.rglob('*'):
    if p.is_file() and '__pycache__' not in p.parts:
        assert p.stat().st_size <= 100_000, p
        if p.suffix in {'.py', '.lean', '.md', '.json'}:
            content = p.read_text()
            assert '/Us'+'ers/' not in content and '/priv'+'ate/tmp' not in content, p
            assert not re.search(r'\]\([^)]*docs/todo', content), p
assert sum(p.stat().st_size for p in HERE.parent.rglob('*') if p.is_file() and '__pycache__' not in p.parts) < 3_000_000
names = ('\n'.join(sorted(targets))+'\n').encode()
result = dict(default_imports=True, modules=len(modules), d_statements=308,
              d_approved_differences=2, d_additional_differences=0,
              e_ledger_statements=617, e_statements=sum(map(len, e_paths.values())), e_differences=e_changes,
              statements_changed=sum(map(len, differences.values())),
              ordinary_rules=sum(len(regular[n]) for n in judgments),
              declarations=len(targets), owned_declarations=len(owned_records),
              owned_private=sum(r['name'].startswith('_private.') for r in owned_records),
              names_bytes=len(names), names_sha256=hashlib.sha256(names).hexdigest(),
              declarations_bytes=(tmp/'declarations.json').stat().st_size,
              declarations_sha256=digest(tmp/'declarations.json'), per_module=owned,
              axiom_sets={','.join(k) or '(none)':v for k,v in sorted(sets.items())},
              fingerprint=fingerprint(sources()))
save(HERE / 'verification.json', result)
print(json.dumps({k:v for k,v in result.items() if k not in {'per_module', 'e_differences'}}, ensure_ascii=False, indent=1))
