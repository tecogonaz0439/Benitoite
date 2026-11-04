"""開始入力と一致する元の AtPrepare を復元し、生成宣言も含む追加件数を区別する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, re, subprocess, time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULE = "Benitoite.Release.Refinement.AtPrepare"
SOURCE_PATH = "formal/Benitoite/Release/Refinement/AtPrepare.lean"

def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / SOURCE_PATH).read_text()
    first = source.index("/-- 解析に成功した入力と同じ有効な起点値を、固定上限の準備へ渡す。 -/")
    last = source.index("theorem AtPrepared.fixed_index", first)
    original = source[:first] + source[last:]
    initial = {}
    for p in HERE.glob("initial-manifest-part-*.json"):
        initial.update(json.loads(p.read_text()))
    assert digest(original.encode())["sha256"] == initial[SOURCE_PATH]
    root = args.tmp / "baseline"
    path = root / "Benitoite/Release/Refinement/AtPrepare.lean"
    path.parent.mkdir(parents=True, exist_ok=True)
    tail = '''
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (n, _) =>
    if (env.getModuleIdxFor? n).isNone then some n else none
  for n in names.mergeSort (fun a b => a.toString < b.toString) do
    logInfo m!"BASELINE_TARGET {n}"
'''
    path.write_text("import Lean.Elab.Command\n" + original + tail)
    raw = args.tmp / "baseline.log"
    start = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    with raw.open("wb") as stream:
        result = subprocess.run(["lake", "env", "lean", "-M", "12288", "--root", str(root), str(path)],
            cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    assert result.returncode == 0 and not re.search(r"error:|warning:", data.decode()), data.decode()
    before = sorted(re.findall(r"^BASELINE_TARGET (.+)$", data.decode(), re.M))
    declarations = [r for p in sorted(HERE.glob("declarations-part-*.json")) for r in json.loads(p.read_text())]
    after = {r["name"] for r in declarations if r["module"] == MODULE}
    assert not set(before) - after
    new_modules = set(json.loads((HERE / "new-modules.json").read_text()))
    added = sorted((after - set(before)) | {r["name"] for r in declarations if r["module"] in new_modules})
    for filename, names in [("baseline-targets.txt", before), ("added-targets.txt", added)]:
        (args.tmp / filename).write_text("\n".join(names)+"\n")
    summary = {"exit": result.returncode, "start_utc": start,
        "end_utc": datetime.now(timezone.utc).isoformat(), "seconds": time.monotonic()-tick,
        "command": ["lake", "env", "lean", "-M", "12288", "--root", "<tmp>/baseline",
            "<tmp>/baseline/Benitoite/Release/Refinement/AtPrepare.lean"],
        "original_source": digest(original.encode()), "restored_input": digest(path.read_bytes()),
        "raw": digest(data), "baseline_declarations": len(before), "module_declarations": len(after),
        "added_in_existing_module": sorted(after-set(before)), "added_declarations": len(added),
        "baseline_targets": digest((args.tmp/"baseline-targets.txt").read_bytes()),
        "added_targets": digest((args.tmp/"added-targets.txt").read_bytes()),
        "script": digest(Path(__file__).read_bytes())}
    (HERE/"baseline-check.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary,ensure_ascii=False))

if __name__ == "__main__":
    main()
