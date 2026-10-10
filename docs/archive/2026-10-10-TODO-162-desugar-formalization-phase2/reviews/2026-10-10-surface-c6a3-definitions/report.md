C6a-3（トップレベルの定数）を実装しました。追加した場合も含め、証明はすべて **`sorry` なし**です。`lake build`、`lake build desugarDiff`、`scripts/check.sh --base HEAD`、既存の差分検査を実行する `scripts/check-formal.sh` が成功しました。変更は `formal/Benitoite/Surface/` 内の 8 ファイルだけで、コミットはしていません。

## 1. 変えたファイル・作ったファイルと行数

行数は作業後のファイル全体、追加・削除は作業開始時の `HEAD` との差分です。

| ファイル | 作業後の行数 | 追加 | 削除 | 変更内容 |
|---|---:|---:|---:|---|
| [Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean:178) | 405 | 6 | 1 | `Expr.constE` と `Expr.Exits` の場合 |
| [Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean:66) | 465 | 7 | 1 | 定数参照の型付け規則 `E_Const` |
| [WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean:33) | 146 | 3 | 1 | 注釈型と、値の変数 0 個での本体の範囲条件 |
| [Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean:132) | 391 | 5 | 1 | 本体を `.other` の位置で脱糖する場合 |
| [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:1709) | 1,753 | 45 | 1 | 脱糖・型付け・範囲条件の例 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean:269) | 377 | 1 | 0 | 定数参照の結果型の不変条件 |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean:59) | 261 | 2 | 0 | 定数本体の脱糖後の範囲保存 |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:23) | 569 | 6 | 0 | 空の環境から使用位置への弱化と型の保存 |

合計 **75 行追加・5 行削除**です。新規のファイルはありません。公理確認用の一時ファイルは指定どおり `formal/` 内に作り、確認後に削除しました。

既存の構成子の欄の並びは維持しています。`Release`・`Core`、文書、レビュー記録、差分テストのソースに変更はありません。

## 2. 足した構文の表し方と、型付けで使う制約の並び・R・環境の決め方とその理由

定数参照には、宣言の注釈型と本体を持たせました。

```lean
| constE (ty : Ty) (body : Expr)
```

本体の中の定数参照も同じ構成子で埋め込むため、入力は有限の木です。定数名を引く表や型引数の欄は追加していません。P5 のとおり、脱糖は本体への構造的再帰で済みます。

本体の型付けでは、**使用位置の C と R を保ち、局所環境だけを `[]` にし、位置を `.other` にします**。注釈型と本体の判断の型は同じにし、本体のエフェクトには `Eff.empty` を求めました。これは、01-06 の宣言型との一致と、定数式がエフェクトを持たない条件を直接表すためです。使用位置で型やエフェクトを広げる場合は、既存の `E_Sub` を使えます。

脱糖後の本体を使用位置の環境へ移す証明は、次の手順です。

1. 本体の導出から、空の環境で脱糖結果に型を付ける。
2. 空の環境の添字について前提が成り立たないことから、`RenOk [] Γ id` を示す。
3. `HasTypeC.rename` を適用し、`Comp.rename_id` で計算を元の形に戻す。

C を空にする `HasTypeC.outer` や、R を `none` に変える補題は使っていません。組み込みの関数の `Assumptions` も追加していません。

## 3. 足した表層の型付けの規則と、01-06・01-12 との対応。表層の型付けが広くなった点

追加した規則は次のとおりです。

```lean
| E_Const {C Γ R p a body} :
    HasType D B opPrim C [] R .other body a Eff.empty →
    HasType D B opPrim C Γ R p (.constE a body) a Eff.empty
```

01-06「定数の型（初回リリース版）」との対応は、注釈型 `a` を参照の型とすること、本体の判断にも同じ `a` を求めること、エフェクトを空とすることです。定数参照自体には、多相な名前の具体化や型パラメータの束縛を設けていません。

範囲条件は次の形です。

```lean
| .constE a body => Ty.VarsIn nt pe a ∧ body.Scoped nt pe 0
```

本体は使用位置の型変数の個数とエフェクト変数の範囲を使い、値の変数は 0 個で検査します。注釈型も使用位置の範囲で検査します。この条件は既存の `Def.Scoped` などを通じて `Program.WellFormed` に含まれるため、プログラム全体に別の前提を追加する必要はありませんでした。

**表層の型付けがソース言語より広い点**は、次のとおりです。

- 01-02 の定数式に書ける式の種類の列挙を検査しません。空のエフェクトで型が付けば、利用者の関数の呼び出し、ラムダ、`if`、`match`、`lazy`、`handle` なども本体として受け入れられます。
- 実行時エラーにならないことや、`Map.fromList`・`Set.fromList` の重複の制限を検査しません。したがって、この型付けから定数計算の停止や成功は導いていません。
- R を保つため、形式化した広い入力では、R に応じて `return` や `try` に型が付く場合もあります。ソース言語の定数式ではこれらは現れません。
- 注釈型と本体に、使用位置の型変数・エフェクト変数の範囲を許します。ソース言語の定数の型を具体的な型に限る条件や、同じ名前の各参照が同じ注釈型・本体を持つ条件は、独立した検査として表していません。

