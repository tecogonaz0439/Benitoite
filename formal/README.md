# formal

形式検証の段階 2 の Lean 4 のプロジェクトである。設計書の[コア計算と脱糖](../docs/design/01-spec/01-12-core-calculus.md)の規則を Lean で定義し、進行と保存・エフェクトの健全性と、脱糖の型の保存（形式化した範囲）を証明する。あわせて、型検査が使う網羅性の判定の手順の健全性と、表層の型付けを計算する検査の関数の健全性を証明し、処理系の判定と型検査の出力をこれらと比べる（段階 E）。対象、進め方、仮定、01-12 との対応は[形式意味論と検証](../docs/design/07-quality/07-04-formal-semantics.md)で定める。形式化した規則は、ここの Lean の定義を正とし、01-12 の規則はその写しである（07-04「01-12 との対応」。段階 2 を終えるまでは 01-12 を正としていた）。形式化した規則を変えるときは、Lean の定義と 01-12 の写しを同じ変更で直し（判断の理由は改造のディレクトリと 01-12 に書く）、`lake build` が `sorry` なしで通ることを確かめる。

## 検査

```sh
cd formal
lake build
```

Lean の版は `lean-toolchain` で固定している。ツールチェーンは elan が導入する。`lake build` は、証明を省いた箇所（`sorry`）を警告として示す。

Lean の脱糖と処理系の脱糖の差分テストと、段階 E の検査（07-03「差分テスト」）は、リポジトリの根で次のように走らせる。`lake build`、実行ファイル（`desugarDiff`・`builtinCheck`・`coverageDiff`・`coverageProgramDiff`・`surfaceCheckAll`）のビルド、処理系の書き出し（`crates/benitoite/tests/desugar_export.rs`・`coverage_export.rs`）、比較を順に行い、一致・既知の差・不一致・対象外の数を示す（全体で約 9〜10 分）。結果は `target/desugar-diff/` と `target/coverage-diff/` に置く（`BENITOITE_DESUGAR_DIFF_DIR`・`BENITOITE_COVERAGE_DIFF_DIR` で変えられる）。

```sh
scripts/check-formal.sh
```

定理が仮定する公理は、次のように確かめる。Lean の標準の公理（`propext`・`Quot.sound`・`Classical.choice`）のほかに `sorryAx` などが現れたら、証明が完了していない。

```sh
cat > /tmp/axioms.lean <<'LEAN'
import Benitoite
open Benitoite.Core
#print axioms progress
#print axioms preservation
#print axioms effect_soundness
#print axioms step_sound
#print axioms step_complete
open Benitoite.Release
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Release.useful_none_sound
#print axioms Benitoite.Release.checkMatch_exhaustive_sound
#print axioms Benitoite.Release.irrefutable_sound
#print axioms Benitoite.Release.checkMatch_unreachable_sound
#print axioms Benitoite.Release.checkMatch_unreachable_runtime
#print axioms Benitoite.Release.checkMatch_unreachable_runtime_of_C_Match
#print axioms Benitoite.Surface.Check.checkExpr_sound
#print axioms Benitoite.Surface.Check.checkBlock_sound
#print axioms Benitoite.Surface.Check.checkArms_sound
#print axioms Benitoite.Surface.Check.checkClauses_sound
#print axioms Benitoite.Surface.Check.checkTypes_sound
#print axioms Benitoite.Surface.Check.checkEach_sound
#print axioms Benitoite.Surface.Check.checkHoleArgs_sound
#print axioms Benitoite.Surface.Check.checkDict_sound
#print axioms Benitoite.Surface.Check.checkDicts_sound
#print axioms Benitoite.Surface.Check.checkDef_sound
#print axioms Benitoite.Surface.Check.checkImpl_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_empty
LEAN
lake env lean /tmp/axioms.lean
```

## 状態

段階 A は 2026-09-30 に完了した。`Core/Theorems.lean` の五つの定理に `sorry` はなく、使う公理は `propext` と `Quot.sound` だけである。

段階 B1 は 2026-09-30 に完了した（コミット 1a208b8）。段階 B2 も 2026-09-30 に完了した。段階 B2 は、段階 B1 の定義と証明を `Benitoite.Release` で広げたものである。`Release/Theorems.lean` の四つの定理に `sorry` はなく、使う公理は `propext`・`Classical.choice`・`Quot.sound` だけである。

