#!/usr/bin/env python3
"""SG 内の検査の証拠を照合し、所要時間と点検結果を記録する。Lean は起動しない。"""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
START = datetime.fromisoformat("2026-10-26T15:12:29+00:00")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


model = (HERE / "Model.lean").read_text()
run = json.loads((HERE / "final-run.json").read_text())
inventory = json.loads((HERE / "inventory.json").read_text())
log = (HERE / "final.log").read_text()
assert run["passed"] and run["remote_exit"] == 0 and run["wrapper_process_exit"] == 0
assert not run["diagnostics"]
assert run["source_sha256_before"] == run["source_sha256_after"] == digest(HERE / "Model.lean")
assert inventory["spike"]["sha256"] == digest(HERE / "Model.lean")
assert all(inventory["sf_proof_bodies_unchanged"].values())
assert re.findall(r"^import (.+)$", model, re.M) == ["Std"]
assert not re.search(r"\b(sorry|admit|axiom)\b", model)
assert "sorryAx" not in log
assert not re.search(r"^Model\.lean:\d+:\d+: (?:error|warning)", log, re.M)
assert (log.count("depends on axioms:") + log.count("does not depend on any axioms")) == inventory["spike"]["axiom_reports"]
assert "Classical.choice" in log
assert run["remote_summary"].strip() == log.strip().splitlines()[-1].strip()
assert run["command"] == ["zsh", "work/m013/remote-lean.sh", "SG", "Model.lean", "6144", "180"]
assert inventory["base_commit"] == "0414065298d373cdb83838749eaeb1bb256d292e"

now = datetime.now(timezone.utc)
seconds = round((now - START).total_seconds())
assert seconds < 120 * 60
minutes, secs = divmod(seconds, 60)
findings_path = HERE / "findings.md"
findings = findings_path.read_text()
old = r"文書と成果物の最終点検までの時間は .*?に記録する。"
replacement = (
    f"文書と成果物の最終点検は{now.strftime('%Y-%m-%d %H:%M:%S UTC')}であり、"
    f"最初の時計からの実時間は **{minutes}分{secs:02d}秒** だった。"
    "時刻と所要時間は [artifact-check.json](artifact-check.json) にも記録した。"
)
if re.search(old, findings):
    findings = re.sub(old, replacement, findings)
    findings_path.write_text(findings)

links = re.findall(r"\[[^\]]+\]\(([^)]+)\)", findings)
checked = []
for link in links:
    if "://" in link or link.startswith("#"):
        continue
    target = (HERE / link.split("#", 1)[0]).resolve()
    assert target.exists() or target == HERE / "artifact-check.json", link
    checked.append(link)

files = ["Model.lean", "findings.md", "run.py", "inventory.py", "inventory.json",
         "verify.py", "final.log", "final-run.json"]
for name in files:
    contents = (HERE / name).read_text()
    assert str(REPO) not in contents, name

record = {
    "passed": True,
    "started_utc": START.isoformat(),
    "verified_utc": now.isoformat(),
    "elapsed_seconds": seconds,
    "elapsed_japanese": f"{minutes}分{secs:02d}秒",
    "within_120_minutes": seconds < 7200,
    "remote_summary": run["remote_summary"],
    "remote_maximum_resident_bytes": run["time_maximum_resident_bytes"],
    "model_sha256": digest(HERE / "Model.lean"),
    "files_sha256": {name: digest(HERE / name) for name in files},
    "relative_links_checked": checked,
    "sf_proof_bodies_unchanged": inventory["sf_proof_bodies_unchanged"],
    "checks": ["最終別機検査の終了0・警告なし", "検査前後と現ソースのハッシュ一致",
               "独立ファイルのimport制限", "禁止した宣言なし・公理依存表示の件数",
               "findingsの相対リンク", "記録に手元のリポジトリの絶対パスなし"],
}
(HERE / "artifact-check.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
assert all((HERE / link.split("#", 1)[0]).exists() for link in checked)
print(json.dumps({key: record[key] for key in ["passed", "elapsed_japanese", "remote_summary",
    "model_sha256", "sf_proof_bodies_unchanged"]}, ensure_ascii=False, indent=2))
