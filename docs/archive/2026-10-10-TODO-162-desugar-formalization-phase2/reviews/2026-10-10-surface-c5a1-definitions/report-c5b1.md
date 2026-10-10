C5b-1 を完了しました。指定された **3 か所の未証明部分をすべて証明し、`lake build` は警告なしで成功**しました。二つの最終定理が使う公理は、指定された三つだけです。変更は `formal/Benitoite/Surface/` 内に限定し、コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

既存8ファイルを変更し、補題のファイルを2つ追加しました。行数は完了時のファイル全体、追加・削除は `HEAD` との差分です。

| 区分 | ファイル | 行数 | 追加／削除 | 変更内容 |
|---|---|---:|---:|---|
| 変更 | [Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean:57) | 262 | +2／−1 | 辞書の自由変数をずらす理由のコメントを修正 |
| 変更 | [Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean:73) | 415 | +2／−1 | `E_MethName` に値引数の先頭が辞書型でないという前提を追加 |
| 新規 | [Lemmas/Dict.lean](../../../../../formal/Benitoite/Surface/Lemmas/Dict.lean:10) | 32 | +32／−0 | 辞書の型付けの `hideConts` 保存、辞書型の置換がエフェクト引数に依存しないこと |
| 新規 | [Lemmas/SubstClean.lean](../../../../../formal/Benitoite/Surface/Lemmas/SubstClean.lean:8) | 52 | +52／−0 | 一般の置換位置での `TyOK` と型列の範囲保存 |
| 変更 | [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean:259) | 350 | +1／−1 | `HasType.clean` の場合分けを新しい前提数に対応 |
| 変更 | [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean:45) | 209 | +1／−1 | `desugar_scoped` の場合分けを新しい前提数に対応 |
| 変更 | [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:62) | 506 | +25／−2 | `E_FunDicts`・`E_MethName` の型保存を証明 |
| 変更 | [Lemmas/Program.lean](../../../../../formal/Benitoite/Surface/Lemmas/Program.lean:45) | 121 | +42／−2 | D-Impl の型保存を証明 |
| 変更 | [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:1055) | 1,263 | +177／−2 | 宣言の補充、型付け導出、制約付き関数の値化と呼び出しの実行例 |
| 変更 | [Theorems.lean](../../../../../formal/Benitoite/Surface/Theorems.lean:4) | 40 | +3／−3 | 証明待ちの注記を完了後の説明へ修正。コメントのみ |
| **合計** | **10ファイル** | **3,250** | **+337／−13** | **差し引き324行増加** |

完了時の検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、66 jobs、警告なし |
| `formal/` で `lake build desugarDiff` | 成功、16 jobs |
| `scripts/check.sh --base HEAD --dry-run` | `formal` の検査だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| `formal/Benitoite/` の Lean ソースの字句確認 | `sorry`・`native_decide` なし |
| 二つの最終定理の言明を `HEAD` と比較 | 前提を含めて一致 |
| 変更範囲の確認 | `Surface/Syntax.lean` は変更なし。`Surface/Desugar.lean` はコメントだけ |

`Release`・`Core`・組み込みの `Assumptions`、指定された変更対象外のファイルは変更していません。

## 2. `#print axioms` の出力

README の手順に従い、`formal/c5b1-axioms.lean` に `import Benitoite` と公理の確認を書き、`formal/` で `lake env lean c5b1-axioms.lean` を実行しました。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

一時ファイルは確認後に削除しました。

## 3. 指摘 1 の前提の足し方

`E_MethName` の `ps = …drop us.length` の直後に、指定の形で次の前提を追加しました。

```lean
(∀ a ∈ ps.head?, ∀ cl t, a ≠ .dict cl t) →
```

値引数がある場合、その先頭の型が辞書型でないことを要求します。値引数が空の場合は自明です。辞書型を先頭に並べるメソッド宣言に対して、辞書の一部を値引数側に残す分割を排除します。表層の値引数には `Dict` 型を書けないため、利用者が書く言語の規則は変わりません。

前提数の変更に合わせて、`HasType.clean`・`HasType.desugar_scoped`・`HasType.desugar` の場合分けを修正しました。

## 4. 証明の構成（足した主な補題と役割）

追加した主な補題は次のとおりです。

| 補題 | 役割 |
|---|---|
| `DictEv.HasType.hide` | 辞書の型付けを `Γ` から `hideConts Γ` へ移す。局所辞書は非継続型なので、同じ番号に残る |
| `DictEv.HasTypes.hide` | 辞書列について同じ環境の移送を示す |
| `FunDecl.dictTys_substEff` | 宣言の辞書型に対する `Ty.subst ts []` と `Ty.subst ts es` の一致を示す |
| `substAt_clean` | `TyOK (c + ts.length) a` と置換型列の範囲条件から、`TyOK (c + n) (a.substAt c ts es)` を示す |
| `substAtList_clean` | 型列について同じ置換の範囲保存を示す |

