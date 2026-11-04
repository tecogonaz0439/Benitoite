"""群末前に追加照合と現在の写しを保存する。"""
from pathlib import Path
import argparse,json,hashlib
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
def digest(p):
 b=p.read_bytes();return {"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp",type=Path,required=True)
raw=parser.parse_args().tmp
evidence={"compiler":"rustc 1.98.1 (48a229cea 2026-09-01)","scope":"固定機械のNaN6例と最短表記1例。全bit/全機械の交換ではない","cases":(raw/"float-nan-conversion.log").read_text().splitlines(),"source":digest(raw/"float-nan-conversion.rs"),"raw":digest(raw/"float-nan-conversion.log"),"lean_check":"r2-numeric-nan04"}
(HERE/"nan-conversion-r2.json").write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+"\n")
addition="""
### String・Bytes・残る数値変換の準備

Stringの表示幅の短い抽出をUTC 2026-11-03T20:54:00.533537+00:00〜20:54:01.106812+00:00に一時領域で実施した（0.572秒）。通常幅・CJK幅の初期状態を抽出し2,417区間を得た。残る全状態の抽出は数秒と見込み、そのまま同じ一時領域でUTC20:54:16.316358〜20:54:19.640784に実施した（3.318秒）。通常132状態・CJK87状態、全22,302区間、String lowercaseのΣの文脈分類615区間を得た。固定rustc 1.98.1とunicode-width 0.2.2の計算から生成する。生成器・入力・生の抽出の大きさとSHA-256は改造内のJSONへ保存する。文字ごとの幅の和に置き換えず、文脈を追う有限遷移を使う。mainの書込みをcore担当と重ねないため、この時点では/tmpだけに出力した。

新たな純粋結果の共通補助は、具体的なString/Bool/Integer64Value/Char/UInt8/Float bits/表現可能なDecimal/List/Optionのpayloadから実Valを作る。出力のTypedやsemantic providerを前提の欄へ足さない。APIごとの具体計算を与えた後に、全BuiltinArgsから同じ実名・型/行/範囲/値引数のδへ結ぶ。ByteOrderの両構成子とOptionを同じ有限Programに宣言し、Bytesの読み書きの入口を空の型にしない。

### 固定署名とR40へ引き継ぐ本体の差

| 対象 | 再開2での実変更と引継ぎ |
|---|---|
| 群Aの固定Row、List.map/filterとMap/Set該当行 | tel/本体の変更0。提案telは試行定義に限り、採用しない |
| 安全な入口19行、主な十言明、Step/Steps/Runs | 変更0。FirstReturnと二つの反例も保持 |
| R40のmapFrom/map | 採用済みの書換え0。元のget→callback→検査付き加算→append→再帰を保持。callback順/回数・効果・失敗・結果値を変更しない。helperの非公開性と公開引数も保持 |
| 通常core27と別名51 | 原署名と原Compを通常型付ける。私有helperのList接頭辞と実IR名の照合は[core記録](core-r2.md)に分ける |
| 新しいFloat/Float32の丸め模型 | 最初に共通nとしたラベルを原ソースどおりFloat=x、Float32=nへ修正。固定Rowへの変更ではない |
| Set.map | 大きさの等式を追加しない |

### 追加の元ソース照合

core担当の書込み停止後に、String/Bytes/数値/Listの具体計算を読み取りだけで別担当に照合させた。Stringの空separator・lines・trim・repeat・replaceと資源上限、Bytesのseparator/符号/エンディアン、Listのu32境界・range上限・sort事前比較を照合した。正式の独立レビュー/受け入れとは数えない。

Float最短表記のbits=c2e2c3e917fb4234についてPythonのreprとはtieの末桁が異なったが、固定Rustの{:e}は-1.6506110868532963e14であり、今回の.63と一致した。Pythonとの差をRustとの差にしない。NaNのnarrow/widenには、最初のLean Model経由だと符号/payloadがcanonical化される差があった。固定Rustで六例を実行して確認し、raw sign/上位payload/quiet bitを構成する枝へ修正した。対応する六例と通常応答全体の単独Lean r2-numeric-nan04はUTC21:16:33.113456に終了0。[入力/出力の識別](nan-conversion-r2.json)を保存した。全bit・全機械の交換をこの六例で証明したとはしない。

### getter調査の結論の補足

通常getter12本と公開射影12本は同じ宣言表で検査できたが、06〜14の精密getter9行は閉じていない。通常のP_Conは欄の型を束縛へ渡し、pathFactsは構成子の識別を渡す。これだけでは、返却した束縛値と元receiverの欄の観測の等号を得ない。欄の篩の既存読者は構文上のconの型付けを入力にするため、開いたreceiverのmatchへそのまま適用できない。調べた導出・wrapper・本体の別表現ではこの不足を解消できなかった。

追加する場合の規則は、欄位置・パターンの束縛順・permutationを対応させ、束縛変数と元receiverのfieldの等号をmatchの枝の事実に加える形になる。WF/Sorted、shift/値代入、Transport、capture、matchの保存とその読者へ影響する。主な十言明の前提・結論の変更が必須とはここで断定しないが、それらの証明への影響確認が要る。規則を加えるかは設計者の判断に残す。代案は精密な内部型をgetterの返却で読まない構成又は同じreceiverの直接の欄の観測を型付ける設計であり、固定safe19を勝手に弱めて採用しない。
"""
f=HERE/"results.md";f.write_text(f.read_text().replace("/tmpの下書き","<tmp>の下書き")+addition)
doc="Float二幅の変換のNaNはraw bitsの符号と上位payloadを読み、変換先のquiet bitを立てて構成する。有限値・符号付き零・Infinityは固定Lean Modelで丸める。型引数を持たない新たな93純粋署名の全欄は、`StandardOrdinarySignatureChecks` の具体例で元ソースから抽出した名前・型と照合する。List.sortのorderedは閉じた型を読むadmissionで表し、篩付きの元型をそのまま使う。"
for name in ["docs/design/01-spec/01-12-core-calculus.md","docs/design/07-quality/07-04-formal-semantics.md"]:
 f=ROOT/name;f.write_text(f.read_text()+"\n"+doc+"\n")

