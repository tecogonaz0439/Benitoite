"""L10 段末の既定ビルドと受渡し・公理依存の再実行。git は使わない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def run(label, argv, cwd):
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    before = time.monotonic()
    result = subprocess.run(argv, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - before
    raw = result.stdout
    record = {"command": argv, "cwd": str(cwd.relative_to(ROOT)) or ".",
              "started_utc": start, "exit": result.returncode, "seconds": elapsed,
              "bytes": len(raw), "sha256": sha(raw)}
    if len(raw) > 100000:
        tmp = Path(tempfile.mkdtemp(prefix="benitoite-l10-f-")) / (label + "-output.txt")
        tmp.write_bytes(raw)
        record["raw_output"] = "<tmp>/" + tmp.parent.name + "/" + tmp.name
    else:
        out = HERE / (label + "-output.txt")
        out.write_bytes(raw)
        record["raw_output"] = out.name
    text = raw.decode("utf-8", errors="replace")
    # sorryAx の検査に加え、コンパイル時の sorry 警告も拒む。
    record["sorry"] = bool(re.search(r"sorryAx|declaration uses .sorry.", text))
    if label == "axioms":
        rows = re.findall(r"'(.+)' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)", text)
        deps = sorted({a.strip() for _, ds in rows for a in ds.split(",") if a.strip()})
        record.update(printed=len(rows), unique_printed=len({n for n, _ in rows}), dependencies=deps, unapproved=sorted(set(deps) - ALLOWED))
        # 完全名と依存を小さい分割ファイルに保存する。大きな生出力を複製しない。
        for i in range(0, len(rows), 200):
            data = [{"name": name, "axioms": [a.strip() for a in ds.split(",") if a.strip()]}
                    for name, ds in rows[i:i+200]]
            (HERE / f"axioms-names-{i//200:03}.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
        modules = re.findall(r"AUDIT_MODULE (\S+) (\d+)", text)
        record["modules"] = [{"name": n, "count": int(c)} for n, c in modules]
        record["expected_printed"] = sum(int(c) for _, c in modules) + 20
    if label.startswith("review-"):
        rows = re.findall(r"'(.+)' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)", text)
        deps = sorted({a.strip() for _, ds in rows for a in ds.split(",") if a.strip()})
        record.update(printed=len(rows), dependencies=deps, unapproved=sorted(set(deps) - ALLOWED))
    if label == "build":
        record["completed"] = re.findall(r"Build completed successfully[^\n]*", text)
    (HERE / (label + "-result.json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(record if label != "axioms" else {k:v for k,v in record.items() if k != "modules"}, ensure_ascii=False))
    if result.returncode or record["sorry"] or record.get("unapproved"):
        print(text[-6000:])
        raise SystemExit(1)
    if label == "axioms" and (not record["printed"] or record["printed"] != record["expected_printed"]):
        raise SystemExit("公理依存の件数が対象一覧と一致しない")


for label in sys.argv[1:]:
    if label == "build":
        run(label, ["lake", "build"], FORMAL)
    elif label == "axioms":
        run(label, ["lake", "env", "lean", "-M", "12288", "../" + str((HERE.parent / "axioms.lean").relative_to(ROOT))], FORMAL)
    elif label == "handoff":
        run(label, ["lake", "env", "lean", "-M", "12288", "../" + str((HERE / "handoff.lean").relative_to(ROOT))], FORMAL)
    elif label in ["review-boundary", "review-t1", "review-t2", "review-t3", "k-boundary"]:
        target = (HERE.parent / "k/boundary.lean") if label == "k-boundary" else (
            HERE / ("boundary.lean" if label == "review-boundary" else "rv-f-" + label.removeprefix("review-") + ".lean"))
        run(label, ["lake", "env", "lean", "-M", "12288", "../" + str(target.relative_to(ROOT))], FORMAL)
    else:
        raise SystemExit("未知の検査: " + label)
