"""隔離した欄の等号の試行を単独検査し、全局所宣言の公理依存と既存入力を照合する。"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import time
from datetime import datetime, timezone

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TRIAL = ROOT / "formal/Trial/L40E5.lean"
ALLOWED = {"propext", "Classical.choice", "Quot.sound"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def manifest_hash(manifest):
    data = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--reuse-build", type=Path)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    before = json.loads(args.before.read_text())
    after = {p: digest(ROOT / p)["sha256"] for p in before}
    assert before == after, "既存のLean・設計書・設定が開始時と異なる"
    source = TRIAL.read_text()
    assert not re.search(r"\b(sorry|admit|axiom|native_decide)\b|#eval", source)
    for p in (ROOT / "formal").rglob("*.lean"):
        if ".lake" in p.parts or p == TRIAL:
            continue
        assert not re.search(r"^import\s+Trial\.", p.read_text(), re.M), "試行へのimportがある"
    records = []
    commands = [(["lake", "env", "lean", "-M", "12288", "Trial/L40E5.lean"], "trial.log")]
    if not args.reuse_build:
        commands.append((["lake", "build"], "default-build.log"))
    for cmd, logfile in commands:
        start = time.monotonic()
        raw = args.tmp / logfile
        with raw.open("wb") as stream:
            proc = subprocess.run(cmd, cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
        record = {"command": cmd, "exit": proc.returncode,
                  "seconds": round(time.monotonic() - start, 3), "raw": digest(raw)}
        records.append(record)
        assert proc.returncode == 0, record
    if args.reuse_build:
        previous = json.loads(args.reuse_build.read_text())
        assert previous["protected_manifest_sha256"] == manifest_hash(before)
        build = next(r for r in previous["commands"] if r["command"] == ["lake", "build"])
        assert build["exit"] == 0
        records.append({**build, "reused": True, "reason": "既定入力993件が同じSHA-256であり、変更は隔離した試行と照合台本だけ"})
    output = (args.tmp / "trial.log").read_text()
    assert not re.search(r"error:|warning:|R5_(AXIOM|MISSING)", output)
    names = re.findall(r"^R5_TARGET (.+)$", output, re.M)
    count = int(re.search(r"^R5_COUNT (\d+)$", output, re.M)[1])
    assert count == len(names) == len(set(names)) and count > 100
    deps = re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])", output, re.M | re.S)
    assert {n for n, _, _ in deps} == set(names) and len(deps) == count
    axiom_sets = {}
    for _, _, ax in deps:
        used = {a.strip() for a in ax.split(",") if a.strip()}
        assert used <= ALLOWED, used
        key = " + ".join(sorted(used)) or "none"
        axiom_sets[key] = axiom_sets.get(key, 0) + 1
    summary = {
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "trial": {"path": "formal/Trial/L40E5.lean", **digest(TRIAL)},
        "verification_script": digest(Path(__file__)),
        "commands": records, "local_declarations": count,
        "private_and_generated_included": True, "new_axioms": 0,
        "axiom_sets": axiom_sets,
        "declaration_list_sha256": hashlib.sha256(("\n".join(names) + "\n").encode()).hexdigest(),
        "protected_input_count": len(before), "protected_inputs_unchanged": before == after,
        "protected_manifest_sha256": manifest_hash(before),
        "default_import_unchanged": True,
        "rust_and_work_checks": "未実行。隔離したLean試行であり、本番作業の群末ではない",
        "rss": "未取得（計画上の非採取）",
    }
    summary_path = HERE / "verification-r5.json"
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    assert summary_path.stat().st_size <= 100000 and TRIAL.stat().st_size <= 100000
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