脱糖の型の保存（性質 1）の段階 C1・C2 は 2026-10-10 に完了した。`Surface/Theorems.lean` の二つの定理（`desugar_typed`・`surface_effect_soundness`）に `sorry` はなく、使う公理は段階 B と同じである。段階 C4（`try`・`with`・`lazy`・ハンドラ・`resume`・利用者の操作）は 2026-10-10 に完了した。段階 C5（型クラス）も 2026-10-10 に完了した。段階 C6（`Decimal` のリテラル・リストの展開・文字列補間・レコード・トップレベルの定数）も 2026-10-10 に完了した。段階 C7（`match` のパターンの拡張: 選択肢・ガード・範囲のパターン・リストのパターン）も 2026-10-10 に完了した。段階 C7 は `Release` の `match` を選択肢とガードを持つ形に置き換え、性質 2・3 の証明を直した（定理の言明は変えていない）。旧来の選択肢もガードもない `match` は `Release` から消し、照合の構成を一つにした（段階 A の `Core` には残る）。表層のすべての照合は、この `match` に脱糖する。

段階 E1（網羅性の判定の手順）は 2026-10-10 に完了した。`Release/Coverage.lean` が 02-05「本体の後の検査」の有用性の手順を定義し、補題 U（`useful_none_sound`）と、その系の網羅性（`checkMatch_exhaustive_sound`）・必ず照合するパターン（`irrefutable_sound`）・選ばれない選択肢（`checkMatch_unreachable_sound`）を証明する。`Release/Lemmas/CoverageRuntime.lean` は、選ばれない選択肢を実行の規則の照合に結ぶ系（`checkMatch_unreachable_runtime`・`checkMatch_unreachable_runtime_of_C_Match`）を証明する。手順は、同じ分岐の左の選択肢を分岐のガードの有無によらず前の行に数え、処理系と違う（07-04「01-12 との対応」。docs/todo の TODO-178）。段階 E2（型検査の出力の検査）も 2026-10-10 に完了した。`Surface/Check.lean` が表層の型付けを計算する検査の関数を定義し、`Surface/CheckSound.lean` が健全性の 11 件を、`Surface/CheckProgramSound.lean` がプログラム全体の検査の健全性（`checkProgram_sound`・`checkProgram_empty`）を証明する。段階 E の定理に `sorry` はなく、使う公理は段階 B と同じである。段階 B・C の定義と定理は変えていない。

## 構成

| ファイル | 内容 | 01-12 の節 |
|---|---|---|
| `Benitoite/Core/Syntax.lean` | 型・値・計算・パターン・定義 | 構文 |
| `Benitoite/Core/Subst.lean` | 型とエフェクトの置き換え、値の置き換え、パターンの照合 | 構文、実行の規則の `match(p, V)` |
| `Benitoite/Core/Typing.lean` | 型の包含、パターン・値・計算の型付け、網羅性、組み込みの関数の型 | 型付け規則 |
| `Benitoite/Core/Semantics.lean` | 抽象機械の状態と遷移、遷移を計算する関数、継続と状態の型付け | 実行の規則、確かめる性質 |
| `Benitoite/Core/WellFormed.lean` | 定義が宣言した型パラメータとエフェクト変数だけを使うこと、エフェクト変数を含まないこと | （番号で表したために要る条件） |
| `Benitoite/Core/Assumptions.lean` | 組み込みの関数について仮定する性質 | 07-04「形式化で仮定するもの」 |
| `Benitoite/Core/Theorems.lean` | 段階 A の定理（`step` と `Step` の一致、進行、保存、エフェクトの健全性）と証明 | 確かめる性質 |
| `Benitoite/Core/Lemmas/Basic.lean` | エフェクトの集合と型の包含の補題 | |
| `Benitoite/Core/Lemmas/Inversion.lean` | 型付けの逆転（V-Sub・C-Sub を通した後の、元の規則の前提の取り出し） | |
| `Benitoite/Core/Lemmas/Rename.lean` / `SubstTyping.lean` | 番号の付け替えと値の置き換えで型付けが保たれること | |
| `Benitoite/Core/Lemmas/Compose.lean` / `TySubst.lean` | 型とエフェクトの置き換えの合成と、置き換えで型付け・網羅性が保たれること | |
| `Benitoite/Core/Lemmas/Canonical.lean` | 閉じた値の形、分岐の選択、パターンの照合が束縛する値の型 | |
| `Benitoite/Core/Lemmas/Preservation.lean` | エフェクトの条件を記録する状態の型付け `StateTyQ` と、その保存 | |
| `Benitoite/Core/Examples.lean` | 小さなプログラムの実行の例（`decide` で期待と比べる） | 実行の規則 |

