#!/usr/bin/env python3
"""試行の差分の各変更行を、新しい版の宣言へ対応付け、言明・証明・定義・腕・Top の構築に分類する（字句の近似）。
使い方: classify.py <worktree の根> <出力の JSON>"""
import json, re, subprocess, sys
W, out = sys.argv[1], sys.argv[2]
diff = subprocess.run(['git', '-C', W, 'diff', '-U0', '--', 'formal'], capture_output=True, text=True).stdout
decl_re = re.compile(r'^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*(theorem|lemma|def|abbrev|instance|inductive|structure|example|opaque|axiom|class)\b\s*([^\s:(\[{]*)')
files = {}
cur = None
for line in diff.splitlines():
    if line.startswith('+++ b/'):
        cur = line[6:]; files.setdefault(cur, {'added': [], 'removed': 0})
    elif line.startswith('@@'):
        m = re.match(r'@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', line)
        start, cnt = int(m.group(1)), int(m.group(2) or 1)
        files[cur]['added'].extend(range(start, start + cnt))
    elif line.startswith('-') and not line.startswith('---'):
        files[cur]['removed'] += 1
res = {'files': {}, 'totals': {}}
cats = {}
decls = {}
for f, d in files.items():
    lines = open(f'{W}/{f}', encoding='utf-8').read().splitlines()
    # 各行の宣言と、言明の部分か本体かを決める
    info = []
    curd, kind, in_stmt = ('<header>', 'header', False)
    for i, s in enumerate(lines):
        m = decl_re.match(s)
        if m:
            kind = m.group(1); curd = m.group(2) or f'<{kind}@{i+1}>'; in_stmt = True
        info.append((kind, curd, in_stmt))
        if in_stmt and re.search(r':=\s*(by\b.*)?$|:= ', s):
            in_stmt = False
    for ln in d['added']:
        if ln - 1 >= len(lines): continue
        s = lines[ln - 1]
        kind, name, stmt = info[ln - 1]
        if re.search(r'nameTop|opaqueTop', s) and kind not in ('abbrev',):
            c = 'top_builder'
        elif re.match(r'^\s*\|', s):
            c = 'match_arm'
        elif kind in ('theorem', 'lemma') and stmt:
            c = 'theorem_statement'
        elif kind in ('theorem', 'lemma'):
            c = 'proof'
        elif kind == 'example':
            c = 'example'
        elif kind == 'header':
            c = 'header'
        else:
            c = 'definition'
        cats[c] = cats.get(c, 0) + 1
        decls.setdefault(c, set()).add((f, f'{kind} {name}'))
res['totals'] = {c: {'changed_lines': n, 'declarations': len(decls[c]), 'files': len({x[0] for x in decls[c]})} for c, n in cats.items()}
alld = set().union(*decls.values())
res['totals']['all'] = {'changed_lines': sum(cats.values()), 'declarations': len(alld), 'files': len(files)}
res['by_category'] = {c: sorted(f'{a}: {b}' for a, b in v) for c, v in decls.items()}
json.dump(res, open(out, 'w'), ensure_ascii=False, indent=1)
print(json.dumps(res['totals'], ensure_ascii=False, indent=1))
for c in ('theorem_statement', 'definition', 'header'):
    print('==', c)
    for x in res['by_category'].get(c, []): print('  ', x)
