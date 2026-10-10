C6a-1 を実装し、追加した場合も含めて **`sorry` なしで証明できました**。`lake build`、`lake build desugarDiff`、`scripts/check.sh --base HEAD` はすべて成功しました。コミットは作成していません。

## 1. 変えたファイル・作ったファイルと行数

変更は `formal/Benitoite/Surface/` の 11 ファイルです。合計は **674 行追加・15 行削除**です。新規ファイルの行数も追加に含めています。

| ファイル | 追加／削除 | 変更後の行数 | 内容 |
|---|---:|---:|---|
| [Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean) | +42 / −3 | 349 | `decimal`、`negDecimal`、`listSpread`、`interpolation`、断片の情報 |
| [Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean) | +28 / −2 | 441 | 追加構文の型付け、条件付きの `StringAddOk` |
| [WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean) | +7 / −2 | 134 | 追加構文の型・式・呼ぶ値の範囲条件 |
| [Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean) | +76 / −4 | 359 | 脱糖と、展開・変換・連結の補助関数 |
| [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:1424) | +149 / −1 | 1,574 | `rfl` の例 20 個、型付けの例 2 個 |
| [Lemmas/CallHead.lean](../../../../../formal/Benitoite/Surface/Lemmas/CallHead.lean:118) | +4 / −3 | 147 | `directCallee_typed` の計算側の許容エフェクトを一般化 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | +3 / −0 | 353 | 追加構文の結果型の不変条件 |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean) | +35 / −0 | 250 | 追加構文の範囲保存を既存の証明へ接続 |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:228) | +32 / −0 | 510 | 追加構文の型の保存を既存の証明へ接続 |
| [Lemmas/Extensions.lean](../../../../../formal/Benitoite/Surface/Lemmas/Extensions.lean) | 新規 189 行 | 189 | 展開・変換・連結の型付けの補題 |
| [Lemmas/ExtensionsScoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/ExtensionsScoped.lean) | 新規 109 行 | 109 | 同じ処理の範囲保存の補題 |

`Release`・`Core`・二つの定理のファイル・`Exchange`・差分テスト・`docs/` には変更がありません。公理確認用の一時ファイルは `formal/` に作り、確認後に削除しました。

## 2. 足した構文の表し方

`Decimal` は `Literal.decimal (n : Int) (scale : Nat)` とし、`Literal.toConst` がそのまま `Release.Const.decimal n scale` に移します。直接の負号は `Expr.negDecimal n scale` で表し、係数だけを反転します。パターンには追加していません。

リストの展開は、次の情報を持ちます。

```lean
listSpread (elemTy : Ty) (concat : Expr)
  (before : Exprs) (spread : Expr) (after : Exprs)
```

`concat` は表層の式で持たせ、型付けで `directCallee concat = some h` を要求します。脱糖では、全要素の束縛の下へ頭をずらし、`CallHead.apply` で呼び出します。

文字列補間は、断片の情報と子の式を分けました。

```lean
interpolation (parts : List InterpPart) (es converters : Exprs)
```

`InterpPart` は子の式を含まない帰納型で、`text s`・`stringExpr`・`converted T` の三種類です。`es` は式の部分に、`converters` は `converted` の部分だけに、それぞれ順に対応します。二つの並行した列の型と個数は、`exprTypes`・`converterTypes` と既存の `HasTypes` で検査します。

変換関数も `directCallee` と `CallHead.apply` で扱います。補間の連結関数は構文に持たせず、既存の `opPrim (.binary .add) (.base .string)` を使います。子の式を含む新しい入れ子の帰納型は作っていません。

## 3. 足した表層の型付けの規則と、01-06・01-12 との対応

| 規則 | 検査する内容 | 対応 |
|---|---|---|
| 既存の `E_Literal` | `Decimal` の結果型は `Const.type` により `Decimal` | 01-12「基本型とコレクションの型」 |
| `E_NegDecimal` | 結果型は `Decimal`、エフェクトは空 | 01-06 の単項負号、処理系の符号込みの定数 |
| `E_ListSpread` | 前後の要素は `T`、展開式は `List[T]`、呼ぶ値は純粋な `(List[T], List[T]) → List[T]` の直接の頭 | 01-06「式と文の型」、01-12「リストの展開」 |
| `E_Interpolation` | 式列と変換関数列の対応、変換関数の純粋性と直接の頭、結果型 `String` | 01-06「演算子の型付け」、01-12「文字列補間」 |
| `StringAddOk` | `E_Binary` と同じ、String の加算に対する表・シグネチャ・型引数・`admits`・純粋性の前提 | 部分が二つ以上ある補間だけに要求 |

補間の式の型は、`String`・`Integer`・`Float`・`Character`・`Boolean`・`Byte`・`Decimal` に限定しました。**補間する式の型を任意の型へ広げてはいません。** 型変数に対する補間の制約の推論・解決は今回形式化しておらず、具体基本型を持つ場合を扱います。

呼ぶ値の表現には、既存の `CallHead` の一般性を使っています。そのため、適切な純粋な型を持つ辞書付きの関数やメソッドの頭も受け入れます。これは Rust が標準ライブラリの特定の関数を選ぶ処理より一般的な表現です。変換の具体的な振る舞いは、その関数の定義または組み込みの意味論に依存します。

追加の前提は型付け規則と式の範囲条件に含めました。`desugarProgram` や二つの定理に、新しい表や引数は追加していません。

## 4. 定理の言明と、`sorry` の有無と場所

`desugar_typed` と `surface_effect_soundness` の言明・引数は変更していません。`Builtins.Assumptions` も変更していません。