`Expr.Exits` の定数の場合は明示的に `False` としました。使用位置の「必ず抜ける文」の判定では、本体を辿りません。

## 4. 定理の言明と、`sorry` の有無と場所。`#print axioms` の出力

**`desugar_typed` と `surface_effect_soundness` の言明は変えていません。** [Theorems.lean](../../../../../formal/Benitoite/Surface/Theorems.lean:17) 自体も変更していません。

`Surface/` 内に `sorry` はありません。`native_decide` や新しい `axiom` も追加していません。公理確認の出力は次のとおりです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

検査結果はすべて成功です。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功 |
| `formal/` で `lake build desugarDiff` | 成功。`Exchange` の修正は不要 |
| `scripts/check.sh --base HEAD --dry-run` | formal の検査だけを選択 |
| `scripts/check.sh --base HEAD` | `all checks passed` |
| `scripts/check-formal.sh` | 成功 |
| `git diff --check` | 成功 |

既存の差分検査では、ゴールデン入力の **218 プログラム・416 関数**、生成入力の **1,000 プログラム・46,218 関数**が一致し、不一致は 0 件でした。定数参照は引き続き比較対象外です。結果は [report.json](../../../../../target/desugar-diff/run-23367/report.json) にあります。

## 5. 01-12 の文と、脱糖の関数の場合・例の対応

01-12「トップレベルの定数」の次の文を、脱糖の場合の直前のコメントに写しました。

> 定数 `const k: A = e` の名前 `k` を、`⟦e⟧` に置き換える。`e` の中の定数の名前も同じく置き換える。

脱糖の場合は、本体を非末尾位置で脱糖した計算そのものを返します。

```lean
| .constE _ body => desugarExpr opPrim .other body
```

使用位置が `.tail` でも、本体には `.other` を渡します。注釈型は脱糖結果に残しません。

| 例 | 確認した内容 |
|---|---|
| `constant_row` | 整数の定数参照を本体の `return 42` に置き換える |
| `nested_constant_row` | リストの定数の本体にある、別の整数の定数参照も置き換える |
| `constant_under_bind_row` | 外側に局所束縛があっても、定数本体の内部の束縛番号を保つ |
| `nested_constant_typed` | 任意の C・Γ・R・位置で、入れ子の定数参照に型が付く |
| `constant_under_bind_typed` | 局所束縛の下で使う定数参照に型が付く |
| `nested_constant_scoped` | 入れ子の本体が範囲条件を満たす |
| `constant_cannot_capture` | 使用位置の局所変数を定数本体から参照できない |

脱糖の三つの等式は、すべて **`rfl`** です。

## 6. 処理系との表し方の違い

処理系は、定数を `Program.consts` の `ConstDef` として保持します。`ConstDef` は宣言型、計算である `body`、型検査時に求めた `value` などを持ち、参照はコアの値 `ValKind::ConstRef(binding)` になります。参照式の脱糖は `Return(ConstRef(...))` です。

今回の Lean の表層は、参照位置に注釈型と本体を埋め込み、コアへの脱糖で本体の計算へ直接置き換えます。定数の宣言表、`ConstRef` に相当するコアの値、事前に評価した定数値は追加していません。これは P5 と 01-12 の置き換えの記述に従った表現です。

循環を検出する処理も追加していません。01-03 の循環の検査を済ませ、本体を有限の木に展開した入力を扱います。

## 7. 差分テストの拡張（C6c-3）で難しくなりそうな箇所の見込み

C6c-3 では、**値である `ConstRef` を、計算である `ConstDef.body` に置き換える処理**が必要です。主に次の対応が要る見込みです。

- **値の位置への計算の挿入。** 呼び出しの引数、構成子のフィールド、リストの要素などにある `ConstRef` は、その場所で計算へ直接置換できません。本体の結果を `let x ⇐ ⟦e⟧` で束縛し、元の値の位置を `x` に置き換える必要があります。Lean 側は既に `sequence` を通じてこの形を作ります。
- **`let` の形の正規化。** 定数本体自身が `let` を含むと、展開後の処理系側と Lean 側で、`let` の左辺の入れ子や余分な `return` の形が異なる可能性があります。結合則・単位則に対応する正規化を、比較する両側で揃える必要があります。
- **変数番号と捕獲の回避。** 定数本体は閉じていますが、展開によって挿入する束縛は周囲の de Bruijn 番号に影響します。ラムダ、パターン、ハンドラの節などの内部束縛を保護しながら、後続の変数を移す必要があります。
- **入れ子の定数参照。** `ConstDef.body` 内の `ConstRef` も再帰的に展開する必要があります。処理系の定数表では本体を共有できても、Lean の入力では参照ごとの木になるため、共有と展開を比較時に同じ形へ揃える必要があります。
- **表層の書き出しとコアの正規化の対応。** 表層側では名前から宣言型・本体を取得して `.constE ty body` を作り、処理系のコア側では同じ定数定義を使って `ConstRef` を展開する必要があります。使用位置の局所変数の対応表を、本体へ渡さない点にも注意が要ります。

今回追加した入れ子のリスト定数と局所束縛の下の例は、この展開後の計算と番号の対応を確認する基準として使えます。