段階 B（`Benitoite/Release/`）は、段階 A の定義を写して初回リリース版の拡張を加えたものである。段階 B2 は、段階 B1 の定義に `Map`・`Set`・`Bytes` と型クラスの辞書（高カインド型を含む）を加える。

| ファイル | 内容 | 01-12 の節 |
|---|---|---|
| `Benitoite/Release/Syntax.lean` | 型・値・計算・節・定義・宣言（型の変数は内側から数えた番号） | 構文、初回リリース版の拡張 |
| `Benitoite/Release/Subst.lean` | 型の番号のずらしと置き換え、値の置き換え、パターンの照合（範囲とリストを含む）、分岐の選択肢の照合 `firstAlt` と束縛の並べ替え `selectSlots`、網羅性に数えるパターン `unguardedPats` | 構文、実行の規則 |
| `Benitoite/Release/Typing.lean` | 組み込みの関数の型と制約、操作の型、型の正しさ、値・計算・節の型付け（選択肢の型付け `AltsTy`、分岐の型付け `HasTypeArms`） | 型付け規則、初回リリース版の拡張 |
| `Benitoite/Release/WellFormed.lean` | 型とエフェクトの変数の範囲、宣言の範囲 | （番号で表したために要る条件） |
| `Benitoite/Release/Semantics.lean` | 状態（照合の途中の状態 `matchRun` を含む）・遷移・遷移を計算する関数、継続（ガードの枠 `guardF`）・ストア・状態の型付け | 実行の規則、確かめる性質 |
| `Benitoite/Release/Assumptions.lean` | 組み込みの関数について仮定する性質、エフェクトの宣言の整合 | 07-04「形式化で仮定するもの」 |
| `Benitoite/Release/Theorems.lean` | 段階 B の定理（`step_sound`、進行、保存、エフェクトの健全性）と証明 | 確かめる性質 |
| `Benitoite/Release/Examples.lean` | 小さなプログラムの実行の例 | 実行の規則 |
| `Benitoite/Release/Model.lean` | 仮定を満たす組み込みの関数の例と、定義を持たないプログラムと型クラスの実装を持つプログラムでの定理の使用例（仮定と前提が矛盾しないことの確認） | 07-04「形式化で仮定するもの」 |
| `Benitoite/Release/Lemmas/Basic.lean` / `Inversion.lean` | エフェクトの集合と型の包含の補題、型付けの逆転 | |
| `Benitoite/Release/Lemmas/Rename.lean` / `SubstTyping.lean` | 番号の付け替え・ストアの型付けの拡大・値の置き換えで型付けが保たれること | |
| `Benitoite/Release/Lemmas/TyLemmas.lean` / `Regularity.lean` / `OuterC.lean` | 型の番号のずらしと置き換えの補題、型付けの結果の型が正しいこと、制約の並びの拡大 | |
| `Benitoite/Release/Lemmas/TySubst.lean` / `TySubstMain.lean` / `Closed.lean` | 型とエフェクトの置き換えで型付けと変数の範囲が保たれること | |
| `Benitoite/Release/Lemmas/Canonical.lean` | 閉じた値の形、分岐の選択、パターンの照合が束縛する値の型 | |
| `Benitoite/Release/Lemmas/ContLemmas.lean` / `StoreLemmas.lean` | 継続の型付けの逆転・分割・連結、`releases`、ストアの更新 | |
| `Benitoite/Release/Lemmas/PresHelpers.lean` / `Preservation.lean` / `PresBase.lean` / `PresMain.lean` | 継続の末尾のエフェクトを固定した状態の型付け `StateTyE` と、その保存 | |
| `Benitoite/Release/Lemmas/Dict.lean` | 実装のメソッドの型の置き換えの合成、E-Super の一歩が型を保つこと | |
| `Benitoite/Release/Lemmas/Progress.lean` / `EffectSound.lean` / `StepSound.lean` | 進行、エフェクトの健全性、`step` の健全性 | |

