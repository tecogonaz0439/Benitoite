C5a-2 を完了しました。**直接の呼び出しを `CallHead` で組み立てる形に変更し、型保存の証明と指定された検査はすべて成功しました。不一致は 0、`sorry` と Lean の警告はありません。** コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

既存 6 ファイルを変更し、補題のファイルを 1 つ追加しました。行数は完了時のファイル全体、追加・削除は `HEAD` との差分です。

| 区分 | ファイル | 行数 | 追加／削除 | 内容 |
|---|---|---:|---:|---|
| 変更 | [Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean:30) | 287 | +38／−13 | `CallHead`・`rename`・`apply`、直接の頭の判定、呼び出しの組み立て、対応する表のコメント |
| 変更 | [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:1017) | 1,426 | +166／−3 | 既存の期待値 1 件を修正。`rfl` の例 13 件と、高カインド型の型付け導出 2 件を追加 |
| 新規 | [Lemmas/CallHead.lean](../../../../../formal/Benitoite/Surface/Lemmas/CallHead.lean:49) | 146 | +146／−0 | 表層の導出の逆転、直接の頭の型付け。宣言の移送と辞書の値化の既存補題も移動 |
| 変更 | [Lemmas/Calls.lean](../../../../../formal/Benitoite/Surface/Lemmas/Calls.lean:14) | 154 | +70／−14 | 頭の型付け・範囲の述語と、共通の呼び出しの証明 |
| 変更 | [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean:28) | 215 | +11／−5 | 辞書付きの頭について範囲保存を証明 |
| 変更 | [Lemmas/Sequence.lean](../../../../../formal/Benitoite/Surface/Lemmas/Sequence.lean) | 143 | +0／−12 | 一般の頭には成立しなくなった旧補題を削除 |
| 変更 | [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:62) | 478 | +17／−45 | 四か所の呼び出し元を新しい頭の型付けへ接続 |
| **合計** | **7 ファイル** | **2,849** | **+448／−92** | **差し引き 356 行増加** |

変更は `formal/Benitoite/Surface/` 内だけです。`Syntax.lean`・表層の `Typing.lean`・`Theorems.lean` は、ファイル全体が `HEAD` と一致しています。`Release`・`Core`・組み込みの仮定、差分テストのファイルは変更していません。公理の確認に使った一時ファイルは削除しました。

## 2. 直接の呼び出しの表し方と、呼び出しの頭の定義、操作の頭への備え

頭は次の二つの形です。

```lean
inductive CallHead where
  | app (func : Val) (dicts : List Val)
  | meth (dict : Val) (method : MethName)
      (tys : List Ty) (effs : List Eff) (dicts : List Val)
```

`directCallee` は、裸の `funDicts` を `.app (.fnRef …) 辞書列`、裸の `methName` を `.meth V m S̄ Ē Ū` にします。`.paren` は直接の頭に含めず、既存のラムダへの値化を通します。`Expr` の構成子と欄の並びは変えていません。

`CallHead.apply` は、辞書を値引数の前へ連結します。`callComp` の直接の分岐が作る最終形は次のとおりです。

- 制約を持つ関数：`.app f (辞書 ++ 挿入引数 ++ 引数の変数)`
- メソッド：`.meth V m S̄ Ē (Ū ++ 挿入引数 ++ 引数の変数)`

頭の値、受け手の辞書、辞書列は、すべて `shift + ms.length` だけ移します。挿入引数は `ms.length` だけ移します。通常の呼び出し、パイプの規則 1・2、プレースホルダの本体が、この共通処理を使います。

操作の頭は **`.app (.op o ts) []`** です。`CallHead.app` 自体は辞書列を持つため、後の操作の辞書を渡す試行にも、同じ引数の並びを使えます。

## 3. 表層の型付けの規則を変えていないことと、直接の呼び出しの型が既存の規則から得られる理由

表層の型付け規則は変更していません。`E_Call`、パイプ、プレースホルダ、`E_FunDicts`、`E_MethName`、`E_Sub` をそのまま使います。

追加した逆転の補題は、次の二つです。

