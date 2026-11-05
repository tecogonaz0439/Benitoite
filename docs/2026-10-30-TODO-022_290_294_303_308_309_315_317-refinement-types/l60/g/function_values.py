"""関数値が到達しうる合成表の行を族ごとに照合する（S19）。

全377行の署名の族は、`StandardModel.sig_scoped` の場合の一覧（行ごとの族の補題）から読む。族ごとに、
型パラメータの宣言と、制約を持たない型パラメータが引数の型に現れるかを、署名の定義のソースの文字列で照合する。
制約のない型パラメータは関数型（例 `Unit → Unit`）へ具体化でき、その型の値は引数の列・写像の値・参照の中身として
行へ到達する。等値・鍵・順序の制約を持つ型パラメータには、関数型は制約の判定で入らない。
到達する行を、値を保存・射影する行と、値の形（個数・構造）を調べる行に分け、値の項の観測（`Val.toTerm?`）を
結果の篩が読むかを別の欄に記す。関数値を禁止する制限や新しい条件は足さない。
"""
from pathlib import Path
import argparse
import collections
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
LEAN = ROOT / "formal/Benitoite/Release/Refinement"


def source(name):
    return (LEAN / (name + ".lean")).read_text()


# 族の補題 → (署名の定義を持つファイル, そのファイルに現れる型パラメータの宣言の文字列, 到達の判定)
FAMILIES = {
    "scoped_unary": ("StandardModelPureInputs", "def unarySig (n : String) (i o : BaseTy) : PrimSig :=\n  ⟨[],0,", None),
    "scoped_binary": ("StandardModelPureInputs", "def binarySig (n m : String) (i j o : BaseTy) : PrimSig :=\n  ⟨[],0,", None),
    "scoped_option": ("StandardModelPureInputs", "def optionSig (n : String) (i o : BaseTy) : PrimSig :=\n  ⟨[],0,", None),
    "scoped_decimal": ("StandardDecimalResponse", "⟨[],0,api.names", None),
    "scoped_string": ("StandardStringOrdinaryResponse", " ⟨[],0,api.names,api.inputs", None),
    "scoped_bytesOrdinary": ("StandardBytesOrdinaryResponse", " ⟨[],0,api.names,api.inputs", None),
    "scoped_bytes": ("StandardBytesResponse", "⟨[],0,api.names,api.inputs,api.result", None),
    "scoped_range": ("StandardListRemainingResponse", " ⟨[],0,[\"start\",\"stop\"]", None),
    "scoped_structural": ("StandardEqualityResponse", "⟨[⟨{equality := true},.value⟩],0,[\"left\",\"right\"]", None),
    "scoped_list": ("StandardListResponse", "⟨[TypeCtx.valueParam],0,api.names,api.inputs (.tvar 0)", "all"),
    "scoped_listRemaining": ("StandardListRemainingResponse", "⟨[⟨api.constraint,.value⟩],0,api.names", "listRemaining"),
    "scoped_headTail": ("StandardHeadTailContracts", "⟨[TypeCtx.valueParam],0,[\"xs\"],[.list (.tvar 0)],", "all"),
    "scoped_append": ("StandardHeadTailContracts", "⟨[TypeCtx.valueParam],0,[\"xs\",\"x\"],[.list (.tvar 0),.tvar 0],", "all"),
    "scoped_map": ("StandardCollectionResponse", "⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,api.names", "map"),
    "scoped_set": ("StandardCollectionResponse", "⟨[⟨TParam.keyC,.value⟩],0,api.names", None),
    "scoped_precision": ("StandardCollectionPrecision", "tparams := if map then [⟨TParam.keyC,.value⟩,TypeCtx.valueParam] else [⟨TParam.keyC,.value⟩]", "precision"),
    "scoped_replaceValues": ("StandardMapReplaceValues", "⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam,TypeCtx.valueParam],0,[\"m\",\"values\"]", "all"),
    "store.1": ("StandardModelSignatures", "⟨[TypeCtx.valueParam],0,[\"value\"],[.tvar 0],.reference (.tvar 0)", "all"),
    "store.2.1": ("StandardModelSignatures", "⟨[TypeCtx.valueParam],0,[\"reference\",\"f\"],", "all"),
    "store.2.2.1": ("StandardModelSignatures", "⟨[TypeCtx.valueParam],0,[\"value\"],[.lazy (.tvar 0)]", "all"),
    "store.2.2.2": ("StandardSafeAccess", " ⟨[TypeCtx.valueParam],0,[\"xs\",\"index\"],[.list (.tvar 0),.base .integer]", "all"),
}
# 範囲付きのモデルの行（targets_scoped・http_scoped）のうち、型パラメータを持つのは参照の取得・設定だけである。
ENTRY_TPARAMS = {"Reference.get": "def refGet : PrimSig :=\n  ⟨[TypeCtx.valueParam],0,[\"reference\"]",
                 "Reference.set": "def refSet : PrimSig :=\n  ⟨[TypeCtx.valueParam],0,[\"reference\",\"value\"]"}
