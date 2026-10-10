C4b-2 を完了しました。**`HasClauses.desugar` の未証明箇所を証明し、`lake build` は Lean の警告なしで成功しました。** 二つの最終定理が使う公理は指定の三つだけです。変更は `formal/Benitoite/Surface/` 内に限定し、コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

既存六ファイルを変更し、補題のファイルを一つ追加しました。行数は完了時のファイル全体、追加・削除は `HEAD` との差分です。

| 区分 | ファイル | 行数 | 追加／削除 | 内容 |
|---|---|---:|---:|---|
| 変更 | [Surface/Desugar.lean](../../../../../formal/Benitoite/Surface/Desugar.lean:198) | 241 | +2／−2 | 節の型パラメータ数の束縛名を `ntys` に変更 |
| 変更 | [Surface/Typing.lean](../../../../../formal/Benitoite/Surface/Typing.lean:280) | 357 | +5／−5 | `HasClauses.cons` の同じ束縛名を変更 |
| 変更 | [Surface/WellFormed.lean](../../../../../formal/Benitoite/Surface/WellFormed.lean:67) | 92 | +2／−2 | `Clauses.Scoped` の同じ束縛名を変更 |
| 変更 | [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean:10) | 297 | +72／−8 | `EnvClean` の拡張、環境と操作シグネチャの補題、`HasType.clean` の修正 |
| 新規 | [Lemmas/ShiftClean.lean](../../../../../formal/Benitoite/Surface/Lemmas/ShiftClean.lean:8) | 58 | +58／−0 | 型と型の並びのシフトが `TyOK` を保つ相互帰納の補題 |
| 変更 | [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:292) | 451 | +25／−6 | `resume` と節の本体の型保存 |
| 変更 | [Surface/Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:841) | 955 | +117／−2 | 多相な利用者の操作とハンドラの型付け・実行の例、注記の更新 |
| **合計** | **七ファイル** | **2,451** | **+281／−25** | **差し引き256行増加** |

完了時の検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、64 jobs、Lean の警告なし |
| `formal/` で `lake build desugarDiff` | 成功、16 jobs |
| `scripts/check.sh --base HEAD --dry-run` | `formal` のみを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `scripts/check-formal.sh` | 成功、Rust の書き出しと差分比較で不一致0 |
| `git diff --check` | 成功 |
| `formal/Benitoite/` の Lean ソースの字句確認 | `sorry`・`native_decide`・`axiom` 宣言なし |
| `Surface/Theorems.lean` と `HEAD` の比較 | ファイル全体が一致 |

差分比較では、golden のプログラム175件・関数352件、random のプログラム1,000件・関数7,218件が一致しました。現在の差分検査では、ハンドラ・再開・利用者の操作はまだ対象外です。その範囲の拡張は、並行して進む C4c-2 の作業に対応します。結果は [report.json](../../../../../target/desugar-diff/run-91570/report.json) にあります。

## 2. `#print axioms` の出力

README の手順に従い、`formal/c4b2-axioms.lean` に `import Benitoite` と二定理の公理確認を書き、`formal/` で `lake env lean c4b2-axioms.lean` を実行しました。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

一時ファイルは確認後に削除しました。

## 3. `EnvClean` の新しい形と、既存の証明の直し方

`EnvClean` を、指定された次の形に広げました。

```lean
def EnvClean (n : Nat) (Γ : List (Option Ty)) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → TyOK n a ∨
    ∃ b t ε, a = .cont b t ε ∧ TyOK n b ∧ TyOK n t
```

通常の環境要素には従来どおり `TyOK` を求めます。継続の要素には、引数型 `b` と結果型 `t` の `TyOK` を求め、エフェクト `ε` には条件を課しません。

既存の証明は次のように修正しました。

- **`HasType.clean` の `E_Local`**：新しい `EnvClean.value` を使います。右の場合は、`E_Local` が持つ「継続の型でない」という前提との矛盾で排除します。
- **`HasType.clean` の `E_Resume`**：環境との矛盾で処理する証明をやめ、`EnvClean.cont` から継続の結果型の `TyOK` を取り出します。
- **`EnvClean.cons`・`binds`**：追加する通常の要素について `Or.inl` を構築します。元の環境の要素には、そのまま元の不変条件を使います。
- **`EnvClean.hide`**：`hideConts_get` の非継続型の条件を使い、残った要素について左の場合を取り出します。
- **`HasType.desugar` の `E_Resume`**：実際の脱糖結果に型を付ける証明へ置き換えました。

`Program.lean` の `EnvClean.binds` の呼び出しは、補題の言明を保ったため、既存の証明のままで通っています。

## 4. 証明の構成（足した主な補題と役割）

追加した主な補題は次のとおりです。

