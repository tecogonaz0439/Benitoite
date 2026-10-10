C4a-1 の前半を実装しました。`formal/` の **`lake build` は成功**し、共通検査 `scripts/check.sh --base HEAD` も `formal` だけを選んで成功しました。`sorry` の字句は、追加した場合の証明分岐 **12 か所だけ**です。コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

既存の八ファイルを変更しました。新規ファイルはありません。行数は作業終了時のファイル全体、追加・削除は `HEAD` との差分です。

| ファイル | 行数 | 追加／削除 | 変更内容 |
|---|---:|---:|---|
| [Surface/Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean) | 235 | +13／−1 | 四つの構文構成子、`with` の `Exits` |
| [Surface/Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean) | 329 | +30／−1 | 四つの表層の型付け規則 |
| [Surface/WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean) | 81 | +5／−1 | 追加構文の範囲条件 |
| [Surface/Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean) | 222 | +22／−1 | 追加構文の脱糖と、01-12 の対応する規則のコメント |
| [Surface/Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean) | 548 | +54／−1 | `rfl` による七つの脱糖例 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | 222 | +5／−0 | 新しい四分岐の証明待ち |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean) | 171 | +5／−0 | 新しい四分岐の証明待ち |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean) | 353 | +5／−0 | 新しい四分岐の証明待ち |
| **合計** | **2,161** | **+139／−6** | **差し引き 133 行増加** |

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `scripts/check.sh --base HEAD --dry-run` | 変更八ファイルに対し `formal` だけを選択 |
| `formal/` で `lake build` | 成功、63 jobs。証明待ちの相互帰納ブロックに `sorry` の警告あり |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| Surface の字句確認 | `sorry` は指定の新しい分岐 12 か所。`native_decide`・新しい `axiom` 宣言なし |

## 2. 足した構文の表し方

`Expr` に次の四つを加えました。

```lean
| tryResult (retArgs : List Ty) (ok err : ConName) (e : Expr)
| tryOption (retArgs : List Ty) (someCon noneCon : ConName) (e : Expr)
| withE (o : OpaqueName) (e : Expr) (body : Block)
| lazyE (body : Block)
```

`tryResult` の `retArgs` は最も内側の関数の戻り値型の型引数 `[U, E]`、`tryOption` では `[U]` です。構成子名も構文に保持し、脱糖の失敗側の構成子にそのまま使います。

`withE` は単一のリソース束縛です。複数の束縛は、外側の `body` を `.last (.withE …)` として入れ子にします。本体の番号 0 は新しいリソースの変数です。束縛列の相互帰納型は追加していません。

`lazyE` は本体だけを持ち、値の変数の束縛を増やしません。脱糖は既存の相互再帰の中で構造的に定義しています。

## 3. 足した表層の型付けの規則と、01-06・01-07・01-12 との対応。`Exits` の扱い

| 規則 | 前提と結果 | 仕様との対応 |
|---|---|---|
| `E_TryResult` | 二つの構成子宣言について、`ntys = 2`、`Ok` の引数型 `[.tvar 0]`、`Error` の引数型 `[.tvar 1]`、同じデータ型であることを要求。入力型は `Result[T, E]` に相当する型、`R` は `Result[U, E]` に相当する型。式の型は `T`、エフェクトは入力式のもの | 01-06「式と文の型」、01-09「try」、01-12 の Result の脱糖行 |
| `E_TryOption` | `ntys = 1`、`Some` の引数型 `[.tvar 0]`、`None` の引数型 `[]`、同じデータ型であることを要求。入力型は `Option[T]` に相当する型、`R` は `Option[U]` に相当する型。式の型は `T` | 同じ各節の Option の規則 |
| `E_With` | 束縛式の型は `.opaque o`、`B.isResource o = true`。本体は `some (.opaque o) :: Γ`、同じ `R`、`.other` で検査。結果型は本体の型 | 01-10「リソースの型」「with の構文」、01-12「解放の枠」 |
| `E_Lazy` | 本体を `hideConts Γ`、`R = none`、`.other`、空のエフェクトで検査。結果型は `.lazy a`、式のエフェクトも空 | 01-06「明示遅延の型」、01-12「ストア」「関数の境界」「ハンドラ」 |

