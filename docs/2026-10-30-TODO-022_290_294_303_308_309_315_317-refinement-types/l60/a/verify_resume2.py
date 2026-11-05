"""再開2の全称反例、全本体参照、台帳の保持と検査を停止状態として照合する。"""
import json
import re
from inventory import HERE, ROOT, digest, write
from collision_inventory import sources
from rust_inventory import registrations
from reference_inventory import collect


def verify(tmp):
    protected = json.loads((tmp / 'protected.json').read_text())
    assert all(digest(ROOT / f)['sha256'] == h for f, h in protected.items())
    summary = json.loads((HERE / 'ledger-summary.json').read_text())
    def read(key):
        out = []
        for p in summary[key]:
            assert digest(HERE / p['file']) == {k: p[k] for k in ['bytes', 'sha256']}
            out.extend(json.loads((HERE / p['file']).read_text()))
        return out
    evidence, ledger, rust, conditions = [read(k) for k in
        ['evidence_pages', 'ledger_pages', 'rust_pages', 'condition_pages']]
    assert [len(x) for x in [evidence, ledger, rust, conditions]] == [552, 640, 523, 75]
    assert summary['composition_complete'] is False
    byid = {r['id']: r for r in ledger}
    for row, original in zip(evidence, sources()):
        for key in ['id', 'lean_name', 'original_def', 'expression', 'evidence']:
            assert row[key] == original[key]
        target = byid[row['ledger']]
        assert target['classification'] == '合成' and row['id'] in target['evidence_rows']
        assert row['evidence'] and set(row['evidence']) <= set(target['evidence'])
    assert len([r for r in ledger if r['classification'] == '合成']) == 486
    assumptions = [r for r in ledger if r['classification'] == '仮定']
    assert len(assumptions) == 154
    assert all(not r['evidence'] and not r['evidence_rows'] and r['reason'] for r in assumptions)
    assert [r['name'] for r in rust] == [r['name'] for r in registrations()]
    graph = json.loads((HERE / 'resume2-reference-summary.json').read_text())
    assert collect(tmp / 'resume2-reference-inventory.log') == graph
    assert graph['distinct_body_defs'] == 129 and graph['body_source_rows'] == 159
    collisions = json.loads((HERE / 'collisions.json').read_text())
    assert len(collisions) == 17 and graph['renamed_names'] == sorted(c['public_name'] for c in collisions)
    text = (HERE / 'reference-closure-obstruction.lean').read_text()
    assert 'ordinary_filter_copy_not_typed' in text and 'ordinary_filter_not_typed' in text
    assert 'support : ∀ name, name ∉ collisionNames → rename name = name' in text
    labels = ['resume2-reference-obstruction', 'resume2-reference-inventory',
              'resume2-default-build', 'resume2-audit-final', 'resume2-work-dry', 'resume2-work-final']
    for label in labels:
        r = json.loads((HERE / (label + '.json')).read_text())
        assert r['exit'] == 0 and r['raw'] == digest(tmp / (label + '.log'))
    audit = json.loads((HERE / 'resume2-audit-summary.json').read_text())
    assert audit['targets'] == 80778 and audit['new_declarations'] == 106
    assert audit['new_axioms'] == audit['sorryAx'] == 0
    assert audit['execution'] == json.loads((HERE / 'resume2-audit-final.json').read_text())
    assert audit['input'] == digest(HERE / 'axioms.lean')
    for key in ['declaration_pages', 'signature_pages']:
        for page in audit[key]:
            assert digest(HERE / page['file']) == {k: page[k] for k in ['bytes', 'sha256']}
    seen = set()
    def visit(module):
        if module in seen: return
        f = ROOT / 'formal' / (module.replace('.', '/') + '.lean')
        if not f.exists(): return
        seen.add(module)
        for child in re.findall(r'^import (\S+)', f.read_text(), re.M): visit(child)
    visit('Benitoite')
    modules = json.loads((HERE / 'changed-modules.json').read_text())
    assert set(modules) <= seen
    local = []
    for name, label in [('reference-closure-obstruction.lean', 'resume2-reference-obstruction'),
                        ('reference-inventory.lean', 'resume2-reference-inventory')]:
        log = (tmp / (label + '.log')).read_text()
        names = re.findall(r'^LOCAL_AUDIT (.+)$', log, re.M)
        rows = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", log, re.M | re.S)
        assert len(names) == len(set(names)) == len(rows)
        assert set(names) == {n for n, _ in rows}
        assert all({x.strip() for x in deps.split(',')} <= {'', 'propext', 'Classical.choice', 'Quot.sound'} for _, deps in rows)
        assert not re.search(r'error:|warning:|sorryAx', log)
        source = (HERE / name).read_text()
        assert not re.search(r'\bsorry\b|^axiom |#eval|set_option max(?:Heartbeats|RecDepth)', source, re.M)
        local.append({'input': name, 'digest': digest(HERE / name), 'names': names,
            'declarations': len(names), 'private': sum(n.startswith('_private.') for n in names),
            'raw': digest(tmp / (label + '.log')), 'new_axioms': 0, 'sorryAx': 0})
    assert [r['declarations'] for r in local] == [13, 1]
    write(HERE / 'resume2-local-audit.json', local)
    for p in HERE.glob('*.py'): compile(p.read_text(), p.name, 'exec')
    files = [f for f in HERE.iterdir() if f.is_file()]
    for file in files:
        assert file.stat().st_size <= 100000, (file.name, file.stat().st_size)
        if file.suffix in ['.md', '.lean', '.json', '.txt']:
            source = file.read_text()
            assert not re.search(r'/(?:Users|private/tmp|tmp)/|\]\([^)]*docs/todo', source), file.name
            if file.suffix == '.md':
                for link in re.findall(r'\]\(([^)]+)\)', source):
                    if not link.startswith(('https:', 'http:', '#')):
                        assert (file.parent / link.split('#')[0]).exists(), (file.name, link)
    assert sum(f.stat().st_size for f in files) < 4000000
    result = {'status': '再開2の停止状態の照合成功。群Aは未完',
        'b_work': '80230d96305756057a63a07dc2b0d8aa1ebf3a75',
        'protected_files': len(protected), 'protected_manifest': digest(tmp / 'protected.json'),
        'production_changes_in_resume2': 0, 'default_import_modules': len(seen),
        'source_rows': len(evidence), 'ledger_rows': len(ledger), 'rust_references': len(rust),
        'assumption_rows': len(assumptions), 'conditions': len(conditions),
        'body_sources': 159, 'distinct_body_defs': 129, 'function_references': 61,
        'audited_default_declarations': audit['targets'], 'audited_local_declarations': 14,
        'new_axioms': 0, 'sorryAx': 0, 'work_executions_in_resume2': 1,
        'composition_complete': False, 'stopped_unit': 'L60.04', 'unstarted_unit': 'L60.05',
        'record_bytes': sum(f.stat().st_size for f in files),
        'independent_review': '未実施・取りまとめの担当', 'acceptance': '未実施・設計者の担当'}
    write(HERE / 'resume2-verification.json', result)
    print(json.dumps(result, ensure_ascii=False))
