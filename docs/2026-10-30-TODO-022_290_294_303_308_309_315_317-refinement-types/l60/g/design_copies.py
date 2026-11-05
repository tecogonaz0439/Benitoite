# -*- coding: utf-8 -*-
"""01-12・07-04の写しに加えた置換の組（変更前の文、変更後の文）の表。ファイルを書き換えない。
verify.py が、各組の変更後の文を変更前の文へ戻すと開始版 B_WORK の内容に一致することを照合する。"""
PAIRS = []
p = "docs/design/01-spec/01-12-core-calculus.md"
old = "`StandardModel.core externals` は任意の外部宣言について `Builtins.CoreAssumptions` の全28欄を、`targets` は `TargetAgreement` を、同じ合成プログラムと合成表で示す。これらはLeanの既存の証拠がある行の合成であり、Rustの全登録の意味の証明とは区別する。\n"
add = """
`collection_inputs`・`scope_inputs`・`io_inputs` は、文字列・バイト列・リスト・写像・集合の79行、範囲付きのパスと要求の六つの純粋な行と %List.getFront、IOと終了の10行のそれぞれで、合成表のlookupが返す署名の `BuiltinArgs` を満たす入力があること（`PureRow.Satisfiable`・`IORow.Satisfiable`）を示す。型引数はIntegerであり、引数の値は基本型の定数、空の列・バイト列・写像・集合、全体を許す範囲（`.absolute .top`）の下で保持したパスと要求である。結果型が引数の値を読む署名（head・tail・append・精密なMapとSetの構築と射影・%Map.replaceValues）では、全署名の形成（`sig_scoped`）と型の具体化から依存列の注釈を得て、引数の値を一つずつ束縛する。そのため `collection_inputs` は外部宣言の表の構造検証 `ExternalWF` を前提に取る。`substitution_inputs`・`admits_sat_input`・`io_field_inputs` は、置換の八欄・admits_sat・IOの四欄と `TargetAgreement` の前提を、Integerと鍵の制約を持つ型変数・Map.getの行・File.readTextInの行で満たす。`positive_inputs` は、外部関数 `0 < self` を一つ持つ外部宣言の表（`positiveExternals`）で、正常値1の生応答により外部応答の二欄の前提を満たし、同じ入力のerrの応答も同じ関係に属することを示す。`normal_facts` は、純粋な行の正常応答の項観測から結果型の篩の事実を返す。これらの定理は契約の前提を満たす入力の存在を示し、契約そのものは各行と各欄の定理が全入力について示す。
"""
PAIRS.append((p, old, old + add))

p = "docs/design/07-quality/07-04-formal-semantics.md"
old = "`program_typed` と `program_wellFormed` は外部宣言の表の構造検証を前提に取る。これらはLeanの既存の証拠がある行の合成であり、Rustの全登録の意味の証明ではない。\n"
add = "\n`StandardModelCollectionInputs`・`StandardModelIOInputs`・`StandardModelConditionInputs` は、合成表の文字列・バイト列・リスト・写像・集合の79行、範囲付きのパスと要求の6行と %List.getFront、IOと終了の10行の契約の前提と、28+1欄のうち置換の八欄・admits_sat・外部応答の二欄・IOの四欄と対象の条件の前提を、合成表の上の正常な入力が満たすことを示す。結果型が引数の値を読む行の入力は外部宣言の表の構造検証を前提に取り、外部応答の二欄の入力は外部関数を一つ持つ外部宣言の表で示す。純粋な行の正常応答の篩の事実も同じ表で読む。\n"
PAIRS.append((p, old, old + add))
old = "| StandardModelListBodies・StandardModelCoreBodies・StandardModelSafeBodies・StandardModelCollectionBodies・StandardModelProgram・StandardModelWellFormed | 同節。合成表の上の全130本体の型付け、格納された宣言の適格性、外部宣言の表の構造検証の下のWellTypedとWellFormed |\n"
add = "| StandardModelCollectionInputs・StandardModelIOInputs・StandardModelConditionInputs | 同節。合成表の純粋な行・IOと終了の行の契約と28+1欄の前提を満たす正常な入力、純粋な正常応答の篩の事実 |\n"
PAIRS.append((p, old, old + add))
old = "外部の関数を組み込みの関数の仮定の欄として与える実装は持たない |"
new = "外部の関数を組み込みの関数の仮定の欄として与える実装は持たない。Leanの側には外部の宣言表を読む型付けと表層の五つの接点の葉（`ExternalSurfaceLeaves`）、外部応答の存在と選択の葉（`ExternalLeafSelection`）があるが、書き出し器と比較の読者はこれらを読まず、この除外は外部型を含む元定義の区間の比較の除外（理由 `externalType`）とともに残る |"
PAIRS.append((p, old, new))

