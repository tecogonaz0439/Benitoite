"""再開1の採取済みの検査・入力・時間を転記する。検査自体は再実行しない。"""
from pathlib import Path
import argparse
import collections
import datetime
import hashlib
import json
import re
import time

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
ROOT = STAGE.parent.parent.parent
MARKER = "\n<!-- 再開1の検査の生成した記録 -->\n"


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def clock(value):
    return datetime.datetime.fromtimestamp(value, datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    tmp = args.tmp
    checks = {}
    for label in ["default-build", "replay", "signatures", "dry-run", "work"]:
        data = json.loads((tmp / (label+"-summary.json")).read_text())
        assert data["exit"] == 0
        checks[label] = dict(data, output=digest(tmp / (label+".log")))
    audit = json.loads((STAGE / "audit-summary.json").read_text())
    checks["axioms"] = {k: v for k, v in audit.items() if k != "modules"}
    assert sum(audit["axiom_sets"].values()) == audit["targets"]
    names = set((tmp / "audit/audit-targets.txt").read_text().splitlines())
    retired = ["State", "State.reserved", "State.remaining", "State.Valid", "step", "run",
               "step_used", "step_limit", "step_valid", "run_used", "run_valid"]
    assert not any("Benitoite.Release.Refinement.StepAccounting." + n in names for n in retired)
    work = (tmp / "work.log").read_text()
    assert "7 passed; 0 failed; 0 ignored" in work and "selected checks passed" in work
    assert work.count("== formal_build") == 1
    replay = (tmp / "replay.log").read_text().splitlines()
    assert len(replay) == 22 and all(l.endswith(": true") for l in replay)
    assert not re.search(r"error(?:\(|:)", (tmp / "signatures.log").read_text())
    before = json.loads((tmp / "before-sources.json").read_text())
    after = {str(p.relative_to(ROOT)): digest(p)["sha256"] for p in sorted((ROOT / "formal").rglob("*.lean"))
             if ".lake" not in p.parts}
    changed = sorted(n for n in set(before) | set(after) if before.get(n) != after.get(n))
    assert set(changed) == {"formal/Benitoite/Release/Refinement/"+n+".lean" for n in
                            ["CoefficientModel", "StepAccounting", "AccountingWork", "ProofContract",
                             "ProofContractExamples", "ProofReplayExamples"]}
    inputs = json.loads((HERE / "inputs.json").read_text())
    assert inputs["formal_manifest"] == digest(tmp / "formal-sources.json")
    completion = json.loads((HERE / "completion-summary.json").read_text())
    assert completion["handoffs"] == {"済": 52, "転記": 11}
    verification = {"resume": 1, "checks": checks, "work_entry_executions_this_resume": 1,
                   "work_selected": ["spec_tally", "spec_examples", "formal_build"],
                   "formal_changed_since_resume_start": changed,
                   "formal_manifest_after_work": inputs["formal_manifest"],
                   "before_source_manifest": digest(tmp / "before-sources.json"),
                   "retired_names_absent_from_environment": retired,
                   "official_max_rss": "未取得（取りまとめの同じ段末workでの採取待ち）",
                   "later_changes": "本番Lean・01-12・07-04・lakefile・既定importはwork後に変更なし。結果の記録のみ更新",
                   "initial_verification": "verification-before-resume1.json",
                   "judgment": "担当Codexの自己点検。RV-L30.l処置の取りまとめの再確認・設計者の受け入れは未実施"}
    payload = json.dumps(verification, ensure_ascii=False, indent=2)+"\n"
    (HERE / "verification-resume1.json").write_text(payload)
    (HERE / "verification.json").write_text(payload)
    start = json.loads((tmp / "start.json").read_text())["start"]
    implementation_end = json.loads((tmp / "implementation-end.json").read_text())["end"]
    finish = time.time()
    times = {"resume": 1, "start": clock(start), "implementation_and_documents_marker": clock(implementation_end),
             "end": clock(finish), "elapsed_seconds": finish-start,
             "note": "時計取得前のレビュー読取りは未採取。所見間で定義と読者を共有し、個別の能動時間と全待ちは分離不能",
             "shared_observation_seconds": implementation_end-start,
             "validation_and_records_seconds": finish-implementation_end,
             "initial_times": "times-before-resume1.json"}
    payload = json.dumps(times, ensure_ascii=False, indent=2)+"\n"
    (HERE / "times-resume1.json").write_text(payload)
    (HERE / "times.json").write_text(payload)
    table = "\n### 再開1の検査・監査と外側の時間\n\n"
    table += "この再開のworkは一回であり、--only・個別testの指定なし。既定のlake buildは8対象を保持し、単独Leanも含め-M12288とした。正式RSSは未取得（取りまとめの採取待ち）。\n\n"
    table += "| 検査 | 終了 | 外側の時間 | 内容 |\n|---|---:|---:|---|\n"
    for key, title, note in [
        ("default-build", "既定lake build", "新規の読者と改名後の全既定対象、sorryなし"),
        ("replay", "同じ列の実行再生", "22行全てtrue、false又は件数不一致は失敗"),
        ("signatures", "固定署名と実型", "固定8署名と主要42宣言、旧名の別名を追加しない"),
        ("axioms", "段末の公理監査", f"{audit['module_count']}モジュール・{audit['targets']:,}宣言"),
        ("dry-run", "workのdry-run", "仕様対応の自己検査/集計、仕様例、既定Leanを確認"),
        ("work", "作業末のwork", "仕様例7成功・失敗/無視0、自己検査/集計、既定Leanとsorry拒否")]:
        table += f"| {title} | 0 | {checks[key]['seconds']:.3f}秒 | {note} |\n"
    table += "\nworkの実コマンドは `scripts/check.sh --level work --base c30b5b3424f6d98295b26cac96fe9a8b35a2eb27`。既定ビルド・再生・署名・dry-runの完全な引数と生出力の識別はverification-resume1.jsonに保存した。\n\n"
    table += "| 公理の依存集合 | 宣言数 |\n|---|---:|\n"
    for axiom_set, count in audit["axiom_sets"].items():
        table += f"| {axiom_set} | {count:,} |\n"
    table += "\n許可三公理以外、新しい公理、sorryAxは0。既定のimportの閉包を保持し、旧主定理・三モデル・十移送・private/生成宣言を含む。\n\n"
    table += "| 新規6モジュールの現行の全定数 | 件数 |\n|---|---:|\n"
    for name, count in audit["new_modules"].items():
        table += f"| {name} | {count} |\n"
    table += f"| 合計 | {sum(audit['new_modules'].values())} |\n"
    table += "\n名前付きの手書き宣言の現行件数は"+str(completion["handwritten_declarations"])+"（"+"・".join(k+str(v) for k,v in completion["declaration_kinds"].items())+"）。匿名exampleは全定数の件数に含めず、既定ビルドと禁止構文の点検で確認する。\n\n"
    table += "| 生出力（全て<tmp>） | bytes | SHA-256 |\n|---|---:|---|\n"
    for key in ["default-build", "replay", "signatures", "dry-run", "work"]:
        d = checks[key]["output"]
        table += f"| {key}.log | {d['bytes']:,} | `{d['sha256']}` |\n"
    for name, d in [("axioms.log", audit["raw"]), ("audit-targets.txt", audit["target_list"]),
                    ("formal-sources.json", inputs["formal_manifest"]),
                    ("before-sources.json", verification["before_source_manifest"])]:
        table += f"| {name} | {d['bytes']:,} | `{d['sha256']}` |\n"
    table += f"\n再開1の観測枠は{clock(start)}〜{clock(finish)}、{finish-start:.3f}秒（約{(finish-start)/60:.1f}分）。所見の共通の定義・証明・読者・一部の文書までの枠は{implementation_end-start:.3f}秒、後の文書の照合・検査・記録の枠は{finish-implementation_end:.3f}秒である。所見別の時間へ分配せず、能動時間と待ちは分離不能とした。時計取得前の読取りは未採取であり、初回の観測枠へ混ぜない。\n"
    table += "\n今回の変更は本番6ファイルと対応する写し・入力・記録であり、他の既存Leanと旧Release・主な十移送・型付け規則・既定importを変更していない。work後の本番・写し・設定の変更はなく、記録のみ更新した。Rust/Lean全比較・32ビットでの実行照合・正式RSSを成功に含めない。\n"
    for path in [HERE / "results.md", STAGE / "stage-results.md"]:
        prefix = path.read_text().split(MARKER, 1)[0]
        path.write_text(prefix+MARKER+table)
    print(json.dumps({"checks": {k: {"exit": v["exit"], "seconds": v["seconds"]} for k,v in checks.items()},
                      "targets": audit["targets"], "handwritten": completion["handwritten_declarations"],
                      "handoffs": completion["handoffs"], "elapsed_seconds": finish-start}))


if __name__ == "__main__":
    main()