| 補題 | 取り出すもの |
|---|---|
| `HasType.inv_funDicts` | `E_FunDicts` の宣言・具体化・辞書の型付けなどの前提と、`Ty.Le (fnTy …) T` |
| `HasType.inv_methName` | `E_MethName` の受け手・メソッド宣言・辞書の分割・先頭非辞書型の条件と、関数型の包含 |

式と型を一般化し、`HasType.rec` による導出の帰納法で証明しました。`E_Sub` の場合は、内側の導出が与える型の包含を推移律でつなぎます。

直接の頭の型付けでは、これらを逆転し、`Ty.Le.fn_fn'` から **引数型と戻り値型の一致、呼び出しのエフェクトの包含**を得ます。制約付き関数では `V_Fun` と辞書列の型付け、メソッドでは受け手の辞書と `C_Meth` の前提を構築します。辞書付きの頭の型は、値化したラムダの型から逆算していません。

## 4. 補題の言明の変え方と、既存の形の証明を保った方法。`#print axioms` の出力

`CallHead.HasType Γ h as a ε` は、辞書を除いた値引数の型列と、呼び出しの結果型・エフェクトを表します。`CallHead.HasType.apply` により、頭と値引数列の型付けから `h.apply ws` の計算の型付けを得ます。頭の `rename` とエフェクトの弱化についても補題を追加しました。

`callComp_typed` の直接の頭の前提は、指定された「移した後」の形に変更しました。

```lean
∀ h, directCallee f = some h → ∀ ys : List (Option Ty),
  CallHead.HasType P B C (ys ++ xs ++ Γ)
    (h.rename (· + (shift + ys.length))) (ips ++ ps) a εcall
```

四か所の呼び出し元では、元の頭の型付けを `RenOk.shift` で一度だけ移します。頭を段階的に移して合成する必要がないため、`Val.rename` の合成の補題は追加していません。

`directCallee_rename` と `desugarExpr_direct` は削除しました。辞書のない閉じた名前については、従来の `return` の逆転による型付けを保っています。間接呼び出しの証明も、callee を先に束縛する既存の形を保っています。範囲保存は `CallHead.Scoped`・`rename`・`apply` を介して証明しました。

公理の確認結果は次のとおりです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

二つの最終定理は、言明・前提・証明本体とも変更していません。

## 5. 01-12 の表の行と、脱糖の関数の場合・例の対応の表。直した既存の例の期待値。高カインドの型の例

| 01-12 の行・規則 | 脱糖の対応 | 主な例 |
|---|---|---|
| 型クラス第 1 行：メソッドの呼び出し | `directCallee.methName` → `CallHead.apply.meth` | `meth_call_row` |
| 型クラス第 3 行：制約付き関数の呼び出し | `directCallee.funDicts` → `CallHead.apply.app` | 修正した `fun_dicts_call_row` |
| 型クラス第 2・4 行：名前を値として使う | 既存の `desugarExpr.methName`・`funDicts` のラムダ | 既存の値化の例、`higher_method_value_row` |
| 呼び出しのパイプの行、01-02 の規則 1 | `pipe` の `.call` → `callComp 1` | `fun_dicts_pipe_call_row`、`meth_pipe_call_row` |
| 同規則 2：裸の名前 | `pipe` の一般の右辺 → `callComp 1` | `fun_dicts_pipe_value_row`、`meth_pipe_value_row` |
| プレースホルダのラムダ展開 | `partialCall` → ラムダ本体の `callComp` | `fun_dicts_partial_row`、`meth_partial_row` |
| 括弧付きの頭・右辺 | `directCallee = none` → 値化・callee の束縛 | `fun_dicts_paren_call_row`、`meth_paren_pipe_row`、`fun_dicts_paren_partial_row` |
| プレースホルダにパイプの規則 2 を適用 | 外側は値化したラムダ、内側は直接の頭 | `fun_dicts_partial_pipe_row` |
| 型クラスの高カインド型 | `ctor .list` の辞書と `tapp` を含むメソッド型 | `higher_method_call_row`、`higher_method_value_row` |

