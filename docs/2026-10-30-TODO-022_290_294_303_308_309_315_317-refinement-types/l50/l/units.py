"""単位の境界を記録する。時刻を指定した場合は根拠をresultsへ別記する。"""
from datetime import datetime, timezone, timedelta
import argparse
import re
from inventory import HERE

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("finished")
ap.add_argument("following", nargs="?")
ap.add_argument("--time")
args = ap.parse_args()
now = args.time or datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
path = HERE / "results.md"
text = path.read_text()
text, count = re.subn(r"(\| " + re.escape(args.finished) + r" \| [^|]+ \|) 未終了 \|[^\n]+",
                     r"\g<1> " + now + " | 担当分完了（独立レビュー・受け入れは別） |", text)
assert count == 1
if args.following:
    text, count = re.subn(r"\| " + re.escape(args.following) + r" \| 未開始 \| 未終了 \|[^\n]+",
                         "| " + args.following + " | " + now + " | 未終了 | 実施中 |", text)
    assert count == 1
path.write_text(text)
print(now)
