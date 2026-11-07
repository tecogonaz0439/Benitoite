# -*- coding: utf-8 -*-
"""各群の results.md の四分類の表の件数を集める（L70.47 (d) の「四分類の最終件数」の入力）。

見出しに「四分類」を含む節（又は「証人と四分類」）の表の各行で、最初に分類の語（実質・自明・空疎・不成立・保留）で
始まる欄を分類とする。同じ群の再開の表は別の節として数え、合算しない値も残す。記録は four.json。
使い方: python3 four.py"""
import collections
import json
from pathlib import Path
import re
from support import HERE, L70, digest, write

WORDS = ["実質", "自明", "空疎", "不成立", "一部保留", "保留"]
GROUPS = ["u", "a", "b", "c", "d", "d-int", "e", "e2", "e3", "f1", "f2", "g", "g42", "k", "k-int", "k2"]


def sections(text):
    """見出しに「四分類」を含む節の表と、見出しによらず表の頭の行に「四分類」を含む表。"""
    out, current, title, heading = [], None, None, ""
    for line in text.splitlines():
        if line.startswith("#"):
            if current is not None:
                out.append((title, current))
            heading = line.strip("# ").strip()
            current, title = ([], heading) if "四分類" in line else (None, None)
        elif line.startswith("|") and not re.match(r"^\|[-| ]+\|$", line):
            if current is None and "四分類" in line:
                current, title = [], heading + "（表）"
            if current is not None:
                current.append(line)
        elif current is not None and title.endswith("（表）") and not line.startswith("|"):
            out.append((title, current))
            current, title = None, None
    if current is not None:
        out.append((title, current))
    return out


def classify(row):
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    for c in cells[1:]:
        for w in WORDS:
            if c.startswith(w) or c.startswith("**" + w):
                return w
    return None


result, totals = {}, collections.Counter()
for g in GROUPS:
    for path in sorted((L70 / g).glob("results*.md")):
        for title, rows in sections(path.read_text()):
            counts = collections.Counter(c for c in map(classify, rows[1:]) if c)
            if counts:
                result[f"{g}/{path.name}#{title}"] = dict(counts)
                totals.update(counts)
write(HERE / "four.json", {"sections": result, "totals": dict(totals),
                          "inputs": {"four.py": digest(Path(__file__))}})
print(json.dumps({"sections": len(result), "totals": dict(totals)}, ensure_ascii=False))
