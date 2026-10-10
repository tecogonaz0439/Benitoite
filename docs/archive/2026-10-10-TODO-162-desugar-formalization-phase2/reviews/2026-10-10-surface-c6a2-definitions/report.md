C6a-2 を実装しました。追加した場合と補題を含め、証明はすべて `sorry` なしです。`lake build`、`lake build desugarDiff`、`scripts/check.sh --base HEAD`、既存の差分テストを実行する `scripts/check-formal.sh` が成功しました。変更は `formal/Benitoite/Surface/` 内だけで、コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

行数は作業後のファイル全体、追加・削除は作業開始時との差分です。

| ファイル | 作業後の行数 | 追加 | 削除 | 主な変更 |
|---|---:|---:|---:|---|
| [Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean) | 400 | 52 | 2 | レコードの構文、位置の操作、取得関数の宣言、表と共通の名前検索 |
| [Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean) | 459 | 19 | 1 | 構築・更新の型付け |
| [WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean) | 144 | 12 | 2 | 範囲の条件、`RecordsOk` |
| [Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean) | 387 | 30 | 2 | 構築・更新の脱糖、取得関数の定義の生成 |
| [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean) | 1,709 | 136 | 1 | 脱糖、型付け、表の優先順、実行の例 |
| [Lemmas/CallHead.lean](../../../../../formal/Benitoite/Surface/Lemmas/CallHead.lean) | 163 | 19 | 3 | 生成する取得関数の宣言との対応 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | 376 | 27 | 4 | 取得関数の範囲の証明、増えた条件への参照の調整 |
| [Lemmas/Program.lean](../../../../../formal/Benitoite/Surface/Lemmas/Program.lean) | 147 | 48 | 22 | 取得関数を含むプログラム全体の証明、`main` の検索との整合 |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean) | 259 | 9 | 0 | 構築・更新の脱糖後の範囲の証明 |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean) | 563 | 53 | 0 | 構築・更新の型の保存 |
| **新規** [Lemmas/Records.lean](../../../../../formal/Benitoite/Surface/Lemmas/Records.lean) | 384 | 384 | 0 | 並べ替え、束縛の番号、網羅性、取得関数の型付けの補題 |

計 11 ファイル、**789 行追加・37 行削除**です。既存の構成子の欄の並びは変えていません。`CallHead`・`directCallee` の別ファイルへの移動も行っていません。`Release`・`Core`・文書・差分テストのソースには変更がありません。

## 2. 足した構文の表し方

レコードは、既存の `cons` に置く構成子の宣言で表します。フィールド名の型や、`DataName` を鍵にした別の表は追加していません。名前の解決後の情報として、構文には次を持たせました。

| 対象 | 構文に持たせる情報 |
|---|---|
| 構築 `Expr.record` | 構成子 `c`、型引数 `tys`、書いた順のフィールド位置 `positions`、書いた順の式 `args : Exprs` |
| 更新 `Expr.recordUpdate` | 構成子 `c`、型引数 `tys`、総フィールド数 `n`、更新する位置 `positions`、元の式 `base`、書いた順の式 `args : Exprs` |
| パターン `Pattern.record` | 構成子 `c`、総フィールド数 `n`、位置 `positions`、子のパターン `args : List Pattern` |

位置と子のパターンは並行したリストです。`Pattern.toCore` は子を再帰的に移した後、宣言の順に並べ、指定されていない位置を `.wild` にします。束縛は宣言の順に数え、最後の束縛の番号が 0 になります。

`Program` には、既定値つきの次の欄を末尾に追加しました。

```lean
accessors : FunName → Option (ConName × Nat) := fun _ => none
```

取得関数の宣言は `accessorDecl cd k`、コアの定義は `accessorDef c cd k` として単独の関数にしました。後の差分テストで、生成した定義を個別に比較できます。

名前の検索は `Program.lookupFun` にまとめました。**`defs` を先に引き、定義がなければ `accessors` と `cons` から生成する**順です。`Program.declarations.funs` と `desugarProgram.defs` の両方がこの関数を使います。`Declarations` 自体に別の表は追加していません。

## 3. 足した表層の型付けの規則と仕様との対応