両方の `try` の規則には、指定された二つのパターンについての `Exhaustive D.patternProgram …` を直接置きました。Result の失敗型 `E` は入力と戻り値で同じ型を使い、自動変換を認めていません。戻り値型についての等式が `some …` を要求するため、`lazy` 本体の `R = none` ではこれらの規則を適用できません。

`with` のエフェクトは次の形です。

```lean
Eff.union εe (Eff.union εbody (Eff.single stateEff))
```

これは束縛式・本体・解放のエフェクトの和であり、01-07 の `State` の扱いと、01-10 の解放の規則に対応します。

範囲条件は、`try` の戻り値型引数に `Ty.VarsInList nt pe` を要求します。`with` の本体では値の変数の範囲を一つ増やし、`lazy` では増やしません。`Program.WellFormed` の形は変更していません。

`Expr.Exits` に加えたのは次の一行だけです。

```lean
| .withE _ _ body => body.Exits
```

01-06「必ず抜ける文」に従い、`try`・`lazy` は既存の `_ => False` のままです。

## 4. 定理の言明（C1 のままか）と、`sorry` を置いた箇所の一覧

**二つの定理の言明・前提・証明本体は、作業開始時のままです。** [Theorems.lean](../../../../../formal/Benitoite/Surface/Theorems.lean) は変更していません。

`desugar_typed` の前提は引き続き `hwf`・`hwt`・`hsig`、結論は脱糖後の `WellFormed`・`WellTyped`・`EffectsOk` です。`surface_effect_soundness` の前提も `hwf`・`hwt`・`hb`・`hmain` のままです。組み込みの関数の `Assumptions` は増やしていません。

`sorry` は次の 12 か所です。表の数字は各ファイルの行番号です。

| 追加した分岐 | `Invariants.lean` — `HasType.clean` | `Scoped.lean` — `HasType.desugar_scoped` | `Typing.lean` — `HasType.desugar` |
|---|---:|---:|---:|
| `E_TryResult` | 192 | 99 | 225 |
| `E_TryOption` | 193 | 100 | 226 |
| `E_With` | 194 | 101 | 227 |
| `E_Lazy` | 195 | 102 | 228 |

新しい補題は追加していません。既存の場合の証明は変更していません。相互帰納ブロック内のほかの定理にも警告が出ますが、その本体に `sorry` を追加したものではありません。

## 5. 01-12 の表の行と、脱糖の関数の場合・例の対応の表

各脱糖の場合の直前に、対応する表の行をコメントとして写しました。`lazy` は指定どおり箇条の文を写しています。

| 01-12 の規則 | `desugarExpr` の場合 | 追加した `rfl` の例 |
|---|---|---|
| `try e`：入力 `Result[T, E]`、戻り値 `Result[U, E]` | [`.tryResult`](../../../../../formal/Benitoite/Surface/Desugar.lean:145) | [`try_result_row`](../../../../../formal/Benitoite/Surface/Examples.lean:381) |
| `try e`：入力 `Option[T]`、戻り値 `Option[U]` | [`.tryOption`](../../../../../formal/Benitoite/Surface/Desugar.lean:150) | [`try_option_row`](../../../../../formal/Benitoite/Surface/Examples.lean:389) |
| `with x1 = e1, …, xn = en do B end with` | [`.withE`](../../../../../formal/Benitoite/Surface/Desugar.lean:158) の入れ子 | [`with_single_row`](../../../../../formal/Benitoite/Surface/Examples.lean:396)、[`with_nested_row`](../../../../../formal/Benitoite/Surface/Examples.lean:402)、[`with_return_row`](../../../../../formal/Benitoite/Surface/Examples.lean:409) |
| 「ストア」の箇条：`⟦lazy B end lazy⟧ = lazy ⟦B⟧` | [`.lazyE`](../../../../../formal/Benitoite/Surface/Desugar.lean:162) | [`lazy_capture_row`](../../../../../formal/Benitoite/Surface/Examples.lean:415)、[`lazy_lambda_row`](../../../../../formal/Benitoite/Surface/Examples.lean:422) |

