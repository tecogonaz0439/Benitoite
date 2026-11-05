# -*- coding: utf-8 -*-
"""01-12・07-04の写しに加えた置換の組（変更前の文、変更後の文）の表。ファイルを書き換えない。
verify.py が、各組の変更後の文を変更前の文へ戻すと開始版 B_WORK の内容に一致することを照合する。"""
PAIRS = []
p = "docs/design/01-spec/01-12-core-calculus.md"
anchor = "篩型は `Ty.refined a p` で表す。"
add = """`StandardModel.program externals` の構成子表は、範囲付きのHTTPのモデルの宣言と丸めの五方式に加え、バイト列の整数の読み書きが読む二つのバイト順（`StandardModel.byteOrder`）を宣言する。写像と集合の鍵の符号化は、合成プログラムの全構成子の名前の並び（`StandardModel.constructorNames`）を読む。合成表は、安全な入口の本体が呼ぶ内部の組込み %List.getFront の行を持ち、その署名とδは `StandardSafe.frontSig` と `StandardSafe.frontDelta` である。`collection_rows` は文字列・バイト列・リスト・写像・集合の純粋な79行を、`scope_rows` は範囲付きのパスと要求の六つの純粋な行と %List.getFront を `PureRow` へ接続し、`pure_rows` は種類がpureの全361行の契約を返す。`io_rows` は、IOと終了の10行について、全 `BuiltinArgs` と全てのIO応答から、型付きで適格な結果・応答の種類・対象の条件と、応答の存在を示す。

`StandardModel.body_typed` は、任意の外部宣言について、全130本体（`Body.all`）が合成プログラムと合成表で型付くことを示す。各本体の証明は、元の本体の証明の構成を、合成プログラムの宣言・合成表の署名・写した関数参照の名前の上で閉じたものである。`definition_typed` は成功した全lookupの定義へ広げ、`program_typed` は外部宣言の表の構造検証 `ExternalWF` の下で `Program.WellTyped` を示す。`body_scoped` は全130本体の依存列の行と範囲の上限と本体の深さの条件を、`cons_scoped` は全構成子のデータ名のarityの一意性と欄の適格性を示し、`program_wellFormed` は `ExternalWF` の下で `Program.WellFormed` を示す。`StandardModel.core externals` は任意の外部宣言について `Builtins.CoreAssumptions` の全28欄を、`targets` は `TargetAgreement` を、同じ合成プログラムと合成表で示す。これらはLeanの既存の証拠がある行の合成であり、Rustの全登録の意味の証明とは区別する。

"""
PAIRS.append((p, anchor, add + anchor))

p = "docs/design/07-quality/07-04-formal-semantics.md"
old = "全ての純粋な行の `delta_typed`、合成した全標準本体の型付けと合成表の全条件の充足は、これらの行の契約とは区別する。\n"
new = old + "\n`StandardModelCollectionRows`・`StandardModelIORows`・`StandardModelCoreRows` は、合成表の種類がpureの全361行（文字列・バイト列・リスト・写像・集合の79行、範囲付きのパスと要求の6行と内部の %List.getFront を含む）の契約と、IOと終了の10行の応答・対象の条件を、既存の応答の証拠から同じ表で示す。合成プログラムはバイト順の二構成子を宣言し、写像と集合の鍵の符号化は合成プログラムの全構成子の並びを読む。`StandardModelSubstitution`・`StandardModelScoped` は制約と許容の八つの保存則と全377行の署名の形成を示し、`StandardModelCore` は任意の外部宣言について全28欄の `CoreAssumptions` と `TargetAgreement` を組み立てる。`StandardModelListBodies`・`StandardModelCoreBodies`・`StandardModelSafeBodies`・`StandardModelCollectionBodies`・`StandardModelProgram` は、元の本体の証明の構成を合成表の宣言・組込み・写した関数参照の名前の上で閉じて全130本体の型付けを示し、`StandardModelWellFormed` は格納された宣言の適格性を示す。`program_typed` と `program_wellFormed` は外部宣言の表の構造検証を前提に取る。これらはLeanの既存の証拠がある行の合成であり、Rustの全登録の意味の証明ではない。\n"
PAIRS.append((p, old, new))
old = "| ScopeCoverage・MembershipTargets・ShapeTargets |"
new = "| StandardModelCollectionRows・StandardModelIORows・StandardModelCoreRows・StandardModelSubstitution・StandardModelScoped・StandardModelCore | 「篩を含むコア計算の形式化」。合成表の種類がpureの全行とIO・終了の行の契約、制約と許容の保存則、全署名の形成、任意の外部宣言の全28欄のCoreAssumptionsとTargetAgreement |\n| StandardModelListBodies・StandardModelCoreBodies・StandardModelSafeBodies・StandardModelCollectionBodies・StandardModelProgram・StandardModelWellFormed | 同節。合成表の上の全130本体の型付け、格納された宣言の適格性、外部宣言の表の構造検証の下のWellTypedとWellFormed |\n" + old
PAIRS.append((p, old, new))