`E_Record` は、構成子の宣言と型引数の個数を確認し、位置の列が `List.range cd.args.length` の置換であることを求めます。各式には、その位置のフィールド型を型引数で具体化した型を付けます。したがって、全フィールドを一度ずつ指定することを検査しつつ、式の評価順は書いた順に保ちます。これは 01-05 のレコード構築と、01-12 の構築の行に対応します。

`E_RecordUpdate` は、次を前提にします。

- `n` が構成子の引数の個数と等しいこと。
- 更新する位置が空でなく、重複せず、すべて `n` 未満であること。
- `base` が `.data cd.data tys` 型を持つこと。
- 更新する式が、同じ型引数で具体化した各フィールド型を持つこと。
- 更新に使う一分岐のパターンが `Exhaustive` を満たすこと。

結果の型は `base` と同じで、エフェクトは `base` と更新する式のエフェクトの和です。網羅性は、指定どおり `E_TryResult` と同様に型付け規則の前提に置きました。単一構成子の条件からこの前提を満たす補題も証明し、`record_update_typed` の例で使っています。

レコードのパターンには独立した型付け規則を追加していません。既存の仕組みで、`Pattern.toCore` の結果に `PatTy` を適用します。

取得関数の型パラメータは `List.replicate cd.ntys {}` とし、制約を持たせていません。引数は、その型変数で具体化したレコード型一つ、戻り値は指定位置のフィールド型、エフェクトは空です。これは 01-05・01-06 のデータ型の型パラメータの制限に対応します。

`Program.RecordsOk` を `Program.WellFormed` の最後の条件に追加しました。`accessors f = some (c, k)` なら、次を要求します。

1. `defs f = none`。
2. `cons c = some cd` となる宣言が存在する。
3. `k < cd.args.length`。
4. `cd.data` に属する構成子は `c` だけである。

`B` に依存する追加条件は必要なかったため、`Program.WellTyped` は変えていません。取得関数の網羅性と型付けは、`RecordsOk` と既存の構成子の範囲の条件から導いています。

**表層の型付けがソース言語より広い点**は、次のとおりです。

- 構築は、レコード専用の印を確認せず、構成子の宣言と位置の置換で検査します。そのため、一般の構成子や引数が空の構成子にも適用できます。
- 更新は、レコード専用の印の代わりに意味上の `Exhaustive` を求めます。
- パターンは、位置の重複・範囲外・並行したリストの長さの違いを独立した前提で排除していません。脱糖後のパターンに型が付くことを検査します。位置の検索は最初の一致を採用します。

これらは形式化した表層の判断が受け入れる範囲の広さであり、ソース言語の規則を変更したものではありません。

## 4. 定理の言明と `sorry`、公理、検査結果

`desugar_typed` と `surface_effect_soundness` の言明は変えていません。[Theorems.lean](../../../../../formal/Benitoite/Surface/Theorems.lean) 自体も変更していません。`desugar_typed` の引数や、組み込みの関数の `Assumptions` は増やしていません。

**`sorry` はありません。** 新しい構築・更新の場合、取得関数を生成する場合、単一構成子からの網羅性、取得関数の型付けまで証明しました。`Surface` 内に `native_decide` や新しい `axiom` もありません。

`formal/` 内に一時ファイルを作って確認した `#print axioms` の出力は次のとおりです。一時ファイルは削除済みです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

検査結果はすべて成功です。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功 |
| `formal/` で `lake build desugarDiff` | 成功 |
| `scripts/check.sh --base HEAD --dry-run` | formal の検査を選択 |
| `scripts/check.sh --base HEAD` | `all checks passed` |
| `scripts/check-formal.sh` | 成功 |
| `git diff --check` | 成功 |

既存の差分テストは、ゴールデンの **206 プログラム・403 関数**、生成入力の **1,000 プログラム・44,218 関数**が一致し、不一致は 0 件でした。レコードなど従来の対象外要素は引き続き対象外です。今回追加したレコードの比較範囲を広げた結果ではありません。記録は [report.json](../../../../../target/desugar-diff/run-17889/report.json) にあります。

## 5. 01-12 の行と脱糖・例の対応

