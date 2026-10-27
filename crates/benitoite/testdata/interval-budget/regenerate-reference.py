"""Lean の実行値から予算の固定表を作る（設計書 02-05「区間解析の駆動と予算」）。

リポジトリの根から python3 <このファイル> [--check] [--log-dir <保存先>]。
先に formal/ で lake build を通す。Lean は formal/ の固定版と -M 12288 を使い、
並行実行しない。入力・列・停止コード・選択規則の詳細は同じ場所の README.md。
"""

import argparse
import collections
import pathlib
import json
import os
import tempfile
import subprocess
import time

DIRECTORY = pathlib.Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]


def lean_rows(filename, width, log_dir, declarations):
    source = (DIRECTORY / filename).read_text()
    marker = "-- RANGE_EXCHANGE: regenerate-reference.py が実交換から宣言をここへ渡す。"
    assert source.count(marker) == 1
    # 実交換の同定だけを注入する。ASTの形・期待値・費用はLeanの入力と実行値による。
    with tempfile.NamedTemporaryFile(mode="w", suffix=".lean", dir=ROOT / "target", delete=False) as temp:
        temp.write(source.replace(marker, declarations))
        path = pathlib.Path(temp.name)
    command = ["lake", "env", "lean", "-M", "12288", str(path)]
    started = time.monotonic()
    try:
        result = subprocess.run(command, cwd=ROOT / "formal", capture_output=True, text=True)
    finally:
        path.unlink()
    if log_dir:
        log_dir.mkdir(parents=True, exist_ok=True)
        output = result.stdout + result.stderr
        output = output.replace(str(ROOT), "<repo>").replace(str(pathlib.Path.home()), "<home>")
        (log_dir / (filename + ".log")).write_text(output)
    print(f"{filename}: exit={result.returncode}, seconds={time.monotonic() - started:.3f}")
    if result.returncode:
        raise RuntimeError("\n".join(line for line in (result.stdout + result.stderr).replace(str(ROOT), "<repo>").splitlines() if "\t" not in line))
    rows = [line.split("\t") for line in result.stdout.splitlines()]
    return [row for row in rows if len(row) in width and row[1].isdigit()]


def generate(log_dir, declarations):
    groups = collections.defaultdict(list)
    for row in lean_rows("budget-reference.lean", (11, 14), log_dir, declarations):
        groups[(row[0], row[1])].append(row)
    assert len(groups) == (117 + 19) * 4, len(groups)
    tables = {"body": [], "whole": []}
    for (name, kind), rows in groups.items():
        assert [int(row[2]) for row in rows] == list(range(601 if name.startswith("whole:range") else 201)), (name, kind)
        if name.startswith("whole:"):
            # 走査上端の全列（cap 以外）と同じになる最小上限の一つ後まで。
            complete = next(int(row[2]) for row in rows if row[3:] == rows[-1][3:])
            target = tables["whole"]
        else:
            # 最初に停止しなくなる上限の一つ後まで。
            complete = next(int(row[2]) for row in rows if row[7] == "0")
            target = tables["body"]
        assert complete < int(rows[-1][2]), (name, kind)
        target.extend(rows[:complete + 2])

    summaries = lean_rows("summary-reference.lean", (9,), log_dir, declarations)
    assert len(summaries) == 11 * 4 * 201 + 8 * 4 * 601, len(summaries)
    by_key = {tuple(row[:3]): row for row in summaries}
    assert len(by_key) == len(summaries), "duplicate summary keys"
    tables["summary"] = [by_key[tuple(row[:3])] for row in tables["whole"]]
    return tables


def range_declarations(export_dir, log_dir):
    if export_dir is None:
        # 書き出しを別の実行と共有しない。Cargo終了後にのみLeanへ進む。
        with tempfile.TemporaryDirectory(prefix="interval-budget-", dir=ROOT / "target") as temp:
            env = dict(os.environ, BENITOITE_DESUGAR_DIFF_DIR=temp)
            command = ["cargo", "test", "-p", "benitoite", "--test", "desugar_export",
                       "interval::export_interval_range", "--", "--exact", "--nocapture"]
            result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True)
            if log_dir:
                log_dir.mkdir(parents=True, exist_ok=True)
                output = (result.stdout + result.stderr).replace(str(ROOT), "<repo>").replace(str(pathlib.Path.home()), "<home>")
                (log_dir / "range-export.log").write_text(output)
            if result.returncode:
                raise RuntimeError("Rangeの実交換に失敗: " + result.stdout + result.stderr)
            return range_declarations(pathlib.Path(temp), log_dir)
    payload = json.loads((export_dir / "range-bindings.json").read_text())
    assert payload["version"] == 1
    entry = next(i for i in payload["inputs"] if i["name"] == "rangeCall")
    names = entry["rangeNames"]
    # 構成子が保存した宣言にあることを確認する。表示名から補わない。
    data = {d["name"]: d for d in entry["declarations"]}
    for owner, keys in [("owner", ["checkedConstructor"]), ("result", ["ok", "err"]),
                        ("error", ["invalidBounds", "outOfRange"])]:
        constructors = {c["name"] for c in data[names[owner]]["ctors"]}
        assert all(names[key] in constructors for key in keys)
    if log_dir:
        log_dir.mkdir(parents=True, exist_ok=True)
        (log_dir / "range-bindings.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    quoted = lambda value: json.dumps(value, ensure_ascii=False)
    fields = [names[key] for key in ["owner", "checkedConstructor", "result", "error", "ok", "err", "invalidBounds", "outOfRange"]]
    return ("private def referenceRangeNames : RangeNames := ⟨" + ", ".join(map(quoted, fields)) + "⟩\n"
            + "private def referenceRangeCheck : String := " + quoted(entry["checkDeclaration"]) + "\n"
            + "private def referenceRangeValue : String := " + quoted(entry["valueDeclaration"]) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="再生成値を保存済みの三表と照合する")
    parser.add_argument("--log-dir", type=pathlib.Path, help="Lean の出力を保存する場所")
    parser.add_argument("--range-export", type=pathlib.Path, help="直前にexport_interval_rangeで書き出した入力（省略時は専用の出力先へ書き出す）")
    args = parser.parse_args()
    (ROOT / "target").mkdir(exist_ok=True)
    declarations = range_declarations(args.range_export, args.log_dir)
    for name, rows in generate(args.log_dir, declarations).items():
        source = "summary-reference.lean" if name == "summary" else "budget-reference.lean"
        header = ("# 設計書 02-05「区間解析の駆動と予算」「区間解析の報告の集計」; "
                  f"Lean testdata/interval-budget/{source}; "
                  "regenerate-reference.py; independent expectations\n")
        output = header + "\n".join("\t".join(row) for row in rows) + "\n"
        path = DIRECTORY / (name + ".tsv")
        if args.check:
            assert path.read_text() == output, f"再生成値と不一致: {path.name}"
        else:
            path.write_text(output)
        print(f"{name}: {len(rows)} cases")


if __name__ == "__main__":
    main()