ENTRY_PLAIN = ["def pureIn (names : List String) (params : List Ty) (ret : Ty) (ks : List Kind) : PrimSig :=\n  ⟨[],0,",
               "def ioIn (names : List String) (params : List Ty) (ret : Ty) (l : EffName) (k : Kind) : PrimSig :=\n  ⟨[],0,",
               "(shape : Scope.Signature.IOShape) (kind : PrimKind := .io) : PrimSig :=\n  ⟨[],0,"]

# 到達する行の扱い。(分類, δ又は遷移の扱い, 結果の篩が入力の項の観測を読むか)
PRESERVE = "値を保存・射影する行"
SHAPE = "値の形（個数・構造）を調べる行"
BEHAVIOR = {
    "List.concatenate": (PRESERVE, "二つの列の要素を順に並べる", False),
    "List.prepend": (PRESERVE, "要素を先頭へ置く", False),
    "List.reverse": (PRESERVE, "要素の順を逆にする", False),
    "List.drop": (PRESERVE, "先頭から整数個を除いた残りの要素", False),
    "List.take": (PRESERVE, "先頭から整数個の要素", False),
    "List.get": (PRESERVE, "添字の位置の要素をOptionで返す", False),
    "List.append": (PRESERVE, "要素を末尾へ置く", True),
    "List.head": (PRESERVE, "先頭の要素をOptionで返す", True),
    "List.tail": (PRESERVE, "先頭を除いた列をOptionで返す", True),
    "%List.getFront": (PRESERVE, "添字の位置の要素を返す（安全な入口の内部）", False),
    "Map.get": (PRESERVE, "鍵の値をOptionで返す", False),
    "Map.set": (PRESERVE, "鍵の値を置き換える", False),
    "Map.remove": (PRESERVE, "鍵の項目を除いた残りの値", False),
    "Map.values": (PRESERVE, "値の列", False),
    "Map.fromList": (PRESERVE, "対の列から写像を作る（鍵を正規化し、値をそのまま置く）", True),
    "Map.toList": (PRESERVE, "写像を対の列にする", True),
    "%Map.replaceValues": (PRESERVE, "値を同じ長さの列の値へ置き換える", True),
    "Reference.new": (PRESERVE, "専用の遷移が値をセルへ置く", False),
    "Reference.get": (PRESERVE, "専用の遷移がセルの値を返す", False),
    "Reference.set": (PRESERVE, "専用の遷移がセルの値を置き換える", False),
    "Reference.update": (PRESERVE, "専用の遷移が取得・関数の呼出し・設定へ展開する", False),
    "Lazy.force": (PRESERVE, "専用の遷移が完了済みの値を返すか評価する", False),
    "List.length": (SHAPE, "要素の個数", False),
    "List.isEmpty": (SHAPE, "要素の有無", False),
    "Map.size": (SHAPE, "項目の個数", False),
    "Map.contains": (SHAPE, "鍵の所属（値は読まない）", False),
    "Map.keys": (SHAPE, "鍵の列（値は読まない）", False),
}


