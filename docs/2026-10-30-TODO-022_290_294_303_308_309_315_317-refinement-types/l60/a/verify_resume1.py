"""再開1の停止状態、全衝突、出典から内部名への対応、検査入力と公理依存を照合する。"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from inventory import HERE, ROOT, FORMAL, digest, write
from ledger import lean_rows, normalized
from collision_inventory import sources
from rust_inventory import registrations


def verify(tmp):
    protected = json.loads((tmp / 'protected.json').read_text())
    assert all(digest(ROOT / f)['sha256'] == h for f, h in protected.items())
    summary = json.loads((HERE / 'ledger-summary.json').read_text())

    def read_pages(key):
        rows = []
        for page in summary[key]:
            assert digest(HERE / page['file']) == {k: page[k] for k in ['bytes', 'sha256']}
            rows.extend(json.loads((HERE / page['file']).read_text()))
        return rows

    evidence, ledger, rust, conditions = [read_pages(k) for k in
        ['evidence_pages', 'ledger_pages', 'rust_pages', 'condition_pages']]
    assert len(evidence) == 552 and len(ledger) == 640 and len(rust) == 523 and len(conditions) == 75
    assert summary['composition_complete'] is False
    assert summary['name_correspondence_complete'] is True
    original = sources()
    assert [r['id'] for r in original] == [r['id'] for r in evidence]
    for old, row in zip(original, evidence):
        for key in ['id', 'lean_name', 'evidence', 'expression', 'category', 'original_def']:
            assert old[key] == row[key], (row['id'], key)
        assert row['public_name'] == row['lean_name'] and row['internal_name']
    assert Counter(r['group'] for r in evidence) == Counter(r['group'] for r in lean_rows())
    byid = {r['id']: r for r in ledger}
    bysource = {r['id']: r for r in evidence}
    for row in evidence:
        entry = byid[row['ledger']]
        assert entry['classification'] == '合成' and row['id'] in entry['evidence_rows']
        corr = next(c for c in entry['name_correspondence'] if c['source'] == row['id'])
        for key in ['public_name', 'internal_name', 'original_def', 'evidence']:
            assert corr[key] == row[key]
    assert [r['name'] for r in rust] == [r['name'] for r in registrations()]
    for row in rust:
        entry = byid[row['ledger']]
        assert normalized(row['name']) == entry['lean_name'] and row['id'] in entry['rust_references']
    source_names = {r['lean_name'] for r in lean_rows()}
    for entry in ledger:
        if entry['classification'] == '仮定':
            assert entry['lean_name'] not in source_names
            assert not entry['evidence'] and not entry['evidence_rows'] and entry['reason']
            assert not entry['name_correspondence'] and not entry['internal_names']
    collisions = json.loads((HERE / 'collisions.json').read_text())
    counts = json.loads((HERE / 'collision-summary.json').read_text())
    assert counts['source_comparison_log'] == digest(tmp / 'resume1-collision-inventory.log')
    assert counts['collisions'] == digest(HERE / 'collisions.json')
    assert len(collisions) == 17 and all(c['bodies_differ'] for c in collisions)
    assert sum(c['inputs_differ'] for c in collisions) == 11
    assert {c['public_name'] for c in collisions} == set(summary['verified_lookup_collisions'])
    bodies = [r for r in original if r['original_def']]
    assert len(bodies) == 159
    expected_pairs = {(x['id'], y['id']) for i, x in enumerate(bodies) for y in bodies[:i]
                      if x['lean_name'] == y['lean_name']}
    comparisons = re.findall(r'^COMPARE (\S+) (\S+) (\S+) (\S+) (\S+)$',
                            (tmp / 'resume1-collision-inventory.log').read_text(), re.M)
    assert len(comparisons) == len(expected_pairs) == 58
    assert {(x, y) for x, y, _, _, _ in comparisons} == expected_pairs
    assert sum(same == 'true' for _, _, same, _, _ in comparisons) == 30
    assert sum(same == 'false' for _, _, same, _, _ in comparisons) == 28
    for c in collisions:
        assert len(c['sources']) == len(c['internal_names']) == 2
        for ids, internal in zip(c['sources'], c['internal_names']):
            assert internal.startswith('%')
            for source in ids:
                assert bysource[source]['internal_name'] == internal
    assert len({r['internal_name'] for r in evidence}) == summary['planned_composition_keys'] == 503
    modules = json.loads((HERE / 'changed-modules.json').read_text())
    seen = set()

    def visit(module):
        if module in seen:
            return
        file = ROOT / 'formal' / (module.replace('.', '/') + '.lean')
        if not file.exists():
            return
        seen.add(module)
        for child in re.findall(r'^import (\S+)', file.read_text(), re.M):
            visit(child)

    visit('Benitoite')
    assert set(modules) <= seen
    audit = json.loads((HERE / 'resume1-audit-summary.json').read_text())
    assert audit['new_axioms'] == audit['sorryAx'] == 0
    assert audit['targets'] == 80778 and audit['new_declarations'] == 106
    assert set(modules) <= set(audit['modules'])
    for key in ['declaration_pages', 'signature_pages']:
        for page in audit[key]:
            assert digest(HERE / page['file']) == {k: page[k] for k in ['bytes', 'sha256']}
    labels = ['resume1-collision-inventory', 'resume1-collision-proofs', 'resume1-internal-name-trial',
              'resume1-helper-reference', 'resume1-default-build', 'resume1-audit-final',
              'resume1-work-dry', 'resume1-work-final']
    for label in labels:
        execution = json.loads((HERE / (label + '.json')).read_text())
        assert execution['exit'] == 0 and execution['raw'] == digest(tmp / (label + '.log'))
    assert audit['execution'] == json.loads((HERE / 'resume1-audit-final.json').read_text())
    local = []
    for filename, label in [('all-contract-collisions.lean', 'resume1-collision-proofs'),
                            ('internal-name-trial.lean', 'resume1-internal-name-trial'),
                            ('helper-reference-collision.lean', 'resume1-helper-reference')]:
        logfile = tmp / (label + '.log')
        text = logfile.read_text()
        names = re.findall(r'^LOCAL_AUDIT (.+)$', text, re.M)
        axiom_rows = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", text, re.M | re.S)
        assert len(names) == len(set(names))
        assert set(names) <= {n for n, _ in axiom_rows}
        assert all({d.strip() for d in deps.split(',')} <= {'propext', 'Classical.choice', 'Quot.sound', ''}
                   for _, deps in axiom_rows)
        assert not re.search(r'error:|warning:|sorryAx', text)
        local.append({'input': filename, 'input_digest': digest(HERE / filename),
                      'declarations': len(names), 'private': sum(n.startswith('_private.') for n in names),
                      'names': names, 'log': digest(logfile), 'new_axioms': 0, 'sorryAx': 0})
    assert local == json.loads((HERE / 'resume1-local-audit.json').read_text())
    for row in local:
        assert row['input_digest'] == digest(HERE / row['input'])
        assert row['new_axioms'] == row['sorryAx'] == 0
        assert row['declarations'] == len(set(row['names']))
        assert not re.search(r'\bsorry\b|^axiom |#eval|set_option max(?:Heartbeats|RecDepth)',
                             (HERE / row['input']).read_text(), re.M)
    for filename in ['internal-name-trial.lean', 'helper-reference-collision.lean', 'all-contract-collisions.lean']:
        assert not any(filename.removesuffix('.lean') in module for module in seen)
    for filename in ['StandardHeadTailBodies.lean', 'StandardActualListBodies.lean', 'StandardListBodies.lean']:
        assert str((FORMAL / filename).relative_to(ROOT)) in protected
    files = [p for p in HERE.iterdir() if p.is_file()]
    for file in files:
        assert file.stat().st_size <= 100000, (file.name, file.stat().st_size)
        if file.suffix in ['.md', '.lean', '.json', '.txt']:
            text = file.read_text()
            assert not re.search(r'/(?:Users|private/tmp|tmp)/|\]\([^)]*docs/todo', text), file.name
            if file.suffix == '.md':
                for link in re.findall(r'\]\(([^)]+)\)', text):
                    if not link.startswith(('https:', 'http:', '#')):
                        assert (file.parent / link.split('#')[0]).exists(), (file.name, link)
    assert sum(f.stat().st_size for f in files) < 4000000
    status = (HERE / 'resume1-stop.md').read_text()
    assert 'L60.05は未着手' in status and 'List.mapFrom' in status
    result = {'status': '再開1の停止状態の照合成功。群Aは未完',
        'b_work': '80230d96305756057a63a07dc2b0d8aa1ebf3a75',
        'protected_files': len(protected), 'protected_manifest': digest(tmp / 'protected.json'),
        'production_changes_in_resume1': 0,
        'source_rows': len(evidence), 'ledger_parent_rows': len(ledger),
        'composition_parent_rows': 486, 'assumption_parent_rows': 154,
        'planned_composition_keys': 503, 'rust_references': len(rust), 'conditions': len(conditions),
        'collision_groups': 17, 'body_differences': 17, 'input_differences': 11,
        'default_closure_modules': len(seen), 'audited_default_declarations': audit['targets'],
        'audited_local_declarations': sum(row['declarations'] for row in local),
        'new_axioms': 0, 'sorryAx': 0, 'work_executions_in_resume1': 1,
        'record_bytes': sum(f.stat().st_size for f in files), 'record_files': len(files),
        'independent_review': '未実施・取りまとめの担当', 'acceptance': '未実施・設計者の担当'}
    write(HERE / 'resume1-verification.json', result)
    print(json.dumps(result, ensure_ascii=False))
