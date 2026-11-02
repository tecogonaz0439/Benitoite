"""段末の対象・義務・署名・入力の小さい照合。リポジトリは変更しない。"""
from pathlib import Path
import collections
import hashlib
import json
import re
import sys
import argparse
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
STAGE = HERE.parent

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--targets', type=Path, help='A-Lが<tmp>に再生成した全名の一覧')
parser.add_argument('--axioms', type=Path, help='A-Lの生出力')
args = parser.parse_args()
summary = json.loads((STAGE / 'audit-summary.json').read_text())
if args.targets:
    target_bytes = args.targets.read_bytes()
else:
    with tempfile.TemporaryDirectory() as temporary:
        output = Path(temporary) / 'targets.txt'
        env = dict(os.environ, L20_AUDIT_TARGETS=str(output))
        result = subprocess.run(['lake', 'env', 'lean', '-M', '12288',
            str((STAGE / 'audit-inventory.lean').relative_to(ROOT)).replace('docs/', '../docs/', 1)],
            cwd=ROOT / 'formal', env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        assert result.returncode == 0, result.stdout.decode()
        target_bytes = output.read_bytes()
assert len(target_bytes) == summary['targets_bytes']
assert hashlib.sha256(target_bytes).hexdigest() == summary['targets_sha256']
names = target_bytes.decode().splitlines()
assert len(names) == len(set(names)) == summary['targets']
assert names == sorted(names)
modules = [s.split()[0] for s in (STAGE / 'audit-modules.txt').read_text().splitlines()]
assert len(modules) == len(set(modules)) == summary['modules']
assert summary['with_axioms'] + summary['without_axioms'] == len(names)
allowed = {'propext', 'Quot.sound', 'Classical.choice'}
for axioms in summary['axiom_sets']:
    assert axioms == 'none' or set(axioms.split(' + ')) <= allowed
if args.axioms:
    raw = args.axioms.read_bytes()
    assert len(raw) == summary['raw_bytes']
    assert hashlib.sha256(raw).hexdigest() == summary['raw_sha256']
    records = re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])", raw.decode(), re.M | re.S)
    found = collections.Counter(n for n, _, _ in records)
    assert set(found) == set(names) and all(n == 1 for n in found.values())
    sets = collections.Counter(tuple(sorted(s.strip() for s in a.split(',') if s.strip())) for _, _, a in records)
    assert {' + '.join(k) or 'none': n for k, n in sets.items()} == summary['axiom_sets']

# 宣言ではない語を役割ごとに区分する。未知の識別子は例外に加えず失敗させる。
roles = {
    'notation': set('A B C D E F I J K L N O P P0 Q R S Eb ID IH _empty'.split()),
    'language_and_frames': set('API BC Byte Bytes CLI Fail Guard HandleFail IO Lazy6 Lean Let Mark None RSS RV Reference4 Refinement Release Rust SMT UF Update'.split()),
    'prose': set('case change checker cutoff forms if plan stage work canonical decode filter reverse scrutinee typed'.split()),
    'withdrawn': {'embedStep'},
}
role_tokens = set().union(*roles.values())
def metadata(token):
    return re.fullmatch(r'(?:O\d{3}|[A-H]\d+[A-Za-z]?|[GLRSVJH]\d+[A-Za-z]?|L20\.s|L10F(?:37|[ABCDE])?|CQ24|V29|plan26)', token)
stage_text = (STAGE / 'stage-results.md').read_text()
prose = re.sub(r'\]\([^)]+\)', ']', stage_text)
prose = re.sub(r'[A-Za-z0-9_./-]+\.(?:md|lean|json|txt|py)\b', '', prose)
all_tokens = set(re.findall(r'(?<![A-Za-z0-9_])[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*', prose))
auxiliary = {'FirstFailureHandoff'}
rust_names = {'collect_impl'}
tokens = sorted(t for t in all_tokens if t not in role_tokens and not metadata(t)
                and t not in auxiliary and t not in rust_names)
