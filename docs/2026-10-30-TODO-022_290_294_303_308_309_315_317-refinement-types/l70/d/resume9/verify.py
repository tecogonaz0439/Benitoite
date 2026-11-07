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
assert e_ledger_differences == json.loads((HERE / 'e-ledger-differences.json').read_text())
expected = {
 'CheckAccept': {'checkProgramAccepted_empty', 'checkProgramAccepted_sound', 'checkProgramAccepted_unknown'},
 'CheckAcceptBase': {'Accepted.def_body_no_ranges', 'acceptDef_no_ranges'},
 'CheckAcceptedRanges': {'Accepted.def_ranges_no_ranges'},
 'CheckMaterialsSound': {'Materials.checkProgramAccepted_empty', 'Materials.checkProgramAccepted_sound',
   'Materials.checkProgram_empty', 'Materials.checkProgram_empty_contracts',
   'Materials.checkProgram_sound', 'Materials.checkProgram_sound_contracts'},
 'CheckProgramSound': {'checkProgram_contracts', 'checkProgram_empty', 'checkProgram_empty_contracts',
   'checkProgram_sound', 'checkProgram_sound_contracts', 'program_parts'},
 'CheckTables': {'checkProgram_unknown'},
 'OpenScopeAccept': {'acceptBody_no_ranges'},
}
assert {Path(p).stem: set(rows) for p, rows in differences.items()} == expected
assert sum(map(len, e_ledger_differences.values())) == 18
# 解決済みの表現を検査する元の六言明は、名前だけを変えて保つ。
raw_compat = []
for stem in ['CheckProgramSound', 'CheckTables']:
    p = 'formal/Benitoite/Release/Refinement/Surface/' + stem + '.lean'
    for name, header in EXTRACT['theorem_headers']((ROOT / p).read_text()).items():
        if name.startswith('checkPreparedProgram'):
            original = name.replace('checkPreparedProgram', 'checkProgram')
            restored = header.replace('checkPreparedProgram', 'checkProgram')
            assert hashlib.sha256(restored.encode()).hexdigest() == old[p][original], original
            raw_compat.append(original)
assert len(raw_compat) == 6
assert summary['statements_before'] == 1948 and summary['statements_removed'] == 0
# 標準行の支持は392行を列挙するが、Leanで大きな具体値を評価しない。
base_support = ROOT / 'formal/Benitoite/Release/Refinement/Surface'
rows = []
for index in range(1, 5):
    rows += re.findall(r'^theorem support_p(\d+)', (base_support / f'PredicateStandardSupport{index}.lean').read_text(), re.M)
assert sorted(map(int, rows)) == list(range(1, 393))
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

checks = {k: json.loads((HERE / (k+'-summary.json')).read_text()) for k in ['build', 'axioms', 'declarations']}
for kind, record in checks.items():
    log = tmp / (kind+'.log')
    assert record['exit_code'] == (1 if kind == 'axioms' else 0) and record['same_inputs']
    assert record['bytes'] == log.stat().st_size and record['sha256'] == digest(log)
    assert record['fingerprint'] == record['after_fingerprint'] == fingerprint(sources())
build = (tmp / 'build.log').read_text()
assert 'error:' not in build
for m in modules:
    assert not any('warning:' in line and m.replace('.', '/')+'.lean:' in line for line in build.splitlines()), m
audit = (tmp / 'axioms.log').read_text()
# 全公理依存の取得後、privateを公開名で指定した必須名の確認だけが失敗した。
# 公理の検査は再実行せず、同じ全対象の宣言記録だけを別途補完する。
errors = [line for line in audit.splitlines() if 'error:' in line]
assert len(errors) == 1 and errors[0].endswith(
    'error: AUDIT_REQUIRED_MISSING Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples.source_input_sound'), errors
assert not re.search(r'sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|MODULE_MISSING)', audit)
completed = (tmp / 'declarations.log').read_text()
assert not re.search(r'error:|AUDIT_(?:MISSING|AXIOM|REQUIRED_MISSING|MODULE_MISSING)|OWN_MODULE_MISSING', completed)
targets = re.findall(r'^AUDIT_TARGET (.+)$', audit, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r'^AUDIT_COUNT (\d+)$', completed, re.M)[1])
assert dict(re.findall(r'^AUDIT_MODULE (\S+) (\d+)$', audit, re.M)) == dict(
    re.findall(r'^AUDIT_MODULE (\S+) (\d+)$', completed, re.M))
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M|re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(',') if x.strip())) for _, a in axioms)
assert all(set(s) <= {'propext', 'Classical.choice', 'Quot.sound'} for s in sets)
owned = dict((m, int(c)) for m, c in re.findall(r'^OWN_MODULE (\S+) (\d+)$', completed, re.M))
assert sorted(owned) == modules
records = re.findall(r'^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$', completed, re.M)
assert len(records) == len(targets)
assert collections.Counter(n for _, _, _, n in records) == collections.Counter(targets)
owned_records = [dict(module=m, kind=k, line=int(line), name=n) for m,k,line,n in records if m in owned]
assert len(owned_records) == sum(owned.values())
save(tmp / 'declarations.json', owned_records)
assert set(json.loads((HERE / 'required-names.json').read_text())) <= set(targets)
assert json.loads((tmp / 'audit-targets.json').read_text()) == targets
for p in HERE.parent.rglob('*'):
    if p.is_file() and '__pycache__' not in p.parts:
        assert p.stat().st_size <= 100_000, p
        if p.suffix in {'.py', '.lean', '.md', '.json'}:
            content = p.read_text()
            assert '/Us'+'ers/' not in content and '/priv'+'ate/tmp' not in content, p
            assert not re.search(r'\]\([^)]*docs/todo', content), p
assert sum(p.stat().st_size for p in HERE.parent.rglob('*') if p.is_file() and '__pycache__' not in p.parts) < 3_000_000
names = ('\n'.join(sorted(targets))+'\n').encode()
result = dict(default_imports=True, axiom_dependencies_complete=True,
              audit_postcheck_corrected=True, audit_invocations=1, declaration_completion_invocations=2, modules=len(modules), d_statements=308,
              d_approved_differences=2, d_additional_differences=0,
              e_ledger_statements=617, e_statements=sum(map(len, e_paths.values())), e_differences=e_changes,
              e_ledger_differences=18, raw_compatible_statements=raw_compat,
              statements_before=summary['statements_before'], statements_after=summary['statements_after'],
              statements_added=summary['statements_added'], statements_removed=summary['statements_removed'],
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
