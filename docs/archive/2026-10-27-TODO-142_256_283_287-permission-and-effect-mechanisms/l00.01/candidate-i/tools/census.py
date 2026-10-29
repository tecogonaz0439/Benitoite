#!/usr/bin/env python3
"""案 (i) で引数の数が変わる構成子（Atom.name・Ty.opaque）を字面に書いた箇所を、
変更したモジュールに依存するファイルについて数える。字句の近似であり、Lean の依存解析ではない。
使い方: census.py <formal の根（基準の状態）> <出力の JSON>"""
import json, os, re, sys
root, out = sys.argv[1], sys.argv[2]
def mod_of(p): return p[:-5].replace('/', '.')
mods = {}
for dp, _, fs in os.walk(root):
    if '.lake' in dp: continue
    for f in fs:
        if f.endswith('.lean') and f != 'lakefile.lean':
            rel = os.path.relpath(os.path.join(dp, f), root); mods[mod_of(rel)] = rel
imports = {m: [x for x in re.findall(r'^import\s+(\S+)', open(os.path.join(root, r), encoding='utf-8').read(), re.M) if x in mods] for m, r in mods.items()}
aff = {'Benitoite.Release.Atom', 'Benitoite.Release.Types'}
g = True
while g:
    g = False
    for m, i in imports.items():
        if m not in aff and any(x in aff for x in i): aff.add(m); g = True
pat = {
 'Ty.opaque': re.compile(r'(?:(?<=[\s(\[,⟨])|^)(?:Ty)?\.opaque\b(?!\s+"[^"]*"\s+\d)'),
 'Atom.name': re.compile(r'(?:(?<=[\s(\[,⟨])|^)(?:Atom)?\.name\b'),
}
decl_re = re.compile(r'^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*(theorem|lemma|def|abbrev|instance|inductive|structure|example|opaque|axiom|class)\b\s*([^\s:(\[{]*)')
res = {k: {'sites': 0, 'arm_sites': 0, 'files': set(), 'decls': set(), 'theorem_decls': set()} for k in pat}
for m in sorted(aff):
    rel = mods[m]
    lines = open(os.path.join(root, rel), encoding='utf-8').read().splitlines()
    cur = ('<header>', '')
    in_comment = False
    for i, line in enumerate(lines):
        if '/-' in line and '-/' not in line: in_comment = True
        if in_comment:
            if '-/' in line: in_comment = False
            continue
        code = line.split('--')[0]
        md = decl_re.match(code)
        if md: cur = (md.group(1), md.group(2) or f'<{md.group(1)}@{i+1}>')
        for k, p in pat.items():
            n = len(p.findall(code))
            if not n: continue
            # Exchange の JSON や記録の欄の .name を除く近似: Release の型を使わないファイル群も含むので、件数は上限寄り
            r = res[k]; r['sites'] += n
            if re.match(r'^\s*\|', code): r['arm_sites'] += n
            r['files'].add(rel); r['decls'].add((rel, cur[1]))
            if cur[0] in ('theorem', 'lemma'): r['theorem_decls'].add((rel, cur[1]))
outj = {'affected_files': len(aff)}
for k, r in res.items():
    outj[k] = {'sites': r['sites'], 'match_arm_sites': r['arm_sites'], 'files': len(r['files']), 'declarations': len(r['decls']),
               'theorem_declarations': len(r['theorem_decls']), 'file_list': sorted(r['files'])}
both_f = res['Ty.opaque']['files'] | res['Atom.name']['files']
both_d = res['Ty.opaque']['decls'] | res['Atom.name']['decls']
outj['union'] = {'files': len(both_f), 'declarations': len(both_d)}
json.dump(outj, open(out, 'w'), ensure_ascii=False, indent=1)
print(json.dumps({k: ({kk: vv for kk, vv in v.items() if kk != 'file_list'} if isinstance(v, dict) else v) for k, v in outj.items()}, ensure_ascii=False, indent=1))
