#!/usr/bin/env python3
"""群 A のビルド・境界・公理依存を実行し、相対パスで記録する。"""
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
REVISION = "RV-L10.a の全所見への処置"
INPUTS = [
    "formal/Benitoite/Shared/Approximation.lean",
    "formal/Benitoite/Interval/ApproxAdapter.lean",
    "formal/Benitoite/Interval/BudgetAnalyze.lean",
    "formal/Benitoite/Release/Refinement/ApproxAdapter.lean",
    "formal/lakefile.toml",
    "formal/lean-toolchain",
    "formal/lake-manifest.json",
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
    "docs/design/00-overview/00-04-glossary.md",
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(phase):
    local_input = "../" + str(HERE.relative_to(ROOT) / f"{phase}.lean")
    command = ["lake", "build"] if phase == "build" else [
        "lake", "env", "lean", "-M", "12288", local_input
    ]
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    start = time.monotonic()
    with tempfile.NamedTemporaryFile(prefix=f"l10-a-{phase}-", suffix=".txt", delete=False) as out:
        result = subprocess.run(command, cwd=FORMAL, stdout=out, stderr=subprocess.STDOUT)
        temporary = Path(out.name)
    seconds = round(time.monotonic() - start, 3)
    output = temporary.read_text()
    size = temporary.stat().st_size
    sha = digest(temporary)
    if size <= 100000:
        destination = HERE / f"{phase}-output.txt"
        destination.write_text(output)
        temporary.unlink()
        record_name = destination.name
    else:
        record_name = "<tmp>/" + temporary.name
        large = HERE / "large-records.md"
        if not large.exists():
            large.write_text("# 大きな生の記録\n\n| 記録 | バイト数 | SHA-256 |\n|---|---:|---|\n")
        with large.open("a") as dest:
            dest.write(f"| `{record_name}` | {size} | `{sha}` |\n")
    record = {
        "phase": phase, "revision": REVISION, "cwd": "formal", "command": command,
        "started_utc": started, "exit": result.returncode, "outer_seconds": seconds,
        "output": record_name, "bytes": size, "sha256": sha,
        "rss": "未取得（計画上の非採取）",
    }
    bad = bool(re.search(r"\bsorryAx\b|declaration uses .sorry.", output))
    if phase != "build":
        declarations = []
        for match in re.finditer(
            r"'([^']+)' (does not depend on any axioms|depends on axioms:\s*\[([^]]*)\])", output
        ):
            axioms = [a.strip() for a in (match[3] or "").split(",") if a.strip()]
            declarations.append({"name": match[1], "axioms": axioms})
        unexpected = sorted({a for d in declarations for a in d["axioms"]} - ALLOWED)
        audit = {"count": len(declarations), "unexpected": unexpected, "declarations": declarations}
        (HERE / f"{phase}-axioms.json").write_text(
            json.dumps(audit, ensure_ascii=False, indent=2) + "\n"
        )
        record.update(axiom_declarations=len(declarations), unexpected_axioms=unexpected)
        bad = bad or bool(unexpected) or not declarations
    else:
        built = re.findall(r"Build completed successfully \((\d+) jobs\)", output)
        record["jobs"] = int(built[-1]) if built else None
    record["accepted"] = result.returncode == 0 and not bad
    (HERE / f"{phase}-result.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n"
    )
    print(json.dumps(record, ensure_ascii=False), flush=True)
    if not record["accepted"]:
        print("\n".join(output.splitlines()[-20:]), flush=True)
        raise SystemExit(result.returncode or 1)


def snapshot():
    paths = [ROOT / p for p in INPUTS]
    paths += sorted(p for p in HERE.iterdir() if p.suffix in {".lean", ".py", ".md"})
    for name in ["RV-L10.a-request.md", "RV-L10.a.md"]:
        review = HERE.parents[1] / "reviews" / name
        if review.exists():
            paths.append(review)
    values = [{"path": str(p.relative_to(ROOT)), "bytes": p.stat().st_size, "sha256": digest(p)}
              for p in paths]
    (HERE / "inputs-sha256.json").write_text(json.dumps(values, ensure_ascii=False, indent=2) + "\n")
    print(f"入力の識別を保存: {len(values)} 件", flush=True)


if __name__ == "__main__":
    for requested in sys.argv[1:]:
        if requested == "snapshot":
            snapshot()
        elif requested in {"build", "boundary", "axioms"}:
            run(requested)
        else:
            raise SystemExit("指定: build boundary axioms snapshot")