**`E_FunDicts`** では、辞書列の型付けを `hideConts Γ` へ移し、既存の `toVal` で値列の型付けを得ます。その後、`RenOk.shift (binds ps) …` でラムダ引数の下へ移し、`boundVars_typed` が与える値引数列と連結します。`dictTys_substEff` で辞書型の置換を合わせ、`V_Fun`・`C_App`・`V_Lam`・`C_Return` を構築しています。

**`E_MethName`** では、受け手の辞書 V と自身の制約の辞書列 Ū を、同じく継続を隠した環境とラムダ引数の下へ移します。Ū と値引数列の型を `List.take_append_drop` で再結合し、`C_Meth` の全引数型の前提を満たします。

**D-Impl** では、`MethSig.Scoped` と実装対象型の範囲条件から、`substAt_clean`・`substAtList_clean` により `methTy` を施した戻り値型と引数型の範囲を得ます。実装の辞書引数には既存の `shiftList_clean` を使い、両列を合わせて `EnvClean` を構築します。これをメソッド本体の `HasBlock.desugar` に渡し、上位辞書は `DictEv.HasType.toVal` で移しています。

`substAt_clean` の `tapp` の場合は `Ty.applyTo_varsIn` を使っています。高カインド型を除外する条件は追加していません。

## 5. 表層の型付けや範囲の条件を、1 のほかに変えた箇所と理由

**なし。**

型付け規則の変更は、指定された `E_MethName` の前提追加だけです。`WellFormed.lean`、二つの最終定理の言明と前提、脱糖の定義は変更していません。

## 6. 加えた型付けの例と実行の例、確かめた振る舞い

| 例 | 確認した内容 |
|---|---|
| `implementation_typed` | `c5Impl` の `ImplDecl.WellTyped`。`combine`・多相な `choose` の本体と、局所の `Monoid` 辞書から `Semigroup` を取り出して作る上位辞書 |
| `meth_value_typed` | `choose` の `E_MethName`。受け手 V と `Show` の辞書1個の Ū を局所環境に置き、値引数を `[Box[Integer], Integer]`、エフェクトを `IO` に具体化 |
| `renderPair_value_typed`・`fun_dicts_value_typed` | `renderPair` の `E_FunDicts`。`Show`・`Order` の二つの辞書を捕え、二つの値引数だけを持つ関数型を得る |
| `constrained_value_definition_typed` | 制約付き関数を値として束縛し、その局所変数を呼ぶ表層関数の `Def.WellTyped` |
| `constrained_value_execution` | 表層プログラムを脱糖して `Release.run` で実行し、`f(7, 11)` が第2引数の `11` を返して、事象なしで終了すること |

実行例は燃料100で検査し、**`decide` で証明**しました。

`c5Program` には `Monoid`・`Semigroup`・`BoxSemigroup`・`Show`・`Order` の宣言と、`BoxSemigroupI`・整数用の辞書実装を補充しました。既存の `rfl` の例が確認する結果は保持しています。`meth_value_row` には、脱糖だけの例であることと、型付け導出は `meth_value_typed` にあることをコメントで明記しました。

## 7. C5a-2（呼び出しの頭の形）で証明を広げるときの注意

- **直接呼び出しでも辞書と値引数の境界条件を保持してください。** メソッドの規則には今回と同じ先頭非辞書型の前提を持たせ、Ū と値引数を連結して `C_Meth` の前提へ接続できます。
- **呼び出しの頭には、辞書列とメソッドの受け手を表す情報が必要です。** 現在の `directCallee : Expr → Option Val` と `callComp_typed` は関数値の呼び出しを扱います。メソッドの直接呼び出しを足す際は、`.app` と `.meth` の双方の組み立てに対応する必要があります。
- **辞書の自由変数は、挿入する束縛の下へ移してください。** 今回の値化ではラムダ引数の個数だけ移します。直接呼び出しでは、値引数の評価用 `let` とパイプの挿入引数に合わせて移す必要があります。
- **関数の辞書型への置換には `dictTys_substEff` を再利用できます。** 宣言側の `Ty.subst ts []` と、呼び出される関数型側の `Ty.subst ts es` を一致させます。
- **操作の頭にも辞書列を持たせられる構成を考慮してください。** ADR 0312 の制限を外す試行では、操作宣言の引数型の先頭に辞書型を置く案と接続できます。
- **直接呼び出しの形を変えたら、既存の脱糖例の期待値も対応が必要です。** 現在の `fun_dicts_call_row` は値化したラムダを束縛する出力を検査しています。今回の実行例は、関数値を明示的に局所変数へ束縛してから呼ぶ振る舞いを検査する例として残せます。