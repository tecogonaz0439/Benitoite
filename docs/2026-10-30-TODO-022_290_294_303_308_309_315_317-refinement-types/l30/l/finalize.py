"""初回の採取済みの検査と時間を転記した台本。再開1の現行結果はresume1.pyで更新する。"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import time

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
MARKER = "\n<!-- 検査と時間の生成した記録 -->\n"


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def clock(value):
    return datetime.datetime.fromtimestamp(value, datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")


def replace(path, content):
    prefix = path.read_text().split(MARKER, 1)[0]
    path.write_text(prefix+MARKER+content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    tmp = args.tmp
    audit = json.loads((STAGE / "audit-summary.json").read_text())
    checks = {}
    documents = "../docs/" + STAGE.parent.name + "/l30/l/"
    for label, command in [
        ("replay", "(cd formal && lake env lean -M 12288 --run " + documents + "replay.lean)"),
        ("signatures", "(cd formal && lake env lean -M 12288 " + documents + "signature-check.lean)"),
        ("dry-run", "scripts/check.sh --level work --base c30b5b3424f6d98295b26cac96fe9a8b35a2eb27 --dry-run"),
        ("work", "scripts/check.sh --level work --base c30b5b3424f6d98295b26cac96fe9a8b35a2eb27")]:
        summary = json.loads((tmp / (label+"-summary.json")).read_text())
        assert summary["exit"] == 0
        checks[label] = dict(summary, command=command, output=digest(tmp / (label+".log")))
    work = (tmp / "work.log").read_text()
    assert "7 passed; 0 failed; 0 ignored" in work and "selected checks passed" in work
    assert work.count("== formal_build") == 1
    assert len((tmp / "replay.log").read_text().splitlines()) == 17
    assert all(l.endswith(": true") for l in (tmp / "replay.log").read_text().splitlines())
    assert not re.search(r"error(?:\(|:)", (tmp / "signatures.log").read_text())
    checks["default-build"] = {"exit": 0, "seconds": 2.005783796310425,
        "command": "(cd formal && lake build)", "jobs": 949,
        "seconds_source": "実行時のsubprocessの戻り値で採取",
        "output": digest(tmp / "local-build-4.log")}
    assert "Build completed successfully (949 jobs)." in (tmp / "local-build-4.log").read_text()
    checks["axioms"] = {k: audit[k] for k in ["command", "exit", "seconds", "raw", "targets",
                                            "target_list", "module_count", "axiom_sets", "new_modules", "new_axioms"]}
    assert sum(audit["axiom_sets"].values()) == audit["targets"] == 67881
    assert sum(audit["new_modules"].values()) == 499
    inputs = json.loads((HERE / "inputs.json").read_text())
    manifest = tmp / "formal-sources.json"
    assert digest(manifest) == inputs["formal_manifest"]
    verification = {"checks": checks, "work_entry_executions": 1,
                   "work_selected": ["spec_tally", "spec_examples", "formal_build"],
                   "rust_lean_full_comparison": "未実施（L70/R50の担当）",
                   "official_max_rss": "未取得（取りまとめが段末の同じworkで採取）",
                   "formal_manifest_after_work": digest(manifest),
                   "later_changes": "本番Lean・01-12・07-04・lakefile・既定importはwork後に変更なし。記録のみ更新",
                   "judgment": "担当Codexの自己点検、2026-11-03。独立レビュー・受け入れは未実施"}
    (HERE / "verification.json").write_text(json.dumps(verification, ensure_ascii=False, indent=2)+"\n")
    observed = json.loads((tmp / "times.json").read_text())
    start = json.loads((tmp / "start.json").read_text())["start"]
    finish = time.time()
    intervals = []
    for n in range(67, 73):
        end = observed[".72"]["end"] if n < 72 else (HERE / "r20-contract.md").stat().st_mtime
        intervals.append({"unit": "L30."+str(n), "start": clock(start), "end": clock(end),
                          "seconds": end-start,
                          "note": "Lの共通観測枠。定義・証明・具体読者を共有し個別分離不能。合算しない" +
                            ("。.72の終点は受渡し文書の保存時刻であり、独立に計時した終了ではない" if n == 72 else "")})
    previous = observed[".72"]["end"]
    for n in [74, 75, 76, 77]:
        end = observed["."+str(n)]["end"]
        intervals.append({"unit": "L30."+str(n), "start": clock(previous), "end": clock(end),
                          "seconds": end-previous,
                          "note": observed["."+str(n)]["note"]+"。後から補った記録はNの枠に含む"})
        previous = end
    for n in [78, 80]:
        intervals.append({"unit": "L30."+str(n), "start": clock(observed[".77"]["end"]),
                          "end": clock(finish), "seconds": finish-observed[".77"]["end"],
                          "note": "Nの最終照合・work・受入資料の共通枠。公理監査自体の38.114秒はMの記録と並行して先に実行。合算しない"})
    intervals.append({"unit": "L30.79", "seconds": None, "note": "未実施。レビュー未依頼、受け口のみ準備"})
    intervals.sort(key=lambda row: row["unit"])
    times = {"first_clock": clock(start), "last_record_check": clock(finish),
             "observed_elapsed_seconds": finish-start,
             "unmeasured": "時計取得前の依頼文・レビュー・スキル等の読取り。能動時間と全待ちは分離不能",
             "intervals": intervals}
    (HERE / "times.json").write_text(json.dumps(times, ensure_ascii=False, indent=2)+"\n")
    table = "\n## 最終の検査と生出力の識別\n\n"
    table += "workの入口は指定どおり一回であり、onlyも個別testも指定しなかった。既定の8対象・-M12288を維持する。正式RSSは未取得（取りまとめの採取待ち）。\n\n"
    table += "| 検査 | 終了 | 外側の時間 | 確認した内容 |\n|---|---:|---:|---|\n"
    labels = [("default-build", "既定lake build", "既定8対象・949 jobs、sorryなし"),
              ("replay", "実行による再生", "同じ17行が全てtrue、件数不一致/falseは失敗"),
              ("signatures", "固定署名の照合", "固定8署名の適用、旧5主定理/十移送等36宣言の実型"),
              ("axioms", "段末の公理監査", "688モジュール・67,881宣言、許可三公理だけ"),
              ("dry-run", "workのdry-run", "仕様対応の自己検査/集計・仕様例・既定Leanを選択"),
              ("work", "作業末のwork", "仕様例7成功・失敗/無視0、仕様対応の自己検査/集計、既定Leanとsorry拒否")]
    for key, title, note in labels:
        table += f"| {title} | 0 | {checks[key]['seconds']:.3f}秒 | {note} |\n"
    table += "\nworkの実コマンドは `scripts/check.sh --level work --base c30b5b3424f6d98295b26cac96fe9a8b35a2eb27`。全コマンドと構成はverification.json、全入力はinputs.jsonに保存した。先の成功した既定ビルドはrows_checkedの核内検査を含む。実行再生と核内検査の時間の差からCPU性能の一般則を推論しない。\n\n"
    table += "| 公理の依存集合 | 宣言数 |\n|---|---:|\n"
    for axiom_set, count in audit["axiom_sets"].items():
        table += f"| {axiom_set} | {count:,} |\n"
    table += "\n新しい公理・未承認依存・sorryAxは0。匿名exampleはこの定数の件数には含まれない。監査は `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l30/audit.py --tmp <tmp>` で再生成する。`--inventory-only`は同じ所属モジュールから全名だけを再生成し、監査済みと誤称しない別の要約へ保存する。\n\n"
    table += "| 生出力（全て<tmp>） | bytes | SHA-256 |\n|---|---:|---|\n"
    for key in ["default-build", "replay", "signatures", "dry-run", "work"]:
        d = checks[key]["output"]
        filename = "local-build-4.log" if key == "default-build" else key+".log"
        table += f"| {filename} | {d['bytes']:,} | `{d['sha256']}` |\n"
    for title, d in [("axioms.log", audit["raw"]), ("audit-targets.txt", audit["target_list"]),
                     ("formal-sources.json", inputs["formal_manifest"])]:
        table += f"| {title} | {d['bytes']:,} | `{d['sha256']}` |\n"
    table += "\nソース・設定・写しのSHA-256はwork前後の同じ関係状態を指す。後の更新は結果・受け入れ資料・台本の記録だけで、本番Lean/仕様例/既定import/設定の変更はない。Rust/Lean全比較や実CLIを実施済みとはしない。\n"
    time_table = "\n## 単位ごとの外側の観測枠\n\n"
    time_table += f"最初の時計は{clock(start)}、最後の記録の照合は{clock(finish)}。観測できた全枠は{finish-start:.3f}秒（約{(finish-start)/60:.1f}分）である。時計以前の読取りは未採取。能動時間と待ちは分離不能。重なる枠を合算しない。\n\n"
    time_table += "| 単位 | 観測した外側の時間 | 精度・範囲 |\n|---|---:|---|\n"
    for row in intervals:
        duration = "未実施" if row["seconds"] is None else f"{row['seconds']:.3f}秒"
        time_table += f"| {row['unit']} | {duration} | {row['note']} |\n"
    time_table += "\n開始・終了の観測値と精度はtimes.jsonに残した。.72の終点だけは受渡し文書の保存時刻を使い、独立に計時した終了と区別した。L30.73は詳細どおり独立の作業なし。.79は取りまとめの依頼後、.80の受け入れ自体は設計者の判断後であり、今回の時間へ足していない。\n"
    replace(HERE / "results.md", table+time_table)
    replace(STAGE / "stage-results.md", table+time_table)
    print(json.dumps({"checks": {k: {"exit": v["exit"], "seconds": v["seconds"]} for k,v in checks.items()},
                      "elapsed_seconds": finish-start, "audit_declarations": audit["targets"]}))


if __name__ == "__main__":
    main()
