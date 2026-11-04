"""再開2の判定を64行へ反映する。初回/再開1は別に保持する。"""
from pathlib import Path
import re
HERE=Path(__file__).resolve().parent
updates={
"O011":"部分。全244純粋行を原署名の全BuiltinArgsから同じ具体δの型/Ground/Adequate/非exitへ接続した。Decimal.fromFloatは同じbits由来parsedを再検査出口へ供給する。73演算子とFull Equality署名のscalar部分は保持する。全モデルと全標準表の合成は別である。",
"O015":"部分。鍵と観測、既存109同ws/out関係と床14のleafを保持する。全244純粋応答とcore84本の通常型を収集した。新179行の通常型と追加Sの全関係を分け、正常篩7行と精密getter9行は未完である。",
"O021":"運用。再開2の開始はUTC2026-11-03T19:46:35.659935+00:00。試行・getter・通常179行・全検査の時刻をresults/checks/core-r2へ保存した。開始時刻の一件の記録漏れは最初のLean時刻と区別し、推定で埋めない。",
"O022":"部分。全328分類はpure-local244/core-local84、通常未接続0である。各pureは同じ具体δ、各coreは原Comp/通常署名のDef.WellTypedへ接続する。通常decodeの精密な事実の接続と全モデルは未完として保持する。",
"O030":"部分。全244応答を全BuiltinArgsから同じδの型/Ground/Adequate/非exitへ、core84本を原本体の通常型付けへ接続した。全構文/全標準表の合成と追加Sの全閉鎖とはしない。",
"O034":"部分。全19Annotationと安全9本の既済みを保持する。精密getter06〜14の9行は束縛と欄の等号の規則を要する経路で停止。NonEmptyList.mapの通常nominal本体は閉じたが、安全な強い本体は未完である。",
"O038":"部分。FiniteStepPreservationの同じ76保存葉と主な十言明を保持する。具体244応答、core84本の通常型、既存73演算子と条件付きscalar Equalityを供給する。全主定理の合成とは数えない。",
"O043":"部分。全244pureで全ts/es/rs/ws/Ψ/a/eを同じδへ逆転した。全core通常型を収集した。既存四像/Transportと二実引数の依存結果/効果を保持し、全Programの合成は別である。",
"O046":"部分。元328署名の分類を保持し、新たなmono93署名の引数名・全入力型・結果型・効果・範囲をStandardOrdinarySignatureChecksで照合した。数値の既存関係を保持し、区間/returned/failed/第一失敗は元担当のままである。",
"O048":"部分。244 pureの型/Ground/Adequateを供給した。対象付きFile6/Http.sendInは328外である。全対象/endpoint/IOの新証明と混同しない。",
"O058":"部分。全244同δ応答とcore84本の通常本体を接続した。正常篩は既存の含意の不足で試行を停止した。主保存・Step/Steps/Runsを変えず、正常関係を未検査の欄へ足さない。",
"O059":"部分。244 APIの具体応答存在/型/Ground/Adequate/非exitとcore通常型を供給した。未接続通常APIは0。全モデル/全step_soundと追加Sの全閉鎖は別である。",
"O062":"部分。全244行から同じret/e/応答/Ground/Adequateを回収し、Decimal.fromFloatの実bits由来parsed供給も閉じた。正常篩7公開行・内部helperと精密getter9は未完である。",
"O065":"部分。全328原署名をpure244/core84の通常契約へ接続した。pureは全型/行/範囲/値引数を保持する。73実演算子とEquality satを保つ既存partialを保持し、全Program/全モデルの充足とはしない。",
"O080":"部分。固定Rowからの実変更0。篩付きmapFrom/mapのtelは形成と含意の反モデルの試行に限り、採用しない。R40へ採用済みの書換本体はなく、元のget/callback/加算/append/再帰を保つ。通常coreの全84本を型付けた。",
"O124":"部分。七整数幅のparse/toString/toFloat21行と別名ラッパー51行を通常契約へ接続した。Decimal.fromFloatの同bits由来parsedも閉じた。既存Some/None・幅・整数性の数学関係を保持し、全別名の動的な関係は別である。",
"O125":"部分。Byte全実名とBytes全16実名を通常契約へ接続した。UnsignedInteger8の別名本体も接続した。byte範囲・数学長・資源上限を分け、既存の同byte列関係を保持する。",
"O126":"部分。Characterの残10実名を固定Rust/Unicode17の有限な分類/大小変換の具体計算へ接続した。既存scalar変換・比較を保持し、実Rustとの全交換は未実施である。",
"O127":"部分。Stringの残26行を同じ入力からの具体計算へ接続した。characters/fromCharacters・UTF-8元境界・Σ文脈・文字列全体の幅を含む。通常型契約と全Unicode算法の交換の証明を区別する。",
"O128":"部分。Float二幅の残る丸め/絶対値/平方根12行、表記/解析/幅変換を全BuiltinArgsへ接続した。透明な固定Lean Modelと具体桁生成を使う。全bitのRust/Lean交換を証明済みとは数えない。",
"O129":"部分。Decimal全実名を通常契約へ接続した。同bitsの最短十進表記からfromFloatのparsedを計算し、既存再検査出口と等しいことを示した。五丸め等の既存関係は保持する。",
"O130":"部分。Stringの二長と既存related_responseを保持する。残26行も通常契約へ接続した。Integer表現外の長さ/幅のerrを残す。",
"O131":"部分。Listの残8純粋行と残5通常coreを接続し、全通常契約を収集した。head/tail/get/take/drop/contains/sort/rangeを具体計算する。map/filterの正常篩は含意の不足で未完である。",
"O132":"部分。Bytes全16実名の通常応答を接続した。二進/十六進・切出し・結合・ByteOrderの整数読み書きを含む。既存fromList/toList/lengthの同列関係を保持する。",
"O133":"部分。Mapの十pureとmap/filter/fold/forEachの通常本体を収集した。鍵の既済み証拠を保持する。map/filterの正常篩は含意の不足で未完である。",
"O134":"部分。Setの十pureとmap/filter/fold/forEachの通常本体を収集した。Set.mapに大きさの等式を足さない。map/filterの正常篩は未完である。",
"O135":"部分。recordの不変欄とdecode済みResultの本体の既済みを保持する。通常decodeから精密事実を得る全接続は、篩付きの呼出し署名の不足で未完である。CallRunは作らない。",
"O138":"部分。Optionの二枝・実本体型付けと短い実Stepsを保持する。FirstReturnと二つの反例を残す。正常関係をtelで読む方針は合意済みで、mapFromのDef.WellTypedは含意不足で未完である。",
"O142":"部分。安全な全19Annotationと安全9本のBodyTypedを保持する。通常Range13/NonEmptyList5は原nominal署名の本体を同じ有限P/Bで閉じた。精密getter9と強いNonEmptyList.mapは未完である。",
"O143":"部分。同じCheckedIndex/同長の内部契約は変更しない。精密getter9行は開いた束縛と欄の等号の規則を要する経路で停止し、影響をresultsへ記録した。通常getter12本と公開射影12本の型付けを、その精密な証明に代用しない。",
"O144":"部分。全328通常契約をpure244/core84へ接続し、再開2の179未接続は0になった。109同ws/outと床14leaf等の既存追加関係を保持する。正常篩7・精密getter9・全APIの意味/全モデル/段末独立レビューは閉じていない。",
"O160":"運用。最初のByte.toStringを含む短い実績から残り178行の見込みを積み上げ直した記録を保持する。各型の実装/検査時刻を保存し、全179完了の実績と未完の精密契約を分ける。",
"O016":"共通。累積268新モジュールを既定importへ追加した。全private/生成宣言を含む群末公理監査と全体照合の結果はresults/checks/verification-r2へ記す。局所成功を独立レビューとしない。",
"O027":"共通。再開2の既定buildは全てformal/から対象/optionなし、単独Leanは-M 12288。再開1の対象指定23件の記録を保持し、新たな逸脱0。群末workを指定baseと絞込みなしで一度実行し、結果をresultsへ記す。",
"O084":"共通。通常328行の局所F06、追加関係、全義務/全APIの閉鎖を分ける。全体closed O/APIは0。正常篩とgetterは独立未完として保持し、L50/L60/R40/R50へ送って完了と数えない。正式独立レビューと受け入れは未実施である。",
"O118":"共通。新モジュールと現在の局所契約を01-12/07-04へ反映した。元Source328、mono93照合、全入力と時刻の根拠を改造内へ保存した。本番の工程ID・絶対パス・一時領域への恒久リンクを追加しない。"
}
def main():
 p=HERE/"obligations.md"
 old=p.read_text()
 if not (HERE/"obligations-r1.md").exists():(HERE/"obligations-r1.md").write_text(old)
 rows=[]
 for line in old.splitlines():
  m=re.match(r"^\| (O\d{3}) \|",line)
  if not m:continue
  cols=line.split("|")
  if m[1] in updates:cols[3]=" "+updates[m[1]]+" "
  cols[-2]=cols[-2].replace("L40分の段末レビュー。","L40分の段末レビュー。")
  rows.append("|".join(cols))
 assert len(rows)==64
 p.write_text("# 義務64行の再開2の判定\n\n初回と再開1の判定は[旧判定](obligations-r1.md)に保持する。再開2で通常179行を全て接続し、全328行の通常分類はpure244/core84、未接続0となった。正常篩は既存含意の不足で指定どおり停止し、精密getter9行は規則を変えずに未完として残した。固定Row・安全19契約・主な十言明・Step/Steps/Runs・FirstReturnと二反例を保持する。全義務と全APIの意味の閉鎖、正式独立レビューと設計者の受け入れは別である。群末検査の確定値は[結果](results.md)と検査JSONに記す。\n\n| 義務 | detailの単位 | Eの判定と証拠 | L40後の境界 |\n|---|---|---|---|\n"+"\n".join(rows)+"\n")
if __name__=="__main__":main()

