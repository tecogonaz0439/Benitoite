#!/usr/bin/env python3
"""比較用ビルドのログから、誤りを宣言・ファイルへ対応付け、未検査のモジュールを数える。
使い方: breakage.py <formal のディレクトリ> <ログ> <出力の JSON>"""
import json, re, sys, os
from collections import defaultdict

formal, logf, outf = sys.argv[1], sys.argv[2], sys.argv[3]
roots = ["Benitoite", "DesugarDiff.Main", "BuiltinCheck.Main", "CoverageDiff.Main",
         "CoverageProgramDiff.Main", "SurfaceCheck.Main", "SurfaceCheck.All", "IntervalDiff.Main"]

def mod_path(m):
    return os.path.join(formal, *m.split(".")) + ".lean"

imports = {}
def load(m):
    if m in imports: return
    p = mod_path(m)
    if not os.path.exists(p):
        return
    imps = []
    for line in open(p, encoding="utf-8"):
        mm = re.match(r"\s*import\s+(\S+)", line)
        if mm: imps.append(mm.group(1))
    imports[m] = [i for i in imps if os.path.exists(mod_path(i))]
    for i in imports[m]: load(i)
for r in roots: load(r)
closure = set(imports)

log = open(logf, encoding="utf-8").read().splitlines()
failed = set()
for l in log:
    mm = re.match(r"✖ \[\d+/\d+\] Building (\S+)", l)
    if mm: failed.add(mm.group(1))

rdeps = defaultdict(set)
for m, imps in imports.items():
    for i in imps: rdeps[i].add(m)
unchecked = set()
stack = list(failed)
while stack:
    x = stack.pop()
    for y in rdeps[x]:
        if y not in unchecked and y not in failed:
            unchecked.add(y); stack.append(y)

decl_re = re.compile(r"^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*"
                     r"(theorem|lemma|def|abbrev|instance|structure|inductive|class|example|opaque|axiom)\b\s*([^\s:({\[]*)")
def enclosing(file, line):
    p = os.path.join(formal, file)
    lines = open(p, encoding="utf-8").read().splitlines()
    for i in range(min(line, len(lines)) - 1, -1, -1):
        mm = decl_re.match(lines[i])
        if mm:
            name = mm.group(2) or f"<{mm.group(1)}@{i+1}>"
            return f"{mm.group(1)} {name}", i + 1
    return "<top>", 0

diags = []
for l in log:
    mm = re.match(r"(error|warning): (\S+\.lean):(\d+):(\d+): (.*)", l)
    if not mm: continue
    kind, file, line, col, msg = mm.groups()
    if kind == "warning" and "sorry" not in msg: continue
    decl, dline = enclosing(file, int(line))
    diags.append(dict(kind=kind, file=file, line=int(line), col=int(col), msg=msg[:160], decl=decl, decl_line=dline))

errs = [d for d in diags if d["kind"] == "error"]
sorries = [d for d in diags if d["kind"] == "warning"]
by_decl = defaultdict(int)
for d in errs: by_decl[(d["file"], d["decl"], d["decl_line"])] += 1
res = dict(
    log=os.path.basename(logf),
    modules_in_default_closure=len(closure),
    failed_modules=sorted(failed),
    unchecked_modules_count=len(unchecked),
    unchecked_modules=sorted(unchecked),
    error_diagnostics=len(errs),
    error_files=sorted({d["file"] for d in errs}),
    error_declarations=[dict(file=f, decl=n, line=ln, errors=c) for (f, n, ln), c in sorted(by_decl.items())],
    sorry_warnings=sorted({(d["file"], d["decl"]) for d in sorries}),
)
json.dump(res, open(outf, "w"), ensure_ascii=False, indent=1)
print(f"closure={len(closure)} failed={len(failed)} unchecked={len(unchecked)} "
      f"errors={len(errs)} files={len(res['error_files'])} decls={len(by_decl)}")
for x in res["error_declarations"]: print("  ", x)
