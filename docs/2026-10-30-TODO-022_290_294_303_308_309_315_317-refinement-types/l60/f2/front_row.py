# -*- coding: utf-8 -*-
"""合成表の組込みの台帳へ、安全な入口の本体が呼ぶ内部の %List.getFront の行を加える（一度だけ適用する）。

StandardModelSignatures の構成子・名前・出典・署名・二分探索木と、
StandardModelPrimitiveLookup の行ごとのlookupへ、同じ一行を加える。群F1の store_rows.py と同じ読み書きを使う。"""
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LEAN = ROOT / "formal/Benitoite/Release/Refinement"
ROWS = [("p377", "%List.getFront", "StandardSafe.frontSig")]


def parse(text, i):
    """木の字面を (key, row, left, right) か None へ読む。"""
    if text.startswith(".empty", i):
        return None, i + len(".empty")
    assert text.startswith("(.node ", i), text[i:i + 20]
    m = re.compile(r'\(\.node "([^"]+)" \.(p\d{3}) rfl ').match(text, i)
    left, j = parse(text, m.end())
    assert text[j] == " "
    right, j = parse(text, j + 1)
    assert text[j] == ")"
    return (m[1], m[2], left, right), j + 1


def emit(tree):
    if tree is None:
        return ".empty"
    key, row, left, right = tree
    return '(.node "%s" .%s rfl %s %s)' % (key, row, emit(left), emit(right))


def insert(tree, key, row):
    if tree is None:
        return (key, row, None, None)
    k, r, left, right = tree
    assert key != k
    # Leanの String の < は文字の符号位置の辞書式順序であり、Pythonの比較と一致する。
    if key < k:
        return (k, r, insert(left, key, row), right)
    return (k, r, left, insert(right, key, row))


path = LEAN / "StandardModelSignatures.lean"
src = path.read_text()
assert "p377" not in src
src = src.replace("  | p376\n", "  | p376\n" + "".join("  | %s\n" % p for p, _, _ in ROWS), 1)
src = src.replace('  | .p376 => "Reference.update"\n', '  | .p376 => "Reference.update"\n' +
                  "".join('  | .%s => "%s"\n' % (p, n) for p, n, _ in ROWS), 1)
src = src.replace("  | .p376 => source23\n", "  | .p376 => source23\n" +
                  "".join("  | .%s => source25\n" % p for p, _, _ in ROWS), 1)
src = src.replace('  | .p376 => refUpdateSig\n',
                  '  | .p376 => refUpdateSig\n' +
                  "".join("  | .%s => %s\n" % (p, s) for p, _, s in ROWS), 1)
head = "private def primitiveTree : SignatureTree := "
start = src.index(head) + len(head)
tree, end = parse(src, start)
for p, n, _ in ROWS:
    tree = insert(tree, n, p)
src = src[:start] + emit(tree) + src[end:]
path.write_text(src)

path = LEAN / "StandardModelPrimitiveLookup.lean"
src = path.read_text()
assert "p377" not in src
anchor = 'private theorem lookup_p376 : primitive "Reference.update" = some Primitive.p376 := rfl\n'
src = src.replace(anchor, anchor + "".join(
    'private theorem lookup_%s : primitive "%s" = some Primitive.%s := rfl\n' % (p, n, p) for p, n, _ in ROWS), 1)
anchor = "  | p376 => exact lookup_p376\n"
src = src.replace(anchor, anchor + "".join("  | %s => exact lookup_%s\n" % (p, p) for p, _, _ in ROWS), 1)
path.write_text(src)
print("rows", len(ROWS))
