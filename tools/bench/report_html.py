#!/usr/bin/env python3
"""測定記録（run.py が書く Markdown）から、グラフ付きの HTML のページを作る。

使い方: python3 tools/bench/report_html.py <results/YYYY-MM-DD-<コミット>.md>
同じ名前の .html を同じディレクトリに書く（既存のファイルは上書きする）。
ページは一つの測定記録だけを示す。別の記録との比較（最適化の前後など）は示さない。
run.py は測定記録を書いた後にこのスクリプトを呼ぶ。Python 3 の標準ライブラリだけで動く。
"""

from __future__ import annotations

import json
import html
import re
import sys
from pathlib import Path

BENCH = Path(__file__).resolve().parent
TEMPLATE = BENCH / "report_template.html"
METRIC_COLUMNS = {
    "HTTP の要求の処理の量と待ち時間": (("要求/秒", (5,)), ("応答時間 (ms)", (6, 7)), ("実行 (秒)", (8,))),
    "回収の費用": (("停止の時間 (ms)", (2, 3, 4, 5, 6)), ("メモリ (bytes)", (9, 10))),
    "並行処理でのメモリ": (("最大 RSS (bytes)", (3,)), ("一つあたりの近似 (bytes)", (5,))),
    "呼び出しの回数の予算": (("実行 (秒)", (3,)),),
    "リストの添字の時間": (("一回あたりの近似 (ns)", (4,)),),
    "起動と検査の内訳": (("段別の時間 (秒)", (1, 2, 3, 4, 5)), ("検査の内訳の近似 (秒)", (6, 7))),
}


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
        "kind": next((line.split(": ", 1)[1] for line in text.splitlines() if line.startswith("- 記録の種類: ")), "本測定"),
        "metrics": {heading: section(text, heading) for heading in METRIC_COLUMNS if section(text, heading)},
        "settings": section(text, "初回リリース版の設定"),
    }


def metric_chart(title: str, headers: list[str], rows: list[list[str]], columns: tuple[int, ...]) -> str:
    values = [(f"{row[0]} / {headers[column]}", value)
              for row in rows for column in columns
              if column < len(row) and (value := number(row[column])) is not None]
    if not values:
        return ""
    low = min(0, min(value for _, value in values))
    high = max(0, max(value for _, value in values))
    span = high - low or 1
    left, width = 260, 400
    zero = left + (-low / span) * width
    height = 40 + 24 * len(values)
    parts = [f'<div class="chart"><h3>{html.escape(title)}</h3><svg viewBox="0 0 850 {height}" role="img" aria-label="{html.escape(title, quote=True)}">',
             f'<line x1="{zero}" x2="{zero}" y1="8" y2="{height - 24}" class="gl"/>']
    for index, (label, value) in enumerate(values):
        y = 10 + index * 24
        endpoint = left + (value - low) / span * width
        parts.extend([f'<text x="250" y="{y + 14}" text-anchor="end">{html.escape(label)}</text>',
                      f'<rect x="{min(zero, endpoint)}" y="{y}" width="{abs(endpoint - zero)}" height="18" fill="var(--gem)"/>',
                      f'<text x="680" y="{y + 14}" class="val">{value:g}</text>'])
    parts.append(f'<text x="{left}" y="{height - 5}" class="axis">{low:g}</text><text x="{left + width}" y="{height - 5}" class="axis" text-anchor="end">{high:g}</text></svg></div>')
    return "".join(parts)


def render_metrics(data: dict) -> str:
    sections = []
    if data["settings"]:
        settings = "\n".join(line for line in data["settings"].splitlines() if line.startswith("- "))
        sections.append(f'<section><h2>初回リリース版の設定</h2><pre style="white-space:pre-wrap">{html.escape(settings)}</pre></section>')
    for heading, block in data["metrics"].items():
        rows = table_rows(block)
        header_line = next((line for line in block.splitlines() if line.startswith("|")), "")
        headers = [cell.strip() for cell in header_line.strip("| ").split("|")]
        note = " ".join(line for line in block.splitlines() if line and not line.startswith(("#", "|")))
        charts = "".join(metric_chart(title, headers, rows, columns) for title, columns in METRIC_COLUMNS[heading])
        table = "<thead><tr>" + "".join(f"<th>{html.escape(cell)}</th>" for cell in headers) + "</tr></thead><tbody>"
        table += "".join("<tr>" + "".join(f"<td>{html.escape(cell)}</td>" for cell in row) + "</tr>" for row in rows) + "</tbody>"
        sections.append(f'<section><h2>{html.escape(heading)}</h2><p>{html.escape(note)}</p><div class="grid-charts">{charts}</div><div class="scroll"><table>{table}</table></div></section>')
    return "\n".join(sections)


def render(record: Path) -> Path:
    data = parse_record(record)
    if not data["time"]:
        raise ValueError(f"{record}: 実行時間の表を読めない")
    page = TEMPLATE.read_text(encoding="utf-8")
    page = page.replace("__LABEL__", f"{data['meta']['date']} {data['meta']['revision']}")
    page = page.replace('const BENCHES = ["fib", "loop", "list", "tree", "eval", "string", "println", "lines"].filter(b => DATA.time.some(x => x.bench === b));',
                        'const BENCHES = [...new Set(DATA.time.map(x => x.bench))];')
    page = page.replace('if (cp) { const f = BENCHES.filter(b => t(b, "Benitoite") < t(b, cp));',
                        'const comparable = cp ? BENCHES.filter(b => t(b, cp) != null) : []; if (cp) { const f = comparable.filter(b => t(b, "Benitoite") < t(b, cp));')
    page = page.replace('f.length + " / " + BENCHES.length', 'f.length + " / " + comparable.length')
    page = page.replace('const ratios = BENCHES.map(', 'const ratios = BENCHES.filter(b => RUNTIMES.some(rt => t(b, rt) != null)).map(')
    page = page.replace('const worst = ratios.reduce(', 'if (ratios.length) { const worst = ratios.reduce(')
    page = page.replace('（" + worst.b + "）" });', '（" + worst.b + "）" }); }')
    # 古い記録はそのまま描き、C16 の動作確認とデータ構造の違いは今回の記録だけに示す。
    if data["metrics"]:
        page = page.replace('</div>\n<div id="tip" hidden></div>', render_metrics(data) + '</div>\n<div id="tip" hidden></div>')
        page = page.replace("Benitoite の list は連結リストで", "Benitoite の list は永続ベクタで")
    if data["kind"] != "本測定":
        page = page.replace('<div class="wrap">', '<div class="wrap"><p class="note">' + html.escape(data["kind"]) + '</p>')
        page = page.replace("10 回", "1 回").replace("約 1 万行", "100 関数")
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
