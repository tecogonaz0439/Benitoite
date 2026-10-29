#!/usr/bin/env python3
"""作業木の formal の差分（B0 から）の変更行を、新しいファイルの宣言へ対応付ける。"""
import re, subprocess, sys, json
wt = sys.argv[1]
out = subprocess.run(["git", "-C", wt, "diff", "-U0", "--", "formal"], capture_output=True, text=True).stdout
decl_re = re.compile(r"^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe|nonrec)\s+)*"
                     r"(theorem|lemma|def|abbrev|instance|structure|inductive|class|example|opaque|axiom)\b\s*([^\s:({\[]*)")
cur = None; changes = {}
for line in out.splitlines():
    if line.startswith("+++ b/"):
        cur = line[6:]; changes.setdefault(cur, set())
    m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
    if m and cur:
        st = int(m.group(1)); n = int(m.group(2) or 1)
        for i in range(st, st + max(n, 1)): changes[cur].add(i)
res = []
for f, ls in changes.items():
    lines = open(f"{wt}/{f}", encoding="utf-8").read().splitlines()
    decls = set()
    for ln in sorted(ls):
        name = "<top>"
        for i in range(min(ln, len(lines)) - 1, -1, -1):
            mm = decl_re.match(lines[i])
            if mm:
                name = f"{mm.group(1)} {mm.group(2) or '@'+str(i+1)}"; break
            if lines[i].startswith("mutual") or lines[i].startswith("end"):
                pass
        decls.add(name)
    res.append((f, sorted(decls)))
for f, ds in sorted(res):
    print(f)
    for d in ds: print("   ", d)
