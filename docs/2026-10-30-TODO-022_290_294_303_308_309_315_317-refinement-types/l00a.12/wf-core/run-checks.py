#!/usr/bin/env python3
"""継続作業の入力・公開名・検査の終了と外側の時間を保存する。"""
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
ROOT = HERE.parents[3]
PREFIX = "Benitoite.Release.Refinement."
MODULES = ["Context", "ShiftOrder", "TypeSubst", "OpenSubstitution", "Subst", "Typing",
           "ValueRegularity", "ValueBinding", "TypedFacts", "TypingShift", "SubstTyping",
           "Narrowing", "SubstTypingObstruction", "NarrowingObstruction"]
EXPOSED = ["renameKind", "hideConts", "hideBuilders", "bindParams", "liftMany", "localExtend"]
CHANGED = ["substTyValues", "substEffValues", "Val.subst", "Val.substList", "Comp.subst",
           "Arm.substList", "Clause.substList"]
kind = sys.argv[1]

if kind == "prepare":
    names = []
    by_module = {}
    for module in MODULES:
        source = ROOT / f"formal/Benitoite/Release/Refinement/{module}.lean"
        stack = []
        module_names = []
        for line in source.read_text().splitlines():
            match = re.match(r"namespace (\S+)$", line)
            if match:
                value = match.group(1)
                stack.append(value if not stack else stack[-1] + "." + value)
                continue
            match = re.match(r"end (\S+)$", line)
            if match and stack and (stack[-1] == match.group(1) or stack[-1].endswith("." + match.group(1))):
                stack.pop()
                continue
            match = re.match(r"\s*(?:@\[[^\]]*\]\s*)*(?:noncomputable\s+)?(?:def|theorem|structure|inductive|abbrev)\s+([^\s:{(]+)", line)
            if match:
                assert stack, line
                module_names.append(stack[-1] + "." + match.group(1))
        names.extend(module_names)
        by_module[module] = module_names
    exposed = [PREFIX + n for n in EXPOSED]
    changed = [PREFIX + n for n in CHANGED]
    (HERE / "public-names.json").write_text(json.dumps(
        {"modules": by_module, "current_declarations": names,
         "exposed": exposed, "changed_definitions": changed}, ensure_ascii=False, indent=2) + "\n")
    lines = ["import Benitoite.Release.Refinement.NarrowingObstruction", ""]
    extra = [PREFIX + "Ctx.Narrows." + n for n in ["here", "under", "underNone", "rec"]]
    for name in dict.fromkeys(names + exposed + changed + extra):
        lines.extend(["#check " + name, "#print axioms " + name])
    (HERE / "proof-audit.lean").write_text("\n".join(lines) + "\n")
    print(f"{len(names)} 公開宣言、{len(exposed)} 公開化、{len(changed)} 変更定義を検査")
    raise SystemExit(0)

if kind == "source-audit":
    paths = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    paths.extend(ROOT / p for p in ["formal/lakefile.toml", "formal/lean-toolchain",
        "formal/lake-manifest.json", "scripts/check.sh"])
    paths.extend(HERE.parent.parent / p for p in ["implementation-request.md", "plan.md",
        "l00a.06a/contracts.md", "reviews/RV-L00a.12-stop.md"])
    audit = {str(p.relative_to(ROOT)): {"size": p.stat().st_size,
        "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(set(paths))}
    output = HERE / "source-audit.json"
    if output.exists():
        assert json.loads(output.read_text()) == audit, "入力のハッシュが一致しない"
        print(f"{len(audit)} 入力が検査前後で一致")
    else:
        output.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n")
        print(f"{len(audit)} 入力の SHA-256 と大きさを保存")
    raise SystemExit(0)

records_path = HERE / "checks.json"
records = json.loads(records_path.read_text()) if records_path.exists() else []
assert all(r["kind"] != kind for r in records), "同じ検査の再実行は別名で記録する"
if kind == "local-build":
    cmd = ["rtk", "proxy", "lake", "build", "Benitoite.Release.Refinement.NarrowingObstruction"]
    cwd = ROOT / "formal"
elif kind == "proof":
    cmd = ["rtk", "proxy", "lake", "env", "lean", "-M", "12288",
           "../" + str((HERE / "proof-audit.lean").relative_to(ROOT))]
    cwd = ROOT / "formal"
else:
    assert kind in ("dry-run", "work")
    if kind == "work":
        assert any(r["kind"] == "dry-run" and r["exit_code"] == 0 for r in records)
    cmd = ["rtk", "proxy", "scripts/check.sh", "--level", "work", "--base", BASE]
    if kind == "dry-run":
        cmd.append("--dry-run")
    cwd = ROOT
started = datetime.now(timezone.utc).isoformat()
start = time.monotonic()
result = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - start
(HERE / (kind + ".log")).write_text(result.stdout)
record = dict(kind=kind, command=cmd, cwd=str(cwd.relative_to(ROOT)) or ".",
    started_at=started, exit_code=result.returncode, elapsed_seconds=elapsed, log=kind + ".log")
records.append(record)
records_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False), flush=True)
if kind in ("dry-run", "work") or result.returncode:
    print(result.stdout, flush=True)
if kind == "proof" and result.returncode == 0:
    dependencies = re.findall(r"depends on axioms: \[([^\]]*)\]", result.stdout)
    observed = sorted({x.strip() for group in dependencies for x in group.split(",") if x.strip()})
    assert set(observed) <= {"propext", "Quot.sound", "Classical.choice"}, observed
    assert "sorryAx" not in result.stdout
    count = len(dependencies) + result.stdout.count("does not depend on any axioms")
    expected = (HERE / "proof-audit.lean").read_text().count("#print axioms ")
    assert count == expected, (count, expected)
    (HERE / "proof-summary.json").write_text(json.dumps(
        {"declarations": count, "axioms": observed, "unapproved": []}, indent=2) + "\n")
    print(f"{count} 宣言の依存は許可一覧内", flush=True)
raise SystemExit(result.returncode)
