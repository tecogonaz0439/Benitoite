# -*- coding: utf-8 -*-
"""段で変えた既存の5モジュールの全宣言を、段の開始版と最終版で比べる。

開始版は、5モジュールの段の開始版のソースを一時領域へ置き、依存の順に単独のLeanで一時領域の olean へ検査して、
一時領域を先頭にした LEAN_PATH の下で全宣言（構造体の欄・private・生成宣言を含む）の種類・行・型を印字する。
間にある段で変えていないモジュール（例: StandardOrderResponse）は既定ビルドの olean を読む。そのため開始版の
環境は「開始版の5モジュール＋現在の中間のモジュール」であり、5モジュールの宣言の型の印字だけに使う。
最終版は段の公理監査の出力（AUDIT_DECL と型の印字）を読む。private の実名は `_private.<モジュール>.0.` の
接頭辞を除き、所属モジュールと残りの名前で対応させる。型は同じ印字の設定の文字列のSHA-256で比べ、
新規・変更・継承・削除に分ける。
使い方: python3 edited.py --tmp <一時領域>（axioms.log を置く。開始版の入力と出力もここへ置く）"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from support import EDITED, HERE, L60_BASE, PREFIX, ROOT, digest, module_path, private_key as key, show, write

ORDER = ["StandardAliasBodies", "StandardDecimalResponse", "StandardOrdinaryCoreBodies",
         "StandardOrdinaryListBodies", "StandardOrdinaryCoreProgram"]
assert sorted(PREFIX + m for m in ORDER) == sorted(EDITED)
DUMP = """
set_option pp.fullNames true
set_option pp.proofs true
set_option pp.maxSteps 1000000
set_option pp.deepTerms.threshold 1000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, ci) in env.constants.toList.mergeSort (fun a b => a.1.toString < b.1.toString) do
    if (env.getModuleIdxFor? name).isSome then continue
    let kind := match ci with
      | .thmInfo _ => "theorem" | .defnInfo _ => "definition" | .opaqueInfo _ => "opaque"
      | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor" | .recInfo _ => "recursor"
      | .quotInfo _ => "quotient" | .axiomInfo _ => "axiom"
    let range ← findDeclarationRanges? name
    let line := range.map (fun r => r.range.pos.line) |>.getD 0
    logInfo m!"BASE_BEGIN {name} {kind} {line}"
    logInfo m!"{ci.type}"
    logInfo m!"BASE_END {name}"
