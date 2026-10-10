C4a-2 の前半を実装しました。**`formal/` で `lake build` と `lake build desugarDiff` が成功**しています。`sorry` の字句は、ハンドラの節の本体の型保存に関わる **一か所だけ**です。コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

既存の 11 ファイルを変更しました。新規ファイルはありません。行数は作業終了時のファイル全体、追加・削除は `HEAD` との差分です。

| ファイル | 行数 | 追加／削除 | 変更内容 |
|---|---:|---:|---|
| [Surface/Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean) | 254 | +25／−6 | 操作名、`handle`、`resume`、節の相互帰納型、操作・エフェクト表 |
| [Surface/Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean) | 357 | +30／−2 | 三つの式の規則、節の型付け、`WellTyped` の条件 |
| [Surface/WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean) | 92 | +13／−2 | 新しい構文の範囲条件、操作宣言と一覧の整合 |
| [Surface/Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean) | 241 | +23／−4 | 新しい構文の脱糖、直接呼び出し、表の保存 |
| [Surface/Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:734) | 840 | +107／−1 | `rfl` による脱糖例 10 個 |
| [Lemmas/Calls.lean](../../../../../formal/Benitoite/Surface/Lemmas/Calls.lean:18) | 98 | +21／−0 | 脱糖前後の `handles`・`handled` の一致 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | 233 | +8／−1 | 新しい式の結果型の不変条件 |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean) | 185 | +12／−0 | 新しい式と節の範囲保存 |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean) | 432 | +24／−2 | 操作・ハンドラの型保存、節の本体の証明待ち |
| [Lemmas/Program.lean](../../../../../formal/Benitoite/Surface/Lemmas/Program.lean) | 53 | +6／−8 | 表の保存の証明、連言の参照の付け替え |
| [Surface/Theorems.lean](../../../../../formal/Benitoite/Surface/Theorems.lean) | 39 | +3／−3 | `desugar_effectsOk` への前提の受け渡し、対象範囲のコメント |
| **合計** | **2,824** | **+272／−29** | **差し引き 243 行増加** |

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功。節の型保存の宣言に `sorry` の警告あり |
| `formal/` で `lake build desugarDiff` | 成功。`Exchange` の修正は不要 |
| `scripts/check.sh --base HEAD --dry-run` | `formal` だけを選択 |
| `git diff --check` | 成功 |
| 二つの定理の言明と開始時の比較 | 両方とも一致 |
| Surface の字句確認 | `sorry` 一か所。`native_decide`・新しい `axiom` 宣言なし |
| 変更範囲の確認 | 全変更が `formal/Benitoite/Surface/` 内 |

共通検査は dry-run までとし、今回指定された完了条件は二つの Lake ビルドで確認しました。

## 2. 足した構文の表し方

`Program` と `Declarations` に、`Release` と同じ型の表を加えました。既定値は空の表です。

```lean
ops : OpName → Option OpDecl := fun _ => none
effects : EffName → Option (List OpName) := fun _ => none
```

`Program.declarations`、`Declarations.patternProgram`、`desugarProgram` は、これらをそのまま写します。`patternProgram` の構成子表も従来どおりそのまま写すため、既存の `consCongr … rfl` は維持できています。

式と節は次の形です。

```lean
-- Expr
| opName (o : OpName) (tys : List Ty)
| handleE (body : Block) (clauses : Clauses)
| resume (k : Nat) (e : Expr)

-- Expr・Block などと相互帰納
inductive Clauses where
  | nil
  | cons (op : OpRef) (arity ntys : Nat) (body : Block) (rest : Clauses)
```

節の `op` は、利用者の操作を `.user o`、組み込みの操作を `.prim b` で表します。`arity` は `_` を含む引数の個数、`ntys` は操作の型パラメータの個数です。

操作の直接呼び出しは `.call (.opName o ts) args` で表し、`directCallee` に `.opName` の場合を加えました。値として使う形の脱糖は `.ret (.op o ts)` です。既存の `directCallee_*` の補題は、証明本体を変えずに通っています。

`Clauses.skeleton` は、操作・引数個数・型パラメータ個数を保ち、本体を Unit の計算に置き換えた `Release.Clause` の並びです。表層の型付けではこれに `handled` を適用し、`desugarClauses_handled` で脱糖後との一致を証明しました。

## 3. 足した表層の型付けの規則と、01-06・01-07・01-12 との対応

