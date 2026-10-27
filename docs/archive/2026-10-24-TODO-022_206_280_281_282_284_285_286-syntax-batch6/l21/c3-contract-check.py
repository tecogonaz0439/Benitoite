"""C3 開始前との中心命題・公開言明の照合。git は読み取りだけに使う。"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = 'd2d9954264daea806db0bf202449938bd1dd0291'
source = (OUT / 'contract-check.py').read_text()
helpers = source[source.index('theorem_prefix ='):source.index("paths = git(")]
namespace = {'re': re}
exec(helpers, namespace)
declaration = namespace['declaration']

def old_file(path):
    result = subprocess.run(['git', 'show', f'{BASE}:{path}'], cwd=ROOT,
                            capture_output=True)
    return result.stdout if result.returncode == 0 else None

record = {'c3_start': BASE, 'unchanged_central_definitions': {},
          'unchanged_models': {}, 'unchanged_public_statements': {}}
paths = subprocess.check_output(['git', 'ls-files', 'formal'], cwd=ROOT).decode().splitlines()
for path in paths:
    if not path.endswith('.lean'):
        continue
    old = old_file(path)
    if old is None:  # C3 で新設したモジュールには比較前の言明がない。
        continue
    old, now = old.decode(), (ROOT / path).read_text()
    names = []
    if path.endswith('/Eval.lean'):
        names = [('def', 'NormalSoundness'), ('def', 'WarningSoundness')]
    if path.endswith('/Environment.lean'):
        names += [('def', name) for name in ['Models', 'SlotModels', 'topSlot']]
    if '/Interval/' in path:
        names += [('theorem', name) for name in re.findall(r'^theorem (analyze\w*)\b', old, re.M)]
    for kind, name in names:
        if kind == 'def':
            # この五定義は空行を含まない。後続する匿名例を本文に含めない。
            def body(text):
                start = re.search(r'^def ' + re.escape(name) + r'(?=\s|\{|\(|:)', text, re.M)
                assert start, name
                return text[start.start():].split('\n\n', 1)[0]
            before, after = body(old), body(now)
        else:
            before, after = declaration(old, kind, name), declaration(now, kind, name)
        assert before == after, (path, name)
        group = ('unchanged_public_statements' if kind == 'theorem' else
                 'unchanged_central_definitions' if path.endswith('/Eval.lean') else 'unchanged_models')
        record[group][path + ':' + name] = hashlib.sha256(before.encode()).hexdigest()

record['reference_files'] = {}
for name in ['Eval', 'Environment', 'RangeState', 'Range', 'BudgetRange',
             'BudgetNormal', 'BudgetSound', 'SyntacticReach', 'EvalClosed']:
    path = f'formal/Benitoite/Interval/{name}.lean'
    old, now = old_file(path), (ROOT / path).read_bytes()
    record['reference_files'][path] = {
        'new_since_c3_start': old is None, 'changed_since_c3_start': old != now,
        'current_sha256': hashlib.sha256(now).hexdigest()}

(OUT / 'c3-contract-check.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({key: len(value) for key, value in record.items()
                  if isinstance(value, dict)}, ensure_ascii=False))