**`sorry` はありません。** 既存の場合と追加した場合の両方を証明済みです。`Surface` のソースには `admit`・`native_decide`・新しい公理の宣言もありません。

最終状態での `#print axioms` の出力は次のとおりです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、69 jobs、警告なし |
| `formal/` で `lake build desugarDiff` | 成功、16 jobs |
| `scripts/check.sh --base HEAD --dry-run` | `formal` だけを選択。長いテスト・`check-heap.sh` は選択なし |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `#print axioms` | 両定理とも標準の三公理だけ |
| `git diff --check` | 成功 |

## 5. 01-12 の行と、脱糖の関数の場合・例の対応の表

例の期待値は Release の項を直接書き、脱糖の補助関数で生成していません。下表の脱糖の例はすべて `rfl` です。

| 01-12 の節・行、または補う場合 | 脱糖の関数の場合・補助関数 | 例 |
|---|---|---|
| 「基本型とコレクションの型」Decimal のリテラル | `.literal`、`Literal.toConst` | `literal_decimal_row` |
| 「名前とリテラル」の直接の負号へ補う Decimal の場合 | `.negDecimal` | `neg_decimal_row`、`neg_decimal_zero_row`、`decimal_no_negative_zero` |
| 「リストの展開」先頭 | `.listSpread`、`spreadValues`、`spreadFinish` | `spread_first_row` |
| 同行、途中 | 同上。最初の連結結果を束縛 | `spread_middle_row` |
| 同行、末尾 | 同上。後ろの連結を省略 | `spread_last_row` |
| 同行、前だけが空 | `concat(s, [after])` | `spread_before_empty_row` |
| 同行、後ろだけが空 | `concat([before], s)` | `spread_after_empty_row` |
| 同行、両側とも空 | 展開式の束縛後に `return s` | `spread_both_empty_row` |
| 「文字列補間」String の式 | `.interpolation`、`interpolate`、`joinStringParts` | `interpolation_string_row` |
| 同行、ほかの型の式と混在 | 同上。全式の束縛後に変換 | `interpolation_integer_row`、`interpolation_mixed_row` |
| 同行、空の断片・部分が 0 と 1 | 空の断片を省略し、連結なしで `return` | `interpolation_zero_parts_row`、`interpolation_one_text_row`、`interpolation_one_string_row`、`interpolation_one_converted_row` |
| 同行、連続する式 | 変換を順に束縛し、最後の連結を末尾に配置 | `interpolation_adjacent_row` |
| 同行、呼ぶ値が辞書付きの関数・メソッド | `directHeads`、`CallHead.rename`、`CallHead.apply` | `interpolation_dict_head_row`、`interpolation_method_head_row` |

加えて、`interpolation_zero_parts_typed` と `interpolation_one_string_typed` で、0・1 部分の型付けには連結のシグネチャが不要であることを確認しました。

## 6. 処理系の脱糖との違いと、01-12 との食い違い

脱糖の組み立ては、指定された Rust の処理に合わせました。

- リストは前・展開式・後の順に評価して束縛し、空の側の `concat` を省きます。両側が空なら `let s ⇐ ⟦e⟧ in return s` です。
- 補間は全式の束縛を終えてから、String 以外の式の変換結果を断片の順に束縛し、その後で左から連結します。最後の連結だけが末尾の計算です。
- 部分が一つだけの場合も、変換結果を束縛してから `return` します。
- 直接の Decimal の負号は符号込みの定数へ移します。`-0.0m` は `.decimal 0 1`、`-1.50m` は `.decimal (-150) 2` です。

**01-12 との食い違い**として、次の三点を対応する脱糖の場合の直前に記録しました。

1. 「名前とリテラル」の直接の負号の行に Decimal がない。
2. リストの展開の表は両方の連結を書き、省略を任意としている。Lean は Rust と同じく必ず省く。
3. 補間の表は全式の `str_T` を書いている。Lean は String の式の変換と空の断片を省く。

残る表現上の違いは、Rust の名前付き変数を Lean では de Bruijn 番号で表すことと、呼ぶ値を `CallHead` で一般的に表すことです。差分テストの範囲は変更しておらず、今回実行したのは `desugarDiff` のビルドまでです。比較の実行結果は今回取得していません。

## 7. C6a-2・C6a-3 と、C6c で難しくなりそうな箇所の見込み

**C6a-2（レコード）**では、書いた順の評価結果を宣言順へ並べ替える補題と、更新しないフィールドだけを束縛するパターンの環境対応が主な作業になる見込みです。フィールドを取り出す関数を Σ に追加すると、表層の宣言と脱糖後の定義の対応、および `RecordsOk` から構成子の一意性・網羅性を得る部分にも証明が要ります。今回の `sequence`・値列の分割・`CallHead.rename` の利用方法は再利用できます。

**C6a-3（トップレベルの定数）**では、空の局所環境で脱糖した本体を使用位置の環境へ移すことと、使用位置の `C`・`R` の扱いが確認点です。本体を構文に埋め込む案なら、構造的再帰を維持できます。

**C6c（差分テスト）**では、補間の各式の型から `stringExpr` と `converted T` を選び、後者だけに変換関数を対応させる書き出しが必要です。特に、全式の束縛後に変換を始める順序、連結途中の変数番号、空の断片と空の側の省略を確認する必要があります。Decimal は係数と scale、および直接の負号の反転前・反転後のどちらを交換形式に持つかを揃える必要があります。型変数のまま補間する入力を比較対象へ含める場合は、今回扱っていない補間の制約の表現を先に検討する必要があります。