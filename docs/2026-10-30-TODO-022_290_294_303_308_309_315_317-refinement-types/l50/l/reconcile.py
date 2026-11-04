"""33義務・31申し送り・75欄・13APIを現行の実名と依存へ一行ずつ照合する。"""
from pathlib import Path
import argparse
import collections
import importlib.util
import json
import re
import sys
from inventory import HERE, STAGE, CHANGE, ROOT, PREFIX, digest, write

sys.dont_write_bytecode = True


def short(name):
    return name.removeprefix(PREFIX)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    args = ap.parse_args()
    sigs = json.loads((args.tmp / "stage-signatures.json").read_text())
    actual = {n: {"source": "formal/" + m.replace(".", "/") + ".lean", "line": int(l),
                  "type_sha256": __import__("hashlib").sha256(t.strip().encode()).hexdigest()}
              for m, n, l, t in sigs}
    coverage = json.loads((HERE / "coverage-judgments.json").read_text())
    assert len(coverage["group_reviews"]) == 11
    for source in coverage["group_reviews"]:
        assert (HERE / source["file"]).is_file() and source["section"]
    judgments = {(r["kind"], r["id"]): r for r in coverage["rows"]}
    assert len(judgments) == len(coverage["rows"]) == 64
    for r in judgments.values():
        assert isinstance(r["l50_independent_unresolved"], list)
        assert r["quantification_source"]["id"] == r["id"]
        assert "group_review_sources" in r
        for source in [r["quantification_source"], r["independent_review"]] + r["group_review_sources"]:
            assert (HERE / source["file"]).is_file()
    unresolved = sum(len(r["l50_independent_unresolved"]) for r in judgments.values())
    trace = json.loads((STAGE / "k/trace.json").read_text())
    connections = json.loads((STAGE / "k/connections.json").read_text())
    expected = {}
    detail = (STAGE / "detail.md").read_text()
    for label, body in [("obligations", detail.split("## 6.", 1)[1].split("## 7.", 1)[0]),
                        ("handoffs", detail.split("## 7.", 1)[1].split("## 8.", 1)[0])]:
        pattern = r"^\| (O\d{3})[・ ]" if label == "obligations" else r"^\| (H\d{2}) \|"
        expected[label] = re.findall(pattern, body, re.M)
    assert len(expected["obligations"]) == 33 and len(expected["handoffs"]) == 31
    assert len(trace) == 64
    for kind, ids in expected.items():
        assert [r["id"] for r in trace if r["kind"] == kind] == ids
    # 群Kの再現台本を読み取り専用で用い、型と値の全定数から依存を再抽出する。
    spec = importlib.util.spec_from_file_location("prior_readers", STAGE / "k/reader_dependencies.py")
    readers = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(readers)
    graph_rows, source = readers.collect(args.tmp)
    saved = json.loads((STAGE / "k/reader-dependencies.json").read_text())
    assert graph_rows == saved["rows"] and source == saved["source"]
    indexed = {(r["kind"], r["id"]): r["dependencies"] for r in graph_rows}
    relations = collections.Counter()
    partial = 0
    for row in trace + connections:
        for n in row.get("proofs", []) + row.get("readers", []):
            assert n in actual, (row["id"], n)
        if "reader_candidates" in row:
            hits = indexed[row["kind"], row["id"]]
            assert list(hits) == row["readers"]
        if row in trace:
            relations[row["relation_kind"]] += 1
            used = {n for ds in indexed[row["kind"], row["id"]].values() for n in ds}
            if used and used != set(row["proofs"]):
                partial += 1
            row["actual_evidence"] = {n: actual[n] for n in row["proofs"] + row["readers"]}
            judgment = judgments[row["kind"], row["id"]]
            assert judgment["trace_status"] == row["status"] and judgment["finding"] == row["finding"]
            row["quantification_judgment"] = judgment
            row["mechanical_checks"] = ["名前の実在・所在", "実型のSHA-256", "読者の型と値の依存の一致"]
            row["stage_status"] = "機械照合済み。量化範囲と担当分の判断はcoverage-judgmentsの出典。全体は未閉鎖"
            if row["id"] == "O016":
                row["stage_status"] = "既定Benitoiteのimport閉包の監査完了。RV-L50.lとL50.59処置済み、受け入れ待ち"
            elif row["id"] == "O027":
                row["stage_status"] = "固定メモリ設定を使用。正式RSSはレビュー後の取りまとめへ"
            elif row["id"] == "O084":
                row["stage_status"] = "各群末レビューとtraceの判断を別に集計。段末受け入れは未実施"
            elif row["id"] == "O118":
                row["stage_status"] = "写し・コメント・全既定importを照合。後段の全読者は未実施"
    assert relations == {"依存する読者あり": 49, "証拠そのものが入口": 8,
                         "同じ前提を共有するだけ": 4, "記録・監査の関係": 3}
    assert partial == 33, partial
    # 照合結果は完全名・所在付きで分割し、段末本文には一行ずつの証拠と残りを置く。
    from audit import pages
    trace_parts = pages("trace", trace)
    conditions = json.loads((STAGE / "j/conditions.json").read_text())
    assert len(conditions) == 75
    assert collections.Counter(r["model"] for r in conditions) == {
        "Model.builtins": 25, "ModelTargets.builtins": 25, "ModelHttp.builtins": 25}
    expected_fields = ["sat_rename", "admits_rename", "sat_values", "admits_values",
        "sat_renameTypes", "admits_renameTypes", "sat_subst", "admits_subst",
        "delta_typed", "io_typed", "io_kind", "io_exists", "sig_scoped",
        "sat_unconstrained", "admits_sat", "pathBases_shape", "io_op", "opEff_io",
        "effect_ops", "state_effect", "ref_get", "ref_set", "store_shape", "store_admits", "io_target"]
    for model in ["Model.builtins", "ModelTargets.builtins", "ModelHttp.builtins"]:
        assert [r["field"] for r in conditions if r["model"] == model] == expected_fields
    contracts = (STAGE / "j/contracts.lean").read_text()
    assert all(re.search(r"theorem\s+" + re.escape(r["contract"].split(".")[-1]) + r"\b", contracts)
               for r in conditions)
    for row in conditions:
        assert row["status"] == "proved"
        model = row["model"].split(".")[0]
        for name in [model + ".scopeConditions"]:
            assert PREFIX + name in actual, name
    pure = [("Scope.checkPathIn", "ScopeDelta.response", "ScopeDelta.delta"),
        ("Http.checkRequestIn", "RequestDelta.response", "RequestDelta.delta"),
        ("Scope.pathInValue", "ScopeDelta.pathInValue_response", "ScopeDelta.valueDelta"),
        ("Http.requestInValue", "RequestDelta.requestInValue_response", "RequestDelta.valueDelta"),
        ("Scope.widenPathIn", "ScopeDelta.widenPathIn_response", "ScopeDelta.valueDelta"),
        ("Http.widenRequestIn", "RequestDelta.widenRequestIn_response", "RequestDelta.valueDelta")]
    io = ["readTextIn", "readBytesIn", "writeTextIn", "writeBytesIn", "appendTextIn", "appendBytesIn", "sendIn"]
    apis = []
    for name, proof, delta in pure:
        apis.append({"name": name, "kind": "pure", "proof": PREFIX + proof, "delta": PREFIX + delta,
                     "all_responses": PREFIX + "ScopeResponse.outcome_typed",
                     "exists": PREFIX + "ScopeResponse.delta_typed", "reader": PREFIX + "ScopedTargetInputs.pure_steps"})
    for name in io:
        apis.append({"name": ("Http." if name == "sendIn" else "File.") + name, "kind": "io",
            "proof": PREFIX + "ScopedIOResponse." + name, "delta": PREFIX + "ScopedIOResponse.ioResponse",
            "all_responses": PREFIX + "ScopedIOResponse.io_typed", "exists": PREFIX + "ScopedIOResponse.io_exists",
            "reader": PREFIX + "ScopedTargetInputs.io_steps"})
    assert len(apis) == len({r["name"] for r in apis}) == 13
    for row in apis:
        for key in ["proof", "delta", "all_responses", "exists", "reader"]:
            assert row[key] in actual, row[key]
        row["status"] = "全入力の型・適格性・非exitと応答存在を別に照合"
        row["normal_success_exists"] = "要求しない"
    write(HERE / "apis.json", apis)
    text = "# 段末の十三 API の照合\n\n完全名の先頭は Benitoite.Release.Refinement である。" \
        "純粋六行は同じ決定的δ、IO七行は同じ関係の全応答と存在を区別する。\n\n" \
        "| API | 全型付き入力の入口 | 実δ又は応答関係 | 全応答の充足 | 応答存在 | 読者 |\n|---|---|---|---|---|---|\n"
    for r in apis:
        text += "| " + " | ".join([r["name"]] + ["`" + short(r[k]) + "`" for k in
                   ["proof", "delta", "all_responses", "exists", "reader"]]) + " |\n"
    text += "\n各行の範囲変数は一度具体化した入力である。正常成功の存在と実IOの成功を保証しない。" \
        "原署名・valKind/valContent・対象位置は [群Eの全16署名](../e/signatures.md)、実際の完全型は段末のsignatures-partへ対応する。\n"
    (HERE / "apis.md").write_text(text)
    summary = {"obligations": 33, "handoffs": 31,
        "obligation_classes": dict(collections.Counter(r["classification"] for r in trace if r["kind"] == "obligations")),
        "handoff_classes": dict(collections.Counter(r["classification"] for r in trace if r["kind"] == "handoffs")),
        "relations": dict(relations), "partially_read_rows": partial,
        "reader_graph": source, "trace_parts": trace_parts, "conditions": 75, "l60_remaining_fields": 12,
        "apis": 13, "technical_independent_unresolved": {
            "count": unresolved, "basis": "各群末の独立レビューと群Kのtraceの判断の集計。機械照合による量化の判定ではない",
            "source": {"file": "coverage-judgments.json", **digest(HERE / "coverage-judgments.json")}},
        "mechanical_scope": ["名前の実在・所在", "実型のSHA-256", "読者の型と値の依存の一致"],
        "whole_obligations_closed": 0,
        "stage_review": "RV-L50.l再確認を受け、再開2で軽1を指摘の三箇所へ限定。取りまとめの再確認待ち", "stage_acceptance": "設計者が判定する"}
    write(HERE / "reconciliation.json", summary)
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
