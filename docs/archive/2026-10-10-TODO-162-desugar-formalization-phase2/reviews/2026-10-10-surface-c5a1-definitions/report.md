C5a-1 の実装を完了しました。`formal/` の **`lake build` と `lake build desugarDiff` は成功**しています。`sorry` の字句は、許可された新しい型保存の分岐 **3 か所だけ**です。コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

変更は `formal/Benitoite/Surface/` の既存 10 ファイルだけです。新規ファイルはありません。行数は完了時のファイル全体、追加・削除は `HEAD` との差分です。

| ファイル | 行数 | 追加／削除 | 変更内容 |
|---|---:|---:|---|
| [Syntax.lean](../../../../../formal/Benitoite/Surface/Syntax.lean) | 310 | +59／−3 | 辞書の根拠、値化の二構成子、辞書引数、型クラスと実装の表 |
| [Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean) | 414 | +62／−5 | 辞書・値化・実装の型付け、関数本体の環境 |
| [WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean) | 129 | +40／−3 | 辞書・値化・宣言と実装の範囲条件 |
| [Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean) | 261 | +23／−3 | 値化のラムダ、辞書付き関数定義、実装の脱糖 |
| [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:957) | 1,088 | +135／−2 | 新しい `rfl` の例 16 件、既存例の機械的な修正 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean) | 350 | +54／−1 | 辞書型の範囲、`main` の辞書引数が空となる補題、結果型の不変条件 |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean) | 209 | +25／−1 | 辞書と値化の脱糖の範囲保存 |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean) | 483 | +35／−3 | 宣言表の対応、辞書の型保存、新しい二分岐の証明待ち |
| [Lemmas/Program.lean](../../../../../formal/Benitoite/Surface/Lemmas/Program.lean) | 81 | +36／−8 | 実装表の範囲保存、関数と入口の証明の修正、実装表の型保存の証明待ち |
| [Theorems.lean](../../../../../formal/Benitoite/Surface/Theorems.lean) | 40 | +4／−3 | `main_typed` に `hwf` を渡す修正、対象範囲と証明待ちの注記 |
| **合計** | **3,365** | **+473／−32** | **差し引き 441 行増加** |

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功 |
| `formal/` で `lake build desugarDiff` | 成功 |
| `scripts/check.sh --base HEAD --dry-run` | `formal` だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| 二つの定理の言明を `HEAD` と比較 | 両方とも一致 |
| Lean ソースの `sorry` の字句確認 | 許可された 3 か所だけ |

`Release`・`Core`・`Assumptions`、設計書・レビュー記録、処理系、差分テストのソースは変更していません。`Exchange` は修正なしでビルドできました。

## 2. 足した構文の表し方

辞書の根拠は指定の三構成子です。

```lean
inductive DictEv where
  | impl (i : ImplName) (tys : List Ty) (args : List DictEv)
  | local (j : Nat)
  | super (d : DictEv) (s : ClassName)
```

`DictEv.toVal` と `DictEv.toValList` は相互の構造的再帰で定義し、それぞれ `.dict`・`.var`・`.super` へ直接移します。計算や `let` は作りません。`local j` は通常の環境 Γ の番号をそのまま使います。

`FunDecl` には、既定値が空の `dictParams : List (ClassName × Nat)` と、そこから辞書型の列を作る `FunDecl.dictTys` を追加しました。`desugarDef` の出力は次の形です。

```lean
params := d.dictTys ++ d.params
```

値として使う形には、既存の `.funName` と別の構成子を追加しました。

```lean
| funDicts (f : FunName) (tys : List Ty) (effs : List Eff)
    (dicts : List DictEv) (params : List Ty)
| methName (dict : DictEv) (m : MethName) (tys : List Ty) (effs : List Eff)
    (dicts : List DictEv) (params : List Ty)
```

末尾の `params` は、具体化したラムダの値引数の型注釈です。脱糖が宣言表を読まずに進めるために持たせ、型付け規則で宣言から得る型と一致することを検査します。両方とも `PipeValue` の残りの場合に属し、`Exits` は偽です。`directCallee`・`callComp` は変更していません。

