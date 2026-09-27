#!/usr/bin/env python3
"""測定記録（run.py が書く Markdown）から、グラフ付きの HTML のページを作る。

使い方: python3 tools/bench/report_html.py <results/YYYY-MM-DD-<コミット>.md>
同じ名前の .html を同じディレクトリに書く（既存のファイルは上書きする）。
ページは一つの測定記録だけを示す。別の記録との比較（最適化の前後など）は示さない。
run.py は測定記録を書いた後にこのスクリプトを呼ぶ。Python 3 の標準ライブラリだけで動く。
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BENCH = Path(__file__).resolve().parent
TEMPLATE = BENCH / "report_template.html"


def section(text: str, heading: str) -> str:
    start = text.find("## " + heading)
    if start < 0:
        return ""
    end = text.find("\n## ", start + 3)
    return text[start : end if end > 0 else None]


def table_rows(block: str) -> list[list[str]]:
    rows = []
    for line in block.splitlines():
        if not line.startswith("|") or line.startswith("|---") or set(line) <= set("|-: "):
            continue
        rows.append([cell.strip() for cell in line.strip().strip("|").split("|")])
    return rows[1:]  # 見出しの行を除く


def number(value: str) -> float | None:
    try:
        return float(value.replace(",", ""))
    except ValueError:
        return None


def parse_record(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    title = re.search(r"^# 性能測定 (\S+) / (\S+)", text, re.MULTILINE)
    date, revision = (title.group(1), title.group(2)) if title else ("", "")

    environment = []
    for line in section(text, "環境").splitlines():
        match = re.match(r"^- ([^:]+): (.+)$", line)
        if match:
            environment.append([match.group(1), match.group(2)])

    versions = [{"rt": row[0], "version": row[1]} for row in table_rows(section(text, "処理系")) if len(row) >= 2]

    inputs = {}
    for row in table_rows(section(text, "入力の大きさ")):
        if len(row) >= 2:
            inputs[row[0]] = row[1]

    time = []
    for row in table_rows(section(text, "実行時間")):
        if len(row) >= 4 and (sec := number(row[3])) is not None:
            time.append({"bench": row[0], "rt": row[1], "mode": row[2], "sec": sec})

    mem = []
    for row in table_rows(section(text, "最大常駐メモリ")):
        if len(row) >= 4 and (value := number(row[3])) is not None:
            mem.append({"bench": row[0], "rt": row[1], "mode": row[2], "bytes": int(value)})

    startup = []
    for row in table_rows(section(text, "起動時間と検査時間")):
        if len(row) >= 2 and (sec := number(row[1])) is not None:
            startup.append({"rt": row[0], "sec": sec})

    return {
        "meta": {"date": date, "revision": revision, "environment": environment, "source": path.name},
        "versions": versions,
        "inputs": inputs,
        "time": time,
        "mem": mem,
        "startup": startup,
    }


def render(record: Path) -> Path:
    data = parse_record(record)
    if not data["time"]:
        raise ValueError(f"{record}: 実行時間の表を読めない")
    page = TEMPLATE.read_text(encoding="utf-8")
    page = page.replace("__LABEL__", f"{data['meta']['date']} {data['meta']['revision']}")
    # </script> を含む値でページが壊れないように、< を JSON のエスケープで書く。
    page = page.replace("__DATA__", json.dumps(data, ensure_ascii=False).replace("<", "\\u003c"))
    output = record.with_suffix(".html")
    output.write_text(page, encoding="utf-8")
    return output


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    output = render(Path(sys.argv[1]))
    print(f"HTML: {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