| 01-12「レコード」の行 | 脱糖の関数・場合 | 例 |
|---|---|---|
| 構築 `R(g1:e1,…,gn:en)` | `desugarExpr` の `.record`。書いた順に `sequence` し、宣言の順に並べ替える | [`record_construct_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1577)：宣言と逆順の指定、自由変数の番号 |
| 更新 `R(..e,g1:e1,…,gk:ek)` | `desugarExpr` の `.recordUpdate`、`recordUpdatePattern`、`recordUpdateValues` | [`record_update_partial_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1583)：一部の更新 |
| 同上 | 同上 | [`record_update_reordered_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1590)：複数のフィールドを逆順に更新 |
| 同上 | 同上。全フィールド更新でも `match` を残す | [`record_update_all_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1598)：全フィールド更新 |
| パターン `R(g1:p1,…,gk:pk)` | `Pattern.toCore` の `.record`。未指定位置を `_` にする | [`record_pattern_partial_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1605)、[`record_pattern_nested_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1610) |
| フィールドを取り出す関数 | `accessorDecl`、`accessorDef`、`desugarProgram.defs` | [`record_accessor_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1656)：具体的な名前で定義を検索 |
| 同上 | 型パラメータを持つ取得関数の生成 | [`record_accessor_polymorphic_row`](../../../../../formal/Benitoite/Surface/Examples.lean:1662) |

この表の脱糖の等式はすべて `rfl` です。さらに、宣言と脱糖後の定義が同じ優先順で検索されることを `record_lookup_priority_row` で確認しました。

[`record_update_accessor_run`](../../../../../formal/Benitoite/Surface/Examples.lean:1707) は、表層のプログラムを脱糖し、構築→一部の更新→フィールド取得を `Release.run` で実行する例です。結果が整数 `42`、事象の列が空であることを `decide` で確認しています。

## 6. 処理系の脱糖との違いと、01-12 との食い違い

妥当なレコード入力について、評価順、フィールドの並べ替え、更新時のパターン、取得関数の本体を処理系に合わせました。更新の評価順は `base` → 書いたフィールドの順です。更新する値はパターンの束縛数だけずらし、残す値は宣言の順に対応する束縛から取り出します。

**01-12 との食い違いは二つです。** 対応する脱糖の直前のコメントにも明記しています。

| 対象 | 01-12 | Lean と処理系 |
|---|---|---|
| レコードの更新 | 全フィールドを変数に束縛する | 更新する位置は `_`、残す位置だけを変数にする |
| フィールドを取り出す関数 | 全フィールドを変数に束縛する | 取り出す位置だけを変数、ほかを `_` にする |

処理系との表し方の違いとして、Lean は抽象的な構成子名と位置を使い、処理系は構成子のタグ・`BindingId`・フィールド名の解決結果を使います。また、レコードのパターンの束縛は、Lean が宣言の順、処理系が書いた順に環境へ積みます。処理系は `BindingId` で参照するため意味は対応しますが、差分テストでは番号の対応付けが必要です。

## 7. C6a-3 と C6c-2 への見込み

**C6a-3（トップレベルの定数）**では、P5 のとおり本体を構文に埋め込めば、脱糖を構造的再帰のまま保てます。証明では、空の `Γ` で型付けした本体を使用位置の環境へ移す扱いと、`let` やパターンの下での自由変数の扱いを確認する必要があります。今回の取得関数は単独の生成関数に分けたため、定数の追加と名前検索の変更が混ざる範囲は小さくなっています。

**C6c-2（差分テストの拡張）**では、特に次の対応が必要です。

- [書き出し側の `definitions()`](../../../../../crates/benitoite/tests/desugar_export/exchange.rs:1471) は現在 `DefKind::Fn` 以外を飛ばします。`FieldGetter` を加え、構成子とフィールド位置から表層の `accessors` を作り、生成した定義も比較対象にする必要があります。通常の関数 AST を探す現在の経路とは別の処理が必要です。
- レコードのパターンでは、処理系が書いた順に積む `BindingId` を、Lean の宣言の順の束縛番号へ対応付ける必要があります。入れ子を含め、分岐本体の変数番号まで同じ対応を使う必要があります。
- 更新では、書いた順の位置と値を保持しつつ、残すフィールドの束縛を宣言の順に対応付ける必要があります。今回の一部更新・逆順更新・全更新の例が、その番号の確認に使えます。
- 定数については、処理系の `ConstRef` を定義本体の脱糖結果へ置き換えて比較する処理が必要です。これをレコードの更新や取得関数の呼び出しの中でも適用する必要があります。

既存の構成子の形は維持し、追加した `accessors` に既定値を付けたため、現在の `Exchange` は修正なしでビルド・差分検査を通っています。