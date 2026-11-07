# -*- coding: utf-8 -*-
"""各群の results*.md の四分類の表の件数を集める（段末の資料の「四分類の最終件数」の入力）。

1. 四分類の表: 見出しに「四分類」を含む節（又は「証人と四分類」）の表と、見出しによらず表の頭の行に「四分類」を含む
   表の各行で、最初に分類の語（実質・自明・空疎・不成立・保留）で始まる欄を分類とする。同じ群の再開の表は別の節として
   数え、合算しない値も残す。
2. 四分類の表を持たない群: 全ての表の行を調べ、分類の語を欄の中に含む表を「分類の語を含む別の表」として、群・節・表の
   頭・語ごとの行数を記す（数えた件数を四分類の件数に足さない。語が別の意味で使われることがあるため）。
対象は段の全群（u・a〜k2・h・h2・h3・h4）である。記録は --out（既定 ../h3）の four.json。
使い方: python3 four.py [--out <記録>]"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import L70, digest, write

WORDS = ["実質", "自明", "空疎", "不成立", "一部保留", "保留"]
GROUPS = ["u", "a", "b", "c", "d", "d-int", "e", "e2", "e3", "f1", "f2", "g", "g42", "k", "k-int", "k2", "h", "h2", "h3", "h4"]


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


def tables(text):
    """全ての表（節の見出し、表の頭の行、本体の行）。"""
    out, heading, current = [], "", None
    for line in text.splitlines():
        if line.startswith("#"):
            heading = line.strip("# ").strip()
        if line.startswith("|"):
            if re.match(r"^\|[-:| ]+\|$", line):
                continue
            if current is None:
                current = (heading, line, [])
            else:
                current[2].append(line)
        elif current is not None:
            out.append(current)
            current = None
    if current is not None:
        out.append(current)
    return out


def classify(row):
    cells = [c.strip() for c in row.strip().strip("|").split("|")]
    for c in cells[1:]:
        for w in WORDS:
            if c.startswith(w) or c.startswith("**" + w):
                return w
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=L70 / "h3")
    args = parser.parse_args()
    result, totals, mentions, groups = {}, collections.Counter(), {}, {}
    for g in GROUPS:
        found = False
        for path in sorted((L70 / g).glob("results*.md")):
            for title, rows in sections(path.read_text()):
                counts = collections.Counter(c for c in map(classify, rows[1:]) if c)
                if counts:
                    found = True
                    result[f"{g}/{path.name}#{title}"] = dict(counts)
                    totals.update(counts)
        groups[g] = "四分類の表あり" if found else "四分類の表なし"
        if found:
            continue
        for path in sorted((L70 / g).glob("results*.md")):
            for heading, head, rows in tables(path.read_text()):
                counts = collections.Counter(w for r in rows for w in WORDS if w in r and
                                             not (w == "保留" and "一部保留" in r))
                if counts:
                    mentions[f"{g}/{path.name}#{heading}"] = {"head": head.strip()[:200],
                                                              "rows_with_word": dict(counts)}
    args.out.mkdir(parents=True, exist_ok=True)
    write(args.out / "four.json", {"sections": result, "totals": dict(totals), "groups": groups,
                                   "other_tables_with_words": mentions,
                                   "inputs": {"four.py": digest(Path(__file__))}})
    print(json.dumps({"sections": len(result), "totals": dict(totals),
                      "without": [g for g, s in groups.items() if s == "四分類の表なし"],
                      "other_tables": len(mentions)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
