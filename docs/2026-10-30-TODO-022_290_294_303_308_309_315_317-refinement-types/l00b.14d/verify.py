#!/usr/bin/env python3
"""既定ビルド、境界、完全署名、公理依存を確認する。git は使用しない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parents[3]
base = Path(__file__).resolve().parent
allowed = {"propext", "Quot.sound", "Classical.choice"}
modules = ["LazyInversion", "LazyStore", "LazyPreservation"]
changed = [root / "formal/Benitoite.lean", *[
    root / "formal/Benitoite/Release/Refinement" / (m + ".lean") for m in modules], *[root / "formal/Benitoite/Release/Refinement" / (m + ".lean")
    for m in ("StateTyping", "ReferenceStore")]]


def digest(path):
    data = path.read_bytes()
    return {"path": str(path.relative_to(root)), "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest()}


def dump(name, obj):
    (base / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


# 再開時に指定されたレビュー入力と報告は読み取り専用である。
protected = json.loads((base / "protected-inputs.json").read_text())["files"]
for entry in protected:
    path = root / entry["path"]
    assert digest(path) == entry, entry["path"]

assert 'moreLeanArgs = ["-M", "12288"]' in (root / "formal/lakefile.toml").read_text()
for path in changed:
    assert not re.search(r"\b(sorry|admit|axiom)\b", path.read_text()), path.name
scratch = Path(tempfile.mkdtemp(prefix="benitoite-lazy-"))
records = []
large = []
for label, args in [
    ("build", ["rtk", "proxy", "lake", "build"]),
    *[(label, ["rtk", "proxy", "lake", "env", "lean", "-M", "12288", "../" +
               str((base / ("rv-14d-t3.lean" if label == "review-t3" else label + ".lean")).relative_to(root))])
      for label in ("boundary", "public-api", "review-t3", "axioms")],
]:
    started = time.monotonic()
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
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
    if label in ("axioms", "boundary", "review-t3") and process.returncode == 0:
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
        record["axioms"] = sorted(dependencies)
        record["axiom_reports"] = reports
        assert reports > 0, label
        assert not dependencies - allowed, dependencies
        if label == "axioms":
            audited = set(re.findall(r"AUDIT_MODULE (\S+)", output))
            required = {"Benitoite", *["Benitoite.Release.Refinement." + m for m in [*modules, "StateTyping", "ReferenceStore"]]}
            assert required <= audited, required - audited
            record["modules"] = len(audited)
            record["cases"] = re.findall(r"(?:cases |THREE_FAMILY_CASES )[^\n]+", output)
            dump("axioms-summary.json", record)
        elif label == "boundary":
            record["boundary_declarations"] = int(re.search(r"BOUNDARY_DECLARATIONS (\d+)", output)[1])
    if label == "public-api" and process.returncode == 0:
        record["public_declarations"] = sum(
            len(re.findall(r"^(?:def|theorem|structure) ([\w.]+)", p.read_text(), re.M))
            for p in changed[1:4])
        assert record["public_declarations"] == 20
    records.append(record)
    dump("verification.json", records)
    print(json.dumps(record, ensure_ascii=False), flush=True)
    if process.returncode:
        raise SystemExit(process.returncode)

initial = json.loads((base / "verification-initial.json").read_text())
large = [dict(r, label="初回/" + r["label"]) for r in initial
         if r["bytes"] > 100_000] + large
(base / "large-records.md").write_text(
    "# L00b.14d の大きな生出力\n\n100 KB を超える生出力は改造内へ置かない。"
    "保存先は再実行ごとに作る `<tmp>` の下である。\n\n"
    "| 出力 | 大きさ（バイト） | SHA-256 | 保存先 |\n|---|---:|---|---|\n" +
    "".join(f"| {r['label']} | {r['bytes']} | `{r['sha256']}` | `{r['record']}` |\n" for r in large))
dump("source-delta.json", {"basis": "起動依頼の B_WORK。git の差分取得・HEAD 照合は行っていない。",
     "base": "66c302eaec9d442d32073515772a0f036fd66762", "files": [digest(p) for p in changed]})
inputs = sorted((root / "formal/Benitoite/Release/Refinement").rglob("*.lean"))
inputs += [root / "formal/Benitoite/Release" / (name + ".lean")
           for name in ("Assumptions", "Model", "ModelTargets", "ModelHttp")]
inputs += [root / "formal" / name for name in ("Benitoite.lean", "lakefile.toml", "lake-manifest.json", "lean-toolchain")]
dump("source-inputs.json", {"files": [digest(p) for p in inputs]})
dump("boundary-inputs.json", {"files": [digest(base / name) for name in
     ("boundary.lean", "public-api.lean", "axioms.lean", "verify.py", "protected-inputs.json")]})
assert all(p.stat().st_size <= 100_000 for p in base.iterdir() if p.is_file()), "oversized artifact"

for entry in protected:
    assert digest(root / entry["path"]) == entry, entry["path"]
