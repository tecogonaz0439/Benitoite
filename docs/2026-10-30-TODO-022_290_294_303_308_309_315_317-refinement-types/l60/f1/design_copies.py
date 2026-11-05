# -*- coding: utf-8 -*-
"""01-12・07-04の写しに加えた置換の組（変更前の文、変更後の文）の表。ファイルを書き換えない。
verify.py が、各組の変更後の文を変更前の文へ戻すと開始時のハッシュに一致することを照合する。"""
PAIRS = []
p = "docs/design/01-spec/01-12-core-calculus.md"
old = "合成表で参照と明示遅延の種類を持つ行はReference.getとReference.setの二行だけであり、ModelTargetsの同じ署名を持つ（`StandardModel.store_lookup`）。合成表はReference.new・Reference.update・Lazy.forceの種類の行を持たない（`no_store_transitions`）。`StandardModel.store_shape` はPathBases以外の全署名が参照と明示遅延の形を満たすことを、`ref_get`・`ref_set` は取得・設定の名前の解決を、`reference_rows` は二行の型引数の種類が `[value]` であること、元の依存列の行の上限と操作の効果がないことを示す。"
new = "合成表で参照と明示遅延の種類を持つ行は、Reference.get・Reference.set・Reference.new・Reference.update・Lazy.forceの五行である（`StandardModel.Primitive.store_rows`）。取得・設定の二行はModelTargetsの同じ署名を持ち（`StandardModel.store_lookup`）、作成・更新・明示遅延の評価の三行は `refNewSig`・`refUpdateSig`・`forceSig` の署名を持つ（`store_transitions`）。三行はδ・IO応答を持たず、実行は `E_RefNew`・`E_RefUpdate`・`E_ForceDone`・`E_Force` が受け持つ。`StandardModel.store_shape` はPathBases以外の全署名が参照と明示遅延の形を満たすことを、`ref_get`・`ref_set` は取得・設定の名前の解決を、`reference_rows` は五行の型引数の種類が `[value]` であること、元の依存列の行の上限と操作の効果がないことを示す。"
PAIRS.append((p, old, new))
anchor = "篩型は `Ty.refined a p` で表す。"
add = """`StandardModel.PureRow P b` は、合成表の名前bについて、`delta_typed` と同じ形の契約である。合成表のlookupが返す署名と、その署名の全 `BuiltinArgs` から、合成表のδが非exitの型付きの応答を返し、その応答が適格であることを表す。`PureRow.of_row` は、組込みの表の行（`StandardModel.Primitive`）の出典の表のδが行の署名の全 `BuiltinArgs` で型付きの応答を返すとき、合成表の同じ名前の契約を返す。`first_sixteen` は、演算子の表の並びの最初の十六行（七整数型のdiv/modとFloatのadd/subtract）を、任意のPで既存の `StandardOperatorResponse.response` へ接続する。`numeric_rows` は、数値の公開モジュール（Byte・Character・Float・Float32・Decimal・Integerと各幅）の全166行を、`operator_rows` は、%で始まる組込みの行から %Map.replaceValues・%eq・%ne を除いた107行と全構造値の %eq/%ne の2行（計109行）を、それぞれ同じ契約へ接続する。各行の証拠は既存の任意のP/Bの応答か、合成プログラムが供給する宣言の下の応答であり、部分表の `table_response` を使わない。合成プログラムは丸めの五方式の宣言 `StandardModel.roundingMode` を持ち、`http_declarations` は範囲付きのHTTPのモデルが読むResult・ScopeError・Pair・要求・要求の誤りの構成子とarityを、`rounding_declarations` はDecimalの応答が読むOptionと五方式の宣言を示す。`PureRow.Satisfiable P b` は、名前bのlookupが返す署名の `BuiltinArgs` を満たす入力があることである。`numeric_inputs` と `operator_inputs` は、数値の166行と演算子の109行のそれぞれで、この前提を基本型の定数の引数列で満たす入力を示す。Decimal.roundは合成プログラムの丸め方式の構成子を、%eq/%neは型引数Integerを使う。これらは行ごとの契約であり、全ての純粋な行の `delta_typed` と合成表の全条件の充足とは区別する。

"""
PAIRS.append((p, anchor, add + anchor))
old = "`StandardDecimalResponse` はOptionとRoundingModeの同じ有限構成子表を使い、Decimal四行と整数へ返す二変換の六実名を全 `BuiltinArgs` から同じ `decimalDelta` へ接続する。"
new = "`StandardDecimalResponse.response_of` は、Optionの二構成子とarityを持ち、RoundingModeのデータ名を持つ構成子を既知の五方式に限るProgram（`StandardDecimalResponse.Declarations P`）で、Decimal四行と整数へ返す二変換の六実名を全 `BuiltinArgs` から同じ `decimalDelta` へ接続する。この条件は五方式の各構成子の存在を要求しない。`response` は五方式を全て宣言する同じ有限構成子表のPへの適用であり、合成プログラムも五方式を全て宣言する（`StandardModel.roundingMode`）。"
PAIRS.append((p, old, new))