七例とも位置 `p : Position` を引数に持つため、`.tail` と `.other` の両方について同じ出力を検査します。期待値はコアの項として直接書いており、脱糖の補助関数で生成していません。

## 6. 処理系の脱糖との違い（`with` の本体の位置を含む）と、01-12 との食い違い

ソースを照合した範囲では、追加した脱糖の形は処理系と対応しています。

- **`try`**：入力を一度評価し、成功側でパターン変数を返し、失敗側で `ret_args` に相当する型引数を持つ構成子を作って `escape` します。Result の失敗側は一変数、Option の失敗側は変数なしです。
- **`with`**：各束縛を `letIn` と `use` の入れ子にします。Lean は本体を常に `.other` で扱います。Rust は外側が `Tail` または `Result` の場合、本体を `Position::Result` で移します。この差は `escape` の結果型の注釈に関わりますが、Release の `escape` はその注釈を持たないため、今回のコア項では同じ形になります。`with_return_row` でも、本体の `return` が `escape` になることを検査しています。
- **`lazy`**：本体を非末尾位置で移して `lazyC` にします。Rust が退避する外側の継続と戻り値型に対応して、表層の型付けでは `hideConts Γ` と `R = none` を使います。

**今回の範囲で、01-12 の脱糖の形との新しい食い違いは見つかりませんでした。** 現在の `with` の表には、本体を末尾位置にないものとして移す説明が既にあります。`lazy` は表の行がないため、箇条をコメントの出典にしています。

処理系との自動差分検査は今回の新しい構文に広げていません。今回の対応確認はソースの照合と Lean の `rfl` の例によるもので、差分検査の拡張は C4c に残ります。設計書への新しい表層構文・型付け規則の反映も、指定どおりオーケストレータの担当です。

## 7. 後半（証明）と、C4a-2（`handle`・`resume`・利用者の操作）で難しくなりそうな箇所の見込み

**C4a-1 の後半では、`try` の型保存が最も手順の多い部分になります。** 構成子宣言の前提から二つのパターンの `PatTy` を構築し、失敗側の戻り値型の具体化と `C_Escape` を結び付ける必要があります。網羅性は既存の `Exhaustive.consCongr` で移せます。`C_Escape` と分岐列の末尾が要求する結果型の `Ty.WF` は、入力式の `HasType.clean` から取り出した `T` の `TyOK` に `Ty.VarsIn.wf` を適用する方針です。

**`with` では、エフェクトの拡大と束縛環境の対応が中心になります。** 本体は既にリソース変数の下にあるため、自由変数の `rename` は不要です。`C_Use` に合わせて本体のエフェクトを `State` を含む集合へ広げ、外側の `letIn` を型付けします。

**`lazy` では、隠した環境の長さと不変条件を合わせます。** 既存の `hideConts_length` と `EnvClean.hide` を使い、`R = none` の帰納法の前提を渡して `C_Lazy` に接続できます。

**C4a-2 では、環境の不変条件の拡張が必要です。** 現在の `EnvClean` はすべての環境要素に `TyOK` を要求するため、節の継続変数を受け入れられません。通常の値の型と継続変数の型を区別し、`E_Local` の継続型を除く前提から通常の値の不変条件を取り出せる形にする必要があります。その変更後も、今回の `lazy` と既存のラムダ・プレースホルダが使う `hideConts` の性質を保つ必要があります。

節の型パラメータを増やす際には、制約の並び `C`、環境の型、戻り値型 `R`、結果型のずらしを同時に扱います。操作・エフェクトの表を加える変更では、現在空の表から証明している `desugar_effectsOk` と、パターン用プログラムとの対応も見直す必要があります。