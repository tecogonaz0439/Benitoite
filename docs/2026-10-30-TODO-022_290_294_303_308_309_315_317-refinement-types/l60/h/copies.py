# -*- coding: utf-8 -*-
"""01-12・07-04 の写しを、段の全体（段の開始版からの追加）で本番と照合する。

1. 段で追加した写しの文の `…` の名前を、既定環境の宣言・モジュールへ解決する。解決できない名前は0とする。
2. 段で足した37モジュールが 07-04 の形式化のモジュールの表の行に現れることを確かめる。
3. 段で消した宣言の名前が写しに残っていないことを確かめる。
4. 写しが述べる件数を、既定環境の構成子の数と前の群の照合の記録で確かめる。
使い方: python3 copies.py --log <graph.lean の出力> [--verify]"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import DESIGN, HERE, L60, L60_BASE, NEW, EDITED, PREFIX, ROOT, git, module_path, show, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--log", type=Path, required=True)
parser.add_argument("--verify", action="store_true")
args = parser.parse_args()

nodes = {}
for line in args.log.read_text().splitlines():
    i = line.find("NODE ")
    if i >= 0:
        name, mod, kind, _, _, _ = json.loads(line[i + 5:])
        nodes[name] = (mod, kind)
suffix = collections.defaultdict(list)
for name in nodes:
    parts = name.split(".")
    for k in range(1, len(parts)):
        suffix[".".join(parts[k:])].append(name)
modules = {str(p.relative_to(ROOT / "formal"))[:-5].replace("/", ".") for p in (ROOT / "formal").rglob("*.lean")
           if ".lake" not in p.parts}
short_modules = {m.split(".")[-1] for m in modules}


def added_text(rel):
    """段の開始版から作業木までの追加の行（読み取りだけのgitの照会）。"""
    diff = git("diff", "-U0", L60_BASE, "--", rel)
    return [l[1:] for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]


def expand(token):
    """`A.b/c` は `A.b`・`A.c`、`StandardModelX/Y` は `StandardModelX`・`StandardModelY` に分ける。"""
    head, *rest = token.split("/")
    out = [head]
    for alt in rest:
        if "." in head:
            out.append(head.rsplit(".", 1)[0] + "." + alt)
        else:
            prefix = next((head[:k] for k in range(len(head), 0, -1) if head[:k] + alt in short_modules), "")
            out.append(prefix + alt)
    return out


# 写しが名指す Lean の既定環境の外の名前と、その所在。
OUTSIDE = {"@external": "表層の構文（外部宣言の注釈）", "json.rs": "処理系のソース（src/builtins の JSON 変換）",
           "Json.Value": "標準ライブラリの公開型（処理系の値）", "surfaceCheckAll": "formal/SurfaceCheck（既定importの外の検査の道具）",
           "ExternalRefinement": "実行時の誤りの理由の文字列（Step.external_reject の行先の error の列）",
           "convert": "処理系のソース（json.rs の関数）", "type": "表層の構文（右辺のない型の宣言）",
           "args": "写しの式の変数（`.external id args` の引数列）"}


def classify(token):
    if re.search(r"[\s()\[\]<>=:,+*%→∀∃'\"]", token) or token.startswith("."):
        # 式は先頭の名前を解決する。構成子の省略形（`.x`）・数・角括弧で始まる式は先頭の名前を持たない。
        head = re.match(r"[A-Za-z][\w.]*", token)
        if head is None:
            return "式", []
        kind, found = classify(head[0])
        assert kind != "未解決", (token, head[0])
        return "式", found[:1]
    if token in OUTSIDE:
        return "Leanの既定環境の外", [OUTSIDE[token]]
    if re.fullmatch(r"[A-Za-z]{1,2}\.[\w.]+", token) and token.split(".", 1)[1] in suffix:
        # `B.valKind`・`P.WellFormed` のような変数の欄。欄の名前が宣言の末尾にあることを確かめる。
        return "変数の欄", sorted(suffix[token.split(".", 1)[1]])[:1]
    if token in short_modules or token in modules:
        return "モジュール", [token]
    if token.startswith("Benitoite.") and token in nodes:
        return "宣言", [token]
    if PREFIX + token in nodes:
        return "宣言", [PREFIX + token]
    found = sorted(n for n in suffix.get(token, []) if n.startswith("Benitoite."))
    if found:
        # 名前空間の内で解決した名前は、Refinement の候補を持つか、既定環境の外の名前の表にある。
        assert any(n.startswith(PREFIX) for n in found) or token in {"recordFields"}, (token, found[:3])
        return "宣言（名前空間の内）", sorted(found, key=lambda n: (not n.startswith(PREFIX), n))
    spaces = sorted({n for n in nodes if n.startswith(PREFIX + token + ".")})
    if spaces:
        return "名前空間", [PREFIX + token]
    return "未解決", []


tokens, rows = collections.Counter(), []
for rel in DESIGN:
    for line in added_text(rel):
        for span in re.findall(r"`([^`]+)`", line):
            for token in (expand(span) if re.fullmatch(r"[\w.%/]+", span) else [span]):
                tokens[(rel, token)] += 1
for (rel, token), count in sorted(tokens.items()):
    kind, found = classify(token)
    rows.append({"file": rel.split("/")[-1], "token": token, "count": count, "class": kind,
                 "resolved": found[:3], "candidates": len(found)})
unresolved = [r for r in rows if r["class"] == "未解決"]

# 2. 07-04 の形式化のモジュールの表（行頭の「|」）に、段で足した全モジュールが現れる。
table = [l for l in (ROOT / DESIGN[1]).read_text().splitlines() if l.startswith("| ")]
missing_modules = [m for m in NEW if not any(re.search(r"(?<![\w])" + m.split(".")[-1] + r"(?![\w])",
                                                         l.split("|")[1]) for l in table)]

# 3. 段で変えた既存のモジュールから消した宣言の名前は写しに残らない。
def declared(text):
    stack, names = [], set()
    for line in text.split("\n"):
        m = re.match(r"^namespace ([\w.]+)$", line)
        if m:
            stack.append(m[1])
        elif re.match(r"^end [\w.]+$", line) and stack:
            stack.pop()
        else:
            m = re.match(r"^(?:private )?(?:theorem|def|abbrev|structure|inductive|noncomputable def) ([A-Za-z][\w.]*)", line)
            if m:
                names.add(".".join(stack[-1:] + [m[1]]))
    return names


removed = []
for module in EDITED:
    rel = str(module_path(module).relative_to(ROOT))
    before, after = declared(show(L60_BASE, rel)), declared(module_path(module).read_text())
    removed.extend(sorted(before - after))
design = "".join((ROOT / rel).read_text() for rel in DESIGN)
cited_removed = [n for n in removed if re.search(r"`[^`]*(?<![\w])" + re.escape(n.split(".")[-1]) + r"(?![\w])[^`]*`", design)
                 and n.split(".")[-1] not in {"P"}]

# 4. 写しが述べる件数。
def constructors(owner):
    return sorted(n for n, (m, k) in nodes.items() if k == "constructor" and n.rsplit(".", 1)[0] == PREFIX + owner)


judgments = ["HasTypeVQ", "HasTypeVsQ", "HasTypeEachQ", "HasTypeCQ", "HasTypeTelArgsQ", "TelBodyTy", "CaptureOk",
             "DependentClosureTy", "CheckedWitness", "AtCallAdmissible", "HasTypeArmsQ", "HasTypeClausesQ",
             "HasFailureClause", "ImageOk"]
b = json.loads((L60 / "b/verification.json").read_text())
f1 = json.loads((L60 / "f1/verification.json").read_text())
g = json.loads((L60 / "g/verification.json").read_text())
counts = {
    "十四判断・七十六枝": [len(judgments), sum(len(constructors(j)) for j in judgments)],
    "of_fields（十四判断）": sum(PREFIX + j + ".of_fields" in nodes for j in judgments),
    "carrierの十二構成子": sum(len(constructors(c)) for c in ["ExternalCarrier", "ExternalCarrierEach",
                                                            "ExternalCarrierFields"]),
    "Tyの21構成子": len(constructors("Ty")),
    "二十九変換": b["transforms"],
    "合成表の組込みの行377": len(constructors("StandardModel.Primitive")),
    "合成表の本体130": len(constructors("StandardModel.Body")),
    "入力の定理（79・7・10）": [g["collection_inputs"], g["scope_inputs"], g["io_inputs"]],
}
assert counts["十四判断・七十六枝"] == [14, 76] and counts["of_fields（十四判断）"] == 14, counts
assert counts["carrierの十二構成子"] == 12 and counts["Tyの21構成子"] == 21 and counts["二十九変換"] == 29, counts
assert counts["合成表の組込みの行377"] == 377 and counts["合成表の本体130"] == 130, counts
assert counts["入力の定理（79・7・10）"] == [79, 7, 10], counts
assert not unresolved, [(r["file"][:5], r["token"]) for r in unresolved]
assert not missing_modules, missing_modules
assert not cited_removed, cited_removed
summary = collections.Counter(r["class"] for r in rows)
record = {"base": L60_BASE, "files": DESIGN, "tokens": len(rows), "by_class": dict(sorted(summary.items())),
          "unresolved": unresolved, "new_modules_in_table": len(NEW) - len(missing_modules),
          "removed_declarations": removed, "removed_cited": cited_removed, "counts": counts, "rows": rows}
if args.verify:
    assert json.loads((HERE / "copies.json").read_text()) == json.loads(json.dumps(record, ensure_ascii=False))
    print(json.dumps({"verified": True, "tokens": len(rows)}))
else:
    write(HERE / "copies.json", record)
    print(json.dumps({k: record[k] for k in ["tokens", "by_class", "new_modules_in_table", "removed_declarations",
                                             "counts"]}, ensure_ascii=False))