"""


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--reuse", action="store_true", help="既に書き出した開始版の出力を使う")
parser.add_argument("--verify", action="store_true", help="記録を書かずに既存の edited.json と照合する（--reuse を含む）")
args = parser.parse_args()
args.reuse = args.reuse or args.verify
work = args.tmp / "edited-base"
src, out = work / "src", work / "olean"
names = [PREFIX + m for m in ORDER]
inputs = {}
for module in ORDER:
    rel = str(module_path(PREFIX + module).relative_to(ROOT))
    path = src / rel.removeprefix("formal/")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(show(L60_BASE, rel))
    inputs[module] = digest(path)
dump = work / "dump.lean"
dump.write_text("".join(f"import {n}\n" for n in names) + "import Lean\n" + DUMP.replace(
    "    if (env.getModuleIdxFor? name).isSome then continue\n",
    "    let some idx := env.getModuleIdxFor? name | continue\n"
    "    unless [" + ", ".join(f"`{n}" for n in names) + "].contains env.header.moduleNames[idx.toNat]! do continue\n"
    "    logInfo m!\"BASE_MODULE {env.header.moduleNames[idx.toNat]!}\"\n"))
base_log = args.tmp / "edited-base.log"
run = None
if not args.reuse:
    # 開始版の5モジュールを依存の順に一時領域の olean へ検査し、一時領域を先頭にした LEAN_PATH で読む。
    # 既定のビルド出力（formal/.lake）は書き換えない。
    # 一時領域の olean の木は、既定のビルド出力の Benitoite 以下の olean への記号リンクで作り、5モジュールだけを
    # 開始版の検査の出力で置く（Lean は根の名前空間を最初に見つけた LEAN_PATH の項目から読むため）。
    build = ROOT / "formal/.lake/build/lib/lean"
    for file in [build / "Benitoite.olean"] + sorted((build / "Benitoite").rglob("*.olean")):
        if file.stem in ORDER and file.parent.name == "Refinement":
            continue
        link = out / file.relative_to(build)
        link.parent.mkdir(parents=True, exist_ok=True)
        if not link.is_symlink():
            link.symlink_to(file)
    timer, steps = time.monotonic(), []
    with base_log.open("wb") as log:
        for module in ORDER + ["dump"]:
            file = dump if module == "dump" else src / "Benitoite/Release/Refinement" / (module + ".lean")
            target = out / "Benitoite/Release/Refinement" / (module + ".olean")
            target.parent.mkdir(parents=True, exist_ok=True)
            command = f'LEAN_PATH="{out}:$LEAN_PATH" lean -M 12288 --root="{src}" '
            command += f'"{file}"' if module == "dump" else f'-o "{target}" "{file}"'
            step = time.monotonic()
            result = subprocess.run(["lake", "env", "sh", "-c", command], cwd=ROOT / "formal", stdout=log,
                                    stderr=subprocess.STDOUT)
            steps.append({"module": module, "exit": result.returncode, "wall_seconds": round(time.monotonic() - step, 2)})
            assert result.returncode == 0, (module, base_log.read_text()[-4000:])
    run = {"steps": steps, "wall_seconds": round(time.monotonic() - timer, 2)}
text = base_log.read_text()
assert not re.search(r"error:", text)
base = {}
for module, name, kind, line, typ in re.findall(
        r"^BASE_MODULE (\S+)\nBASE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^BASE_END \2$", text, re.M | re.S):
    k = key(module.removeprefix(PREFIX), name)
    base[k] = {"name": name, "kind": kind, "type_sha256": hashlib.sha256(typ.strip().encode()).hexdigest()}
assert {k[0] for k in base} == set(ORDER)

audit = (args.tmp / "axioms.log").read_text()
final = {}
signatures = {n: t.strip() for _, n, _, t in
              re.findall(r"^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$", audit, re.M | re.S)}
for module, kind, _, name in re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", audit, re.M):
    short = module.removeprefix(PREFIX)
    if short in ORDER:
        final[key(short, name)] = {"name": name, "kind": kind,
                                   "type_sha256": hashlib.sha256(signatures[name].encode()).hexdigest()}

rows = []
for k in sorted(set(base) | set(final)):
    b, f = base.get(k), final.get(k)
    state = "新規" if b is None else "削除" if f is None else "継承" if b["type_sha256"] == f["type_sha256"] else "変更"
    rows.append({"module": k[0], "name": k[1], "private": k[2], "kind": (f or b)["kind"], "state": state,
                 "final_name": f["name"] if f else None, "type_sha256": (f or b)["type_sha256"],
                 "base_type_sha256": b["type_sha256"] if b else None})
counts = {m: dict(collections.Counter(r["state"] for r in rows if r["module"] == m)) for m in ORDER}
record = {"base": L60_BASE, "order": ORDER, "inputs": inputs, "dump": digest(dump), "output": digest(base_log),
          "base_declarations": len(base), "final_declarations": len(final), "counts": counts,
          "changes": [r for r in rows if r["state"] != "継承"],
          "inherited": {m: sum(r["state"] == "継承" and r["module"] == m for r in rows) for m in ORDER}}
if run:
    record["run"] = run
else:
    record["run"] = json.loads((HERE / "edited.json").read_text()).get("run")
if args.verify:
    assert json.loads((HERE / "edited.json").read_text()) == json.loads(json.dumps(record, ensure_ascii=False))
    print(json.dumps({"verified": True, "base_declarations": len(base)}))
    raise SystemExit(0)
write(HERE / "edited.json", record)
print(json.dumps({k: record[k] for k in ["base_declarations", "final_declarations", "counts"]}, ensure_ascii=False))
