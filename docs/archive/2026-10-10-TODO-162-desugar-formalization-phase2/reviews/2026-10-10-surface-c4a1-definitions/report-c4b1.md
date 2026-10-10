C4b-1 を完了しました。指定された **12 か所の証明待ちをすべて証明し、`formal/` の `lake build` は Lean の警告なしで成功**しました。二つの定理が使う公理は指定の三つだけです。`scripts/check.sh --base HEAD` も、`formal` の検査だけを選んで成功しました。コミットは行っていません。

## 1. 変えたファイル・作ったファイルと行数

変更は `formal/Benitoite/Surface/` 内の既存四ファイルだけです。新規ファイルはありません。行数は完了時のファイル全体、追加・削除は `HEAD` との差分です。

| ファイル | 行数 | 追加／削除 | 内容 |
|---|---:|---:|---|
| [Examples.lean](../../../../../formal/Benitoite/Surface/Examples.lean:550) | 734 | +187／−1 | 実行用プログラム、結果・事象の要約、三つの実行定理、`lazy` の型付けの証明 |
| [Lemmas/Invariants.lean](../../../../../formal/Benitoite/Surface/Lemmas/Invariants.lean:191) | 226 | +9／−5 | `HasType.clean` の四分岐 |
| [Lemmas/Scoped.lean](../../../../../formal/Benitoite/Surface/Lemmas/Scoped.lean:98) | 173 | +7／−5 | `HasType.desugar_scoped` の四分岐 |
| [Lemmas/Typing.lean](../../../../../formal/Benitoite/Surface/Lemmas/Typing.lean:224) | 410 | +62／−5 | `HasType.desugar` の四分岐 |
| **合計** | **1,543** | **+265／−16** | **差し引き249行増加** |

検査結果は次のとおりです。

| 検査 | 結果 |
|---|---|
| `formal/` で `lake build` | 成功、63 jobs、Lean の警告なし |
| `scripts/check.sh --base HEAD --dry-run` | 変更四ファイルに対し `formal` だけを選択 |
| `scripts/check.sh --base HEAD` | 成功、`all checks passed` |
| `git diff --check` | 成功 |
| `formal/Benitoite/` の Lean ソースの字句確認 | `sorry`・`native_decide`・`axiom` 宣言なし |

## 2. `#print axioms` の出力

README の手順に従い、`formal/c4b1-axioms.lean` に `import Benitoite` と二定理の公理確認を書き、`lake env lean c4b1-axioms.lean` を実行しました。出力は次のとおりです。

```text
'Benitoite.Surface.desugar_typed' depends on axioms: [propext, Classical.choice, Quot.sound]
'Benitoite.Surface.surface_effect_soundness' depends on axioms: [propext, Classical.choice, Quot.sound]
```

一時ファイルは確認後に削除しました。

## 3. 証明の構成

既存の相互帰納の構成を保ち、型の不変条件・脱糖の範囲保存・脱糖の型保存のそれぞれに四つの分岐を追加しました。独立した補題ファイルを増やさず、既存の補題と各分岐内の局所補題で証明しています。

| 対象 | 証明の構成 |
|---|---|
| Result の `try` | 入力式の `HasType.clean` から成功型 `T` と失敗型 `E` の `TyOK` を取り出す。構成子宣言から局所補題 `hpok`・`hperr` で二つの `PatTy` を構築し、成功側に `C_Return`、失敗側に戻り値の型引数を使った `V_Con` と `C_Escape` を適用する |
| Option の `try` | 入力型から `T` の `TyOK` を取り出す。局所補題 `hps`・`hpn` で Some／None の `PatTy` を構築し、None 側では引数のない構成子を作って `C_Escape` を適用する |
| 両方の `try` の共通部分 | `clean_notCont` で `V_Var` の前提を得る。`Ty.VarsIn.wf` で `C_Escape` と `HasTypeArms.nil` の結果型の `Ty.WF` を得る。網羅性は `Exhaustive.consCongr` で脱糖後へ移す |
| `with` | `.opaque o` の `TyOK` を `EnvClean.cons` に渡して本体の帰納法を適用する。`HasTypeC.weakenEff`（`C_Sub`）で束縛式と本体のエフェクトを全体へ広げ、`State` を含むことを示して `C_Use`・`C_Let` を構築する |
| `lazy` | `hideConts_length` で範囲条件を合わせ、`EnvClean.hide` と `R = none` の自明な戻り値条件を本体の帰納法へ渡す。型保存は `C_Lazy` に接続する |

