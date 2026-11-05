# -*- coding: utf-8 -*-
"""数値と演算子の全275行の署名の欄を既定環境で簡約し（一時領域の入力。既定ビルドに置かない）、
前提を満たす入力の証人の各行の字面と形の件数を出す。

使い方: python3 inputs.py --tmp <一時領域>  （formal/ の既定ビルドの後に実行する）"""
import argparse
import collections
import json
import re
import subprocess
import sys
from support import HERE, ROOT, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", required=True)
parser.add_argument("--emit", action="store_true")
args = parser.parse_args()
rows = json.loads(subprocess.run([sys.executable, str(HERE / "rows.py"), "--json"], capture_output=True,
                                 text=True, check=True).stdout)["rows"]
lines = ["import Benitoite.Release.Refinement.StandardModelOperatorRows",
         "open Benitoite.Release.Refinement StandardModel"]
for r in rows:
    p = r["row"]
    lines.append("#reduce (Primitive.{0}.signature.names, Primitive.{0}.signature.params, "
                 "Primitive.{0}.signature.ret, Primitive.{0}.signature.tparams.length, "
                 "Primitive.{0}.signature.neffs, Primitive.{0}.signature.rkinds)".format(p))
source = __import__("pathlib").Path(args.tmp) / "inputs-reduce.lean"
source.write_text("\n".join(lines) + "\n")
result = subprocess.run(["lake", "env", "lean", "-M", "12288", str(source)], cwd=ROOT / "formal",
                        capture_output=True, text=True)
assert result.returncode == 0 and "error" not in result.stdout, result.stdout[-2000:]
chunks = re.split(r"\n(?=\()", result.stdout.strip())
assert len(chunks) == len(rows), (len(chunks), len(rows))
B = "Ty.base Benitoite.Release.BaseTy."
counts = collections.Counter()
emitted = {"operator": [], "numeric": []}
for r, c in zip(rows, chunks):
    flat = " ".join(c.split())
    m = re.match(r"\((\[[^\]]*\]), \[(.*?)\], (.*), (\d+), (\d+), \[(.*)\]\)$", flat)
    assert m, flat
    names = json.loads(m[1])
    params = [x.strip() for x in m[2].split(",")] if m[2] else []
    ret, tparams, neffs, ranges = m[3], int(m[4]), int(m[5]), m[6]

    def base(t):
        rest = t[len(B):] if t.startswith(B) else None
        return rest if rest and " " not in rest else None

    inputs = [base(t) for t in params]
    plain = tparams == 0 and neffs == 0 and ranges == "" and all(inputs) and len(names) == len(params)
    option = re.match(r"Ty\.data \"Option\" \[Ty\.base Benitoite\.Release\.BaseTy\.(\w+)\]$", ret)
    p = r["row"]
    if plain and base(ret) and len(params) == 1:
        shape, text = "unary", 'PureRow.Satisfiable.unary .%s "%s" .%s .%s rfl' % (p, names[0], inputs[0], base(ret))
    elif plain and base(ret) and len(params) == 2:
        shape, text = "binary", 'PureRow.Satisfiable.binary .%s "%s" "%s" .%s .%s .%s (by decide) rfl' % (
            p, names[0], names[1], inputs[0], inputs[1], base(ret))
    elif plain and option and len(params) == 1:
        shape, text = "option", ('PureRow.Satisfiable.option .%s "%s" .%s .%s (option_declarations externals).arity rfl'
                                 % (p, names[0], inputs[0], option[1]))
    elif r["name"] == "Decimal.round":
        shape, text = "round", "⟨StoreTy.empty, _, [], [], [], _, _, _, row_lookup _ .%s, round_arguments⟩" % p
    elif r["name"] in ("%eq", "%ne"):
        shape, text = "equality", "⟨StoreTy.empty, _, [.base .integer], [], [], _, _, _, row_lookup P .%s, equality_arguments⟩" % p
    else:
        raise AssertionError(flat)
    counts[(r["kind"], shape)] += 1
    emitted[r["kind"]].append("  case %s => exact %s" % (p, text))
summary = {"rows": len(rows), "shapes": {"%s/%s" % k: v for k, v in sorted(counts.items())}}
if args.emit:
    for kind in ("operator", "numeric"):
        print("-- " + kind)
        print("\n".join(emitted[kind]))
else:
    write(HERE / "inputs.json", summary)
    print(json.dumps(summary, ensure_ascii=False))
