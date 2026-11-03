"""本番署名・入力の識別・義務と申し送りの件数を再生成して点検する。"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import re
import subprocess

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
CHANGE = STAGE.parent
ROOT = CHANGE.parent.parent
FORMAL = ROOT / "formal"
NAMES = ["CoefficientModel", "StepAccounting", "AccountingWork", "ProofContract",
         "ProofContractExamples", "ProofReplayExamples"]
SOURCES = [FORMAL / "Benitoite/Release/Refinement" / (n + ".lean") for n in NAMES]
EXPECTED = {"O015", "O017", "O019", "O020", "O021", "O022", "O023", "O026", "O034",
            "O043", "O050", "O054", "O071", "O072", "O127", "O130", "O131", "O132",
            "O133", "O134", "O135", "O136", "O137", "O144", "O158", "O161", "O167",
            "O046", "O079", "O138", "O143", "O016", "O084", "O027", "O118"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def declarations(path):
    """今回の通常の名前空間と宣言だけを読む。生成宣言はLean環境の監査で扱う。"""
    lines = path.read_text().splitlines()
    result = []
    namespace = []
    for i, line in enumerate(lines):
        if line.startswith("namespace "):
            namespace.append(line.split(maxsplit=1)[1])
        elif line.startswith("end"):
            if namespace:
                namespace.pop()
        match = re.match(r"(?:private )?(def|abbrev|theorem|structure|inductive|instance)\b", line)
        if not match:
            continue
        j = i + 1
        if match[1] in {"inductive", "structure"}:
            while j < len(lines) and lines[j].strip():
                j += 1
            signature = "\n".join(lines[i:j])
        else:
            while ":=" not in "\n".join(lines[i:j]) and j < len(lines):
                j += 1
            signature = "\n".join(lines[i:j]).split(":=", 1)[0].rstrip()
        result.append({"namespace": ".".join(namespace), "kind": match[1],
                       "line": i+1, "signature": signature})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    extracted = []
    for path in SOURCES:
        for row in declarations(path):
            extracted.append(dict(row, source=str(path.relative_to(ROOT))))
    (HERE / "declarations.json").write_text(json.dumps(extracted, ensure_ascii=False, indent=2)+"\n")
    intro = """# 群 L の契約と完全署名

2026-11-03。群A〜Kの固定署名は変更していない。以下はrecords.pyで本番から抽出した宣言の完全署名である。定義の本文を除き、構造体の欄と有限の構成子は省かない。型・名前空間と前提は実物どおりである。生成宣言とprivateを含む全名の件数は段末のaudit-summary.jsonに置く。

数学の係数の幅はbits、一時域はtemporaryBitsと別に量化する。storageBits=128は契約の値である。binaryのdivideは非零の負の除数も計算し、min/−1の結果が保存域を超えれば拒否する。丸めの正除数の条件は既存のLinearStepが検査する。

StepStateのpendingは(Nat × Cleanup)の列で、Ticketはこの組である。reservedとremainingは別の可変欄にせず、保存状態から計算する。Action.destroyはTicketを取り、予約された同じ組を一度だけ消費する。runActionsは成功か理由を返し、executeは途中停止時の状態も保持する。実作業との対応とR20の残りはr20-contract.md、検査はresults.mdを正とする。

