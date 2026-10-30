#!/usr/bin/env python3
"""L00a末の公理依存とdry-runを記録する。build/work本実行は起動しない。"""
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
CHANGE = HERE.parent
ROOT = CHANGE.parent.parent
BASE = "9863c0141511dc225aff9ec787a4b733d65a9431"


def save(name, obj):
    (HERE / name).write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


def snapshot():
    paths = list((ROOT / "formal").rglob("*.lean"))
    paths = [p for p in paths if ".lake" not in p.parts]
    paths += [ROOT / "formal" / n for n in ("lakefile.toml", "lake-manifest.json", "lean-toolchain")]
    paths += list((ROOT / "crates/benitoite/src").rglob("*.rs"))
    paths += list((ROOT / "docs/design").rglob("*.md"))
    paths += [ROOT / "scripts/check.sh", CHANGE / "plan.md", CHANGE / "implementation-request.md"]
    return {str(p.relative_to(ROOT)): {"bytes": p.stat().st_size,
            "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in sorted(set(paths))}


def prepare():
    groups = {}
    def add(group, prefix, names):
        groups[group] = [prefix + n for n in names.split()]
    add("旧Core主定理", "Benitoite.Core.",
        "progress preservation step_sound step_complete effect_soundness")
    add("旧Release主定理と対象健全性", "Benitoite.Release.",
        "progress preservation preservationE step_sound effect_soundness effect_soundness_noLamNames "
        "step_target_sound step_target_sound_event step_target_sound_of_assumptions "
        "reachable_target_sound reachable_target_sound_event reachable_target_sound_of_assumptions")
    add("旧表層の脱糖と健全性", "Benitoite.Surface.",
        "desugar_typed desugar_wellFormed desugar_wellTyped desugar_effectsOk "
        "main_typed main_typed_eff surface_effect_soundness surface_target_sound")
    add("旧網羅性", "Benitoite.Release.",
        "Coverage.usefulFuelWithView_none_sound Coverage.usefulFuel_none_sound "
        "usefulWithView_none_sound useful_none_sound checkMatchWithView_exhaustive_sound "
        "checkMatch_exhaustive_sound checkMatchWithView_unreachable_sound checkMatch_unreachable_sound "
        "irrefutableWithView_sound irrefutable_sound usefulWithView_extension_exhaustive")
    add("旧表層検査器", "Benitoite.Surface.Check.",
        "checkExpr_sound checkBlock_sound checkArms_sound checkClauses_sound checkTypes_sound "
        "checkEach_sound checkHoleArgs_sound checkDict_sound checkDicts_sound checkDef_sound checkImpl_sound "
        "acceptEffCover_sound")
    add("旧プログラム検査と必須判定", "Benitoite.Surface.",
        "CheckTables.checkProgram_sound CheckTables.checkProgram_sound_contracts "
        "CheckAccept.acceptProgram_sound CheckAccept.checkProgramAccepted_sound "
        "CheckAccept.accepted_check_connection CheckAccept.accepted_check_connection_at "
        "CheckTools.Finite.effCovers_sound ScopeSound.scope_check_connection "
        "ScopeSound.scope_check_core ScopeSound.scope_local_typed "
        "ScopeSound.scope_check_connection_at ScopeSound.scope_check_core_at "
        "ScopeSound.productionRules_sound ScopeSound.http_check_connection")
    add("旧区間と局所解析の中心定理", "Benitoite.",
        "Interval.analyzeBase_normal_sound Interval.analyzeBase_warning_sound "
        "Interval.evalClosed_sound Scope.Inference.apply_sound Release.Eff.Covers.sound")
    add("旧使用定義", "Benitoite.Release.",
        "Ty.WF Eff.WF Ty.Le Eff.Covers HasTypeVQ HasTypeCQ StateTy StateTyE "
        "Program.WellTyped Builtins.CoreAssumptions Builtins.TargetAgreement Builtins.Assumptions Step Steps")
    add("新使用定義", "Benitoite.Release.Refinement.",
        "Ty EffR Term Pred Entails Ty.LeQ Eff.Covers HasTypeVQ HasTypeVsQ HasTypeEachQ HasTypeCQ "
        "Ty.norm Eff.norm Eff.memFail Eff.Canonical ConstOK embedTy embedEff")
    # 公理検査済みの本番名を現在の名前で統合する。旧停止時点の一覧は使わない。
    sources = ["l00a.06b/proof-audit.lean", "l00a.08/proof-audit-08.lean",
               "l00a.08/proof-audit-09a.lean", "l00a.08/proof-audit-09b.lean",
               "l00a.08/proof-audit-10.lean", "l00a.08/rv-l00a.08/proof-audit.lean",
               "l00a.12/wf-core/proof-audit.lean"]
    for source in sources:
        groups[source] = re.findall(r"^#print axioms (\S+)", (CHANGE / source).read_text(), re.M)
    targets = list(dict.fromkeys(n for ns in groups.values() for n in ns))
    save("targets.json", {"base": BASE, "groups": groups, "targets": targets, "count": len(targets)})
    (HERE / "targets.txt").write_text("\n".join(targets) + "\n")
    (HERE / "axioms.lean").write_text(
        "import Benitoite\n\n-- formal/ で lake env lean -M 12288 により検査する。\n"
        + "\n".join("#print axioms " + n for n in targets) + "\n")
    save("inputs-before.json", snapshot())
    print(json.dumps({"targets": len(targets), "protected_inputs": len(snapshot())}))


def run(mode):
    records = HERE / "checks.json"
    data = json.loads(records.read_text()) if records.exists() else {}
    if mode in data:
        raise SystemExit("同じ検査の再実行を拒否する: " + mode)
    if mode == "axioms":
        cwd = ROOT / "formal"
        cmd = ["lake", "env", "lean", "-M", "12288", str((HERE / "axioms.lean").relative_to(ROOT))]
        cmd[-1] = "../" + cmd[-1]
    elif mode == "dry-run":
        cwd = ROOT
        cmd = ["scripts/check.sh", "--level", "work", "--base", BASE, "--dry-run"]
    else:
        raise SystemExit("許すモードは prepare / axioms / dry-run / verify だけ")
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    t = time.monotonic()
    result = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - t
    (HERE / (mode + ".log")).write_bytes(result.stdout)
    data[mode] = {"command": cmd, "cwd": str(cwd.relative_to(ROOT)) or ".", "base": BASE,
                  "start_utc": start, "elapsed_seconds": elapsed, "exit_code": result.returncode,
                  "rss": "未取得（取りまとめが最後のworkに付けて採取する）"}
    save("checks.json", data)
    if mode == "axioms" and result.returncode == 0:
        output = result.stdout.decode()
        found = re.findall(r"'([^']+)' (?:depends on axioms: \[([^\]]*)\]|does not depend on any axioms)", output, re.S)
        actual = {name: [a.strip() for a in axioms.split(",") if a.strip()] for name, axioms in found}
        targets = json.loads((HERE / "targets.json").read_text())["targets"]
        allowed = {"propext", "Quot.sound", "Classical.choice"}
        unapproved = {n: a for n, aa in actual.items() for a in aa if a not in allowed}
        missing = sorted(set(targets) - set(actual))
        extra = sorted(set(actual) - set(targets))
        summary = {"count": len(actual), "allowed": sorted(allowed), "dependencies": actual,
                   "unapproved": unapproved, "missing": missing, "extra": extra,
                   "pass": not (unapproved or missing or extra) and len(found) == len(targets)}
        save("axioms-summary.json", summary)
        if not summary["pass"]:
            raise SystemExit("公理依存の照合不一致。停止し取りまとめへ報告する")
    print(json.dumps(data[mode], ensure_ascii=False))
    raise SystemExit(result.returncode)


def verify():
    before = json.loads((HERE / "inputs-before.json").read_text())
    after = snapshot()
    save("inputs-after.json", after)
    differences = sorted(k for k in set(before) | set(after) if before.get(k) != after.get(k))
    save("input-verification.json", {"count": len(after), "differences": differences,
                                   "verified_utc": datetime.datetime.now(datetime.timezone.utc).isoformat()})
    if differences:
        raise SystemExit("保護対象の変更: " + repr(differences))
    print("保護対象の一致: " + str(len(after)))


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "prepare":
        prepare()
    elif mode == "verify":
        verify()
    else:
        run(mode)