| 規則 | 前提と結果 | 対応 |
|---|---|---|
| `E_Op` | `D.ops o = some od` と `SatAll B C ts od.tparams` から、操作名に `fnTy od.params od.ret (Eff.single od.eff) ts []`、空のエフェクトを与える | 01-06 の操作の多相な型、01-12 の `V_Op` |
| `E_Handle` | 本体を `.other` で型 `t`、エフェクト `εbody` として検査。`εbody ⊆ ε ∪ handled(H)` と、各節が型 `t`・エフェクト `ε` を持つことを要求 | 01-06・01-07 のハンドラの型付け、01-12 の `C_Handle` |
| `E_Resume` | `Γ[k]? = some (some (.cont b t ε))` と、引数式が `b ! ε` を持つことから、再開式に `t ! ε` を与える | 01-12 の `C_Resume` と、引数計算の `let` |
| `HasClauses.cons` | `opSig`、`arity`、`ntys` の一致を検査し、型パラメータと継続を加えた環境で節の本体を検査 | `Release.HasTypeClauses.cons` |

節の本体の環境は、指定された形をそのまま使っています。

```lean
C' = sg.tparams ++ C
Γ' = some (.cont sg.ret (t.shift k 0) ε) ::
       (binds sg.params ++ shiftEnv k Γ)
R' = R.map (Ty.shift k 0)
```

本体の位置は `.other`、結果型は `t.shift k 0`、エフェクトはずらさない `ε` です。`sg.params` と `sg.ret` は宣言の型をそのまま使います。`R` を保持するため、ハンドラの本体と節の中の `return`・`try` を禁じていません。

範囲条件は、節の本体を型変数 `nt + ntys`、値の変数 `nv + 1 + arity` で検査します。`resume k e` は `k < nv` と引数式の範囲条件を要求します。操作名の条件は、指定どおり **`Ty.VarsInList nt pe ts` そのもの**です。

`Program.WellFormed` には、既存の条件に次を加えました。

- 操作宣言が `OpDecl.Scoped` を満たすこと。
- エフェクトの一覧の各操作が、同じエフェクトに属する操作宣言を持つこと。
- 操作宣言が、そのエフェクトの一覧に含まれること。

`Program.WellTyped B opPrim` には、利用者のエフェクト名と組み込みのエフェクト名が重ならない条件 `p.effects l = some os → B.effects l = none` を加えました。

**表層の型付けが処理系より広くなる点**は、`resume` が継続の番号を明示するため、内側の節から外側の節の継続へ再開する項にも型を付けられることです。処理系の脱糖は最も内側の節を暗黙に選び、この形を作りません。この形の脱糖も `inner_clause_outer_resume_row` で検査しています。

`Expr.Exits` は変更していません。`handle`・`resume` は既存の `_ => False` に従います。

## 4. 定理の言明と、`sorry` を置いた箇所の一覧

**`desugar_typed` と `surface_effect_soundness` の言明・引数は変更していません。** 開始時のソースとの比較でも一致しました。表の条件は、指定どおり `Program.WellFormed`・`WellTyped` の中に置いています。

`sorry` は次の一か所だけです。

| 場所 | 未証明の目標 |
|---|---|
| [Lemmas/Typing.lean:381](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:381)、`HasClauses.desugar` の `.cons` 分岐 | 継続変数と型パラメータを加えた環境で、脱糖後の節の本体に型を付ける目標 |

この分岐でも、操作シグネチャの移送、`arity`・`ntys` の一致、残りの節への再帰は証明しています。新しい補題には、節の継続の結果型を扱うための `ht : TyOK C.length t` を渡します。この条件は `E_Handle` の本体の `HasBlock.clean` から得ています。

次は `sorry` なしで証明しました。

- 操作名の型保存と結果型の不変条件。
- `HasType.clean` の `E_Handle`。
- 現在の `EnvClean` の前提と矛盾する `E_Resume` の分岐。
- 新しい式と節の範囲保存。
- 脱糖前後の `handles`・`handled` の一致。
- `desugar_wellFormed` の操作表の目標と、`desugar_effectsOk`。

`#print axioms` では、二つの最終定理に `sorryAx` が含まれることを確認しました。一方、`HasType.clean`、節の範囲保存、`handled` の一致、`desugar_effectsOk` は、標準の `propext`・`Classical.choice`・`Quot.sound` だけに依存しています。

## 5. 01-12 の表の行と、脱糖の関数の場合・例の対応

新しい脱糖の場合の直前に、01-12「ハンドラ」の対応する行をコメントで写しました。追加例はすべて `rfl` です。