表には次を追加しました。

- `Program.classes`：`Release.ClassDecl` の表。既定値は空。
- `Program.impls`：表層の `ImplDecl` の表。既定値は空。
- `Declarations.classes`：型クラス宣言の表。既定値は空。
- `Declarations.impls`：`ImplSig` の表。既定値は空。

`ImplSig` は `tparams`・`dictParams`・`cls`・`target` を持ち、表層の `ImplDecl` はそれに `supers : ClassName → Option DictEv` と `methods : MethName → Option Block` を加えます。`Program.declarations` はこれらの表を写します。`patternProgram.impls` は空のままです。

## 3. 足した表層の型付けの規則と、01-06・01-12 との対応

| 規則 | 検査する内容 | 対応 |
|---|---|---|
| `DictEv.HasType.impl` | 実装シグネチャ、`SatAll`、具体化した実装の制約の辞書型 | 01-12 の V-Dict |
| `DictEv.HasType.local` | `Γ[j]? = some (some (.dict cl τ))` | 01-12 の受け取った辞書の引数、P6 |
| `DictEv.HasType.super` | 元の辞書型、型クラス宣言、上位クラスへの所属 | 01-12 の V-Super、01-06 の上位クラスの制約 |
| `E_Fun` | 既存の前提に `d.dictParams = []` を追加 | 辞書を要しない関数名 |
| `E_FunDicts` | 関数宣言、型・エフェクト引数、非空の辞書引数宣言、値引数型の注釈、具体化した辞書型 | 01-12 の表の第 4 行、01-06 の制約を持つ関数 |
| `E_MethName` | 受け手の辞書、メソッド宣言、型・エフェクト引数、自身の制約の辞書、値引数型の注釈 | C-Meth と表の第 2 行 |
| `ImplDecl.WellTyped` | 宣言と本体・上位辞書の対応、各本体と辞書の型付け | D-Impl、01-06 の実装の規則 |

`E_FunDicts` の表層の型は、値引数だけを含む `fnTy d.params …` です。辞書列は `d.dictTys.map (Ty.subst ts [])` で検査します。

`E_MethName` の置き換えは、指定どおり次の形です。

```lean
θ := Ty.subst (ss ++ [τ]) es
```

`τ` は受け手の辞書型から取ります。具体化した `ms.params` の前半を `take us.length`、後半を `drop us.length` で分け、前半を辞書の根拠、後半をラムダの引数に対応させています。

**この分割位置は、宣言が持つメソッド自身の制約数とは結び付いていません。** `MethSig` にその個数の欄がないためです。型が合う範囲では、辞書型の引数の一部をラムダの引数側に残す形も表せます。これは指定された表層の判断の広さであり、処理系の辞書選択を変更するものではありません。

関数本体の環境は `binds (d.dictTys ++ d.params)` に変更しました。実装のメソッド本体は、次の制約と環境で検査します。

```lean
C := ms.tparams ++ id.tparams
Γ := binds
  (id.dictTys.map (Ty.shift ms.tparams.length 0) ++
   ms.params.map (id.methTy ms))
R := some (id.methTy ms ms.ret)
```

本体は `.tail` で検査し、各本体に `body.Exits ∨ ret = Unit` を要求します。実装のメソッドと上位辞書の有無も宣言と一致させ、宣言にないものを持てない条件を置きました。

`Program.WellFormed` には、型クラスの `ClassDecl.Scoped` と表層の `ImplDecl.Scoped` を追加しました。実装の条件には、辞書引数の型パラメータ番号、対象型、上位辞書の型・値変数の範囲、メソッド本体の型変数範囲 `ms.tparams.length + id.tparams.length`、エフェクト変数範囲 `(· < ms.neffs)`、値変数の個数を含めています。関数の `Def.Scoped` にも辞書引数の番号条件と、辞書・値引数を合わせた本体の変数数を追加しました。

