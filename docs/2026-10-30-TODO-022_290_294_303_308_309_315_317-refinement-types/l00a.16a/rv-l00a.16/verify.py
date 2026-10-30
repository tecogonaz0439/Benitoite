#!/usr/bin/env python3
"""RV-L00a.16の文書・上限算術・入力不変性を照合する。ビルドしない。"""
from datetime import datetime, timezone
from decimal import Decimal as D, ROUND_CEILING
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
CHANGE = HERE.parent.parent
ROOT = CHANGE.parent.parent


def save(name, value):
    (HERE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def upper(seconds, plan):
    return str((seconds / D(3600) / plan).quantize(D('.001'), rounding=ROUND_CEILING))


past = D('11274.486227')
first16 = D('739.025')
span = D(14879)
groups = [
    ('埋め込み', D(817), D('.5'), D(1)),
    ('移動・置換・被覆', D('2943.021'), D(2), D(4)),
    ('相互置換・narrowing', D(3772), D(1), D(2)),
    ('証明以外', past + first16 - D('7532.021'), D('3.5'), D(7)),
    ('合計', past + first16, D(7), D(14)),
    ('隙間を含む対象区間', span + first16, D(7), D(14)),
]
ratios = [{'group': n, 'elapsed_seconds': str(e), 'plan_low_hours': str(lo),
           'plan_high_hours': str(hi), 'ratio_upper_at_high': upper(e, hi),
           'ratio_upper_at_low': upper(e, lo)} for n, e, lo, hi in groups]
save('bounds.json', {'scope': 'RV対象の初版まで。今回のレビュー対応は含めない',
                    'past_elapsed_seconds': str(past), 'first16_seconds': str(first16),
                    'past_span_seconds': str(span), 'gap_seconds': str(span - past),
                    'total_recorded_seconds': str(past + first16),
                    'past_span_plus_first16_seconds': str(span + first16),
                    'gap_12_to_16_seconds': 746,
                    'continuous_span_seconds': str(span + first16 + D(746)),
                    'ratio_bounds': ratios})
assert sum(e for _, e, _, _ in groups[:4]) == past + first16
assert [r['ratio_upper_at_low'] for r in ratios] == ['0.454', '0.409', '1.048', '0.356', '0.477', '0.620']

problems = []
docs = {}
paths = [CHANGE / 'l00a.16a' / n for n in ('results.md', 'lemmas.md', 'times.md')]
paths += [CHANGE / 'l00a.16b' / n for n in ('results.md', 'estimate.md')]
for p in paths:
    s = p.read_text()
    fences = 0
    cols = None
    tables = links = 0
    for i, line in enumerate(s.splitlines(), 1):
        if line.startswith('```'):
            fences += 1
            continue
        if fences % 2:
            continue
        if line.startswith('|'):
            n = len(line.split('|')) - 2
            if cols is None:
                cols = n
                tables += 1
            if cols != n:
                problems.append([str(p.relative_to(CHANGE)), i, '表の列数不一致'])
        else:
            cols = None
    if fences % 2:
        problems.append([str(p), 'コード柵が閉じていない'])
    for target in re.findall(r'\]\(([^)]+)\)', s):
        if target.startswith(('http:', 'https:', '#')):
            continue
        name, _, anchor = target.partition('#')
        q = p.parent / name
        if not q.exists():
            problems.append([str(p.relative_to(CHANGE)), target, 'リンク先なし'])
        elif anchor and q.suffix == '.md':
            headings = re.findall(r'^#+ (.+)$', q.read_text(), re.M)
            slugs = [re.sub(r'[^\w\- ]', '', x.lower()).replace(' ', '-') for x in headings]
            if anchor not in slugs:
                problems.append([str(p.relative_to(CHANGE)), target, '見出しなし'])
        links += 1
    docs[str(p.relative_to(CHANGE))] = {'tables': tables, 'links': links}

estimate = (CHANGE / 'l00a.16b/estimate.md').read_text()
assert estimate.index('## 見込みの読み方の選択肢') < estimate.index('## 相談条件に当たった場合の実装方針の選択肢')
assert estimate.index('| E、E_g |') < estimate.index('| 群（RV対象の初版まで）')
for p in [CHANGE / 'l00a.16a/results.md', CHANGE / 'l00a.16b/results.md']:
    assert '## RV-L00a.16 への対応' in p.read_text()
    for mark in ['中1', '中2', '中3', *['軽' + str(i) for i in range(1, 8)]]:
        assert '| ' + mark + ' |' in p.read_text()

before = json.loads((HERE / 'inputs-before.json').read_text())
after = {name: {'bytes': (ROOT / name).stat().st_size,
                'sha256': hashlib.sha256((ROOT / name).read_bytes()).hexdigest()} for name in before}
save('inputs-after.json', after)
changed = [name for name in before if before[name] != after[name]]
assert not changed
compiled = json.loads((CHANGE / 'l00a.16a/environment.json').read_text())['compiled_inputs']
compiled_changes = [name for name, record in compiled.items()
                    if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != record['sha256']]
assert not compiled_changes

axioms = json.loads((CHANGE / 'l00a.16a/axioms-summary.json').read_text())
targets = json.loads((CHANGE / 'l00a.16a/targets.json').read_text())
input_names = re.findall(r'^#print axioms (\S+)', (CHANGE / 'l00a.16a/axioms.lean').read_text(), re.M)
assert axioms['pass'] and axioms['count'] == targets['count'] == len(input_names) == 694
assert set(input_names) == set(targets['targets']) == set(axioms['dependencies'])

old_docs = json.loads((HERE / 'documents-before.json').read_text())
root_relative_changes = [name for name, content in old_docs.items() if (ROOT / name).read_text() != content]
assert len(root_relative_changes) == 5
assert not any(name.endswith('work-orchestrator.md') for name in root_relative_changes)
out = {'verified_at': datetime.now(timezone.utc).isoformat(), 'documents': docs, 'problems': problems,
       'protected_inputs': len(after), 'protected_changes': changed,
       'compiled_inputs': len(compiled), 'compiled_changes': compiled_changes,
       'axioms_input_names': len(input_names), 'axioms_rerun': False,
       'changed_documents': root_relative_changes,
       'review_response': '中1〜中3・軽1〜7が両resultsにあり、読み方/凡例の順序を確認',
       'independent_review': False}
save('document-check.json', out)
assert not problems, problems
print(json.dumps({k: v for k, v in out.items() if k != 'changed_documents'}, ensure_ascii=False))
