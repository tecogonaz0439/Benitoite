#!/usr/bin/env python3
"""群Gの二人目の担当の作業末の照合。群Gが足した・変えたモジュールの一覧を git から作り直し、既定 import への所属・
sorry と公理の不在・処理系の本体の不変を確かめ、同じ一覧の全宣言の公理監査の入力を作り、監査の出力を照合する。

使い方:
  python3 verify_g2.py --tmp <一時領域> --prepare   # 監査の入力（Lean）と対象の一覧を作る
  python3 verify_g2.py --tmp <一時領域>             # 監査の出力（<tmp>/audit-g2.log）を照合して記録を書く
"""
import argparse
import json
import pathlib
import re
import subprocess
from records import HERE, ROOT, audit, closure, digest, module_graph, write

START = "d9cf242d97ac3b93c439177da0e67a625a87f626"  # 群Gの開始版
GROUP_TIP = "e1b5b847"                              # 群Gの途中の保存（結合の前）
D_SIDE = "05341b96"                                 # 結合した san_benito の版
MERGE = "dc22b231"                                  # 結合した版（この担当の開始版）


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True)


def lean_files(rev):
    return {p for p in git("ls-tree", "-r", "--name-only", rev, "formal/").split() if p.endswith(".lean")}


def module(path):
    return path.removeprefix("formal/").removesuffix(".lean").replace("/", ".")


def targets():
    tree = {str(p.relative_to(ROOT)) for p in (ROOT / "formal").rglob("*.lean")
            if ".lake" not in p.parts and "tests" not in p.parts}
    added = sorted(tree - lean_files(START) - lean_files(D_SIDE))
    changed = set(git("diff", "--name-only", START, GROUP_TIP, "--", "formal/").split())
    changed |= set(git("diff", "--name-only", MERGE, "--", "formal/").split())
    changed = sorted(p for p in changed if p in tree and p.endswith(".lean") and p not in added)
    return added, changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=pathlib.Path, required=True)
    parser.add_argument("--prepare", action="store_true")
    args = parser.parse_args()
    added, changed = targets()
    names = [module(p) for p in added + changed]
    # 入口の実行ファイルの根はどれも main を持つので、一つの環境に読めない。根ごとに別の監査の入力にする。
    groups = {"library": sorted(n for n in names if n.startswith("Benitoite"))}
    for n in sorted(n for n in names if not n.startswith("Benitoite")):
        groups[n] = [n]
    if args.prepare:
        template = (HERE / "axioms.lean").read_text()
        selected = "  let modules := env.header.moduleNames.toList.filter fun n => n.toString.startsWith \"Benitoite\""
        assert selected in template
        for key, chosen in groups.items():
            listing = ", ".join("`" + n for n in chosen)
            text = template.replace("import Benitoite\n", "".join(f"import {n}\n" for n in chosen))
            text = text.replace(selected, f"  let chosen : List Name := [{listing}]\n"
                                "  let modules := env.header.moduleNames.toList.filter fun n => chosen.contains n")
            (args.tmp / f"audit-g2-{key}.lean").write_text(text)
        print(json.dumps({"added": len(added), "changed": len(changed), "inputs": sorted(groups)}))
        return
    graph = module_graph()
    default = closure(graph, ["Benitoite"])
    entry_roots = ["DesugarDiff.Main", "BuiltinCheck.Main", "CoverageDiff.Main", "CoverageProgramDiff.Main",
                   "SurfaceCheck.Main", "SurfaceCheck.All", "IntervalDiff.Main"]
    reachable = closure(graph, ["Benitoite", *entry_roots])
    new_modules = [module(p) for p in added]
    assert set(new_modules) <= default, sorted(set(new_modules) - default)
    assert set(names) <= reachable, sorted(set(names) - reachable)
    for p in added + changed:
        source = (ROOT / p).read_text()
        assert not re.search(r"\bsorry\b|^\s*axiom\s", source, re.M), p
    body = git("diff", "--name-only", START, GROUP_TIP, "--", "crates/benitoite/src/").split()
    body += git("diff", "--name-only", MERGE, "--", "crates/benitoite/src/").split()
    assert not body, body
    parts = {key: audit(args.tmp / f"audit-g2-{key}.log") for key in groups}
    axioms = {}
    for part in parts.values():
        for key, count in part["axioms"].items():
            axioms[key] = axioms.get(key, 0) + count
    summary = {"targets": sum(p["targets"] for p in parts.values()), "axioms": axioms, "parts": parts}
    record = {"start": START, "merge": MERGE, "new_modules": new_modules,
              "changed_modules": [module(p) for p in changed], "default_modules": len(default),
              "axioms": summary,
              "audit_inputs": {key: digest(args.tmp / f"audit-g2-{key}.lean") for key in groups}}
    write(HERE / "verification-g2.json", record)
    print(json.dumps({"new": len(new_modules), "changed": len(changed), "audit_targets": summary["targets"],
                      "axioms": summary["axioms"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