段階 C（`Benitoite/Surface/`）は、型の情報を付けた表層の構文と、`Benitoite.Release` への脱糖を定め、脱糖の型の保存（性質 1）を証明する。段階 B の定義と証明は変えない。ただし段階 C7 は、パターンの拡張をコア計算に加えるために、`Release` の `match` を置き換えて性質 2・3 の証明を直した。

| ファイル | 内容 | 01-12 の節 |
|---|---|---|
| `Benitoite/Surface/Syntax.lean` | 型の情報を付けた表層の構文（局所の束縛は内側から数えた番号。分岐の選択肢 `Alternative`・ガード、パターンの条件 `Pattern.Valid`）、必ず抜ける文、宣言、フィールドを取り出す関数の表と名前の検索 `lookupFun` | 型の情報を付けた表層の構文と型付け |
| `Benitoite/Surface/Typing.lean` | 表層の型付け、プログラムの入口の条件 | 型の情報を付けた表層の構文と型付け |
| `Benitoite/Surface/WellFormed.lean` | 型・エフェクト・局所の束縛の番号の範囲、レコードの条件 `RecordsOk` | （番号で表したために要る条件） |
| `Benitoite/Surface/Desugar.lean` | 脱糖の関数（表の行ごとに一つの場合） | 表層からの脱糖 |
| `Benitoite/Surface/Theorems.lean` | 性質 1（`desugar_typed`）と、性質 3 と組み合わせた表層の形（`surface_effect_soundness`） | 確かめる性質 |
| `Benitoite/Surface/Examples.lean` | 表の行ごとの脱糖の例（`rfl`）と、脱糖したプログラムの実行の例 | 表層からの脱糖 |
| `Benitoite/Surface/Lemmas/Invariants.lean` / `ShiftClean.lean` / `ScopedRename.lean` / `Scoped.lean` | 環境の型の不変条件（普通の値の型は継続の型を含まず、節の継続の変数は引数と結果の型が範囲内）、型のずらしが範囲を保つこと、番号の付け替えと脱糖が範囲を保つこと | |
| `Benitoite/Surface/Lemmas/Dict.lean` / `SubstClean.lean` / `CallHead.lean` | 辞書の根拠の型付けを継続を隠した環境へ移すこと、任意の位置の型の置き換えが範囲を保つこと、制約を持つ関数とメソッドの名前の型付けの逆転と呼び出しの頭の型付け | |
| `Benitoite/Surface/Lemmas/Calls.lean` / `Patterns.lean` | 呼び出しの組み立ての型付けと範囲、パターンの型付けと網羅性を構成子の表の等しいプログラムの間で移すこと、パターンの束縛の下での弱化 | |
| `Benitoite/Surface/Lemmas/Sequence.lean` / `Typing.lean` / `Program.lean` | 引数の並びの `let` と番号、式・ブロックの型の保存、プログラム全体の三つの性質と入口の型付け | |
| `Benitoite/Surface/Lemmas/Extensions.lean` / `ExtensionsScoped.lean` | リストの展開と文字列補間が加える `let` と、断片・式・呼ぶ値の並びの型付け、型の変数とエフェクト変数の範囲の保存 | |
| `Benitoite/Surface/Lemmas/Records.lean` | レコードの位置の並べ替え、更新とフィールドを取り出す関数のパターンの束縛の番号と網羅性、取り出す関数の定義の型付け | |
| `Benitoite/Exchange/Syntax.lean` / `Convert.lean` | 脱糖の差分テストの交換用の表現（JSON）と、表層の構文・`Release` の項との変換 | |
| `DesugarDiff/Main.lean` | 脱糖の差分テストの実行ファイル（`lakefile.toml` の `lean_exe desugarDiff`） | |

