#!/usr/bin/env python3
"""捕捉Φの既定ビルド・境界・公開署名・公理依存を記録する。git は使わない。"""
import hashlib
import json
import platform
import re
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
REL = HERE.relative_to(ROOT).as_posix()
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
large = []


def digest(data):
    return hashlib.sha256(data).hexdigest()


def save_json(name, data):
    HERE.joinpath(name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def save_output(name, data):
    if len(data) <= 100_000:
        HERE.joinpath(name + ".log").write_bytes(data)
        return name + ".log"
    with tempfile.NamedTemporaryFile(prefix="l00b14b-" + name + "-", suffix=".log", delete=False) as sink:
        sink.write(data)
        target = "<tmp>/" + Path(sink.name).name
    large.append(dict(record=name, bytes=len(data), sha256=digest(data), output=target))
    HERE.joinpath(name + ".log").write_text(
        f"生の記録: `{target}`\n\nバイト数: {len(data)}\n\nSHA-256: `{digest(data)}`\n")
    return target


start = json.loads(HERE.joinpath("start-inputs.json").read_text())
source_paths = sorted(p for p in ROOT.joinpath("formal").rglob("*.lean") if ".lake" not in p.parts)
now = {p.relative_to(ROOT).as_posix(): digest(p.read_bytes()) for p in source_paths}
changes = [dict(path=p, before=start["sha256"].get(p), after=h, bytes=ROOT.joinpath(p).stat().st_size)
           for p, h in now.items() if start["sha256"].get(p) != h]
save_json("source-delta.json", dict(base=start["base"],
    comparison="開始時のハッシュとの照合。指定B_WORKの内容との独立照合ではない。gitは未使用。",
    changes=changes))
review_start = json.loads(HERE.joinpath("review-start-inputs.json").read_text())
reference_updates = json.loads(HERE.joinpath("review-reference-updates.json").read_text())
expected_protected = dict(review_start["sha256"])
for item in reference_updates["updates"]:
    expected_protected[item["path"]] = item["after"]
allowed_edits = {
    "formal/Benitoite/Release/Refinement/CapturedFacts.lean",
    (HERE.parent / "reviews/RV-L00b.14b-request.md").relative_to(ROOT).as_posix(),
}
protected = {p: h for p, h in expected_protected.items() if p not in allowed_edits}
changed = [p for p, h in protected.items() if digest(ROOT.joinpath(p).read_bytes()) != h]
save_json("protected-inputs.json", dict(checked=len(protected), changed=changed,
    comparison="RV対応の開始入力と取りまとめの参照文書の追記後の照合。依頼文とCapturedFactsだけを保護対象から除く。"))
review_changes = [dict(path=p, before=review_start["sha256"].get(p), after=h)
                  for p, h in now.items() if review_start["sha256"].get(p) != h]
save_json("review-source-delta.json", dict(comparison="RV対応の開始時からの本番の差。gitは未使用。",
    changes=review_changes))
if changed:
    raise SystemExit("既存の保護対象が変わった。")
if {p["path"] for p in changes} != {
    "formal/Benitoite.lean", "formal/Benitoite/Release/Refinement/CapturedFacts.lean"
}:
    raise SystemExit("予定した本番の変更と一致しない。")
config = ROOT.joinpath("formal/lakefile.toml").read_text()
if 'moreLeanArgs = ["-M", "12288"]' not in config:
    raise SystemExit("既定ビルドのメモリ指定が違う。")

modules = sorted("Benitoite.Release.Refinement." +
    p.relative_to(ROOT / "formal/Benitoite/Release/Refinement").with_suffix("").as_posix().replace("/", ".")
    for p in ROOT.joinpath("formal/Benitoite/Release/Refinement").rglob("*.lean")) + ["Benitoite"]
inputs = source_paths + [ROOT / "formal/lakefile.toml", ROOT / "formal/lean-toolchain"]
inputs += [HERE / s for s in ["boundary.lean", "axioms.lean", "public-api.lean", "verify.py", "signatures.md"]]
inputs += sorted(HERE.glob("rv-*.lean")) + [HERE / "review-start-inputs.json", HERE / "review-reference-updates.json"]
hashes = {p.relative_to(ROOT).as_posix(): digest(p.read_bytes()) for p in inputs}
save_json("inputs-sha256.json", hashes)
save_json("environment.json", dict(machine=platform.machine(), os=platform.platform(),
    python=platform.python_version(), lean_memory_mib=12288, rss="未取得（計画上の非採取）"))

commands = [("build", ["lake", "build"])]
commands += [(s, ["lake", "env", "lean", "-M", "12288", "../" + REL + "/" + s + ".lean"])
             for s in ["boundary", "axioms", "public-api"]]
commands += [("lean-version", ["lake", "env", "lean", "-M", "12288", "--version"])]
records, names, dependencies, audited, counts = [], [], set(), [], []
for name, command in commands:
    started = datetime.now(timezone.utc).isoformat()
    before = time.monotonic()
    with tempfile.TemporaryFile() as sink:
        proc = subprocess.run(command, cwd=ROOT / "formal", stdout=sink, stderr=subprocess.STDOUT)
        sink.seek(0)
        output = sink.read().decode().replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>")
    elapsed = time.monotonic() - before
    data = output.encode()
    target = save_output(name, data)
    records.append(dict(name=name, command=command, cwd="formal", started_utc=started,
        elapsed_seconds=round(elapsed, 6), exit_code=proc.returncode, bytes=len(data),
        sha256=digest(data), output=target, rss="未取得（計画上の非採取）"))
    save_json("verification.json", records)
    print(json.dumps(records[-1], ensure_ascii=False), flush=True)
    if proc.returncode:
        print(output[-6000:], flush=True)
        raise SystemExit(proc.returncode)
    if re.search(r"declaration uses [‘']sorry", output):
        raise SystemExit("sorry を含む宣言。")
    if name in {"axioms", "boundary"}:
        names += re.findall(r"'([^']+)' (?:depends on axioms|does not depend on any axioms)", output)
        for match in re.finditer(r"depends on axioms:\s*\[([^\]]*)\]", output):
            dependencies.update(re.sub(r"\.\{[^}]*\}", "", n.strip())
                                for n in match[1].split(",") if n.strip())
        if "sorryAx" in output:
            dependencies.add("sorryAx")
    if name == "axioms":
        audited = re.findall(r"AUDIT_MODULE (\S+)", output)
        counts = [s for s in output.splitlines() if s.startswith(("cases ", "THREE_FAMILY_CASES"))]
    if name == "boundary":
        boundary_count = re.findall(r"BOUNDARY_DECLARATIONS (\d+)", output)

invalid = sorted(dependencies - ALLOWED)
production = [s for s in names if s.startswith("Benitoite.Release.Refinement.") and
              (s.endswith(("CaptureOk.evaluated_fact", "CaptureOk.addEntailed", "CaptureOk.addEvaluated", "CaptureOk.close_entails",
                           "HasTypeTelArgsQ.captured_one", "StateTyE.captured_beta_one", "StateTy.captured_beta_one")))]
save_json("axioms-summary.json", dict(checked_declarations=len(names), unique_declarations=len(set(names)),
    dependencies=sorted(dependencies), unapproved=invalid, sorryAx="sorryAx" in dependencies,
    audited_modules=audited, expected_modules=modules, missing_modules=sorted(set(modules) - set(audited)),
    production_public=production, boundary_declarations=boundary_count,
    scope="Refinement全モジュール・集約・旧モデル/主定理12宣言・境界の私有/生成宣言を含む。"))
save_output("axiom-targets", ("\n".join(names) + "\n").encode())
HERE.joinpath("case-inventory.txt").write_text("\n".join(counts) + "\n")
changed_inputs = [p for p, h in hashes.items() if digest(ROOT.joinpath(p).read_bytes()) != h]
save_json("input-stability.json", dict(checked=len(hashes), changed=changed_inputs))
HERE.joinpath("large-records.md").write_text("# 大きい記録\n\n"
    "| 記録 | バイト | SHA-256 | 保存先 |\n|---|---:|---|---|\n" + "".join(
    f"| {r['record']} | {r['bytes']} | `{r['sha256']}` | `{r['output']}` |\n" for r in large))
if invalid or set(modules) - set(audited) or changed_inputs or len(production) != 7:
    raise SystemExit("公理依存・監査の範囲・入力の安定性が不適合。")
print("全検査終了0。未承認公理・未監査モジュール・検査中の入力変更は0。", flush=True)
