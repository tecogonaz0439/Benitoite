#!/usr/bin/env python3
"""SF の最終証拠と参照の整合を点検する。Lean は起動しない。"""
from __future__ import annotations

import ast
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote

HERE = Path(__file__).resolve().parent
model = (HERE / "Model.lean").read_bytes()
digest = hashlib.sha256(model).hexdigest()
run = json.loads((HERE / "final-run.json").read_text())
inventory = json.loads((HERE / "inventory.json").read_text())
log = (HERE / "final.log").read_text()
findings = (HERE / "findings.md").read_text()
checks: dict[str, bool] = {}
checks["remote_succeeded_without_diagnostics"] = (
    run["passed"] and run["remote_exit"] == 0 and run["diagnostics"] == []
)
checks["all_source_hashes_match"] = (
    digest == run["source_sha256_before"] == run["source_sha256_after"]
    == inventory["spike"]["sha256"] and digest in findings
)
checks["remote_summary_matches_log_and_findings"] = (
    run["remote_summary"].strip() in log and run["remote_summary"].strip() in findings
)
checks["no_proof_holes_or_custom_axioms"] = (
    not re.search(r"\b(?:sorry|admit|axiom)\b", model.decode())
    and "sorryAx" not in log
)
checks["only_Std_imported"] = re.findall(r"^import (.+)$", model.decode(), re.M) == ["Std"]
checks["theorem_and_guard_counts_match"] = (
    len(re.findall(rb"^theorem ", model, re.M)) == inventory["spike"]["named_theorems"] == 73
    and len(re.findall(rb"^#guard ", model, re.M)) == inventory["spike"]["guards"] == 22
)
checks["axiom_reports_match"] = len(re.findall(r"^'SF\..*depends on axioms:", log, re.M)) == 15
links = []
for link in re.findall(r"\[[^\]]*\]\(([^)]+)\)", findings):
    local = unquote(link.split("#", 1)[0])
    target = (HERE / local).resolve()
    exists = target.is_file() or target == HERE / "artifact-check.json"
    links.append({"target": link, "exists": exists})
checks["relative_links_exist"] = all(link["exists"] for link in links)
checks["no_absolute_local_paths_in_records"] = all(
    "/Users/" not in (HERE / name).read_text()
    for name in ("findings.md", "final.log", "final-run.json", "inventory.json")
)
checks["no_trailing_whitespace_in_sources_or_findings"] = all(
    not re.search(r"[^\S\n]+$", (HERE / name).read_text(), re.M)
    for name in ("Model.lean", "findings.md", "inventory.py", "run.py", "verify.py")
)
for name in ("inventory.py", "run.py", "verify.py"):
    ast.parse((HERE / name).read_text(), filename=name)
checks["python_scripts_parse"] = True
checks["timing_filled"] = "最後の点検時刻とともにここへ記録する" not in findings
data = {
    "checked_utc": datetime.now(timezone.utc).isoformat(),
    "source_sha256": digest,
    "checks": checks,
    "links": links,
    "passed": all(checks.values()),
    "scope": "最終ソース・検査出力・記録の整合。Rustや本番formal/の検査ではない。",
}
(HERE / "artifact-check.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
print(json.dumps({"checks": checks, "passed": data["passed"]}, ensure_ascii=False, indent=2))
raise SystemExit(0 if data["passed"] else 1)