def names():
    text = source("StandardModelSignatures")
    body = text.split("def Primitive.name : Primitive → String", 1)[1].split("\n\n", 1)[0]
    return dict(re.findall(r"\| \.(p\d{3}) => \"([^\"]+)\"", body))


def families():
    text = source("StandardModelScoped").split("theorem sig_scoped", 1)[1]
    out = {}
    for row, rest in re.findall(r"^  case (p\d{3}) => exact (.+)$", text, re.M):
        m = re.match(r"(scoped_\w+|targets_scoped|http_scoped) externals ?(.*)$", rest)
        if m:
            out[row] = (m[1], m[2].strip())
        else:
            out[row] = (re.match(r"(store[.\d]*)", rest)[1], "")
    return out


def reachable(lemma, args, name):
    """制約のない型パラメータが引数の型に現れるか。"""
    if lemma in ("targets_scoped", "http_scoped"):
        return name in ENTRY_TPARAMS
    rule = FAMILIES[lemma][2]
    if rule is None:
        return False
    if rule == "all":
        return True
    if rule == "listRemaining":
        # contains は等値の制約、sort は順序の型の許容を持ち、関数型を入れない。
        return args not in (".contains", ".sort")
    if rule == "map":
        return args != ".empty"
    if rule == "precision":
        return args.startswith("true")
    raise AssertionError(rule)


def build():
    row_names = names()
    rows = families()
    assert len(rows) == 377 and set(rows) == set(row_names), len(rows)
    for lemma, (file, needle, _) in FAMILIES.items():
        assert needle in source(file), (lemma, needle[:40])
    for needle in ENTRY_TPARAMS.values():
        assert needle in source("ScopeSignatures"), needle[:40]
    for needle in ENTRY_PLAIN:
        assert needle in source("ScopeSignatures"), needle[:40]
    # 制約の判定は関数型を等値・鍵の型と認めず、順序の型の集合にも関数型はない。
    assert "| .fn _ _ _ _ | .opaque _ _ | .reference _ | .lazy _ | .cont _ _ _" in (ROOT / "formal/Benitoite/Release/BuiltinTable.lean").read_text()
    assert " | .contains => {equality:=true} | _ => {}" in source("StandardListRemainingResponse")
    assert "(api=.sort → ∀ t ∈ ts, orderedType t)" in source("StandardListRemainingResponse")
    # 観測できない値（関数値を含む）は項の欄が欠ける。生lambdaとclosureはどちらもこの枝に入る。
    assert "    | _ => none\n  def Val.toTermSlots" in source("Syntax")
    found = {}
    for row, (lemma, args) in sorted(rows.items()):
        name = row_names[row]
        if reachable(lemma, args, name):
            found[name] = {"row": row, "family": lemma, "args": args}
    assert set(found) == set(BEHAVIOR), set(found) ^ set(BEHAVIOR)
    out = []
    for name, info in sorted(found.items(), key=lambda x: x[1]["row"]):
        category, treatment, observes = BEHAVIOR[name]
        out.append(info | {"name": name, "category": category, "treatment": treatment,
                           "result_refinement_observes_terms": observes})
    return {"rows": out, "counts": dict(collections.Counter(r["category"] for r in out)),
            "families": dict(collections.Counter(lemma for lemma, _ in rows.values())),
            "unreachable": 377 - len(out)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    data = build()
    if args.verify:
        assert json.loads((HERE / "function-values.json").read_text()) == data
        print(json.dumps({"verified": True, **data["counts"]}, ensure_ascii=False))
        return
    (HERE / "function-values.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps({"rows": len(data["rows"]), **data["counts"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
