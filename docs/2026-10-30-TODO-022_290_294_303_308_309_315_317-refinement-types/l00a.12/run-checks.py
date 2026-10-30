#!/usr/bin/env python3
"""停止時点の再現と既定ビルドの検査記録を保存する。"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

BASE = "c652fa3d15f0c4a86e89250c28eccf662cb91f93"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCE = ROOT / "formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean"
kind = sys.argv[1]

if kind == "source-audit":
    paths = set((ROOT / "formal/Benitoite").rglob("*.lean"))
    paths.update(ROOT / p for p in [
        "formal/Benitoite.lean", "formal/lakefile.toml", "formal/lean-toolchain",
        "formal/lake-manifest.json", "scripts/check.sh",
        str(HERE.parent.relative_to(ROOT) / "implementation-request.md"),
        str(HERE.parent.relative_to(ROOT) / "plan.md"),
        str(HERE.parent.relative_to(ROOT) / "l00a.06a/contracts.md"),
    ])
    audit = {
        str(p.relative_to(ROOT)): {"size": p.stat().st_size,
                                  "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
        for p in sorted(paths)
    }
    output = HERE / "source-audit.json"
    if output.exists():
        assert json.loads(output.read_text()) == audit, "検査前後の入力が一致しない"
        print(f"{len(audit)} 入力が検査前の SHA-256 と一致")
    else:
        output.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
        print(f"{len(audit)} 入力の SHA-256 を保存")
    raise SystemExit(0)

if kind == "prepare-audit":
    names = []
    namespace = "Benitoite.Release.Refinement"
    for line in SOURCE.read_text().splitlines():
        if line == "namespace RawValueSubstCollision":
            namespace += ".RawValueSubstCollision"
        match = re.match(r"(?:noncomputable )?(?:def|theorem) (\S+)", line)
        if match:
            names.append(namespace + "." + match.group(1))
    (HERE / "public-names.json").write_text(
        json.dumps({"added": names, "exposed": []}, ensure_ascii=False, indent=2) + "\n")
    lines = ["import Benitoite.Release.Refinement.SubstTypingObstruction", ""]
    for name in names:
        lines.extend(["#check " + name, "#print axioms " + name])
    (HERE / "proof-audit.lean").write_text("\n".join(lines) + "\n")
    print(f"{len(names)} 公開宣言の署名と公理依存を検査する入力を保存")
    raise SystemExit(0)

records_path = HERE / "checks.json"
records = json.loads(records_path.read_text()) if records_path.exists() else []
assert all(r["kind"] != kind for r in records), "同じ検査は再実行しない"
if kind == "local-build":
    command = ["rtk", "proxy", "lake", "build", "Benitoite.Release.Refinement.SubstTypingObstruction"]
    cwd = ROOT / "formal"
elif kind == "proof":
    command = ["rtk", "proxy", "lake", "env", "lean", "-M", "12288",
               "../" + str((HERE / "proof-audit.lean").relative_to(ROOT))]
    cwd = ROOT / "formal"
else:
    assert kind in ("dry-run", "work")
    if kind == "work":
        assert any(r["kind"] == "dry-run" and r["exit_code"] == 0 for r in records)
    command = ["rtk", "proxy", "scripts/check.sh", "--level", "work", "--base", BASE]
    if kind == "dry-run":
        command.append("--dry-run")
    cwd = ROOT
started = datetime.now(timezone.utc).isoformat()
start = time.monotonic()
result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - start
log = HERE / (kind + ".log")
log.write_text(result.stdout)
record = dict(kind=kind, command=command, cwd=str(cwd.relative_to(ROOT)) or ".",
              started_at=started, exit_code=result.returncode,
              elapsed_seconds=elapsed, log=log.name)
records.append(record)
records_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False), flush=True)
if kind in ("work", "dry-run") or result.returncode:
    print(result.stdout, flush=True)
if kind == "proof" and result.returncode == 0:
    dependencies = re.findall(r"depends on axioms: \[([^\]]*)\]", result.stdout)
    observed = sorted({x.strip() for group in dependencies for x in group.split(",") if x.strip()})
    allowed = {"propext", "Quot.sound", "Classical.choice"}
    assert set(observed) <= allowed, observed
    assert "sorryAx" not in result.stdout
    count = len(dependencies) + result.stdout.count("does not depend on any axioms")
    expected = len(json.loads((HERE / "public-names.json").read_text())["added"])
    assert count == expected, (count, expected)
    (HERE / "proof-summary.json").write_text(json.dumps(
        {"declarations": count, "axioms": observed, "unapproved": []}, indent=2) + "\n")
    print(f"{count} 宣言の依存は許可一覧内", flush=True)
raise SystemExit(result.returncode)
