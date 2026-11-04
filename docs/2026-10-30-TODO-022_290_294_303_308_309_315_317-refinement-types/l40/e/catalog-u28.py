"""原署名を保持した328行の証拠・未完分類を再収集する。"""
from pathlib import Path
from datetime import datetime, timezone
import collections, hashlib, json
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def digest(p):
    b = p.read_bytes()
    return {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
def main():
    original = json.loads((HERE / "sources.json").read_text())
    candidate = json.loads((HERE / "api-connections-r1-u28.json").read_text())
    full = json.loads((HERE / "api-numeric.json").read_text()) + json.loads((HERE / "api-collections.json").read_text())
    actual = {x["module"] + "." + x["name"]: x for x in full}
    assert len(actual) == 328 and len({x["module"] for x in full}) == 23
    assert sum(x["builtin"] is not None for x in full) == 244
    for path, expected in original["inputs"].items():
        assert digest(ROOT / path) == expected, path
    assert {r[0] for r in candidate["rows"]} == set(actual)
    rows = []
    for entry in candidate["rows"]:
        api, profile, dispatch, partial, result, extra, _, _, outer, line, generics, parameters, effect = entry
        src = actual[api]
        assert [line, generics, parameters, result, effect] == [src["line"], src["generics"], src["parameters"], src["result"], src["effect"]]
        ordinary = "open"
        evidence = []
        if profile == "P-key-collections":
            ordinary = "pure-local"
            evidence = ["StandardCollections.map_api_response" if api.startswith("Map.") else "StandardCollections.set_api_response", "StandardCollectionModel.map_reply" if api.startswith("Map.") else "StandardCollectionModel.set_reply"]
        elif profile == "P-integer" and api.split(".")[-1] in ["minimum", "maximum"]:
            ordinary = "pure-local"
            evidence = ["StandardIntegerResponse.minMax_model_response"]
        elif profile in ["P-length", "P-bytes-list", "P-list-sequence"]:
            ordinary = "pure-local"
            evidence = ["StandardListResponse.table_response" if api.startswith("List.") else "StandardBytesResponse.table_response"]
        elif profile in ["P-byte-character", "P-float-class"]:
            ordinary = "pure-local"
            evidence = ["StandardScalarResponse.table_response"]
        elif profile in ["P-decimal", "P-decimal-option"] and api != "Decimal.fromFloat":
            ordinary = "pure-local"
            evidence = ["StandardDecimalResponse.table_response"]
        elif profile == "P-scalar-option":
            ordinary = "pure-local"
            evidence = ["StandardConversionResponse.table_response"]
        elif profile == "P-integer":
            ordinary = "pure-local"
            evidence = ["StandardIntegerAPI.table_response"]
        elif api in ["Map.map", "Map.filter", "Set.map", "Set.filter"]:
            ordinary = "core-local"
            evidence = ["StandardCollectionModel.typed"]
        relation = "none" if not extra else "local-partial"
        if profile.startswith("C-") and extra:
            relation = "boundary-wait" if api in ["List.map", "List.filter", "Map.map", "Map.filter", "Set.map", "Set.filter", "NonEmptyList.map"] else "core-open"
            if extra == ["S31"]:
                relation = "core-static-open"
        if api in ["List.map", "List.filter"]:
            ordinary = "core-local"
            evidence = ["StandardActualListBodies.model_typed"]
        if ordinary == "pure-local" and (profile == "P-scalar-option" or profile in ["P-length", "P-bytes-list", "P-list-sequence"] or api.endswith((".minimum", ".maximum"))):
            relation = "same-input-local"
            if profile == "P-scalar-option": evidence += ["StandardConversionResponse.fromInteger_math", "StandardConversionResponse.toInteger_math"]
            elif api.startswith("List."): evidence += ["StandardListResponse.related_response"]
            elif profile in ["P-length", "P-bytes-list"]: evidence += ["StandardBytesResponse.related_response"]
            else: evidence += ["StandardIntegerResponse.minMax_response"]
        elif ordinary == "pure-local" and profile == "P-integer":
            if api.endswith(".absolute"):
                relation = "same-input-local"
                evidence += ["StandardIntegerAPI.absolute_response_math"]
            elif api.endswith((".floorDivide", ".floorModulo")):
                relation = "same-input-leaf"
                evidence += ["StandardIntegerAPI.floor_math", "StandardIntegerAPI.floor_equation"]
                if api.endswith(".floorModulo"): evidence += ["StandardIntegerAPI.modulo_no_overflow"]
            else:
                relation = "same-input-local"
                evidence += ["StandardIntegerAPI.bits_math"]
        elif ordinary == "pure-local" and profile in ["P-byte-character", "P-float-class"]:
            relation = "same-input-local"
            if api == "Byte.fromInteger": evidence += ["StandardScalarResponse.byteFrom_math"]
            elif api == "Byte.toInteger": evidence += ["StandardScalarResponse.byteTo_math"]
            elif api == "Character.fromInteger": evidence += ["StandardScalarResponse.characterFrom_math"]
            elif api == "Character.toInteger": evidence += ["StandardScalarResponse.characterTo_math"]
            elif profile == "P-float-class": evidence += ["StandardScalarResponse.float_class_math"]
            else: evidence += ["StandardScalarResponse.byte_bits_math"]
        elif ordinary == "pure-local" and profile in ["P-decimal", "P-decimal-option"]:
            relation = "same-input-local"
            method = api.split(".")[1]
            evidence += ["StandardDecimalResponse." + method + "_math"]
        if api == "Decimal.fromFloat":
            evidence = ["StandardDecimalResponse.fromFloat_exit"]
        pending = []
        if ordinary == "open":
            pending.append("ordinary-F06")
        if relation == "boundary-wait":
            pending.append("境界の決定待ち")
        elif relation in ["local-partial", "core-open", "core-static-open", "same-input-leaf"]:
            pending.append("追加関係の全実表収集")
        if outer:
            pending.append("既存の外側アルゴリズム境界")
        receiver = "L60へ証明済みδ/本体契約だけを供給。L40未完は移管しない"
        rows.append([api, profile, src["builtin"], src["calls"], ordinary, evidence, extra, relation, outer, pending, receiver])
    assert len(rows) == len({r[0] for r in rows}) == 328
    counts = dict(collections.Counter(r[4] for r in rows))
    out = {"updated_utc": datetime.now(timezone.utc).isoformat(),
           "scope": "全実名分類。pure-local/core-localは有限な具体表の契約であり全標準Program又は全モデルの充足ではない。",
           "counts": {"modules": 23, "apis": 328, "builtin": 244, "core": 84, "aliases": 51, **counts},
           "status_definitions": {"pure-local": "原署名の全ts/es/rs/ws/Ψ/a/eを逆転し同じ具体δの型/Ground/Adequate/非exitを証明", "core-local": "同じ有限P/Bの実Comp/Row.BodyTypedを証明。一般Program収集と正常関係は別", "open": "境界とは独立のL40未完", "boundary-wait": "正常返却関係を使う接続は境界の決定待ち"},
           "columns": ["api", "profile", "actual_builtin", "actual_core_calls", "ordinary_F06", "evidence", "additional_S", "relation_status", "outer_algorithm", "pending", "receiver"],
           "rows": rows,
           "original_signature_records": {name: digest(HERE / name) for name in ["sources.json", "api-numeric.json", "api-collections.json", "api-connections-r1-u28.json"]},
           "whole_obligations_closed": 0, "whole_api_contracts_closed": 0, "L40_unproved_transferred": 0,
           "additional_relation_counts": dict(collections.Counter(r[7] for r in rows)),
           "closure_criteria": {"ordinary_F06": "pure-localは同実名/全引数/同δ/型/Ground/Adequate/非exit、core-localは同Comp/RowのBodyTyped", "additional_S": "same-input-localは同ws/outの数学値/列/長さ/既存err。same-input-leafの床14は実符号補正・q*b+r・zero/結果幅err・mod非overflowまで。商overflowをsignedmin/-1へ整理する一般化は元.29", "whole_API": "原署名の実標準表/Programへの全収集、全追加S、必要な境界の接続と段末レビュー。有限profileの証明数を全API閉鎖へ繰り上げない"},
           "limits": ["実Rust登録型/ABI/鍵の全比較は行っていない", "100行の名前付きδ未実装は独立未完。常時err又はsemantic providerを追加しない", "Decimal.fromFloatの任意parsedの出口とactualbitsからの供給は別", "%eq/%neは328外。scalar部分表を全Equalityへ拡張したとはしない", "現行Range/NonEmptyListの原署名と内部safe19を区別する"]}
    dest = HERE / "sources-r1-u28.json"
    dest.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n")
    assert dest.stat().st_size <= 100000
    print(json.dumps(out["counts"], ensure_ascii=False))
if __name__ == "__main__": main()