| 01-12 の行・確認する条件 | 脱糖の場合 | 追加した例 |
|---|---|---|
| `handle B with … end handle` と節の並び | `desugarExpr.handleE`、`desugarClauses.cons` | `handle_clauses_row` |
| 本体と節は非末尾位置 | 両方の本体を `desugarBlock … .other` で脱糖 | `handle_return_other_row` |
| 節の中の `resume(v)` | `letIn ⟦v⟧ (resume (var (k+1)) (var 0))` | `resume_row` |
| 入れ子の本体から外側へ再開、内側の節から内側へ再開 | `handleE`・`resume` の組合せ | `nested_handle_resumes_row` |
| 明示番号による、内側の節から外側への再開 | 同上 | `inner_clause_outer_resume_row` |
| 利用者の操作名を値として使う | `desugarExpr.opName` | `user_op_value_row` |
| 利用者の操作を直接呼ぶ | `directCallee.opName` と既存の `callComp` | `user_op_call_row` |
| 型パラメータを持つ操作の節 | `desugarClauses.cons` の `ntys` を保存 | `handle_polymorphic_op_row` |
| 節内の `try` の型引数をずらした形で保持 | 節の脱糖と既存の `tryOption`・`tryResult` | `handle_clause_try_option_row`、`handle_clause_try_result_row` |

`nested_handle_resumes_row` では、外側の節で束縛を一つ追加したため、内側の `handle` の本体から再開する外側の継続は **番号 1** です。内側の節では、その節自身の継続を **番号 0** で指します。

## 6. 処理系の脱糖との違いと、01-12 との食い違い

今回追加した四つの脱糖行について、**現在の 01-12 の表との新しい食い違いはありません**。処理系と同じく、本体と節は非末尾位置で移し、操作の直接呼び出しでは操作値の `let` を作らず、`resume` の引数には原子的な値でも `let` を作ります。

表し方には次の違いがあります。

- 処理系は `ContVar` と節の引数を別々に保持します。Lean は同じ環境の番号で表します。
- 処理系の節の型パラメータは `Rigid { clause, index }` です。Lean は節の内側から数える `tvar` で表します。
- 処理系の操作値は `TArgs` の型引数・エフェクト引数を保持します。今回の表層は、`Release.Val.op` に合わせて型引数だけを持ちます。
- 処理系の `Handle` の識別子、`handled`、`tail_resumptive`、ノード・位置などの付随情報は、このコア項には含めません。

明示番号による外側の節への再開は、処理系が生成する形より広い表層表現です。言語仕様や処理系の振る舞いを変更したものではありません。

## 7. C4b-2・C4c-2 への見込みと申し送り

C4b-2 では、`EnvClean` を継続変数を許す形へ拡張したうえで、通常の式の結果型については `TyOK` を取り出せる条件を維持する必要があります。`E_Local` の継続型を禁止する前提、`hideConts`、既存の `try` の証明との接続が要点です。

節の本体の証明では、`shiftEnv` が環境の不変条件を保つこと、`sg.tparams ++ C` の長さ、ずらした結果型と `R` の条件をまとめて扱います。`E_Resume` は環境との矛盾で処理する現在の分岐を、引数の型保存、`C_Let`、一つずらした継続番号の `C_Resume` を組み立てる証明に置き換えます。範囲保存と表の保存は証明済みです。

C4c-2 には次を申し送ります。

- **操作のエフェクト引数**：処理系の操作値の `TArgs.effects` を確認してください。今回の `Release` と表層には対応する欄がないため、非空の引数を単に捨てて比較すると情報を失います。非空の場合の扱いは範囲判定で明示する必要があります。
- **`Rigid` と `resume` の型**：処理系は `resume` の結果型を、継続を登録したときの型から読みます。外側の節に属する `Rigid` の識別子・`index` 自体は、内側の節へ入ってもずれていません。書き出しでは `clause` と節の入れ子から、現在位置での de Bruijn 番号を求めてください。通常の `Ty::Param` も、囲む節の型パラメータ数だけずらします。
- **変数を作る順**：処理系は節の引数を宣言順に作り、その後に継続を作ります。Lean の番号は、継続が 0、最後の引数が 1、その前の引数が 2、以降が外側の環境です。`_` に割り当てる変数も数えてください。
- **入れ子の本体と節の区別**：内側の `handle` の本体では外側の節の継続を使います。内側の節へ入ると、新しい継続と引数が先頭に加わります。今回の入れ子の例が、この番号付けの比較に使えます。
- **節の中の `try`**：`retArgs` は、ずらした `R` と同じ番号で書き出してください。Option・Result の両方について、番号を保存する脱糖例を追加済みです。
- **プレースホルダの引数の `resume`・`try`**：表層の型付けは既存の `hideConts` と展開後のラムダの `R` を使います。処理系の `placeholder` は `conts`・`return_ty` を退避していないため、P10／TODO-178 の候補を再現検査で確認し、差分テストでは既知の差として扱う必要があります。
- **表と付随情報**：操作宣言とエフェクトごとの操作一覧を両側から書き出し、`Handle` の付随情報を比較対象から除いてください。今回、`Exchange`・差分テスト・処理系のファイルは変更していません。