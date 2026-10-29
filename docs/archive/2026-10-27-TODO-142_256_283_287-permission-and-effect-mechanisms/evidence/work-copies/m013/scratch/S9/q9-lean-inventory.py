#!/usr/bin/env python3
"""S9 読み取り専用の git grep と字句上の直接参照の集計。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

OUT = Path(__file__).resolve().parent
BASE = '04c78e527e6c23c0be8a9dbce26f23d685a5e04d'
AREAS = ['formal/Benitoite/Release', 'formal/Benitoite/Surface']

def git(*args):
    p = subprocess.run(['git', *args], text=True, capture_output=True)
    if p.returncode not in (0, 1):
        raise RuntimeError(p.stderr)
    return p.stdout

# 既存SAのコメント/文字列消去関数だけを抽出する。元のスクリプトの本体は実行しない。
helper_path = Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/spikes/SA/inventory.py')
helper = ast.parse(helper_path.read_text())
node = next(n for n in helper.body if isinstance(n, ast.FunctionDef) and n.name == 'erase_comments_strings')
exec(compile(ast.Module(body=[node], type_ignores=[]), '<SA erase function>', 'exec'))

GROUPS = {
    'operation_signature': ['OpDecl','OpSig','opSig','V_Op'],
    'handler_removal': ['effOps','handles','handled','HasTypeClausesQ','HasClausesQ','C_Handle','E_Handle','K_Handle','name_end','end_of_noHandler'],
    'row_substitution': ['substAt','substAtoms','MethodRowsAdmissible','Admissible','NoFail','Qsig'],
    'type_effect_representation': ['EffName','Atom','Canonical','norm','eq_of_sub_of_sub'],
}

SYMBOLS = sorted(set(sum(GROUPS.values(), [])))
patterns = {k: r'\b(?:' + '|'.join(map(re.escape, vs)) + r')\b' for k, vs in GROUPS.items()}
raw = {}
for s in SYMBOLS:
    result = git('grep', '-n', '-w', s, BASE, '--', *AREAS)
    (OUT / ('q9-lean-' + s + '.grep.txt')).write_text(result)
    raw[s] = {'lines': len(result.splitlines()), 'files': len({x.split(':', 2)[1] for x in result.splitlines()})}

entries = []
hashes = {}
for path in git('ls-tree', '-r', '--name-only', BASE, *AREAS).splitlines():
    if not path.endswith('.lean'):
        continue
    source = git('show', BASE + ':' + path)
    hashes[path] = hashlib.sha256(source.encode()).hexdigest()
    lines = erase_comments_strings(source).splitlines(keepends=True)
    heads = []
    bounds = []
    for i, line in enumerate(lines):
        if re.match(r'^(?:namespace|end|section|noncomputable\s+section|mutual|example|(?:noncomputable\s+)?instance|variable|open|attribute|import)\b|^#', line):
            bounds.append(i)
        d = re.match(r'^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe)\s+)*(theorem|lemma|def|abbrev|inductive|structure)\s+([^\s({:]+)', line)
        if d:
            heads.append((i, d))
    for pos, (i, d) in enumerate(heads):
        stop = heads[pos + 1][0] if pos + 1 < len(heads) else len(lines)
        stop = min([stop] + [b for b in bounds if i < b < stop])
        body = ''.join(lines[i:stop])
        body = body[:d.start(2)] + ' ' * (d.end(2)-d.start(2)) + body[d.end(2):]
        cats = [k for k, p in patterns.items() if re.search(p, body)]
        if cats:
            entries.append({'path': path, 'line': i+1, 'kind': d[1], 'name': d[2], 'categories': cats,
                            'statement_categories': [k for k,p in patterns.items() if re.search(p,body.split(':=',1)[0])]})

summary = {}
for group in [*GROUPS, 'union']:
    selected = [e for e in entries if group == 'union' or group in e['categories']]
    theorems = [e for e in selected if e['kind'] in ('theorem','lemma')]
    core = [e for e in theorems if not re.search(r'Examples|Counterexamples|/Model\.lean|/tests/',e['path'])]
    summary[group] = {'declarations':len(selected), 'files':len({e['path'] for e in selected}),
                      'theorems':len(theorems),'theorem_files':len({e['path'] for e in theorems}),
                      'nonexample_theorems':len(core),'nonexample_files':len({e['path'] for e in core}),
                      'statement_theorems':sum(bool(e['statement_categories']) if group == 'union' else group in e['statement_categories'] for e in theorems)}
result = {'base': BASE, 'areas': AREAS, 'raw': raw, 'groups':summary, 'entries':entries, 'sha256':hashes,
          'limits':'git grep -n -w; comments, strings and own declaration name excluded in declaration scan; direct lexical references, not Lean dependency graph or exact edits; statement split at first := is approximate'}
(OUT/'q9-lean-inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
report = ['# S9 Q9 Lean 直接参照の集計','',f'基準版: `{BASE}`。','',
          'git grep -n -w と宣言単位の字句検索。コメント・文字列・自身の宣言名を除く。推移的依存数でも変更確定数でもない。',
          '', '| 群 | 宣言 | 定理 | 定理のファイル | 例を除く定理 | 言明に直接現れる定理 |', '|---|---:|---:|---:|---:|---:|']
for k,s in summary.items():
    report.append(f"| {k} | {s['declarations']} | {s['theorems']} | {s['theorem_files']} | {s['nonexample_theorems']} | {s['statement_theorems']} |")
report += ['', '## 宣言の一覧','']
for e in entries:
    report.append(f"- `{e['path']}:{e['line']}` `{e['name']}` ({e['kind']}): {', '.join(e['categories'])}; 言明: {', '.join(e['statement_categories'])}")
(OUT/'q9-lean-inventory.md').write_text('\n'.join(report)+'\n')
print(json.dumps({'base':BASE,'raw':raw,'groups':summary},ensure_ascii=False,indent=2))