段階 E1（網羅性の判定の手順）は `Benitoite/Release/` に、段階 E2（型検査の出力の検査）は `Benitoite/Surface/` と `Benitoite/Exchange/` に、新しいファイルとして加えた。

| ファイル | 内容 | 01-12 の節 |
|---|---|---|
| `Benitoite/Release/Coverage.lean` | 有用性の手順（型ごとの構成子、特殊化、燃料）、`match` の判定 `checkMatch`（網羅していないときの反例、選ばれない選択肢、覆っている分岐）と束縛の文の判定 `irrefutable`、補題 U と系、手順の例 | 型付け規則の C-Match の網羅性（02-05「本体の後の検査」の正） |
| `Benitoite/Release/CoverageShow.lean` | 反例を処理系の診断と同じ文字列にする関数と例 | |
| `Benitoite/Release/Lemmas/CoverageRuntime.lean` | 選ばれない選択肢を、実行の規則の照合（`firstAlt` と分岐の順）に結ぶ系 | 実行の規則の `match` |
| `Benitoite/Release/BuiltinTable.lean` | 宣言から等値の型・鍵の型の要約を求める計算と、組み込みの制約の判定 | （01-06 の組み込みの制約） |
| `Benitoite/Surface/Check.lean` | 表層の型付けを計算する検査の関数（最小の型とエフェクト、失敗の箇所と理由） | 型の情報を付けた表層の構文と型付け |
| `Benitoite/Surface/CheckTools.lean` / `CheckSupport.lean` | 原子の有限の集合の上のエフェクトの包含と型の等しさの判定、型の結び、エフェクトの差、原子の集合の前提 | |
| `Benitoite/Surface/CheckPatterns.lean` / `CheckPredicates.lean` | パターンの束縛の型の計算と網羅性の判定の包み、型付けの判断以外の前提の判定 | |
| `Benitoite/Surface/CheckInduction.lean` / `CheckLemmas.lean` | 健全性の相互帰納法の契約と、成功した検査の分解の補題 | |
| `Benitoite/Surface/CheckSoundBasicExpr.lean` / `CheckSoundCalls.lean` / `CheckSoundCollections.lean` / `CheckSoundControl.lean` / `CheckSoundDicts.lean` / `CheckSoundSequence.lean` | 構文の場合ごとの健全性の証明 | |
| `Benitoite/Surface/CheckSound.lean` | 検査の関数の健全性の 11 件 | |
| `Benitoite/Surface/CheckTables.lean` / `CheckTablesSound.lean` / `CheckProgramSound.lean` | 有限の宣言の材料から検査の入力の表を作る関数と、その前提の証明、プログラム全体の検査と健全性（`CheckedUnder`） | |
| `Benitoite/Surface/CheckExamples.lean` / `CheckToolsExamples.lean` / `CheckCounterexamples.lean` | 検査の関数と判定の例、docs/todo の TODO-178 の型検査の誤りを検査の関数が拒否する例 | |
| `Benitoite/Exchange/Builtins.lean` / `CheckInput.lean` | 組み込みの関数とデータ型の宣言の交換用の表現と具体的な組み込みの関数の欄、型検査の出力の検査の入力（原子の集合を含む）の読み込み | |
| `BuiltinCheck/Main.lean` | 組み込みの関数の表の検査の実行ファイル（`lean_exe builtinCheck`） | |
| `CoverageDiff/Main.lean` | 網羅性の手順の差分テストの実行ファイル（`lean_exe coverageDiff`） | |
| `CoverageProgramDiff/Main.lean` | 型検査を通ったプログラムの網羅性の確かめの実行ファイル（`lean_exe coverageProgramDiff`） | |
| `SurfaceCheck/` | 型検査の出力の検査の実行ファイル（一つの入力の `lean_exe surfaceCheck`、全入力の `lean_exe surfaceCheckAll`）、末尾位置の `match` の注釈の置き換え、結果の分類とその確かめ | |

定義の名前は 01-12 の規則の名前に対応させる（規則 `E-Return` は構成子 `Step.E_Return`、規則 `C-Sub` は `HasTypeC.C_Sub`、規則 `K-Let` は `ContTy.K_Let`）。

## 証明の構成