`Program.WellTyped` には実装表の型付けを追加しています。高カインド型について、新しい制限は加えていません。

## 4. 定理の言明と、`sorry` を置いた箇所の一覧

**`desugar_typed` と `surface_effect_soundness` の言明・前提は変更していません。** `HEAD` のソースから取り出した言明との比較で一致を確認しました。`surface_effect_soundness` の証明内で、`main_typed` に既存の `hwf` を渡す修正だけを行っています。

`main_typed` では、`HasMain` の `tparams = []` と `Def.Scoped` の辞書引数の番号条件から `dictParams = []` を導きます。この補題と入口の証明に `sorry` はありません。

残した `sorry` は次の 3 か所です。

| 場所 | 未証明の目標 |
|---|---|
| [Lemmas/Typing.lean:61](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:61) | `HasType.desugar` の `E_FunDicts`：辞書を渡すラムダの型保存 |
| [Lemmas/Typing.lean:62](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:62) | `HasType.desugar` の `E_MethName`：メソッドを値にするラムダの型保存 |
| [Lemmas/Program.lean:59](../../../../../formal/Benitoite/Surface/Lemmas/Program.lean:59) | `desugar_wellTyped` の実装表：D-Impl の型保存 |

辞書の値への移送の型保存・範囲保存、新しい二構成子の結果型の不変条件と脱糖の範囲保存、実装表を含む `desugar_wellFormed` は証明済みです。既存の場合の証明にも `sorry` は追加していません。

`#print axioms` でも、これらの証明済み補題と `main_typed` が `sorryAx` に依存しないことを確認しました。二つの最終定理は、上記の証明待ちを通じて `sorryAx` に依存する状態です。

## 5. 01-12 の表の行と、脱糖の関数の場合・例の対応の表

追加した 16 件の例は、すべて期待するコア項との一致を `rfl` で確認します。

| 01-12 の行・規則 | 脱糖の関数・場合 | 例 |
|---|---|---|
| V-Dict、実装の制約の辞書 | `DictEv.toVal.impl`・`toValList` | `dict_impl_row`、`dict_list_row` |
| 受け取った辞書の引数 | `DictEv.toVal.local` | `dict_local_row` |
| V-Super、上位の上位への参照 | `DictEv.toVal.super` | `dict_super_row` |
| 第 2 行：メソッドを値として使う | `desugarExpr.methName` | `meth_value_row`、`meth_nullary_value_row` |
| 第 4 行：制約を持つ関数を値として使う | `desugarExpr.funDicts` | `fun_dicts_value_row`、`fun_dicts_nested_value_row`、`fun_dicts_nullary_value_row` |
| 第 1・3 行の呼び出しに相当する形 | C5a-1 では既存の `callComp` で値化したラムダを呼ぶ。直接の形は C5a-2 | `fun_dicts_call_row` |
| 辞書型を値引数の前に置く関数定義 | `desugarDef` | `constrained_function_row` |
| 型クラス宣言 | `desugarProgram.classes` | `class_declaration_row` |
| D-Impl のシグネチャ | `desugarImpl` | `implementation_signature_row` |
| D-Impl の上位辞書 | `desugarImpl.supers` | `implementation_super_row` |
| D-Impl のメソッド本体 | `desugarImpl.methods` → `desugarBlock … .tail` | `implementation_method_row`、`implementation_polymorphic_method_row` |

実装の `supers`・`methods` は、構造体全体ではなく、脱糖後の実装表から具体的な名前で引いた結果を比較しています。二つの値化の主要例は `pos : Position` を引数に取り、末尾・非末尾の両方について同じ出力になることを確認します。

## 6. 処理系の脱糖との違いと、01-12 との食い違い

