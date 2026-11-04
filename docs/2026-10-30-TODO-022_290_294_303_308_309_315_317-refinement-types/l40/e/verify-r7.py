"""再開6の verify を継承し、出典追記と RV-L40.e6 の文書処置後の入力を照合する。Lean は再実行しない。"""
from pathlib import Path
from datetime import datetime, timezone
import ast
import hashlib
import importlib.util
import json
import re
import sys
import subprocess
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREFIX = 'formal/Benitoite/Release/Refinement/'

def digest(path):
    data = path.read_bytes()
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}

def load(name):
    return json.loads((HERE / name).read_text())

def checked_parts(parts):
    result = []
    for entry in parts:
        assert digest(HERE / entry['file']) == {k: entry[k] for k in ('bytes', 'sha256')}, entry['file']
        result.append(load(entry['file']))
    return result

def normalize(text):
    return re.sub(r'\s+', '', re.sub(r'\((-?\d+)\)', r'\1', text))

def main():
    started = datetime.now(timezone.utc)
    clock = time.monotonic()
    baseline = {}
    for path in sorted(HERE.glob('inputs-r6-part-*.json')):
        baseline.update(json.loads(path.read_text()))
    changes = load('changes-r7.json')
    changed = {entry['path']: entry for entry in changes['changed']}
    added = {entry['path']: entry for entry in changes['new']}
    deleted = set(changes['deleted'])
    for path, before in baseline.items():
        if path in deleted:
            assert not (ROOT / path).exists(), path
            continue
        expected = changed[path]['after'] if path in changed else before
        assert digest(ROOT / path) == expected, path
        if path in changed:
            assert changed[path]['before'] == before, path
    for path, entry in added.items():
        assert path not in baseline
        assert digest(ROOT / path) == {k: entry[k] for k in ('bytes', 'sha256')}, path
    actual = {str(path.relative_to(ROOT)) for path in (ROOT / 'formal').rglob('*.lean')
              if '.lake' not in path.relative_to(ROOT / 'formal').parts}
    expected = {path for path in baseline if path.endswith('.lean')} - deleted | set(added)
    assert actual == expected, (actual - expected, expected - actual)
    assert not (ROOT / 'formal/Trial').exists()
    safe = PREFIX + 'StandardSafeContracts.lean'
    assert digest(ROOT / safe) == baseline[safe]
    ten = load('ten-statements-r6.json')
    assert len(ten) == 10
    for entry in ten:
        text = (ROOT / entry['file']).read_text()
        match = re.search(r'theorem ' + re.escape(entry['name']) + r'\b[\s\S]*?(?=:= by)', text)
        assert match and hashlib.sha256(match[0].encode()).hexdigest() == entry['sha256'], entry['name']
    modules = load('modules-r6.json')
    assert len(modules) == len(added) == 8
    root_text = (ROOT / 'formal/Benitoite.lean').read_text()
    for module in modules:
        assert 'import Benitoite.Release.Refinement.' + module + '\n' in root_text
        text = (ROOT / (PREFIX + module + '.lean')).read_text()
        assert not re.search(r'\b(sorry|admit|axiom|native_decide)\b|#eval', text), module
    audit = load('audit-summary-r6.json')
    assert audit['exit'] == audit['new_axioms'] == 0
    assert audit['private_and_generated_included'] and audit['closure_rounds'] >= 2
    assert set(audit['new_modules']) == set(modules)
    assert all(audit['new_modules'].values())
    allowed = {'propext', 'Classical.choice', 'Quot.sound'}
    for key in audit['axiom_sets']:
        assert key == 'none' or set(key.split(' + ')) <= allowed, key
    assert sum(audit['axiom_sets'].values()) == audit['targets']
    module_counts = {}
    for part in checked_parts(audit['module_parts']):
        module_counts.update(part)
    assert 'local_records' in module_counts
    assert len(module_counts) - 1 == audit['module_count']
    assert sum(module_counts.values()) == audit['targets']
    requested = []
    for part in checked_parts(audit['requested_module_parts']):
        requested.extend(part)
    for entry in requested:
        names = sum(checked_parts(entry['parts']), [])
        assert len(names) == len(set(names)) == entry['count'], entry['module']
    assert sum(entry['count'] for entry in requested) == audit['requested_module_declarations']
    for part in checked_parts(audit['source_input_parts']):
        for path, entry in part.items():
            assert digest(ROOT / path) == entry, path
    for entry in load('audit-execution-r6.json'), load('default-build-r6.json'), load('work-r6.json'):
        assert entry['exit'] == 0
    assert load('default-build-r6.json')['command'] == ['lake', 'build']
    assert load('work-r6.json')['command'] == ['scripts/check.sh', '--level', 'work', '--base',
        '548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8']
    typing = (ROOT / (PREFIX + 'Typing.lean')).read_text()
    plain_start = typing.index('    | plain {Ψ Q C Γ Φ Δ R obs alts body')
    guarded_end = typing.index('\n\n  inductive HasTypeClausesQ', plain_start)
    rules = typing[plain_start:guarded_end]
    core_path = 'docs/design/01-spec/01-12-core-calculus.md'
    core = (ROOT / core_path).read_text()
    assert rules in core
    assert 'StandardSafe.precise_rows_typed' in (ROOT / 'docs/design/07-quality/07-04-formal-semantics.md').read_text()
    assert load('spec-text-fences-r6.json')['unchanged']
    cert_counts = {}
    for script, module in [('gen-head-tail-certificates-r6.py', 'StandardHeadTailBodies'),
                           ('gen-collection-certificates-r6.py', 'StandardCollectionRefinedBodies')]:
        spec = importlib.util.spec_from_file_location('certificate_check', HERE / script)
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)
        generated = generator.output()
        source = normalize((ROOT / (PREFIX + module + '.lean')).read_text())
        lines = [line for line in generated.splitlines() if line]
        for line in lines:
            assert normalize(line) in source, (script, line[:100])
        cert_counts[module] = len(lines) // 4
    review = load('inputs-r7.json')
    for entry in review['design_inputs']:
        assert digest(ROOT / entry['path']) == entry['r7_after'], entry['path']
    assert digest(HERE / 'verify-r6.py') == review['r6_verifier']
    assert digest(HERE / 'verification-r6.json') == review['r6_verification']
    reason = next(line for line in core.splitlines() if 'Jhala と Vazou' in line and 'Chk-Alt' in line)
    assert {'bytes': len(reason.encode()), 'sha256': hashlib.sha256(reason.encode()).hexdigest()} == review['preserved_reason']
    blocks = re.findall(r'^```text[^\n]*\n(.*?)^```[ \t]*$', core, re.M | re.S)
    assert len(blocks) == review['text_fences']['blocks']
    assert hashlib.sha256(json.dumps(blocks, ensure_ascii=False).encode()).hexdigest() == review['text_fences']['sha256']
    paths = subprocess.check_output(['rg', '--files', '--hidden', '-g', '!.git', '-g', '!docs/todo',
                                     '-g', '!private', '-g', '!work'], cwd=ROOT, text=True).splitlines()
    protected = {}
    for ext in ('.lean', '.rs', '.bnt'):
        entries = {path: digest(ROOT / path) for path in sorted(paths) if path.endswith(ext) and (ROOT / path).is_file()}
        protected[ext] = {'files': len(entries), 'sha256': hashlib.sha256(
            json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()).hexdigest()}
    assert protected == review['protected_sources']
    records = sorted(path for path in HERE.iterdir() if path.is_file() and
                     ('r6' in path.name or 'r7' in path.name or path.name == 'results.md'))
    for path in records:
        assert path.stat().st_size <= 100000, path.name
        text = path.read_text()
        assert ('/' + 'Users' + '/') not in text and ('/' + 'private' + '/') not in text, path.name
        if path.suffix == '.py':
            ast.parse(text, filename=path.name)
    result = {
        'start_utc': started.isoformat(), 'end_utc': datetime.now(timezone.utc).isoformat(),
        'seconds': time.monotonic() - clock, 'exit': 0,
        'baseline_inputs': len(baseline), 'modified': len(changed), 'new_modules': len(added),
        'deleted': sorted(deleted), 'ten_statements_unchanged': len(ten),
        'safe19_contract_unchanged': True, 'explicit_root_imports': modules,
        'audited_declarations': audit['targets'], 'audited_modules': audit['module_count'],
        'new_module_declarations': sum(audit['new_modules'].values()), 'new_axioms': 0,
        'certificate_families': cert_counts, 'rules_copy_exact': True, 'text_fences_unchanged': True,
        'records_under_100000_bytes': len(records), 'largest_record': max(path.stat().st_size for path in records),
        'lean_reexecuted': False, 'rust_reexecuted': False,
        'review': 'RV-L40.e6', 'preserved_reason_unchanged': True,
        'protected_sources_unchanged': protected, 'design_input_transitions': review['design_inputs'],
        'evidence': {name: digest(HERE / name) for name in ['changes-r7.json', 'inputs-r7.json', 'verify-r6.py', 'verify-r7.py', 'ten-statements-r6.json',
             'audit-summary-r6.json', 'default-build-r6.json', 'work-r6.json', 'spec-text-fences-r6.json']}}
    data = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    assert len(data.encode()) <= 100000
    (HERE / 'verification-r7.json').write_text(data)
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__':
    main()