実行例には `loopCall_typed`・`lazyLoop_typed`・`lazy_definitions_typed` も追加しました。これらは、再帰呼び出し、遅延の本体、未強制／強制の二つの関数が空のエフェクトで型付けされることを示します。

## 4. 表層の型付けや範囲の条件を変えた箇所と理由

**なし。**

表層の型付け規則と範囲条件、`Surface/Syntax.lean`・`Surface/Desugar.lean`、二つの定理の言明と前提、`Release`・`Core`、組み込みの `Assumptions` は変更していません。設計書・レビュー記録など、指定された変更対象外のファイルも変更していません。

## 5. 加えた実行の例と、確かめた振る舞い

三つの実行定理で、表層プログラムを脱糖して `Release.run` で実行した結果を検査しています。すべて `decide` で証明し、組み込みの関数・解放の応答・確保には既存の `Release.Examples` の定義を使いました。

| 実行定理 | 例 | 確かめた振る舞い |
|---|---|---|
| `try_execution_rows` | Result の成功 | `Ok(11)` の後に続く処理を評価し、`Ok("after")` を返す。入力の成功型 Integer と戻り値の成功型 String が異なる |
| 同上 | Result の失敗 | `Error("bad")` を返し、後続の `Ok("after")` を作らない |
| 同上 | Option の成功／失敗 | Some 側では取り出した `11` を後続へ渡し、None 側では関数から抜けて None を返す |
| 同上 | 失敗する `tryResult` の呼び出し元 | 呼び出された関数から抜けた後、呼び出し元は続行して `42` を返す |
| `with_execution_rows` | 通常終了 | `5` を返し、`File 1` の解放事象を一回記録する |
| 同上 | 入れ子の本体の途中の `return` | `7` を返し、内側の `File 2`、外側の `File 1` の順に解放する。後続の `99` は評価されない |
| `lazy_execution_rows` | 純粋な `loop()` を含む遅延を未強制で作成 | `7` を返し、事象を起こさない |
| 同上 | 同じ遅延を `force` | 燃料40・100の両方で未終了となり、次の実行ステップが存在することを確認する。事象はない |

`Event` の比較には、事象の種類・リソースの型名・識別子・解放の応答を写す `C4Event` を使っています。燃料切れの判定は、終了結果に一致しないだけでなく、`Release.step` が次の一歩を返すことも確認します。

## 6. C4a-2 で証明を広げるときの注意

- **`EnvClean` の拡張後も、通常の値の `TyOK` を取り出せる条件が必要です。** 今回の `try` は入力式の結果型から `TyOK` を得て `V_Var` を構築します。節の継続変数を環境に認めても、通常の式の結果型についてこの性質を維持する必要があります。
- **`EnvClean.hide` と `hideConts_length` の性質を維持してください。** 今回の `lazy` は、継続を隠した環境で本体を検査する既存の構成に依存しています。`with` では、リソース型を追加した環境に対する `EnvClean.cons` が引き続き使える必要があります。
- **節の型パラメータを増やすときは、`R` と `try` の `retArgs` の番号を合わせてください。** `R.map (Ty.shift k 0)` に対応する型引数を節の中の番号で保持すれば、今回の失敗側の構成子と `C_Escape` の接続を保てます。
- **利用者の操作・エフェクトの表を追加するときは、プログラム全体の証明も拡張が必要です。** 現在の `desugar_effectsOk` は空の表を使っています。今回の `try` の網羅性の移送は構成子の表の一致だけに依存するため、その部分は再利用できます。