| 要素 | 今回の Lean／`Release` | 処理系との対応 |
|---|---|---|
| 上位クラスの参照 | `.super d s` が型クラス名を持つ | `DictKind::Super` の上位クラス一覧の番号を、名前に写す必要がある |
| 受け取った辞書 | 通常の Γ の de Bruijn 番号 | `DictKind::Param` の変数番号と `ImplParam` の制約番号を、通常の環境の位置に写す |
| 関数の辞書引数 | `Def.params` の先頭に含める | 処理系の独立した `dict_params` を値引数の前へ連結する |
| 関数の呼び出し | `.app f (辞書 ++ 値引数)` | `App { func, dicts, args }` の二列を連結する |
| メソッドの呼び出し | `.meth V m ss es (Ū ++ 値引数)` | 辞書選択の列の 0 番が V、残りが Ū。処理系の `MethodCall` では V を `dict`、Ū を `dicts` に分けて保持する |
| メソッド宣言の型番号 | γ̄ が `0..g-1`、P が `g` | 処理系の P が 0、γ̄ がその後の並びを並べ替える |
| 実装のメソッドの型番号 | γ̄ が先、β̄ が後 | 処理系の β̄ が先、γ̄ が後の並びを並べ替える |
| 実装のメソッドの辞書環境 | 実装の辞書 d̄、その後にメソッド引数。自身の制約の辞書は `ms.params` の先頭 | 処理系の `ImplParam` と、メソッド自身の `dict_params` を同じ環境に写す |
| `f[T̄; Ē]` 自体の型 | `V_Fun` は辞書を含む全引数の関数型 | 02-06 の処理系では値引数だけの関数型を持てる。今回の表層では辞書を適用するラムダによって、値引数だけの型を与える |
| 制約付き関数・メソッドの直接呼び出し | C5a-1 では値化したラムダを束縛して呼ぶ | 処理系の `prepare` は直接の頭を作る。この差は C5a-2 で解消する |

**今回実装した表の第 2・4 行と D-Impl の脱糖について、新しい 01-12 との食い違いはありません。** メソッド本体は処理系の `definition` と同じく末尾位置で脱糖します。

第 1・3 行の直接呼び出しは今回の範囲外です。ラムダを経由する現在の形は、依頼で指定された C5a-1 の暫定の形です。型クラスを含む処理系との自動差分検査はまだ拡張しておらず、今回の確認はソースの照合と `rfl` の脱糖例によるものです。

## 7. 後続の作業で難しくなりそうな箇所の見込み

**C5b-1 の証明**では、残した三目標が中心になります。辞書の型保存は証明済みなので、二つの値化規則ではそれを `hideConts Γ` とラムダの引数の下へ移し、値引数の `boundVars` と連結します。関数の場合は辞書型の具体化に使う `[]` と、全関数型の具体化に使う `es` の一致を整理します。メソッドの場合は `take` と `drop` の再結合を使って C-Meth の全引数列を復元します。D-Impl では `methTy` による対象型の置き換えと、辞書型を γ̄ の個数だけずらした環境の不変条件を組み立てる必要があります。

**C5a-2**では、`directCallee`・`callComp` と、それらの型付け・範囲保存の補題を同時に変更することが主な作業になります。パイプとプレースホルダで、挿入した束縛の下へ V と Ū の両方をずらす必要があります。高カインド型は既存の `Ty.tapp`・`Ty.ctor` と置き換えの補題を使えますが、P と γ̄ の番号の区別を具体例で確認する必要があります。

**C5c**では、上表の型番号・辞書番号の変換と、実装の定義を比較対象に加える部分が要点です。実装の辞書・自身の制約の辞書・値引数を混同せず、上位クラスとメソッドの番号を名前へ写す必要があります。C5a-1 のラムダ経由の呼び出しは、C5a-2 後の直接の形に合わせて比較してください。

**ADR 0312 の制限を外した版の試み**では、操作の宣言と節が辞書を束縛するかどうかが問題になります。現在の辞書の型付けは通常の Γ に辞書型の要素を要求するため、辞書を渡さない案では、その要素を得られない箇所で型保存が止まる見込みです。渡す案では、計画にあるとおり、`Release` の操作宣言・操作値の型付け・節の引数と、表層の `arity`・`opName` を合わせて変更する必要があります。今回の実装では、その制限や `Release` の規則を変更していません。