**既存の期待値を変更したのは `fun_dicts_call_row` だけです。** callee のラムダを束縛する形から、次の直接の形に変更しました。

```lean
.letIn (.ret (vInt 7))
  (.app (.fnRef "render" [intTy] []) [.var 1, .var 0])
```

旧期待値の値化する形は、新しい `fun_dicts_paren_call_row` で確認しています。C5b-1 の、関数値を局所変数へ束縛してから呼ぶ実行例も残しています。

高カインド型の例では、`FunctorList` の実装対象を `.ctor .list` とし、`identity` メソッドの引数・戻り値を `.tapp 1 [.tvar 0]` としました。型クラス引数 P が番号 1、メソッドの型パラメータが番号 0 です。具体化後の型が `List[Integer]` になることを、**値化と直接呼び出しの両方の型付け導出**で確認しました。

## 6. 処理系の脱糖との違いと、01-12 との食い違い。`scripts/check-formal.sh` の結果

今回の変更で、制約付き関数とメソッドの直接の呼び出しは、処理系の `prepare`・`invoke`・`method` と同じ組み立てになりました。括弧による値化の境界も一致しています。

残る表現上の違いは、既存の対応づけです。Rust は辞書列と値引数列を別の欄に保持し、Lean は一つの引数列に連結します。Rust の名前付き変数は Lean の de Bruijn 番号に写し、メソッドの型クラス引数 P とメソッドの型パラメータの番号も並べ替えます。

**01-12 との食い違い**として、型クラスの表の第 3 行が具体的な形を決めきっていないため、Rust の直接の `App` の形に合わせたことをコメントに記しました。通常の名前の直接呼び出しとパイプの再束縛の省略は、現在の 01-12 に既に記載されているため、そのコメントも現在の表に合わせました。

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、67 jobs、警告なし |
| `formal/` で `lake build desugarDiff` | 成功、16 jobs |
| `scripts/check.sh --base HEAD --dry-run` | `formal` の検査だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `scripts/check-formal.sh` | 成功、不一致 0 |
| Lean ソースの字句確認 | `sorry`・`native_decide` なし |
| `git diff --check` | 成功 |

差分検査では、ゴールデン **190 プログラム・371 関数**、ランダム **1,000 プログラム・14,218 関数**が一致しました。Rust の書き出しは約 75 秒、差分比較は約 2 秒でした。記録は [report.json](../../../../../target/desugar-diff/run-4201/report.json) にあります。

## 7. 差分テストの拡張、操作の頭の辞書の並び、C6・C7 で難しくなりそうな箇所の見込み

**C5c-2** では、直接の制約付き関数・メソッドを比較対象へ加えられます。現在のコーパスでは型クラスと高カインド型が引き続き対象外なので、今回の不一致 0 は既存範囲の維持を確認する結果です。拡張時には、辞書と値引数の連結、受け手 V と自身の辞書 Ū の区別、パイプと穴の束縛による番号の移動、括弧付きの頭を確認する必要があります。

**ADR 0312 の制限を外した版**については、操作の辞書を渡す順序が今回の頭の定義と一致することを確認できます。

```lean
(CallHead.app (.op o ts) ds).apply (inserted ++ args)
  = .app (.op o ts) (ds ++ (inserted ++ args))
```

`OpDecl.params` の先頭に辞書型を置く案では、`CallHead.HasType.app` の `dtys ++ as` と `V_Op`・`C_App` を接続できます。操作宣言と節の arity・束縛を合わせる試行は、後の作業です。今回の表層の操作の頭の辞書は空のままです。

**C6** では、定数の参照やフィールドを取り出す関数を、直接の頭と値として評価する頭のどちらへ分類するかが確認点になります。今回の共通処理は、その分類後の辞書・挿入引数・値引数の組み立てを再利用できます。

**C7** では、選択肢ごとの束縛対応と、ガードの環境への移送が主な負担になる見込みです。頭に含まれる辞書も、その束縛対応に従って移す必要があります。今回は `CallHead.HasType.rename` と範囲保存の補題を追加したため、頭を構成する値ごとに証明を繰り返す必要はありません。