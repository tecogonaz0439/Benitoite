# formal

形式検証の段階 2 の Lean 4 のプロジェクトである。設計書の[コア計算と脱糖](../docs/design/01-spec/01-12-core-calculus.md)の規則を Lean で定義し、進行と保存・エフェクトの健全性を証明する。対象、進め方、仮定、01-12 との対応は[形式意味論と検証](../docs/design/07-quality/07-04-formal-semantics.md)で定める。形式化した規則は、ここの Lean の定義を正とし、01-12 の規則はその写しである（ADR 0307。段階 2 を終えるまでは 01-12 を正としていた。ADR 0295）。形式化した規則を変えるときは、ADR を添えて Lean の定義と 01-12 の写しを同じ変更で直し、`lake build` が `sorry` なしで通ることを確かめる。

## 検査

```sh
cd formal
lake build
```

Lean の版は `lean-toolchain` で固定している。ツールチェーンは elan が導入する。`lake build` は、証明を省いた箇所（`sorry`）を警告として示す。

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
LEAN
lake env lean /tmp/axioms.lean
```

## 状態

段階 A は 2026-09-30 に完了した。`Core/Theorems.lean` の五つの定理に `sorry` はなく、使う公理は `propext` と `Quot.sound` だけである。

段階 B1 は 2026-09-30 に完了した（コミット 1a208b8）。段階 B2 も 2026-09-30 に完了した。段階 B2 は、段階 B1 の定義と証明を `Benitoite.Release` で広げたものである。`Release/Theorems.lean` の四つの定理に `sorry` はなく、使う公理は `propext`・`Classical.choice`・`Quot.sound` だけである。

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
| `Benitoite/Release/Subst.lean` | 型の番号のずらしと置き換え、値の置き換え、パターンの照合 | 構文、実行の規則 |
| `Benitoite/Release/Typing.lean` | 組み込みの関数の型と制約、操作の型、型の正しさ、値・計算・節の型付け | 型付け規則、初回リリース版の拡張 |
| `Benitoite/Release/WellFormed.lean` | 型とエフェクトの変数の範囲、宣言の範囲 | （番号で表したために要る条件） |
| `Benitoite/Release/Semantics.lean` | 状態・遷移・遷移を計算する関数、継続・ストア・状態の型付け | 実行の規則、確かめる性質 |
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

これまでのレビューの依頼と回答は `reviews/` に置く。


レビューでは、定義が変更の ADR と 01-12 の規則の意図と一致すること、01-12 の写しが定義と一致すること、定理の言明が 01-12 の性質と一致すること、仮定が 07-04 に挙げたものに限られることを確かめる。証明の本体は、`lake build` を通ればレビューしない（ADR 0295、ADR 0307）。