with tempfile.TemporaryDirectory() as temporary:
    source_tokens = Path(temporary) / 'stage-tokens.txt'
    source_tokens.write_text('\n'.join(tokens) + '\n')
    env = dict(os.environ, L20_STAGE_TOKENS=str(source_tokens))
    result = subprocess.run(['lake', 'env', 'lean', '-M', '12288',
        '../' + str((HERE / 'stage-names.lean').relative_to(ROOT))],
        cwd=ROOT / 'formal', env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert result.returncode == 0, result.stdout.decode()
    stage_names = re.findall(r'^STAGE_(DECL|MODULE|NAMESPACE|UNRESOLVED) (\S+)(?: (\S+))?$', result.stdout.decode(), re.M)
    assert {t for _, t, _ in stage_names} == set(tokens)
    unresolved = [t for kind, t, _ in stage_names if kind == 'UNRESOLVED']
    assert not unresolved, unresolved
    name_counts = collections.Counter(kind for kind, _, _ in stage_names)
    if output := os.environ.get('L20_STAGE_OUTPUT'):
        Path(output).write_bytes(result.stdout)
    name_output_sha256 = hashlib.sha256(result.stdout).hexdigest()
    name_output_bytes = len(result.stdout)
# 改造内だけの補助宣言は、定義と名前空間の実在・Leanの検査を確認する。
aux_path = STAGE / 'n/h04-handoff.lean'
aux_text = aux_path.read_text()
assert 'namespace Benitoite.Release.Refinement.IntervalConnection.H04' in aux_text
assert re.search(r'^def FirstFailureHandoff\b', aux_text, re.M)
aux_check = subprocess.run(['lake', 'env', 'lean', '-M', '12288', '../' + str(aux_path.relative_to(ROOT))],
    cwd=ROOT / 'formal', stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
assert aux_check.returncode == 0, aux_check.stdout.decode()
rust_text = (ROOT / 'crates/benitoite/src/typeck/traits/collect.rs').read_text()
assert re.search(r'\bfn collect_impl\b', rust_text)
# 存在しなかった二語は例外にも対象文書にも置かない。
for bad in ['SourceScopedType', 'SourceScopedTypeSubstCode']:
    assert bad not in all_tokens and bad not in role_tokens

source = (STAGE / 'detail.md').read_text()
source = source[source.index('### plan のL20担当28行'):source.index('## 本番追随の最初の同種19規則')]
expected = set(re.findall(r'^\| (O\d{3})[ ・]', source, re.M))
actual = re.findall(r'^\| (O\d{3})・', (STAGE / 'stage-results.md').read_text(), re.M)
assert len(expected) == len(actual) == len(set(actual)) == 60
assert expected == set(actual)
obligations = json.loads((STAGE / 'stage-obligations.json').read_text())
assert set(actual) == {row['id'] for row in obligations['rows']}
assert collections.Counter(row['category'] for row in obligations['rows']) == {
    'proof_leaf': 27, 'operation': 2, 'common': 4, 'inherited_other': 27}
assert obligations['whole_obligations_closed'] == 0
plan = (STAGE.parent / 'plan.md').read_text()
for obligation in ['O027', 'O118']:
    row = next(row for row in obligations['rows'] if row['id'] == obligation)
    line = next(line for line in plan.splitlines() if line.startswith('| ' + obligation + ' |'))
    assignments = line.split('|')[4].strip().split('/')
    assert row['remaining_stages'] == assignments
    actual_row = next(line for line in stage_text.splitlines() if line.startswith('| ' + obligation + '・'))
    for owner in assignments:
        assert owner in actual_row.split('|')[-2], (obligation, owner)


regular = (ROOT / 'formal/Benitoite/Release/Refinement/LegacyRegularity.lean').read_text()
regular = regular[regular.index('inductive LegacyRule'):]
rules = set(re.findall(r'^  \| (V_\w+|Vs_\w+|Each_\w+|C_\w+|Arms_\w+|Clauses_\w+|Failure_\w+)\b', regular, re.M))
listed_rules = re.findall(r'^\| (V_\w+|Vs_\w+|Each_\w+|C_\w+|Arms_\w+|Clauses_\w+|Failure_\w+) \|', (STAGE / 'stage-results.md').read_text(), re.M)
assert len(rules) == len(listed_rules) == len(set(listed_rules)) == 46
assert rules == set(listed_rules)

handwritten = json.loads((HERE / 'declarations.json').read_text())
assert len(handwritten) == len({i['name'] for i in handwritten}) == 125
assert {i['name'] for i in handwritten} <= set(names)
assert sum(not i['private'] for i in handwritten) == 29
assert collections.Counter(i['kind'] for i in handwritten) == {'theorem': 101, 'def': 16, 'abbrev': 8}
for filename in ['signatures.md', 'aux-signatures.md']:
    assert (HERE / filename).stat().st_size <= 100000

comment_ids = []
for mod in modules:
    path = ROOT / 'formal' / (mod.replace('.', '/') + '.lean')
    assert path.is_file(), mod
    for comment in re.findall(r'/\-[\s\S]*?\-/|--[^\n]*', path.read_text()):
        if re.search(r'\b(?:L20|RV-L20|TODO-\d|O\d{3}|S0\d)\b', comment):
            comment_ids.append(mod)
assert not comment_ids, comment_ids

before = json.loads((HERE / 'inputs.json').read_text())['files']
unchanged = 0
for name, meta in before.items():
    if name.startswith('formal/') and name not in [
        'formal/Benitoite.lean', 'formal/Benitoite/Release/Refinement/Embedding.lean']:
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == meta['sha256'], name
        unchanged += 1

files = [STAGE / 'stage-results.md', STAGE / 'audit-summary.md',
         HERE / 'results.md', HERE / 'signatures.md', HERE / 'aux-signatures.md',
         ROOT / 'docs/design/01-spec/01-12-core-calculus.md',
         ROOT / 'docs/design/07-quality/07-04-formal-semantics.md']
for path in files:
    text = path.read_text()
    assert not re.search(r'/Users/|/private/(?:tmp|var)|\]\([^)]*docs/todo', text), path.name
    prose = re.sub(r'```[\s\S]*?```|`[^`]*`', '', text)
    for target in re.findall(r'\]\(([^)]+)\)', prose):
        if target.startswith(('http:', 'https:', '#', 'mailto:')):
            continue
        target = target.split('#')[0]
        assert (path.parent / target).exists(), (path.name, target)

print(json.dumps({'targets': len(names), 'modules': len(modules), 'obligations': 60,
                  'rules': 46, 'handwritten': len(handwritten), 'unchanged_inputs': unchanged,
                  'comment_id_matches': len(comment_ids), 'links': 'ok',
                  'stage_names': dict(name_counts), 'auxiliary_declarations': 1, 'rust_declarations': 1,
                  'name_output_bytes': name_output_bytes, 'name_output_sha256': name_output_sha256}, ensure_ascii=False))
