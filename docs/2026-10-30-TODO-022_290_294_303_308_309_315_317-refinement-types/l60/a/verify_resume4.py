"""RV-L60.aの処置・全件入力・保護対象・現在の監査を照合する。"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from inventory import HERE, ROOT, FORMAL, digest, write
from composition_inventory import read_pages, verify_tables
from assumption_inventory import run as assumptions
from audit_resume4 import collect as audit_result


def verify(tmp):
    before = json.loads((tmp / 'before.json').read_text())
    allowed = {'formal/Benitoite/Release/Refinement/' + name for name in [
        'FunctionNameMap.lean', 'StandardModelDeclarations.lean', 'ResourceReleaseModel.lean']}
    allowed |= {'docs/design/01-spec/01-12-core-calculus.md', 'docs/design/07-quality/07-04-formal-semantics.md'}
    changed = {f for f, h in before.items() if digest(ROOT / f)['sha256'] != h}
    assert changed == allowed, sorted(changed)
    # 前段・旧Release・Rust・レビュー・計画等の広い保護対象も変更していない。
    previous = json.loads((tmp.parent / 'l60r3/protected.json').read_text())
    # 計画の取りまとめの追記など、再開4の開始時点で存在した変更はbeforeを正とする。
    previous_changed = {f for f, h in previous.items() if digest(ROOT / f)['sha256'] != before.get(f, h)}
    assert previous_changed == allowed & set(previous), sorted(previous_changed)
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
    assert len(modules) == 11 and set(modules) <= seen
    for module in modules:
        source = (ROOT / 'formal' / (module.replace('.', '/') + '.lean')).read_text()
        assert not re.search(r'\bsorry\b|^axiom |#eval|L60|L70|set_option maxRecDepth', source, re.M), module
    # 本番三ファイルの差は三適用例とdocstringだけである。
    snippets = {
        'FunctionNameMap.lean': ['''
example : rename false "List.map" ≠ rename false "List.filter" := by
  intro h
  have same := rename_injective false h
  exact (by decide : ("List.map" : String) ≠ "List.filter") same
'''],
        'StandardModelDeclarations.lean': ['''
example (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs Body.b001.key = some Body.b001.definition :=
  (definitions_iff externals _ _).mpr ⟨Body.b001,List.mem_cons_self,rfl,rfl⟩
''', '''
example : StandardActualListBodies.ListOptionDeclarations (program []) :=
  option_declarations []
''']}
    for name, additions in snippets.items():
        source = (FORMAL / name).read_text()
        for snippet in additions:
            assert source.count(snippet) == 1
            source = source.replace(snippet, '', 1)
        assert hashlib.sha256(source.encode()).hexdigest() == before[str((FORMAL / name).relative_to(ROOT))], name
    source = (FORMAL / 'ResourceReleaseModel.lean').read_text().replace(
        '/-- 対象の値型へ分類されない名前oのopaque型に型付く閉じた値は、同じ名前のopaque定数である。 -/',
        '/-- 資源の名前を持つ閉じた値は、対象の保持値ではなく同じopaque定数である。 -/')
    assert hashlib.sha256(source.encode()).hexdigest() == before[str((FORMAL / 'ResourceReleaseModel.lean').relative_to(ROOT))]
    composition = verify_tables(record=False)
    classification = assumptions()
    assert classification == {'δ': 81, '専用の遷移': 11, 'IO 応答': 46, '通常資源の状態': 16}
    context = json.loads((HERE / 'resume4-context-summary.json').read_text())
    for name, h in context['inputs'].items():
        assert digest(HERE / name) == h
    assert context['raw'] == digest(tmp / 'resume4-context.log')
    assert context['execution'] == json.loads((HERE / 'resume4-context.json').read_text())
    assert context['execution']['exit'] == 0
    rows = read_pages(context, 'rows')
    refs = read_pages(context, 'references')
    assert len(rows) == 128 and len(refs) == 130
    assert Counter(r['kind'] for r in rows) == {'lookupなどの副条件付き': 51, '固定のP/B': 77}
    assert sum(len(r['lookups']) for r in rows) == 114
    assert all(x['equal'] is True for r in rows for x in r['lookups'])
    assert not any(n.startswith('%') for r in refs for n in r['references'])
    assert context['mismatches'] == context['internal_source_references'] == 0
    actual = json.loads((HERE / 'resume4-actual-definitions.json').read_text())
    collisions = json.loads((HERE / 'resume3-closure-summary.json').read_text())['renamed_names']
    assert [r['name'] for r in actual] == collisions and len(actual) == 18
    for row in actual:
        file = ROOT / row['file']
        assert digest(file) == row['source']
        assert file.read_text().splitlines()[row['line'] - 1] == row['definition'].splitlines()[0]
        assert row['definition'] in file.read_text()
        assert row['verdict'] == '通常側' and row['rust_registration'] is None
    result = (HERE / 'results.md').read_text()
    current = result.split('### 担当27義務の最終判定', 1)[1].split('### 再開4の検査と記録', 1)[0]
    obligations = re.findall(r'^\| (O\d+) \|', current, re.M)
    assert len(obligations) == len(set(obligations)) == 27
    findings = result.split('### 所見ごとの処置', 1)[1].split('### 18名', 1)[0]
    assert set(re.findall(r'^\| ((?:中|軽)\d+) \|', findings, re.M)) == {'中1', '中2'} | {'軽' + str(i) for i in range(1, 11)}
    twelve = result.split('### 三モデルの到達と12欄の四分類', 1)[1].split('| 後続単位', 1)[0]
    categories = re.findall(r'^\| (?:Model|Targets|Http) \| \w+ \| (\S+) \|', twelve, re.M)
    assert Counter(categories) == {'保留': 6, '自明': 3, '空疎': 2, '実質': 1}
    for name in ['stop.md', 'resume1-stop.md', 'resume2-stop.md']:
        assert '再開3で解消した。現在の判定は' in (HERE / name).read_text().splitlines()[2]
    for name in ['audit-summary.json', 'resume1-audit-summary.json', 'resume2-audit-summary.json']:
        assert '分割記録は再開3の監査で置き換えた' in json.loads((HERE / name).read_text())['snapshot_note']
    for name, heading, phrase in [
        ('01-spec/01-12-core-calculus.md', '【決定】本節から', '`BuiltinTypingTransport` の'),
        ('07-quality/07-04-formal-semantics.md', '【決定】`Benitoite.Release.Refinement`', '`BuiltinTypingTransport` は')]:
        text = (ROOT / 'docs/design' / name).read_text()
        assert text.index(heading) < text.index(phrase)
        assert '型付けが読む七つの射影（`Builtins.TypingFieldsEq` の七欄）' in text
        assert '18名の公開名は合成表のキーに現れない' in text
        assert all(n in text for n in ['Body.all', 'Primitive.all', 'Body.definition'])
    audit = audit_result(tmp)
    assert audit['targets'] == 83376 and audit['group_a_declarations'] == 2704
    assert not audit['added_declarations']
    build = json.loads((HERE / 'resume4-default-build.json').read_text())
    assert build['exit'] == 0 and build['raw'] == digest(tmp / 'resume4-default-build.log')
    assert 'Build completed successfully' in (tmp / 'resume4-default-build.log').read_text()
    # 台本の構文、リンク、大きさを全件確かめる。過去の記録の内容は直さない。
    for file in HERE.glob('*.py'):
        compile(file.read_text(), file.name, 'exec')
    files = [f for f in HERE.iterdir() if f.is_file()]
    for file in files:
        assert file.stat().st_size <= 100000, (file.name, file.stat().st_size)
        if file.suffix in ['.md', '.lean', '.json', '.txt']:
            text = file.read_text()
            assert not re.search(r'/(?:Users|private/tmp|tmp)/|\]\([^)]*docs/todo', text), file.name
            if file.suffix == '.md':
                for link in re.findall(r'\]\(([^)]+)\)', text):
                    if not link.startswith(('http:', 'https:', '#')):
                        assert (file.parent / link.split('#')[0]).exists(), (file.name, link)
    assert sum(f.stat().st_size for f in files) < 6000000
    outcome = {'status': 'RV-L60.aの中2・軽10の処置と自己照合を完了。処置の確認と受け入れは取りまとめの担当',
        'b_work': '80230d96305756057a63a07dc2b0d8aa1ebf3a75',
        **composition, 'assumption_categories': classification,
        'evidence_context_bodies': len(rows), 'lookup_comparisons': 114,
        'source_body_references_checked': 130, 'internal_source_references': 0,
        'actual_definitions': {'通常側': 18, '精密側': 0, 'どちらでもない': 0, '未判定': 0},
        'twelve_fields': dict(Counter(categories)), 'obligations': obligations,
        'audited_default_declarations': audit['targets'], 'group_a_declarations': 2704,
        'local_audited_declarations': context['local_audit']['declarations'],
        'new_axioms': 0, 'sorryAx': 0, 'default_import_modules': len(seen),
        'protected_files_in_resume3': len(previous), 'protected_files_in_resume4': len(before),
        'allowed_changed_files': sorted(changed),
        'current_changed_inputs': {f: digest(ROOT / f) for f in sorted(changed)},
        'default_build_executions_in_resume4': 1, 'axiom_audit_executions_in_resume4': 1,
        'work_executions_in_resume4': 0, 'verify_executions_in_resume4': 1,
        'record_files': len(files), 'record_bytes': sum(f.stat().st_size for f in files),
        'maximum_record_bytes': max(f.stat().st_size for f in files)}
    write(HERE / 'resume4-verification.json', outcome)
    print(json.dumps(outcome, ensure_ascii=False))
