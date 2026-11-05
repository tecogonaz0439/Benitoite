# -*- coding: utf-8 -*-
"""組込みの表の完成が読む名前の一覧の Lean のモジュールを、台帳と処理系の登録から作る（照合もする）。

- 仮定側の名前（δ・IO 応答・通常資源の状態・形式化の外）は、L60 の最終の台帳の仮定側（l60/f2/assumptions.json）から
  台帳の順で取る。区分を混ぜない。
- 資源の種類の名前は、処理系の実行の報告が使う資源の名前（crates/benitoite/src/runtime/report.rs の RESOURCE_*）の
  うち、形式化の外の TaskGroup を除いたものである。
- 合成側の名前は Lean の合成表の行（`StandardModel.Primitive.all`）から Lean の中で作るので、ここでは書かない。
  台帳の合成の行（l60/a の台帳に群 F1・F2 の差分を重ねたもの）の件数と、その lookup が合成表の行・本体・資源名
  だけであることを照合する。

使い方: python3 names.py --write（モジュールを書く）/ python3 names.py（書かずに照合する）。
"""
import argparse
import collections
import json
from pathlib import Path
import re
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parents[1]
MODULE = ROOT / "formal/Benitoite/Release/Refinement/StandardModelNameLists.lean"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--write", action="store_true")
args = parser.parse_args()

assumptions = json.loads((CHANGE / "l60/f2/assumptions.json").read_text())
KINDS = [("δ", "deltaNames", "δ の応答の条件で量化する名前"),
         ("IO 応答", "ioNames", "IO 応答の条件で量化する名前"),
         ("通常資源の状態", "stateNames", "通常資源の作成・参照・解放の名前（分類と抽象の解放の境界だけを受ける）"),
         ("形式化の外", "outsideNames", "形式化の外の名前（署名を持たせない）")]
by_kind = collections.defaultdict(list)
for row in assumptions["names"]:
    by_kind[row["kind"]].append(row["lean_name"])
assert sorted(by_kind) == sorted(k for k, _, _ in KINDS), sorted(by_kind)
counts = {k: len(v) for k, v in by_kind.items()}
assert counts == {"δ": 80, "IO 応答": 47, "通常資源の状態": 16, "形式化の外": 7}, counts
every = [n for v in by_kind.values() for n in v]
assert len(set(every)) == len(every) == 150

report = (ROOT / "crates/benitoite/src/runtime/report.rs").read_text()
resources = re.findall(r'pub const RESOURCE_[A-Z_]+: &str = "([^"]+)";', report)
assert "TaskGroup" in resources, resources
resources = [r for r in resources if r != "TaskGroup"]
assert resources == ["File.Reader", "File.Writer", "Http.Listener", "Http.Exchange"], resources

# 台帳の合成の行（群 F2 の照合の台本と同じ重ね方）。
ledger = []
for part in sorted((CHANGE / "l60/a").glob("ledger-[0-9][0-9].json")):
    ledger.extend(json.loads(part.read_text()))
classification = {r["id"]: r["classification"] for r in ledger}
f1 = json.loads((CHANGE / "l60/f1/ledger-diff.json").read_text())
f2 = json.loads(subprocess.run([sys.executable, str(CHANGE / "l60/f2/ledger_diff.py"), "--json"],
                               capture_output=True, text=True, check=True).stdout)
for diff in (f1, f2):
    for row in diff["moved"]:
        classification[row["id"]] = row["after"]
composed_rows = [r for r in ledger if classification[r["id"]] == "合成"]
assumed_rows = [r for r in ledger if classification[r["id"]] == "仮定"]
assert len(composed_rows) == 490 and len(assumed_rows) == 150, (len(composed_rows), len(assumed_rows))
lookups = collections.Counter()
for r in composed_rows:
    for c in r.get("name_correspondence", []) + r.get("helper_correspondence", []):
        if c.get("composition_lookup"):
            lookups[c["composition_lookup"].split(".")[-2] if "." in c["composition_lookup"] else "?"] += 1
assumed_names = {r["lean_name"] for r in assumed_rows}
assert assumed_names == set(every), sorted(assumed_names ^ set(every))


def lit(xs):
    lines, line = [], "  ["
    for i, x in enumerate(xs):
        item = json.dumps(x, ensure_ascii=False) + ("," if i + 1 < len(xs) else "]")
        if len(line) + len(item) + 1 > 110:
            lines.append(line.rstrip())
            line = "   "
        line += item if line.endswith("[") or not line.strip() else " " + item
    lines.append(line)
    return "\n".join(lines)


body = ["/-! # 組込みの表の完成が読む名前の一覧",
        "",
        "利用者のプログラムの組込みの表を、合成表の行と仮定側の行で完成させるときの、仮定側の名前の区分と資源の種類の名前で",
        "ある（設計書 07-04「01-12 との対応」）。台帳から生成する（手で直さない）。合成側の名前は合成表の行から作る",
        "（`StandardModel.nameLists`）。 -/",
        "namespace Benitoite.Release.Refinement.StandardModel",
        ""]
for kind, name, doc in KINDS:
    body += [f"/-- {doc}（{len(by_kind[kind])}）。 -/", f"def {name} : List String :=", lit(by_kind[kind]), ""]
body += ["/-- 通常資源の状態の名前が作る資源の種類の名前（形式化の外の TaskGroup を除く）。 -/",
         "def resourceNames : List String :=", lit(resources), "",
         "end Benitoite.Release.Refinement.StandardModel", ""]
text = "\n".join(body)
summary = {"counts": counts, "resources": resources, "ledger_composed": len(composed_rows),
           "ledger_assumed": len(assumed_rows), "composed_lookups": dict(sorted(lookups.items()))}
if args.write:
    MODULE.write_text(text)
else:
    assert MODULE.read_text() == text, "StandardModelNameLists.lean が台帳から作った内容と違う"
print(json.dumps(summary, ensure_ascii=False))
