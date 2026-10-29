#!/usr/bin/env python3
"""比較用ビルドのログから、診断を宣言・ファイルへ対応付けて数え、未検査のモジュールを列挙する。
使い方: count_breaks.py <formal の根> <ログ> <変更したモジュール,...> <出力の JSON>"""
import json, os, re, sys

root, logf, changed, out = sys.argv[1], sys.argv[2], sys.argv[3].split(','), sys.argv[4]
# 宣言の対応付けは、ビルドした時点のソースの写し（第5引数）で行う
src = sys.argv[5] if len(sys.argv) > 5 else root

def mod_of(path):
    return path[:-5].replace('/', '.')

mods = {}
for dp, _, fs in os.walk(root):
    if '.lake' in dp:
        continue
    for f in fs:
        if f.endswith('.lean') and f != 'lakefile.lean':
            rel = os.path.relpath(os.path.join(dp, f), root)
            mods[mod_of(rel)] = rel
imports = {}
for m, rel in mods.items():
    imps = []
    for line in open(os.path.join(root, rel), encoding='utf-8'):
        mm = re.match(r'^import\s+(\S+)', line)
        if mm and mm.group(1) in mods:
            imps.append(mm.group(1))
    imports[m] = imps
# 変更したモジュールに推移的に依存するモジュール（変更したもの自身を含む）
affected = set(changed)
changed_flag = True
while changed_flag:
    changed_flag = False
    for m, imps in imports.items():
        if m not in affected and any(i in affected for i in imps):
            affected.add(m)
            changed_flag = True

log = open(logf, encoding='utf-8').read().splitlines()
checked, failed = set(), set()
for line in log:
    mm = re.match(r'^[✔✖⚠ℹ] \[\d+/\d+\] (Built|Building|Replayed) (\S+?)(:c\.o|:exe|:\S+)? ', line)
    if mm and mm.group(3) is None:
        m = mm.group(2)
        if m in mods:
            checked.add(m)
            if line.startswith('✖'):
                failed.add(m)

decl_re = re.compile(r'^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*'
                     r'(theorem|lemma|def|abbrev|instance|inductive|structure|example|opaque|axiom|class)\b\s*([^\s:(\[{]*)')
def decl_at(rel, lineno):
    lines = open(os.path.join(src, rel), encoding='utf-8').read().splitlines()
    for i in range(min(lineno, len(lines)) - 1, -1, -1):
        mm = decl_re.match(lines[i])
        if mm:
            name = mm.group(2) or f'<{mm.group(1)}@{i+1}>'
            if mm.group(1) in ('example', 'instance') and not mm.group(2):
                name = f'<{mm.group(1)}@{i+1}>'
            return f'{mm.group(1)} {name}', i + 1
    return '<file header>', 0

diags = []
for line in log:
    mm = re.match(r'^(error|warning): (\S+\.lean):(\d+):(\d+): (.*)$', line)
    if not mm:
        continue
    kind, rel, ln, col, msg = mm.group(1), mm.group(2), int(mm.group(3)), int(mm.group(4)), mm.group(5)
    if kind == 'warning' and 'sorry' not in msg:
        continue
    d, dl = decl_at(rel, ln)
    diags.append({'kind': kind, 'file': rel, 'line': ln, 'col': col, 'decl': d, 'decl_line': dl, 'msg': msg[:120]})
errs = [d for d in diags if d['kind'] == 'error']
decls = sorted({(d['file'], d['decl']) for d in errs})
files = sorted({d['file'] for d in errs})
# 失敗したモジュールに推移的に依存するモジュールは、lake が検査しない（失敗したもの自身は除く）
blocked = set(failed)
grow = True
while grow:
    grow = False
    for m, imps in imports.items():
        if m not in blocked and any(i in blocked for i in imps):
            blocked.add(m)
            grow = True
unchecked = sorted(blocked - failed)
res = {
    'affected_modules': len(affected),
    'checked_affected': len(affected - set(unchecked)),
    'failed_modules': sorted(failed),
    'error_diagnostics': len(errs),
    'sorry_warnings_from_errors': len([d for d in diags if d['kind'] == 'warning']),
    'broken_declarations': len(decls),
    'broken_files': len(files),
    'declarations': [{'file': f, 'decl': d, 'errors': len([e for e in errs if e['file'] == f and e['decl'] == d])} for f, d in decls],
    'files': files,
    'unchecked_count': len(unchecked),
    'unchecked': unchecked,
    'diagnostics': diags,
}
json.dump(res, open(out, 'w'), ensure_ascii=False, indent=1)
print(json.dumps({k: v for k, v in res.items() if k not in ('diagnostics', 'unchecked', 'declarations', 'files')}, ensure_ascii=False))
for x in res['declarations']:
    print(f"  {x['file']}: {x['decl']} ({x['errors']})")
