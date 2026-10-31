#!/usr/bin/env python3
"""既定ビルド・境界・公理依存を実行し、消える場所への依存なしに要約する。"""
import hashlib
import json
import re
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FORMAL = ROOT / "formal"
RELPATH = HERE.relative_to(ROOT).as_posix()
COMMANDS = [
    ("build", ["lake", "build"]),
    ("boundary", ["lake", "env", "lean", "-M", "12288", "../" + RELPATH + "/boundary.lean"]),
    ("axioms", ["lake", "env", "lean", "-M", "12288", "../" + RELPATH + "/axioms.lean"]),
    ("public-api", ["lake", "env", "lean", "-M", "12288", "../" + RELPATH + "/public-api.lean"]),
]
records = []
large = []
for name, cmd in COMMANDS:
    start = time.monotonic()
    at = datetime.now(timezone.utc).isoformat()
    proc = subprocess.run(cmd, cwd=FORMAL, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    text = proc.stdout.replace(str(ROOT), "<repo>")
    text = text.replace(str(Path.home()), "<home>")
    data = text.encode()
    digest = hashlib.sha256(data).hexdigest()
    if len(data) > 100_000:
        with tempfile.NamedTemporaryFile(prefix="l00b05-" + name + "-", suffix=".log", delete=False) as f:
            f.write(data)
        large.append((name, len(data), digest))
        location = "<tmp>"
    else:
        HERE.joinpath(name + ".log").write_bytes(data)
        location = name + ".log"
    record = dict(name=name, command=" ".join(cmd), cwd="formal", started_utc=at,
                  elapsed_seconds=round(time.monotonic()-start, 3), exit_code=proc.returncode,
                  bytes=len(data), sha256=digest, output=location)
    records.append(record)
    print(json.dumps(record, ensure_ascii=False), flush=True)
    if name == "axioms":
        dependencies = set()
        for match in re.finditer(r"depends on axioms:\s*\[([^\]]*)\]", text):
            dependencies.update(x.strip() for x in match.group(1).split(",") if x.strip())
        invalid = sorted(dependencies - {"propext", "Quot.sound", "Classical.choice"})
        targets = re.findall(r"^TARGET (.+)$", text, re.M)
        declarations = re.findall(r"'([^']+)' (?:depends on axioms|does not depend on any axioms)", text)
        HERE.joinpath("axiom-targets.txt").write_text("\n".join(declarations)+"\n")
        summary = dict(module_targets=len(targets), checked_declarations=len(declarations),
                       dependencies=sorted(dependencies), unapproved=invalid,
                       sorryAx="sorryAx" in text, exit_code=proc.returncode)
        HERE.joinpath("axioms-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
        HERE.joinpath("case-inventory.txt").write_text("\n".join(x for x in text.splitlines() if x.startswith("CONSTRUCTORS "))+"\n")
        print(json.dumps(summary, ensure_ascii=False), flush=True)
        if invalid or "sorryAx" in text:
            raise SystemExit("未承認の公理依存")
    HERE.joinpath("verification.json").write_text(json.dumps(records, ensure_ascii=False, indent=2)+"\n")
    if proc.returncode:
        print(text[-12000:])
        raise SystemExit(proc.returncode)
HERE.joinpath("large-records.md").write_text(
    "# 大きい生の記録\n\n100 KBを超える生の記録は`<tmp>`へ保存した。絶対パスは記さない。\n\n"
    "| 記録 | 大きさ（バイト） | SHA-256 | 保存先 |\n|---|---:|---|---|\n" +
    "".join(f"| {name}.log | {size} | `{digest}` | `<tmp>` |\n" for name, size, digest in large))
