# -*- coding: utf-8 -*-
"""群 H3 の Lean の担当が足した・変えたモジュールの公理監査（段の監査の入力 ../axioms.lean と ../h/stage.py の読み取りを使う）。

prepare: ../axioms.lean の SELECT・REQUIRED の行を、群 H3 のモジュールの一覧と述べ直した定理の名前に差し替えた入力を
  一時領域に作る（環境は既定 import の閉包。AUDIT は true のまま）。
run: 共有ロックの下で `lake env lean -M 12288` を一度実行し、生の出力を一時領域に置く。
analyze: 生の出力を ../h/stage.py の `load` で読み、選んだモジュールの全宣言（private・生成宣言・構造体の欄・マクロの
  スコープを持つ名前を含む）が監査され、許可した三公理の部分集合だけに依存し、sorryAx がないことを確かめ、
  記録 audit.json を書く。
使い方: python3 audit-lean.py prepare|run|analyze --tmp <一時領域> [--lock <共有ロック>]"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
L70 = HERE.parent
sys.path.insert(0, str(L70 / "h"))
from support import ROOT, digest, write  # noqa: E402
import stage  # noqa: E402

CHANGES = json.loads((HERE / "changes-lean.json").read_text())
MODULES = CHANGES["audited_modules"]
REQUIRED = CHANGES["required"]
INPUT, LOG = "h3-audit.lean", "h3-audit.log"


def prepare(tmp):
    text = (L70 / "axioms.lean").read_text()
    select_old = '  let selected : String → Bool := fun s => s.startsWith "Benitoite"\n'
    required_old = "  let required : List Name := []\n"
    assert text.count(select_old) == text.count(required_old) == 1
    listed = ", ".join(f'"{m}"' for m in MODULES)
    text = text.replace(select_old, f"  let selected : String → Bool := fun s => [{listed}].contains s\n")
    names = ", ".join(f"`{n}" for n in REQUIRED)
    text = text.replace(required_old, f"  let required : List Name := [{names}]\n")
    (tmp / INPUT).write_text(text)
    print(json.dumps({"modules": len(MODULES), "required": len(REQUIRED)}))


def run(tmp, lock):
    source, log = tmp / INPUT, tmp / LOG
    start, stamp = time.monotonic(), time.strftime("%Y-%m-%dT%H:%M:%S%z")
    with log.open("wb") as out:
        done = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(lock), "lake", "env", "lean", "-M", "12288",
                               str(source)], cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
    record = {"start": stamp, "exit": done.returncode, "seconds": round(time.monotonic() - start, 1),
              "input": digest(source), "output": digest(log), "lock": "共有ロック"}
    write(HERE / "audit-run-lean.json", record)
    print(json.dumps(record, ensure_ascii=False))
    assert done.returncode == 0, log.read_text()[-3000:]


def analyze(tmp):
    part = stage.load(tmp / LOG)
    assert not part["errors"], part["errors"][:3]
    assert part["sorry"] == 0
    assert part["count"] == len(part["nodes"])
    assert part["macro_count"] == len(part["macros"])
    assert {n for _, n in part["targets"]} | set(part["macros"]) == set(part["nodes"])
    assert sorted(part["modules"]) == sorted(MODULES), (sorted(set(MODULES) - set(part["modules"])))
    audits = {}
    for name, axioms in list(part["audits"].items()) + list(part["macros"].items()):
        assert set(axioms) <= stage.ALLOWED, (name, axioms)
        audits[name] = tuple(sorted(axioms))
    assert set(audits) == set(part["nodes"]), (len(audits), len(part["nodes"]))
    assert all(n["kind"] != "axiom" for n in part["nodes"].values())
    assert set(REQUIRED) == set(part["signatures"]), sorted(set(REQUIRED) - set(part["signatures"]))
    by_module = collections.Counter(n["module"] for n in part["nodes"].values())
    private = sum(1 for n in part["nodes"] if n.startswith("_private."))
    record = {
        "modules": MODULES,
        "declarations": len(part["nodes"]),
        "by_module": dict(sorted(by_module.items())),
        "private": private,
        "macro_scoped": len(part["macros"]),
        "unresolved": len(part["unresolved"]),
        "axiom_sets": dict(collections.Counter(" + ".join(a) or "なし" for a in audits.values())),
        "sorryAx": 0, "new_axioms": 0, "axiom_declarations": 0, "allowed": sorted(stage.ALLOWED),
        "required": {n: {"module": part["nodes"][n]["module"], "kind": part["nodes"][n]["kind"],
                         "type_sha256": hashlib.sha256(part["signatures"][n].encode()).hexdigest(),
                         "axioms": list(audits[n])} for n in REQUIRED},
        "raw": part["raw"],
        "inputs": {"axioms.lean": digest(L70 / "axioms.lean"), "audit-lean.py": digest(Path(__file__)),
                   "changes-lean.json": digest(HERE / "changes-lean.json")},
    }
    write(HERE / "audit-lean.json", record)
    print(json.dumps({k: record[k] for k in ["declarations", "private", "macro_scoped", "axiom_sets"]},
                     ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["prepare", "run", "analyze"])
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    if args.command == "prepare":
        prepare(args.tmp)
    elif args.command == "run":
        run(args.tmp, args.lock)
    else:
        analyze(args.tmp)


if __name__ == "__main__":
    main()
