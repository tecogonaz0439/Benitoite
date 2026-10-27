"""基準の全定義・言明を保ち、HTTP の補助宣言だけを追加したことを点検する。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '6e47419f989453b55dc4bc8a121285a1819b3d9f'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def sha(data):
    return hashlib.sha256(data).hexdigest()


assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert git('branch', '--show-current').decode().strip() == 'mod012/L23'
appended = {'formal/Benitoite/Interval/' + name for name in
            ['Eval.lean', 'Environment.lean', 'FixedDomain.lean']}
paths = git('ls-files', 'formal', 'crates/benitoite/testdata/interval-budget').decode().splitlines()
unchanged, additions = {}, {}
statements = 0
for path in paths:
    old = git('show', BASE + ':' + path)
    new = (ROOT / path).read_bytes()
    if old == new:
        unchanged[path] = sha(new)
    elif path in appended:
        ending = b'end Benitoite.Interval\n'
        assert old.endswith(ending) and new.endswith(ending), path
        prefix = old[:-len(ending)]
        assert new.startswith(prefix), path
        added = new[len(prefix):-len(ending)]
        additions[path] = dict(before=sha(old), after=sha(new),
                               preserved_prefix=sha(prefix), added_sha256=sha(added))
    else:
        assert path == 'formal/Benitoite.lean', path
        assert new.replace(b'import Benitoite.Interval.HttpRecordExamples\n', b'') == old
    if path.endswith('.lean'):
        statements += len(re.findall(r'^\s*(?:@\[[^\n]*?\]\s*)?'
            r'(?:(?:private|protected|noncomputable)\s+)*(?:theorem|lemma)\s+', old.decode(), re.M))

assert set(additions) == appended
assert not git('diff', BASE, '--', 'crates', 'fuzz', 'scripts',
               'formal/lakefile.toml', 'formal/lean-toolchain')
new_file = 'formal/Benitoite/Interval/HttpRecordExamples.lean'
sources = [ROOT / p for p in appended] + [ROOT / new_file]
for path in sources:
    code = re.sub(r'/\-.*?\-/', '', path.read_text(), flags=re.S)
    code = re.sub(r'--[^\n]*', '', code)
    assert not re.search(r'\b(sorry|admit|native_decide|implemented_by|extern|unsafe)\b|'
                         r'^\s*axiom\b|^\s*attribute\b', code, re.M), path.name
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = dict(base=BASE, head=BASE, unchanged_existing_theorem_statements=statements,
    appended_formal=additions, unchanged_tracked_sha256=unchanged,
    new_examples_sha256=sha((ROOT / new_file).read_bytes()),
    central_definitions_and_all_existing_declarations_byte_preserved=True,
    protected_definitions=['NormalSoundness', 'WarningSoundness', 'EvalPartial', 'Unmodeled',
        'UnknownAt', 'ConcreteValue', 'ConcreteValue.type', 'targetOperationAt', 'concreteRule',
        'AbstractSlot', 'AbstractEnv', 'SlotModels', 'Models'],
    no_new_axioms_or_proof_holes=True, fixed_tables_unchanged=True,
    analysis_budget_and_closed_evaluator_unchanged=True, git_diff_check=0)
(OUT / 'contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k: v for k, v in record.items()
    if k not in ['unchanged_tracked_sha256', 'appended_formal']}, ensure_ascii=False))
