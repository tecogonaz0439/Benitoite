#!/usr/bin/env python3
"""失敗したファイルの中で、旧の綴りを明示の Top の構築関数へ書き換え、置き換えの数を記録する。
使い方: fixtop.py <build番号> <formal からの相対パス>..."""
import re, sys, json, os
S = "<scratch>"
base = S + "/c/formal/"
pats = [
    ("name_lit", r'\.name "([^"]+)"', r'.name (.top "\1")'),
    ("single_lit", r'Eff\.single "([^"]+)"', r'Eff.single (.top "\1")'),
    ("opaque_lit", r'\.opaque "([^"]+)"', r'.opaque (.top "\1")'),
    ("stateEff_name", r'\.name stateEff\b', r'.name (.top stateEff)'),
    ("stateEff_single", r'Eff\.single stateEff\b', r'Eff.single (.top stateEff)'),
    ("single_odeff", r'Eff\.single od\.eff\b', r'Eff.single (.top od.eff)'),
    ("withE_lit", r'\.withE "([^"]+)"', r'.withE (.top "\1")'),
    ("single_deff", r'Eff\.single (d|od)\.eff\b', r'Eff.single (.top \1.eff)'),
    ("name_deff", r'\.name (d|od)\.eff\b', r'.name (.top \1.eff)'),
]
tally = {}
for f in sys.argv[2:]:
    p = base + f
    s = open(p, encoding="utf-8").read()
    for k, a, b in pats:
        s, n = re.subn(a, b, s)
        if n: tally.setdefault(f, {})[k] = n
    open(p, "w", encoding="utf-8").write(s)
log = S + "/fixtop-tally.jsonl"
with open(log, "a") as fp:
    fp.write(json.dumps({"build": sys.argv[1], "tally": tally}, ensure_ascii=False) + "\n")
print(json.dumps(tally, ensure_ascii=False, indent=1))
