"""単位を始める/終える時点で時刻とresultsの表を更新する。"""
from datetime import datetime
from pathlib import Path
import json
import sys

here = Path(__file__).resolve().parent
times = json.loads((here / "times.json").read_text())
unit, event = sys.argv[1:3]
now = datetime.now().astimezone().isoformat(timespec="seconds")
assert event not in times.setdefault(unit, {}), (unit, event)
times[unit][event] = now
(here / "times.json").write_text(json.dumps(times, indent=2) + "\n")
file = here / "results.md"
text = file.read_text()
start = text.index("| 単位 |")
end = text.index("\n\n", start)
rows = ["| 単位 | 開始（JST） | 終了（JST） | 判定 |", "|---|---|---|---|"]
for name, values in times.items():
    rows.append(f"| {name} | {values['start']} | {values.get('end', '実施中')} | "
                + ("終了。担当分の判定は本文参照" if 'end' in values else "実施中") + " |")
file.write_text(text[:start] + "\n".join(rows) + text[end:])
print(now, unit, event)
