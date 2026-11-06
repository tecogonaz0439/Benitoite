"""再開1の局所入力、既定ビルド、全環境監査を実行する。gitは呼ばない。"""
import argparse
import json
from pathlib import Path
import subprocess
import time
from run_checks import HERE, ROOT, date, digest, snapshot


LOCAL_AUDIT = r'''
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      if (env.getModuleIdxFor? name).isNone && !seen.contains name then some name else none
    if pending.isEmpty then break
    if rounds > 20 then throwError "AUDIT_FIXED_POINT_LIMIT"
    for name in pending.mergeSort (fun a b => a.toString < b.toString) do
      let env ← getEnv
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
      seen := seen.insert name
      logInfo m!"AUDIT_TARGET {name}"
      elabCommand (← `(#print axioms $(mkIdent name)))
  logInfo m!"AUDIT_ROUNDS {rounds}"
  logInfo m!"AUDIT_COUNT {seen.size}"
'''


def audited_source(stem):
    return "import Lean\n" + (HERE / (stem + ".lean")).read_text() + LOCAL_AUDIT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    baseline = args.tmp / "sources-resume-before.json"
    assert not baseline.exists(), "検査の初回記録を上書きしない"
    before = snapshot()
    baseline.write_text(json.dumps(before, ensure_ascii=False, sort_keys=True) + "\n")
    records = {"base": "dcaa396bad7a60d4da9b99d07ad9b75c0f328b07",
               "source_snapshot": digest(baseline), "source_count": len(before),
               "production_modules_added": [], "production_declarations_added": 0, "checks": {}}
    commands = []
    for stem in ["range-resume-trial", "legacy-resume-trial"]:
        target = args.tmp / (stem + "-audit.lean")
        target.write_text(audited_source(stem))
        commands.append((stem, ["lake", "env", "lean", "-M", "12288", str(target)], target))
    lock = ["/usr/bin/lockf", "-t", "3600", str(args.lock)]
    relative = "../" + str(HERE.relative_to(ROOT)) + "/axioms.lean"
    commands += [("build", lock + ["lake", "build"], None),
                 ("axioms", lock + ["lake", "env", "lean", "-M", "12288", relative], HERE / "axioms.lean")]
    for label, command, source in commands:
        stamp, tick = date(), time.monotonic()
        print(label + " 開始 " + stamp, flush=True)
        raw = args.tmp / (label + ".log")
        with raw.open("wb") as out:
            result = subprocess.run(command, cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
        clean_command = [arg.replace(str(args.lock), "<lock>").replace(str(args.tmp), "<tmp>")
                         for arg in command]
        row = {"command": clean_command, "cwd": "formal", "start": stamp, "end": date(),
               "seconds": round(time.monotonic() - tick, 3), "exit": result.returncode,
               "raw": digest(raw), "maximum_rss": "未取得（計画上の非採取）"}
        if source is not None:
            row["input"] = digest(source)
        if label.endswith("trial"):
            row["saved_input"] = digest(HERE / (label + ".lean"))
        records["checks"][label] = row
        (HERE / "resume1-checks.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
        print(label + " 終了 " + str(result.returncode) + " " + str(row["seconds"]) + "秒", flush=True)
        if result.returncode:
            print(raw.read_text()[-5000:])
            raise SystemExit(result.returncode)
    assert before == snapshot(), "検査中に本番又は写しが変わった"


if __name__ == "__main__":
    main()
