"""Map/Setの実宣言・型付き入口・残る接続を照合する。ビルドと公理監査は行わない。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULES = ["StandardMapSet", "StandardCollectionBodies", "StandardCollectionResponse", "StandardCollectionExamples"]
PURE = {"Map": ["empty", "fromList", "toList", "get", "set", "remove", "contains", "size", "keys", "values"],
        "Set": ["empty", "fromList", "toList", "contains", "add", "remove", "size", "union", "intersection", "difference"]}
CORE = ["Map.map", "Map.filter", "Set.map", "Set.filter"]

def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}

sources = {}
rows = []
other = []
for module in ["Map", "Set", "Pair", "List"]:
    path = Path("crates/benitoite/src/prelude/stdlib") / (module + ".bnt")
    text = (ROOT / path).read_text()
    sources[str(path)] = digest(ROOT / path)
    for number, line in enumerate(text.splitlines(), 1):
        match = re.match(r"public function (\w+)", line)
        if not match:
            continue
        name = module + "." + match.group(1)
        if match.group(1) in PURE.get(module, []):
            rows.append({"name": name, "kind": "pure", "source": str(path), "line": number,
                         "signature": line, "delta": module.lower() + "Delta",
                         "typed_response": module.lower() + "_api_response",
                         "default_reader": "StandardCollectionModel." + module.lower() + "_reply"})
        elif name in CORE:
            rows.append({"name": name, "kind": "core", "source": str(path), "line": number,
                         "signature": line, "body": "collectionHigherBody", "typed": "collectionHigher_body_typed",
                         "default_reader": "StandardCollectionModel.typed", "normal_relation": "境界の決定待ち"})
        elif module in PURE:
            other.append({"name": name, "signature": line, "status": "今回のmap/filter四本とは異なる既存core行。全328行の合成で別途照合"})
assert len(rows) == 24 and len({r["name"] for r in rows}) == 24
assert sum(r["kind"] == "pure" for r in rows) == 20
for path in ["crates/benitoite/src/builtins/funcs/map.rs", "crates/benitoite/src/builtins/funcs/set.rs",
             "crates/benitoite/src/runtime/map.rs", "crates/benitoite/src/runtime/map/keys.rs",
             "crates/benitoite/src/runtime/map/tree.rs", "crates/benitoite/src/base/prim.rs"]:
    sources[path] = digest(ROOT / path)

lean = {}
combined = "\n".join((ROOT / "formal/Benitoite/Release/Refinement" / (n + ".lean")).read_text() for n in MODULES)
for module in MODULES:
    path = Path("formal/Benitoite/Release/Refinement") / (module + ".lean")
    text = (ROOT / path).read_text()
    assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", text)
    names = []
    for match in re.finditer(r"^(?:  )?(def|theorem|structure|inductive) ([^\s({:]+)", text, re.M):
        name = match.group(2)
        uses = len(re.findall(r"(?<![A-Za-z0-9_])" + re.escape(name) + r"(?![A-Za-z0-9_])", combined)) - 1
        names.append({"name": name, "kind": match.group(1), "line": text[:match.start()].count("\n") + 1,
                      "textual_readers": uses,
                      "role": "具体P/Bの公開読者" if module == "StandardCollectionExamples" else "既定の具体読者又は応答/個数の導出で使用"})
    lean[module] = {"path": str(path), **digest(ROOT / path), "public_named": names,
                    "anonymous_examples": len(re.findall(r"^example\b", text, re.M))}
start = json.loads((HERE / "r1-start.json").read_text())
frozen = {}
for path, before in start["files"].items():
    if path.startswith("formal/"):
        after = digest(ROOT / path)
        assert before == after, path
        frozen[path] = after
report = {
    "checked_utc": datetime.now(timezone.utc).isoformat(), "sources": sources, "rows": rows, "other_existing_core": other,
    "counts": {"pure": 20, "map_filter_core": 4}, "lean": lean, "six_frozen_modules": frozen,
    "quantification": {"pure": "全P/B/StoreTy/ts/es/rs/ws/結果型/効果のBuiltinArgsから同じ具体deltaの応答存在、Outcome.Typed/Ground、AdequateResult、非exit",
        "inputs": ["同じStandardKeyTyping.Table", "P.VarianceValid", "Mapは同じPair/Optionの構成子とarity"],
        "no_new_semantic_input": "callbackの全域性、正常値の型、意味上の保存を新しい前提やProp欄へ追加しない",
        "body": "四本のRow.BodyTyped。元の型引数、引数名、効果E、Mapの二回のPair.firstと一回のcallbackを保持"},
    "order": {"key_equal": "Key.code?と同じ数値的Decimal等値。元Valを保持し、Map値の観測noneも保持",
        "normalization": "Key.normalizeMap/Setは挿入順。normalizedMap/Setは元表現を縮約して比較木で整列。長さの対応から順序の等号を推測しない",
        "rust_leaves": "base/prim.rs cmp_key_atom: 同じ型内の数値順、Decimal.cmp_num、String.chars辞書順、Bytes辞書順",
        "rust_composites": "runtime/map/keys.rs: constructorはtag、同tagの欄、欄数。Listは要素列、Mapは鍵/値列、Setは要素列の辞書順",
        "rust_representatives": "runtime/map.rs map_insert/set_insertとtree::combineは最初のMap鍵/第一Setの元表現を保持",
        "lean_constructors": "同じtable.declarations.flatMap DataDecl.entriesの名前の位置。任意csの型/個数証明と、現実のRust tag順の収集は別",
        "typed_boundary": "比較は同じKの値内で行う。不正な混合型入力はBuiltinArgsの型付けで排除する",
        "pending": "R50の実ID/tag収集とRust比較木全体との一般の対応。これを仮定欄へ追加せず未完として残す"},
    "pending": ["Map/Set.map/filter四本の正常関係は境界の決定待ち", "List側の正常関係を前提にしない", "全328行の合成", "全モデルCoreAssumptions", "R50のID/tag/順序収集"],
    "exclusions": "本記録はソース照合と局所検査。work/dry-run、Rust変更、全公理監査を実行しない"
}
out = HERE / "sources-r1-u24.json"
encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
assert len(encoded.encode()) <= 100000
out.write_text(encoded)
print(json.dumps({"exit": 0, "rows": len(rows), "public_named": {m: len(r["public_named"]) for m,r in lean.items()},
                  "sources": len(sources), "frozen": len(frozen), "record_bytes": len(encoded.encode())}, ensure_ascii=False))
