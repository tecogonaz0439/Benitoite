#!/usr/bin/env python3
"""既定ビルド・境界・完全署名・公理依存を確認する。git は使用しない。"""
from pathlib import Path
import datetime
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[3]
base = Path(__file__).resolve().parent
modules = ['HandlerContinuation', 'HandlerStore', 'HandlerEffects', 'HandlerFailure', 'HandlerCalls', 'HandlerTelescope', 'HandlerPreservation', 'HandlerOperation']
allowed = {"propext", "Quot.sound", "Classical.choice"}
changed = [root / "formal/Benitoite.lean", root / "formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean", *[
    root / "formal/Benitoite/Release/Refinement" / (m + ".lean") for m in modules]]

def digest(path):
    data = path.read_bytes()
    return {"path": str(path.relative_to(root)), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}

def dump(name, obj):
    (base / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")

def audit(output):
    dependencies = set()
    reports = 0
    lines = output.splitlines()
    for index, line in enumerate(lines):
        if "depends on axioms:" in line:
            reports += 1
            value = line.split("depends on axioms:", 1)[1]
            next_line = index + 1
            while "]" not in value and next_line < len(lines):
                value += lines[next_line]
                next_line += 1
            value = re.sub(r"\.\{[^}]*\}", "", value)
            dependencies.update(re.findall(r"[A-Za-z_][A-Za-z0-9_.]*", value))
        elif "does not depend on any axioms" in line:
            reports += 1
    assert reports > 0
    assert not dependencies - allowed, dependencies
    return {"axioms": sorted(dependencies), "axiom_reports": reports}

protected = json.loads((base / "protected-inputs.json").read_text())["files"]
for entry in protected:
    assert digest(root / entry["path"]) == entry, entry["path"]
# 旧 EffectsOk と同じ三つの条件であることも文字列で照合する。
old = (root / "formal/Benitoite/Release/Assumptions.lean").read_text()
new = (root / "formal/Benitoite/Release/Refinement/HandlerEffects.lean").read_text()
pattern = r"def Program.EffectsOk .*?: Prop :=(.*?)(?=\n\n)"
assert re.sub(r"\s+", "", re.search(pattern, old, re.S)[1]) == re.sub(r"\s+", "", re.search(pattern, new, re.S)[1])
assert 'moreLeanArgs = ["-M", "12288"]' in (root / "formal/lakefile.toml").read_text()
for path in [*changed, base / "boundary.lean"]:
    assert not re.search(r"\b(sorry|admit|axiom|native_decide|unsafe|implemented_by)\b", path.read_text()), path.name
scratch = Path(tempfile.mkdtemp(prefix="benitoite-handler-"))
parser = argparse.ArgumentParser()
parser.add_argument("--reuse-build", action="store_true", help="ソースと設定のハッシュを照合し、成功済みの既定ビルドを引用する")
options = parser.parse_args()
records = []
large = []
for label, args in [
    ("build", ["rtk", "proxy", "lake", "build"]),
    *[(label, ["rtk", "proxy", "lake", "env", "lean", "-M", "12288", "../" +
              str((base / (label + ".lean")).relative_to(root))])
      for label in ("boundary", "public-api", "axioms")],
]:
    if label == "build" and options.reuse_build:
        saved = json.loads((base / "verified-build.json").read_text())
        for entry in saved["files"]:
            assert digest(root / entry["path"]) == entry, entry["path"]
        assert saved["record"]["exit_code"] == 0
        record = {**saved["record"], "reused_after_input_hash_check": True,
                  "input_record": "verified-build.json"}
        path = record["record"]
        raw_path = Path(tempfile.gettempdir()) / path.removeprefix("<tmp>/") if path.startswith("<tmp>/") else base / path
        assert hashlib.sha256(raw_path.read_bytes()).hexdigest() == record["sha256"]
        records.append(record)
        print("build: ソースと設定のハッシュ一致を確認して成功済みの実行を引用", flush=True)
        continue
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    started = time.monotonic()
    raw = scratch / (label + ".log")
    with raw.open("wb") as out:
        process = subprocess.run(args, cwd=root / "formal", stdout=out, stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    output = data.decode()
    record = {"label": label, "command": "cd formal && " + " ".join(args),
              "started_utc": timestamp, "exit_code": process.returncode,
              "seconds": round(time.monotonic() - started, 3), "bytes": len(data),
              "sha256": hashlib.sha256(data).hexdigest()}
    if len(data) > 100_000:
        record["record"] = "<tmp>/" + scratch.name + "/" + raw.name
        large.append(record.copy())
    else:
        (base / (label + ".log")).write_bytes(data)
        record["record"] = label + ".log"
    records.append(record)
    dump("verification.json", records)
    assert process.returncode == 0, record
    assert not re.search(r"\berror(?:\(|:)|declaration uses 'sorry'", output), label
    if label == "build":
        snapshot = [p for p in (root / "formal").rglob("*.lean") if ".lake" not in p.parts]
        snapshot += [root / "formal/lakefile.toml",
                     root / "formal/lean-toolchain", root / "formal/lake-manifest.json"]
        dump("verified-build.json", {"record": record, "files": [digest(p) for p in sorted(snapshot)]})
    if label in ("axioms", "boundary"):
        record.update(audit(output))
        if label == "axioms":
            audited = set(re.findall(r"AUDIT_MODULE (\S+)", output))
            required = {"Benitoite", *["Benitoite.Release.Refinement." + m for m in modules]}
            assert required <= audited, required - audited
            record["modules"] = len(audited)
            record["cases"] = re.findall(r"(?:cases |THREE_FAMILY_CASES )[^\n]+", output)
            dump("axioms-summary.json", record)
        else:
            record["boundary_declarations"] = int(re.search(r"BOUNDARY_DECLARATIONS (\d+)", output)[1])
    if label == "public-api":
        names = json.loads((base / "public-names.json").read_text())
        assert all(name in output for name in names)
        record["public_declarations"] = len(names)
    print(json.dumps({"label": label, "exit_code": process.returncode,
                      "seconds": record["seconds"], "reports": record.get("axiom_reports")}), flush=True)
dump("verification.json", records)
dump("source-delta.json", {"B_WORK": "c64c0dc376b85185744303c4752d1f1bb34967af", "files": [digest(p) for p in changed]})
inputs = list((root / "formal/Benitoite/Release/Refinement").rglob("*.lean"))
inputs += [root / "formal/lakefile.toml", root / "formal/lean-toolchain", root / "formal/lake-manifest.json", root / "formal/Benitoite.lean"]
dump("source-inputs.json", {"files": [digest(p) for p in sorted(inputs)]})
dump("boundary-inputs.json", {"files": [digest(base / name) for name in
    ("boundary.lean", "public-api.lean", "public-names.json", "axioms.lean", "verify.py", "protected-inputs.json")] + protected})
for entry in protected:
    assert digest(root / entry["path"]) == entry, entry["path"]
dump("protected-check.json", {"unchanged": True, "files": protected})
(base / "large-records.md").write_text("# 大きな生の記録\n\n100 KB を超える生の出力は一時領域に置く。手元の絶対パスは記さない。\n\n| 記録 | バイト | SHA-256 |\n|---|---:|---|\n" +
    "".join("| " + r["record"] + " | " + str(r["bytes"]) + " | `" + r["sha256"] + "` |\n" for r in large))
