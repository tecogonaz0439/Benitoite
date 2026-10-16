"""D1〜D3 の変更モジュールの公理依存を、Lean の環境から採取する。

改造のレビュー用の道具であり、通常の検査からは呼ばない。
formal/ で lake build を通した後、リポジトリの根で
python3 -B <このファイル> を実行する。
"""

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[3]
BASE = "dc2c15a1"
SCOPE_END = "c6d48439"
IMPORTS = (
    "Benitoite", "DesugarDiff.Main", "BuiltinCheck.Main", "CoverageDiff.Main",
    "CoverageProgramDiff.Main", "SurfaceCheck.Main", "SurfaceCheck.All",
)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main():
    base = git("rev-parse", BASE)
    scope_end = git("rev-parse", SCOPE_END)
    head = git("rev-parse", "HEAD")
    files = git("diff", "--name-only", base, scope_end, "--", "formal").splitlines()
    modules = sorted(str(Path(p).relative_to("formal").with_suffix("")).replace("/", ".")
                     for p in files if p.endswith(".lean"))
    if not modules:
        raise SystemExit("no D1-D3 modules found")
    out = ROOT / "target/d4-review"
    out.mkdir(parents=True, exist_ok=True)
    rows = {}
    # 実行ファイルはそれぞれ root の main を定義するので、一つずつ import する。
    # private・自動生成された宣言も含め、変更モジュールの全宣言を調べる。
    for module in IMPORTS:
        query = out / f"axioms-{module}.lean"
        query.write_text(f"import {module}\nimport Lean\n" + """
open Lean Elab Command in
run_elab do
  let modules : List String := """ + json.dumps(modules) + """
  let env ← getEnv
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
            previous = rows.setdefault((row["module"], row["name"]), row)
            if previous != row:
                raise SystemExit(f"inconsistent imports: {row['name']}")
    summary = {}
    for module in modules:
        selected = [r for r in rows.values() if r["module"] == module]
        if not selected:
            raise SystemExit(f"module was not audited: {module}")
        summary[module] = {
            "declarations": len(selected),
            "axioms": sorted({a for r in selected for a in r["axioms"]}),
        }
    allowed = {"propext", "Quot.sound", "Classical.choice"}
    unexpected = [r for r in rows.values() if set(r["axioms"]) - allowed]
    report = {"base": base, "scopeEnd": scope_end, "head": head, "modules": summary,
              "declarations": len(rows), "unexpected": unexpected}
    (out / "axioms.json").write_text(json.dumps(sorted(rows.values(), key=lambda r: (r["module"], r["name"])),
                                                ensure_ascii=False, indent=2) + "\n")
    (out / "axioms-summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"modules": len(modules), "declarations": len(rows),
                      "unexpected": len(unexpected)}))
    if unexpected:
        raise SystemExit("unexpected axiom dependencies; see target/d4-review/axioms-summary.json")


if __name__ == "__main__":
    main()