再開1でStepAccountingのState/step/runをStepState/stepAction/runActionsへ、対応するstep_*とrun_*の補題もstepAction_*/runActions_*へ改名した。旧名の別名は残していない。AccountingWorkには逐次検査のreadCoefficient/addCoefficientsと数学の結果の同値を追加した。checkAccountedは計上失敗時に再生へ進まず、成功からAcceptedを得る。AccountingWorkの操作列は規範に従う例示である。product_then_saveの一時幅の表現可能性は前提であり、その幅での計算を実装する定義ではない。群A〜Kの引数・量化・結論への変更は0件である。
"""
    chunks = [intro]
    for path in SOURCES:
        chunks.append("\n## " + path.stem + "\n")
        for row in declarations(path):
            chunks.append("\n名前空間: `"+row["namespace"]+"`\n\n```lean\n"+row["signature"]+"\n```\n")
    (HERE / "signatures.md").write_text("".join(chunks))
    full_manifest = {str(p.relative_to(ROOT)): digest(p) for p in sorted(FORMAL.rglob("*.lean"))
                     if ".lake" not in p.parts}
    manifest = args.tmp / "formal-sources.json"
    manifest.write_text(json.dumps(full_manifest, sort_keys=True, indent=2)+"\n")
    selected = SOURCES + [FORMAL / "Benitoite.lean", FORMAL / "lakefile.toml", FORMAL / "lean-toolchain",
        ROOT / "docs/design/01-spec/01-12-core-calculus.md",
        ROOT / "docs/design/07-quality/07-04-formal-semantics.md",
        CHANGE / "implementation-request.md", CHANGE / "plan.md", CHANGE / "README.md",
        STAGE / "detail.md", STAGE / "axioms.lean", STAGE / "audit.py",
        HERE / "records.py", HERE / "finalize.py", HERE / "resume1.py", HERE / "signature-check.lean", HERE / "replay.lean",
        HERE / "case-completion.md", HERE / "r20-contract.md", HERE / "review-handoffs.md",
        HERE / "review-response.md", HERE / "signatures.md"]
    for group in ["a", "b", "d", "f", "h", "j"]:
        selected += [STAGE / group / "results.md", STAGE / group / "signatures.md",
                     CHANGE / "reviews" / ("RV-L30." + group + ".md")]
    selected += [STAGE / "a/comparison.md", CHANGE / "l20/stage-results.md",
                 CHANGE / "l20/axioms.lean", CHANGE / "l20/audit-inventory.lean",
                 CHANGE / "effort-ledger.md"]
    selected += [CHANGE / "reviews/RV-L30.l.md"]
    inputs = {"B_WORK": "c30b5b3424f6d98295b26cac96fe9a8b35a2eb27",
              "branch": "m014/l30.l", "basis": "起動依頼で受領。担当はgitコマンドを実行していない",
              "configuration": "既定8target、増分build、Lean -M12288",
              "formal_source_count": len(full_manifest), "formal_manifest": digest(manifest),
              "inputs": {str(p.relative_to(ROOT)): digest(p) for p in selected},
              "tools": {"lean": subprocess.check_output(["lake", "env", "lean", "--version"], cwd=FORMAL, text=True).strip(),
                        "lake": subprocess.check_output(["lake", "--version"], cwd=FORMAL, text=True).strip()}}
    (HERE / "inputs.json").write_text(json.dumps(inputs, ensure_ascii=False, indent=2)+"\n")
    stage = (STAGE / "stage-results.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", stage, re.M)
    assert len(ids) == 35 and set(ids) == EXPECTED
    plan = (CHANGE / "plan.md").read_text()
    assert all(re.search(r"^\| " + i + r" \|.*L30", plan, re.M) or i in {"O016", "O084", "O027", "O118"}
               for i in EXPECTED)
    detail = (STAGE / "detail.md").read_text().split("## 7.", 1)[1].split("## 8.", 1)[0]
    assert EXPECTED <= set(re.findall(r"O\d{3}", detail))
    units = []
    groups = collections.defaultdict(lambda: [0, 0, 0])
    for line in (STAGE / "detail.md").read_text().splitlines():
        match = re.match(r"\| L30\.(\d+)/([A-N]) \|", line)
        if not match:
            continue
        bounds = re.search(r"(\d+)〜(\d+)分/", line.split("|")[-2])
        assert bounds, line
        lower, upper = map(int, bounds.groups())
        units.append(int(match[1]))
        row = groups[match[2]]
        row[0] += 1
        row[1] += lower
        row[2] += upper
    assert len(units) == 79 and set(units) == set(range(1, 81)) - {73}
    assert sum(v[1] for v in groups.values()) == 2825
    assert sum(v[2] for v in groups.values()) == 5515
    effort = []
    for number, line in enumerate((CHANGE / "effort-ledger.md").read_text().splitlines(), 1):
        if not line.startswith("| "):
            continue
        fields = [f.strip() for f in line.split("|")[1:-1]]
        if len(fields) < 5 or not fields[1].startswith(("L30", "RV-L30")):
            continue
        duration = fields[4]
        minutes = re.search(r"(\d+)分", duration)
        seconds = re.search(r"([\d.]+)秒", duration)
        total = (int(minutes[1])*60 if minutes else 0)+(float(seconds[1]) if seconds else 0)
        if fields[1].startswith("L30 群 L・M・N") and fields[2] == "Codex":
            category = "L/M/Nの実装と再開"
        elif fields[1].startswith("RV-L30.l"):
            category = "L/M/Nの独立レビュー"
        elif fields[1].startswith("L30 群") and fields[2] == "Codex":
            category = "実装と再開"
        elif fields[1].startswith("RV-L30."):
            category = "群の独立レビュー"
        elif fields[1].startswith("L30 群") and fields[2] == "取りまとめ":
            category = "取りまとめのwork"
        elif fields[1].startswith("L30-plan"):
            category = "詳細化の計画"
        elif fields[1].startswith("RV-L30-plan"):
            category = "計画のレビュー"
        else:
            continue
        effort.append({"line": number, "unit": fields[1], "category": category,
                       "source_duration": duration, "seconds": total})
    totals = collections.Counter()
    for row in effort:
        totals[row["category"]] += row["seconds"]
    estimates = {"units": 79, "groups_count_lower_upper_minutes": dict(groups),
                 "lower_minutes": 2825, "upper_minutes": 5515,
                 "effort_ledger_rows": effort, "effort_category_seconds": dict(totals),
                 "note": "台帳の約の値を使用。A〜KとL/M/Nを分離し、能動時間へ変えない。本再開の未転記分はtimes-resume1.jsonを正とする"}
    (HERE / "estimates.json").write_text(json.dumps(estimates, ensure_ascii=False, indent=2)+"\n")
    handoffs = (HERE / "review-handoffs.md").read_text()
    dispositions = collections.Counter(re.findall(r"^\| [^|]+ \| (済|転記) \|", handoffs, re.M))
    assert dispositions == {"済": 52, "転記": 11}
    stage_id = re.compile(r"(?<![A-Za-z0-9_])[LRKDV]\d{2}[a-z]?(?:\.(?:\d+[a-z]?|[a-z]))?(?![A-Za-z0-9_])")
    assert all(stage_id.search(s) for s in ["L00a", "L00a.06b", "L30.67", "R10b.02", "R20の", "K10", "D10", "V10"])
    assert not any(stage_id.search(s) for s in ["UInt32", "Integer64", "StepState", "L30Value", "xR20", "R20_x"])
    bad_source = re.compile(r"\b(sorry|axiom|native_decide|implemented_by|unsafe|set_option)\b|#eval|/Users/")
    for p in SOURCES:
        assert not bad_source.search(p.read_text()), str(p.relative_to(ROOT))
        assert not stage_id.search(p.read_text()), str(p.relative_to(ROOT))
    issues = []
    docs = list(HERE.glob("*.md")) + [STAGE / "stage-results.md"]
    for p in docs:
        content = p.read_text()
        assert not re.search(r"/Users/|\]\([^)]*docs/todo|\]\([^)]*(?:work/|reference/)", content)
        for target in re.findall(r"\]\(([^)]+)\)", content):
            target = target.split("#", 1)[0]
            if target and not re.match(r"https?://", target) and not (p.parent / target).exists():
                issues.append([str(p.relative_to(ROOT)), target])
    assert not issues, issues
    artifacts = list(HERE.iterdir()) + [STAGE / n for n in ["stage-results.md", "axioms.lean", "audit.py", "audit-summary.json"]]
    assert all(p.stat().st_size <= 100_000 for p in artifacts if p.is_file())
    summary = {"obligations": len(ids), "technical": 31, "common_complete": 2, "common_partial": 2,
               "whole_obligations_closed": 0, "handoffs": dict(dispositions),
               "new_source_modules": len(SOURCES), "handwritten_declarations": len(extracted),
               "declaration_kinds": dict(collections.Counter(r["kind"] for r in extracted)),
               "links_checked": True, "new_source_forbidden_tokens": 0, "new_source_stage_ids": 0,
               "each_artifact_under_100kb": True, "formal_manifest": digest(manifest)}
    (HERE / "completion-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
