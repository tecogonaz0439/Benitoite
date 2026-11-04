"""全S行とAPI外の供給先、実ソースの原文断片と識別を保存する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def digest(p):
    data = p.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
def save(name, value):
    p = HERE / name
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    assert p.stat().st_size <= 100000, name

def main():
    sources = json.loads((HERE / "sources-r1-u28.json").read_text())
    section = (HERE.parent / "detail.md").read_text().split("### 関係を追加する契約の有限表", 1)[1].split("## 4.", 1)[0]
    descriptions = {}
    for line in section.splitlines():
        if re.match(r"\| S\d\d \|", line):
            fields = [x.strip() for x in line.split("|")[1:-1]]
            descriptions[fields[0]] = fields[1:]
    assert len(descriptions) == 36
    notes = {
      "S01": "328外の加減乗/負号25実名を実left/right/value・全BuiltinArgs・同δ・数学値/幅/overflowへ接続。区間/第一失敗は元.29〜35。",
      "S02": "328外のintDiv/mod。integerDeltaAtの未接続名をfloor二演算で代替しない。独立未完。",
      "S03": "328外の四比較48実名を全BuiltinArgs・同δ・同二値の述語へ接続。%eq/%neは全Equality署名/元の篩付きTを維持し12scalar域の条件付きpartial。構造Equalityは独立未完。",
      "S04": "Byteの全八応答と同変換のSome同値/0〜255・None域外・同Integer射影、実bitwise/shift/count域外を全BuiltinArgs・同δへ接続。UnsignedInteger8のalias本体は独立未完。",
      "S05": "Character二応答とcode/scalarを保持。Characterの同code/Some/None/scalarを全引数から接続。String.characters/fromCharactersとUnicode全分類の具体接続は独立未完。",
      "S06": "三つの公開分類のnamedδを全引数・同bitsのNaN/二∞or述語へ接続。四比較の実演算子はOrderResponseの48行へ接続。全bit丸め/表記は元の外側。",
      "S07": "Decimal六実名を五モード/Optionの同Pへ接続。fromFloatは再検査出口のみ、同bits由来のparsed供給は独立未完。",
      "S08": "String二長の同ws/outの関係をrelated_responseで保持。表現外errを正常値の関係に混ぜない。",
      "S09": "Bytes.fromList/toList/lengthの同じbyte列と同長をrelated_responseで保持。",
      "S10": "List.length/isEmptyの同じ列と正常値の関係を保持。consの既存観測と区別する。",
      "S11": "prepend/appendの同じ要素と列、n+1をrelated_responseで保持。",
      "S12": "concatenateの同じ二列と順序、n+mをrelated_responseで保持。",
      "S13": "reverseの同じ列と長さnをrelated_responseで保持。",
      "S14": "実left/rightで元の同じComp/Rowの静的BodyTypedを供給。正常返却の関係と使用部分は境界の決定待ち。",
      "S15": "実left/rightで元の同じComp/Rowの静的BodyTypedを供給。正常返却の関係と使用部分は境界の決定待ち。",
      "S16": "旧Option APIのhead/tail/getの全入力F06は独立未完。内部safe9本と公開旧APIを同一視しない。",
      "S17": "既存Map純粋十実名の全BuiltinArgs契約と縮約/sizeの局所証拠を収集。全S収集を完了へ繰り上げない。",
      "S18": "既存Map keys/valuesの全引数応答と同entriesの射影を収集。",
      "S19": "既存Map get/set/remove/containsの全応答と更新/削除の両枝を保持。",
      "S20": "四高階本体の既存BodyTypedを保持。Mapの正常関係は境界の決定待ち。",
      "S21": "既存Set純粋十実名の全BuiltinArgs契約と縮約の局所証拠を収集。",
      "S22": "Set add/removeと高階の静的BodyTypedを保持。map/filterの正常関係は境界の決定待ち。",
      "S23": "既存集合演算の全引数応答と上下限を保持。新実装を重ねない。",
      "S24": "328外のrecord不変欄と連鎖、同じPの構築条件を既存証拠から供給。",
      "S25": "328外のdecode済みResultの後処理本体/順序を保持。通常decodeへの全接続は境界の決定待ち。",
      "S26": "現行nominal APIの原署名を保持。内部safe19の注釈とbody9本、getter9本の静的未証明を区別する。",
      "S27": "現行CheckedLengthの原署名と内部精密契約を区別。getter静的未証明は独立未完。",
      "S28": "元List/elementを保つ内部getFront/slice応答とsafe本体を保持。公開原署名の全収集は独立未完。",
      "S29": "328外の同長別Listへの内部safeGet。同じ保持Listと別Listを区別する既存証拠を供給。",
      "S30": "現行nominal NonEmptyList五行と内部NE別名/safe19を区別。R40表現変換、getter静的未完、map正常の境界待ちを混ぜない。",
      "S31": "全位置の静的受理拒否/依存結果効果/四像を保持。S31だけのfold等9行の実本体への静的適用は独立未完。正常関係待ちは明示した7公開行だけ。",
      "S32": "対象付きFile六本/Http.sendInは328外。L50へ元の保持値/要求/対象を供給し、L40未完を移管しない。",
      "S33": "正常/returned/failed所属の全合成は元の.29〜35担当。pureのerr/exit排除をStop全意味関係の証明としない。",
      "S34": "整数十二行・Byte/Character四行・Decimalの変換を同ws/outのSome/None/数学値/幅/整数性へ接続。fromFloatは任意parsed出口のみ。alias本体と実bits由来parsed供給は独立未完。",
      "S35": "七幅十四実名の全BuiltinArgsを同符号補正数学値・q*b+r・zero/補正結果幅外へ接続。modの商overflow由来の拒否は排除。quotient overflowをsignedmin/-1へ整理する一般化と区間/returned/第一失敗は元.29〜35。",
      "S36": "min/max十四行の同ws/out数学値、absolute七行の正常非負/幅/unsigned同値とoverflow iff signedmin、整数46+Byte6の同bit演算/wrap/count域外errを接続。区間/returned/第一失敗は元.29〜35。"}
    relations = []
    for sid, desc in descriptions.items():
        apis = [row[0] for row in sources["rows"] if sid in row[6]]
        relations.append({"id": sid, "detail": desc, "apis": apis, "status": notes[sid],
                          "receiver": "L60へ証明済みδ/本体契約だけを供給。各独立未完と境界待ちはL40内に保持。"})
    save("relations-r1-u28.json", {"rows": relations, "count": 36,
        "outside_API": {"operators": "S01/S02/S03。実left/rightと負号valueを保持。全Equalityは未完。",
          "record_decode": "S24/S25。既存同Pの欄/順序。正常decodeの全接続は境界待ち。",
          "internal_safe19": "S16/S26〜30。全19Annotation/body9/getter9未証明/map境界待ち。原公開署名と分ける。",
          "scoped_File_Http": "S32。対象付きFile6/Http.sendInはL50の元担当。",
          "generators": "R40の生成器/NE別名変換とR50の実ID/ABI/鍵収集は元の境界。L40不足を移管しない。"},
        "whole_S_closed": 0})
    snippets = []
    requests = {"crates/benitoite/src/builtins/table.rs": [(146,151),(190,207),(975,1055)],
        "crates/benitoite/src/base/parameter_names.rs": [(1,10)],
        "crates/benitoite/src/prelude/stdlib/Option.bnt": [(10,17)],
        "crates/benitoite/src/prelude/stdlib/RoundingMode.bnt": [(1,18)]}
    for rel, ranges in requests.items():
        path = ROOT / rel; lines = path.read_text().splitlines()
        snippets.append({"path": rel, **digest(path), "excerpts": [{"start": a,"end": min(b,len(lines)),"text": "\n".join(lines[a-1:b])} for a,b in ranges]})
    modules = json.loads((HERE / "modules-r1.json").read_text())[20:]
    save("source-evidence-u28.json", {"captured_utc": datetime.now(timezone.utc).isoformat(),
        "source_schema": "Declaredの型はstdlibの原宣言。既存api-numeric/api-collectionsに全328署名/制約/引数/効果/core呼先と本体を保持。",
        "original_records": {name: digest(HERE / name) for name in ["sources.json", "api-numeric.json", "api-collections.json", "api-connections-r1-u28.json", "sources-r1-u28.json", "relations-r1-u28.json"]},
        "new_modules": {m: digest(ROOT / f"formal/Benitoite/Release/Refinement/{m}.lean") for m in modules},
        "actual_source_excerpts": snippets,
        "outer_boundaries": ["Decimal.fromFloatは同bits由来parsedの実供給が未接続。fromFloat_exitは任意parsedの再検査出口だけ。", "Float全bit丸め/parseformat/Unicode全分類の元の外側境界を保持。", "100行の全入力F06収集は独立未完。List.getの局所model内の実δの存在だけでは全入力契約を得ない。"],
        "limits": ["Rust登録スキーマ/ABI/鍵の実行全比較は未実施。必要範囲の原文読取りだけ。", "全モデルCoreAssumptions/全API閉鎖/独立レビュー/受け入れは未完。"]})
    print(json.dumps({"relations": len(relations), "modules": modules, "api_counts": sources["counts"], "additional": sources["additional_relation_counts"]},ensure_ascii=False))
if __name__ == "__main__": main()