p = "docs/design/07-quality/07-04-formal-semantics.md"
old = "合成表の参照と明示遅延の種類の行はReference.getとReference.setだけで、PathBases以外の全署名が参照と明示遅延の形を満たす。"
new = "合成表の参照と明示遅延の種類の行はReference.get・Reference.set・Reference.new・Reference.update・Lazy.forceの五行で、作成・更新・明示遅延の評価の三行はδ・IO応答を持たず専用の遷移が受け持つ。PathBases以外の全署名が参照と明示遅延の形を満たす。"
PAIRS.append((p, old, new))
old = "同じ名前に異なる元Defを持つ18名（`FunctionNames.collisionNames`）の公開名は合成表のキーに現れない。\n"
new = old + "\n`StandardModelPureRows`・`StandardModelNumericRows`・`StandardModelOperatorRows` は、合成表の名前ごとの `delta_typed` と同じ形の契約（`StandardModel.PureRow`）を、演算子の表の最初の十六行、数値の公開モジュールの全166行、演算子の107行と全構造値の %eq/%ne の2行について、既存の応答の証拠から示す。合成プログラムは丸めの五方式を宣言し、範囲付きのHTTPのモデルの宣言とDecimalの応答の宣言の条件を満たす。`StandardModelPureInputs` は、数値と演算子の各行で、lookupが返す署名の `BuiltinArgs` を満たす入力を基本型の定数で示す。全ての純粋な行の `delta_typed`、合成した全標準本体の型付けと合成表の全条件の充足は、これらの行の契約とは区別する。\n"
PAIRS.append((p, old, new))
old = "`StandardDecimalResponse` はOptionとRoundingModeの同じ有限構成子表を使い、Decimal四行と整数へ返す二変換の六実名を全 `BuiltinArgs` から同じ `decimalDelta` へ接続する。"
new = "`StandardDecimalResponse.response_of` は、Optionの二構成子とarityを持ち、RoundingModeのデータ名を持つ構成子を既知の五方式に限るProgram（`StandardDecimalResponse.Declarations P`）で、Decimal四行と整数へ返す二変換の六実名を全 `BuiltinArgs` から同じ `decimalDelta` へ接続する。この条件は五方式の各構成子の存在を要求しない。`response` は五方式を全て宣言する同じ有限構成子表のPへの適用であり、合成プログラムも五方式を全て宣言する（`StandardModel.roundingMode`）。"
PAIRS.append((p, old, new))
old = "| ScopeCoverage・MembershipTargets・ShapeTargets |"
new = "| StandardModelPureRows・StandardModelNumericRows・StandardModelOperatorRows・StandardModelPureInputs | 「篩を含むコア計算の形式化」。合成表の名前ごとの純粋な応答の契約、演算子の表の最初の十六行・数値の公開モジュールの166行・演算子の107行と構造の等号の2行への既存の応答の接続、各行の契約の前提を満たす入力、丸めの五方式とHTTPのモデルの共有の宣言 |\n" + old
PAIRS.append((p, old, new))
