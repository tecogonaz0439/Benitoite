#!/usr/bin/env python3
"""Record the checks after the group review without replacing the first run."""
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
REL = HERE.relative_to(ROOT).as_posix()
INPUTS = [
    ROOT / "formal/Benitoite/Release/Refinement/ExternalConnection.lean",
    ROOT / "formal/Benitoite.lean",
    ROOT / "formal/lakefile.toml",
    ROOT / "formal/lean-toolchain",
    HERE / "boundary.lean",
    HERE / "signatures.md",
    HERE / "r2-axioms.lean",
    HERE / "r2-verify.py",
]
HERE.joinpath("r2-inputs-sha256.json").write_text(json.dumps([
    dict(path=p.relative_to(ROOT).as_posix(), bytes=p.stat().st_size,
         sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in INPUTS
], indent=2) + "\n")
records = []
dependencies = set()
declarations = []
for name, cmd in [
    ("build", ["lake", "build"]),
    ("boundary", ["lake", "env", "lean", "-M", "12288", "../" + REL + "/boundary.lean"]),
    ("axioms", ["lake", "env", "lean", "-M", "12288", "../" + REL + "/r2-axioms.lean"]),
]:
    at = datetime.now(timezone.utc).isoformat()
    start = time.monotonic()
    proc = subprocess.run(cmd, cwd=ROOT / "formal", text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    output = proc.stdout.replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>")
    data = output.encode()
    digest = hashlib.sha256(data).hexdigest()
    target = "r2-" + name + ".log"
    if len(data) > 100_000:
        with tempfile.NamedTemporaryFile(prefix="l00b05-r2-", suffix=".log", delete=False) as f:
            f.write(data)
        with HERE.joinpath("large-records.md").open("a") as f:
            f.write(f"| {target} | {len(data)} | `{digest}` | `<tmp>` |\n")
        target = "<tmp>"
    else:
        HERE.joinpath(target).write_bytes(data)
    record = dict(name=name, command=" ".join(cmd), cwd="formal", started_utc=at,
                  elapsed_seconds=round(time.monotonic() - start, 3), exit_code=proc.returncode,
                  bytes=len(data), sha256=digest, output=target)
    records.append(record)
    HERE.joinpath("r2-verification.json").write_text(json.dumps(records, indent=2) + "\n")
    print(json.dumps(record), flush=True)
    if proc.returncode:
        print(output[-12000:])
        raise SystemExit(proc.returncode)
    if name in {"boundary", "axioms"}:
        for match in re.finditer(r"depends on axioms:\s*\[([^\]]*)\]", output):
            dependencies.update(x.strip() for x in match.group(1).split(",") if x.strip())
        declarations.extend(re.findall(
            r"'([^']+)' (?:depends on axioms|does not depend on any axioms)", output))
        if "sorryAx" in output:
            raise SystemExit("sorryAx")
invalid = sorted(dependencies - {"propext", "Quot.sound", "Classical.choice"})
summary = dict(checked_declarations=len(declarations), dependencies=sorted(dependencies),
               unapproved=invalid, sorryAx=False)
HERE.joinpath("r2-axioms-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
HERE.joinpath("r2-axiom-targets.txt").write_text("\n".join(declarations) + "\n")
print(json.dumps(summary), flush=True)
if invalid:
    raise SystemExit("unapproved axioms")
