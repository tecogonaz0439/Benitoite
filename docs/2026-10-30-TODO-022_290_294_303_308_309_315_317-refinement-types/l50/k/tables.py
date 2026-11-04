"""一行表を JSON と依存の経路から生成し、Markdown の参照名も集める。"""
from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent
NAME = r"(?<![A-Za-z0-9_.])(?:_private\.Benitoite|Benitoite\.Release\.Refinement)\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*"
REFERENCE_DOCS = ["obligations.md", "handoffs.md", "connections.md", "error-fields.md",
                  "denials.md", "l60-fields.md", "results.md"]


def read(name):
    return json.loads((HERE / name).read_text())


def names(values):
    return "、".join("`" + value + "`" for value in values)


def relation(row, dependencies):
    if not row["readers"]:
        return "関係：" + row["relation_kind"] + "。" + row["relation"]
    edges = dependencies[row["kind"], row["id"]]
    return "読者：" + "、".join(
        "`" + reader + "`（依存する証拠：" + names(edges[reader]) + "）"
        for reader in row["readers"]) + "。"


def rendered():
    dependencies = {(r["kind"], r["id"]): r["dependencies"]
                    for r in read("reader-dependencies.json")["rows"]}
    result = {}
    for kind, filename, count, title in [
            ("obligations", "obligations.md", 33, "義務"),
            ("handoffs", "handoffs.md", 31, "申し送り")]:
        text = f"# 群 K の{count}{title}の照合\n\n"
        text += "各行はL50の担当範囲の判定であり、義務全体の閉鎖は0行である。"
        text += "後段の所有はdetail.md第6・7節を正とする。\n\n"
        text += "読者は型と値の定数の依存の閉包で同じ行の証拠を使う名前付き宣言（定理・定義、privateを含む）である。"
        text += "読者ごとに依存する証拠を示し、他の証拠への依存は含意しない。"
        text += "本番にその読者がない場合は関係の種類と受け口を書く。"
        text += "[抽出台本](reader_dependencies.py)・[依存の経路](reader-dependencies.json)で再現する。\n\n"
        text += "| ID | 分類・判定 | 全称の証拠と読者・関係 | 後段の所有と受け口 |\n|---|---|---|---|\n"
        for row in read("trace.json"):
            if row["kind"] == kind:
                text += (f'| {row["id"]} | {row["classification"]}：{row["status"]} | '
                         f'{row["finding"]} 証拠：{names(row["proofs"])}。'
                         f'{relation(row, dependencies)} | {row["remaining_entry"]} |\n')
        result[filename] = text
    text = "# 7位置・5具体化行・11実行葉の接続\n\n"
    text += "全称の言明を根拠にし、具体例から全入力を推測しない。"
    text += "同じws/req/endpoint/σを保ち、出力の型・効果からrsを逆算しない。\n\n"
    text += "位置・具体化行の読者は型と値の依存の閉包で証拠を使う名前付き宣言（定理・定義、privateを含む）だけを示す。"
    text += "同じ行でも読者が使う証拠は併記した名前に限る。"
    text += "[抽出台本](reader_dependencies.py)・[依存の経路](reader-dependencies.json)で再現する。\n\n"
    for kind, title in [("position", "U1の7位置"), ("instantiation", "D09の5具体化行"), ("leaf", "実行の11葉")]:
        text += "## " + title + "\n\n"
        last = "読者・関係" if kind != "leaf" else "同じ実δ・応答表又は準備・検査（読者の主張ではない）"
        text += f"| 行 | 判定と全称の境界 | 実定理 | {last} |\n|---|---|---|---|\n"
        for row in read("connections.json"):
            if row["kind"] != kind:
                continue
            last_text = relation(row, dependencies) if kind != "leaf" else names(row["readers"])
            text += f'| {row["id"]} | 完了：{row["finding"]} | {names(row["proofs"])} | {last_text} |\n'
        text += "\n"
    old = (HERE / "connections.md").read_text()
    text += old[old.index("## 後段の所有"):]
    result["connections.md"] = text
    return result


def references():
    result = set()
    for filename in ["trace.json", "connections.json", "denials.json"]:
        for row in read(filename):
            result.update(row["proofs"] + row.get("readers", []))
    for filename in REFERENCE_DOCS:
        result.update(re.findall(NAME, (HERE / filename).read_text()))
    return sorted(result)


def main():
    for filename, content in rendered().items():
        (HERE / filename).write_text(content)
    refs = references()
    (HERE / "referenced-names.json").write_text(json.dumps(refs, indent=2) + "\n")
    private = [n for n in refs if n.startswith("_private.")]
    checks = "".join("#check @" + name + "\n" for name in refs if name not in private)
    if private:
        checks += "".join("-- PRIVATE_CHECK " + name + "\n" for name in private)
        # private 名の数値成分を表層構文で解析せず、環境が持つ正確な Name を使う。
        checks += "open Lean Elab Command in\nrun_cmd do\n  let env ← getEnv\n"
        checks += "  for name in " + json.dumps(private) + " do\n"
        checks += "    let some (n, _) := env.constants.toList.find? (fun entry => entry.1.toString == name)\n"
        checks += '      | throwError "PRIVATE_CHECK_MISSING {name}"\n'
        checks += "    elabCommand (← `(#check @$(mkIdent n)))\n"
    (HERE / "contracts.lean").write_text("import Benitoite\nimport Lean\n\n"
        "-- JSON と Markdown の全一行表の参照名を既定環境で照合する。\n"
        + checks)
    print(json.dumps({"references": len(refs)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
