"""再レビューの二所見、仮定側154行の区分と対象外の根拠を照合する。"""
from collections import Counter
import json
import re
from inventory import HERE, ROOT, FORMAL, digest, write
from assumption_inventory import run as assumptions, TASK_SCOPE
from composition_inventory import read_pages, verify_tables
from ledger import definition


COUNTS = {'δ': 81, 'IO 応答': 46, '通常資源の状態': 16,
          '専用の遷移': 4, '形式化の外': 7}
OUTSIDE = {'Task.all', 'Task.allOk', 'Task.race', 'Task.withTimeout',
           'Task.await', 'TaskGroup.open', 'TaskGroup.spawn'}
DEDICATED = {'Reference.new', 'Reference.update', 'Lazy.force', 'Process.exit'}


def verify(tmp):
    before = json.loads((tmp / 'before.json').read_text())
    docs = {'docs/design/01-spec/01-12-core-calculus.md',
            'docs/design/07-quality/07-04-formal-semantics.md'}
    local = {'assumption_inventory.py', 'verify.py', 'results.md',
             'ledger-summary.json', 'ledger-09.json', 'ledger-10.json', 'ledger-11.json'}
    allowed = docs | {str((HERE / name).relative_to(ROOT)) for name in local}
    changed = {name for name, value in before.items() if digest(ROOT / name) != value}
    assert changed == allowed, sorted(changed ^ allowed)
    # 対象外の既存ファイルも全件照合する。Leanの宣言・コメントは変更なし。
    assert not any(name.startswith('formal/') for name in changed)
    for name in docs:
        old = (tmp / (ROOT / name).name).read_text()
        expected = old.replace('18名の公開名は合成表のキーに現れない。',
            '同じ名前に異なる元Defを持つ18名（`FunctionNames.collisionNames`）の公開名は合成表のキーに現れない。')
        expected = expected.replace('有限台帳と全lookupの双方向の対応',
            '有限の本体表（`Body.all`）と組込みの表（`Primitive.all`）に対する全lookupの双方向の対応')
        actual = (ROOT / name).read_text()
        assert actual == expected and '有限台帳' not in actual, name
        assert actual.count('`FunctionNames.collisionNames`') == 1
    collisions = re.findall(r'"([^"]+)"', definition('FunctionNameMap.lean', 'collisionNames'))
    assert len(collisions) == len(set(collisions)) == 18
    composition = verify_tables(record=False)
    counts = assumptions()  # 欠けた区分、実登録と異なる区分・理由・根拠を拒む。
    assert counts == COUNTS
    summary = json.loads((HERE / 'ledger-summary.json').read_text())
    rows = [r for r in read_pages(summary, 'ledger_pages') if r['classification'] == '仮定']
    outside = [r for r in rows if r['assumption_kind'] == '形式化の外']
    assert {r['lean_name'] for r in outside} == OUTSIDE
    assert Counter(r['lean_name'].split('.')[0] for r in outside) == {'Task': 5, 'TaskGroup': 2}
    assert {r['lean_name'] for r in rows if r['assumption_kind'] == '専用の遷移'} == DEDICATED
    assert all(r['scope_basis'] == TASK_SCOPE for r in outside)
    assert all('仮定として量化する範囲に含めず' in r['reason'] for r in outside)
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
    modules = json.loads((HERE / 'changed-modules.json').read_text())
    assert len(modules) == 11 and set(modules) <= seen
    build = json.loads((HERE / 'resume5-default-build.json').read_text())
    assert build['exit'] == 0 and build['raw'] == digest(tmp / 'resume5-default-build.log')
    assert 'Build completed successfully' in (tmp / 'resume5-default-build.log').read_text()
    result = (HERE / 'results.md').read_text().split('## 再開5', 1)[1]
    for category, count in COUNTS.items():
        assert f'| {category} | {count} |' in result
    for file in HERE.glob('*.py'):
        compile(file.read_text(), file.name, 'exec')
    files = [f for f in HERE.iterdir() if f.is_file()]
    for file in files:
        assert file.stat().st_size <= 100000, file.name
        if file.suffix == '.md':
            for link in re.findall(r'\]\(([^)]+)\)', file.read_text()):
                if not link.startswith(('http:', 'https:', '#')):
                    assert (file.parent / link.split('#')[0]).exists(), (file.name, link)
    assert sum(f.stat().st_size for f in files) < 6000000
    outcome = {'status': '新軽1・新軽2の処置と自己照合を完了',
        'b_work': '80230d96305756057a63a07dc2b0d8aa1ebf3a75', **composition,
        'assumption_categories': counts, 'outside_names': sorted(OUTSIDE),
        'outside_scope_basis': TASK_SCOPE, 'dedicated_names': sorted(DEDICATED),
        'collision_names': collisions, 'default_import_modules': len(seen),
        'group_a_default_modules': len(modules), 'protected_files': len(before),
        'changed_existing_files': sorted(changed),
        'current_changed_inputs': {name: digest(ROOT / name) for name in sorted(changed)},
        'lean_source_changes': 0, 'axiom_audit_executions_in_resume5': 0,
        'default_build_executions_in_resume5': 1, 'verify_executions_in_resume5': 1,
        'check_sh_executions_in_resume5': 0}
    write(HERE / 'resume5-verification.json', outcome)
    print(json.dumps(outcome, ensure_ascii=False))