- 進行は、型の付いた閉じた値が網羅性の `Inhabits` を満たすこと（`HasTypeV.inhabits`）と、真偽値の型の閉じた値が定数であること（`HasTypeV.canonical_boolean`）から導く。進行の証明は `Program.WellFormed` と `Program.WellTyped` を使わない（呼び出す関数の定義があれば E-Fun で遷移できる）。
- 保存の E-Fun の場合は、型とエフェクトの置き換えで型付けが保たれること（`HasTypeC.substTy`）を使う。この補題が、`Program.WellFormed` と `Builtins.Assumptions` の `sig_scoped`・`admits_subst` を使う。
- エフェクトの健全性は、`preservation` だけからは導けない。エフェクトの集合の条件 `Q` を引数に取る状態の型付け `StateTyQ` を定め、`Q` が部分集合について閉じていれば遷移で保たれることを示した（`preservationQ`）。`Q` をどの集合でも成り立つ条件にすると保存が、「`IO` を含まない」にするとエフェクトの健全性が得られる。

段階 B1 の証明の構成:

- 保存は、継続の末尾で許すエフェクト Eb を固定した状態の型付け `StateTyE` について示す（`preservationE`）。Eb は遷移で変わらない。
- E-Fun と E-Op の場合は、型の置き換えで型付けが保たれること（`HasTypeC.substTy`）を使う。E-Op は、継続を処理する `handle` の枠で分け（`ContTy.split`）、捕えた継続をストアに置く。E-Resume は、捕えた継続といまの継続をつなぐ（`ContTy.resume_append`）。
- 進行では、どの `handle` の枠も処理しない利用者の操作の呼び出しが起きないことを、Eb が組み込みのエフェクトの名前だけであることから導く（`no_unhandled_user`）。
- エフェクトの健全性は、Eb を空として実行を始め、到達するどの状態でも Eb が空であることから導く。解放の枠は `State` を要し、IO の関数は組み込みのエフェクトを要するので、Eb が空の状態は事象を伴う遷移をしない（`no_event`）。

段階 B2 の証明の構成:

- 型の置き換えで `α[Ā]` の α を型構成子に置き換える `Ty.applyTo` は、型の置き換えとずらしと入れ替えられる（`Ty.substAt_applyTo`・`Ty.shift_applyTo`）。型の種類が合わない場合も成り立つので、種類の検査は要らない。
- 保存の E-Meth の場合は、実装のメソッドの本体に `S̄ ++ T̄` の置き換えを施した型が、C-Meth の型と等しいこと（`ImplDecl.methTy_subst`・`ImplDecl.dictTys_subst`）を使う。E-Super の場合は、上位の型クラスの辞書に型が付くこと（D-Impl）から、取り出した辞書の型を導く（`superStep_typed`）。
- 進行では、辞書の型の閉じた値が、実装の辞書か、E-Super で `↑` を一段取り出せる値であること（`HasTypeV.canonical_dict`）を示す。実装の定義がメソッドの本体と上位の型クラスの辞書を持つことは D-Impl から導くので、進行の証明は `Program.WellTyped` を使う。

## レビュー

定義と言明のレビューの依頼と回答は、改造のディレクトリの `reviews/` に置き、改造を終えたら改造のディレクトリと一緒に `docs/archive/` へ移す。これまでの記録は次の場所にある。段階 A・B は `docs/archive/2026-10-09-implement-first-release/formal-reviews/`、段階 C1〜C3 は `docs/archive/2026-10-09-TODO-162-desugar-formalization/reviews/`、段階 C4〜C7 は `docs/archive/2026-10-10-TODO-162-desugar-formalization-phase2/reviews/`、段階 E1・E2 は `docs/archive/2026-10-10-TODO-162-desugar-formalization-phase3/reviews/`。これらの記録に残る ADR・OPEN の番号は、初回リリース版の設計書の写し（`docs/archive/2026-10-09-design-first-release/` の `decisions/` と `open-issues.md`）を指す。


レビューでは、定義が変更の理由と 01-12 の規則の意図と一致すること、01-12 の写しが定義と一致すること、定理の言明が 01-12 の性質と一致すること、仮定が 07-04 に挙げたものに限られることを確かめる。証明の本体は、`lake build` を通ればレビューしない（07-04「レビューと、見つかった誤りの扱い」）。
