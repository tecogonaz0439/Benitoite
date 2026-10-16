"""B5 のレビュー用に、formal/ の全 Lean モジュールの公理依存を採取する。

通常の検査からは呼ばない。lake build 後、リポジトリの根で
python3 -B <このファイル> を実行する。詳細は target/b5-review/ に出す。
"""

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[3]
BASE = "cdd0cdc2"
SCOPE_END = "d91a7e3f"
IMPORTS = (
    "Benitoite", "DesugarDiff.Main", "BuiltinCheck.Main", "CoverageDiff.Main",
    "CoverageProgramDiff.Main", "SurfaceCheck.Main", "SurfaceCheck.All",
)
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def module_name(path):
    return str(Path(path).relative_to("formal").with_suffix("")).replace("/", ".")


def main():
    base = git("rev-parse", BASE)
    scope_end = git("rev-parse", SCOPE_END)
    modules = sorted(module_name(p) for p in git("ls-files", "formal").splitlines()
                     if p.endswith(".lean"))
    changed = {module_name(p) for p in git("diff", "--name-only", base, scope_end,
                                         "--", "formal").splitlines() if p.endswith(".lean")}
    remaining = set(modules)
    rows = {}
    out = ROOT / "target/b5-review"
    out.mkdir(parents=True, exist_ok=True)
    # 各実行ファイルは root の main を定義するため、別の環境で調べる。
    # 先に調べたモジュールは再採取せず、private・自動生成の宣言も含める。
    for module in IMPORTS:
        query = out / f"axioms-{module}.lean"
        query.write_text(f"import {module}\nimport Lean\n" + """
open Lean Elab Command in
run_elab do
  let modules : List String := """ + json.dumps(sorted(remaining)) + """
  let env ← getEnv
  let loaded := env.header.moduleNames.toList.map Name.toString
  logInfo (Json.compress (Json.mkObj [("loaded", toJson (modules.filter loaded.contains))]))
  let names := env.constants.toList.filterMap fun (name, _) => do
    let index ← env.getModuleIdxFor? name
    let mod ← env.header.moduleNames[index.toNat]?
    if modules.contains mod.toString then some (name, mod) else none
  for (name, mod) in names.toArray.qsort (fun a b => Name.lt a.1 b.1) do
    let axs ← collectAxioms name
    logInfo (Json.compress (Json.mkObj [
      ("name", toJson name.toString), ("module", toJson mod.toString),
      ("axioms", toJson (axs.map Name.toString))]))
""")
        result = subprocess.run(["lake", "env", "lean", str(query)],
                                cwd=ROOT / "formal", text=True, capture_output=True)
        (out / f"axioms-{module}.log").write_text(result.stdout + result.stderr)
        result.check_returncode()
        for line in result.stdout.splitlines():
            row = json.loads(line)
            if "loaded" in row:
                remaining.difference_update(row["loaded"])
            else:
                rows[(row["module"], row["name"])] = row
    if remaining:
        raise SystemExit(f"modules were not imported: {sorted(remaining)}")
    summary = {}
    counts = {}
    for module in modules:
        selected = [r for r in rows.values() if r["module"] == module]
        summary[module] = {
            "changedInB1B4": module in changed,
            "declarations": len(selected),
            "axioms": sorted({a for r in selected for a in r["axioms"]}),
        }
    for row in rows.values():
        key = ", ".join(sorted(row["axioms"])) or "none"
        counts[key] = counts.get(key, 0) + 1
    unexpected = [r for r in rows.values() if set(r["axioms"]) - ALLOWED]
    report = {"base": base, "scopeEnd": scope_end, "head": git("rev-parse", "HEAD"),
              "modules": summary, "declarations": len(rows),
              "axiomSets": counts, "unexpected": unexpected}
    (out / "axioms.json").write_text(json.dumps(
        sorted(rows.values(), key=lambda r: (r["module"], r["name"])), indent=2) + "\n")
    (out / "axioms-summary.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"modules": len(modules), "changedModules": len(changed),
                      "declarations": len(rows), "unexpected": len(unexpected)}))
    if unexpected:
        raise SystemExit("unexpected axiom dependencies; see target/b5-review/axioms-summary.json")


if __name__ == "__main__":
    main()