| 補題 | 役割 |
|---|---|
| `shift_clean` | `TyOK n a → TyOK (n + ntys) (a.shift ntys 0)` を示す |
| `shiftList_clean` | 型の並びを `Ty.shift ntys 0` で写した場合の範囲保存を、`shift_clean` と相互帰納で示す |
| `EnvClean.value` | 非継続型の通常の変数から `TyOK` を取り出す |
| `EnvClean.cont` | 継続の環境要素から、引数型と結果型の両方の `TyOK` を取り出す |
| `EnvClean.consCont` | 両成分が `TyOK` の継続を環境の先頭へ追加する |
| `EnvClean.shift` | `shiftEnv ntys Γ` が、範囲を `n + ntys` に広げた `EnvClean` を満たすことを示す |
| `opSig_clean` | 利用者の操作は `OpDecl.Scoped`、組み込みの操作は既存の `hsig` から、引数型と戻り値型の `TyOK` を得る |

`HasClauses.desugar` の `.cons` 分岐では、まず次の長さの等式を得ます。

```lean
(sg.tparams ++ C).length = C.length + ntys
```

この等式で、シフトの補題が返す範囲と節の型文脈の長さを合わせます。操作シグネチャの引数型・戻り値型は `Ty.VarsInList.mono`・`Ty.VarsIn.mono` で範囲を広げます。外側の環境は `EnvClean.shift`、節の引数は `EnvClean.binds`、継続は `EnvClean.consCont` で加えます。`R.map (Ty.shift ntys 0)` の条件も `shift_clean` で示し、これらを本体の `HasBlock.desugar` に渡しています。

`E_Resume` の型保存では、引数式の型保存を `C_Let` の第一前提に使います。第二前提では、

```lean
(some b :: Γ)[k + 1]? = Γ[k]?
```

により継続を参照し、`C_Resume` を組み立てます。引数値 `.var 0` に必要な非継続型の条件は、`EnvClean.cont` が返す `b` の `TyOK` と `clean_notCont` から得ています。

## 5. 表層の型付けや範囲の条件を変えた箇所と理由

**なし。**

指定された束縛名の変更として、節の型パラメータ数を表す `k` を `ntys`、対応する証明の仮定名を `hntys` にしました。型付け規則・範囲条件の意味と脱糖結果は同じです。

`Surface/Syntax.lean`、二つの定理の言明と前提、`Release`・`Core`、組み込みの `Assumptions` は変更していません。

## 6. 加えた型付けの例と実行の例、確かめた振る舞い

利用者の操作として、次の多相な操作を使う表層プログラムを追加しました。

```text
Identity.identity[T](value: T) -> T
```

節は型パラメータを一つ束縛し、継続を番号0、操作の引数を番号1に置きます。

`identityHandled_typed` は、`E_Op`・`E_Handle`・`HasClauses.cons`・`E_Resume` を使って、ハンドラ式に空のエフェクトで型が付くことを示します。`handler_definitions_typed` は、実行する二つの関数の `Def.WellTyped` を示します。

実行例は、表層の `handlerProgram` を脱糖し、`Release.run` に燃料100を渡して、次を **`decide`** で確認しています。

| 関数 | 節の振る舞い | 確認した結果 |
|---|---|---|
| `resumed` | 操作の引数 `11` で `resume` する | 本体の続きが再開値に1を足し、`12` を返す。事象なし |
| `aborted` | `resume` せず `99` を返す | 本体の加算を続行せず、`handle` の結果が `99` になる。事象なし |

二つの例は本体と操作宣言を共有し、節で再開するかどうかだけを変えています。既存の C4a-2 の注記も、後続の C4b-2 の例で型付けと実行を検査する説明に直しました。

## 7. 後の段階（C5 の型クラス、C6、C7）で証明を広げるときの注意

**C5 の型クラス**では、辞書の引数も通常の環境要素として `TyOK` を示し、`EnvClean.binds` に渡せます。今回のシフトの証明は、既存の `Ty.dict`・`Ty.tapp`・`Ty.ctor` も扱っています。ADR 0312 の制限を外した版を試す際には、操作の値の辞書引数と、節の `arity` が数える引数の範囲を対応させる必要があります。`opSig_clean` が得る引数型の並びも、その宣言に合わせて扱ってください。

**C6 の脱糖だけで表す拡張**では、追加する計算の結果について `HasType.clean` を広げ、挿入する束縛には通常の型の `TyOK` を渡す構成を維持してください。生成する関数や埋め込む定数でも、入口の引数型・戻り値型の範囲条件から環境と `R` の不変条件を得る必要があります。節の中の型注釈は、引き続きシフト後の番号で保持する必要があります。

**C7 のパターンとガード**では、パターンが加える通常の束縛は `PatTy.clean` と `EnvClean.binds` で扱えます。ガードの中で `resume` を認める場合は、外側の継続を環境に保持し、パターンや脱糖が挿入する束縛の分だけ継続番号を移す証明が必要です。ラムダ・`lazy`・プレースホルダが使う `hideConts` による継続の非可視化と、ガードの環境の扱いを区別してください。