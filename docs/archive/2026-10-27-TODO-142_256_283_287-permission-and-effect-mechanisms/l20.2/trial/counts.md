# L20.2 の試行ビルドの件数

plan「検査の割り当て」の「L の一度の切り替えの試行ビルド」の行に従い、B_WORK `361ca673b4c98d4ea04367f3b08d65559743a6de` の作業用のディレクトリで、排他の道具の全体の `lake build`（既定の全入口、`-M 12288`）を回ごとに走らせた。壊れた宣言は、診断の行の直前の宣言の見出しで数えた（`tools/count.py`）。未検査のモジュールは、壊れたモジュールを import の先に持ち、既定の入口から届くモジュールである（その回の総数 284）。各回の宣言の名前は、その回の時点のソースで数えた。

最初の差分（`trial-1.diff`）は、`Ty.WF`・`Ty.WFList`・`Eff.WF`・`Ty.VarsIn`・`Ty.VarsInList`・`Eff.VarsIn`・`Eff.VarsInList` の定義に範囲の変数の個数 `nr` を先頭の引数として加え、利用側の全ての呼び出しに機械的に `0` を挿入したものである（58ファイル）。回 1〜7 は効果の整形式 `Eff.WF` にも名前の原子の条件を入れた形、回 8 以降はその条件を外した形である（results「決めたことと理由」1）。

| 回 | ログ | 終了 | 誤りの診断 | 壊れた宣言 | 壊れたファイル | 未検査のモジュール | 外側の時間 | 最大常駐量（バイト） |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | build-1.log | 1 | 4 | 3 | 1 | 212 | 11.77 秒 | 843710464 |
| 2 | build-2.log | 1 | 3 | 3 | 1 | 207 | 9.80 秒 | 1608040448 |
| 3 | build-3.log | 1 | 10 | 8 | 2 | 204 | 1.07 秒 | 732266496 |
| 4 | build-4.log | 1 | 6 | 4 | 2 | 189 | 4.92 秒 | 849002496 |
| 5 | build-5.log | 1 | 9 | 6 | 4 | 103 | 153.29 秒 | 1664090112 |
| 6 | build-6.log | 1 | 10 | 7 | 3 | 88 | 141.85 秒 | 1678573568 |
| 7 | build-7.log | 1 | 9 | 6 | 3 | 59 | 157.28 秒 | 1667858432 |
| 8 | build-8.log | 1 | 1 | 1 | 1 | 204 | 12.93 秒 | 1588854784 |
| 9 | build-9.log | 1 | 3 | 2 | 2 | 17 | 146.97 秒 | 2644508672 |
| 10 | build-10.log | 0 | 0 | 0 | 0 | 0 | 25.24 秒 | 1512980480 |

回 8 の未検査が増えたのは、`Eff.WF` の定義を戻して `TypeVariables` の一つの宣言が壊れ、その先を全て検査しなかったためである。

## 壊れた宣言の一意数

回 1〜9 を通して、一意の壊れた宣言は 37、ファイルは 16 である。

| ファイル | 宣言 | 回 |
|---|---|---|
| `Release/TypeRegularity.lean` | `Eff.WF.mono`・`Eff.norm_WF`・`Eff.rawShift_of_wf` | 1 |
| `Release/TypeBounds.lean` | `Eff.WF.raw`・`Eff.norm_rawWF`・`Ty.norm_rawWF` | 2 |
| `Release/TypeCongruence.lean` | `Eff.bind_congr_scoped` | 3 |
| `Release/TypeVariables.lean` | `Ty.VarsInList.iff`・`Ty.VarsIn.wf`・`Ty.VarsIn.rows`・`Ty.VarsIn.mono`・`Eff.VarsInList.mono`・`Ty.norm_VarsIn`・`Eff.norm_VarsIn`（3）、`Eff.VarsIn.wf`（8） | 3・8 |
| `Release/Lemmas/Closed.lean` | `Ty.VarsIn.substAt`・`Eff.VarsIn.substAt` | 4 |
| `Release/Lemmas/Regularity.lean` | `Const.type_wf`・`HasTypeVQ.wf` | 4 |
| `Release/Lemmas/TySubstMain.lean` | `HasTypeVQ.substTy` | 5 |
| `Release/Lemmas/VariableBind.lean` | `Eff.bind_clean` | 5 |
| `Surface/Lemmas/ShiftClean.lean` | `shift_clean`・`shiftEff_clean`・`rawShiftEff_clean` | 5 |
| `Surface/Typing.lean` | 例（1204行目の `example`） | 5 |
| `Release/Lemmas/PresFailure.lean` | `pres_failure` | 6・7 |
| `Surface/FinitePredicates.lean` | `wfTy_spec`・`wfEff_spec`・`cleanTy_spec`・`cleanEff_spec` | 6 |
| `Surface/Lemmas/Invariants.lean` | `funDecl_scoped`・`HasTypeQ.clean` | 6・7 |
| `Surface/CheckLemmas.lean` | `cleanFails_sound`・`wfFails_sound`・`effect_wf_check` | 7 |
| `Release/Lemmas/EffectSound.lean` | `stateTyE_init_eff` | 9 |
| `Surface/Lemmas/Records.lean` | `accessorDef_scoped` | 9 |

このうち `pres_failure`・`wfEff_spec`・`wfFails_sound`・`effect_wf_check` の4件は、`Eff.WF` に原子の条件を入れた形だけで壊れた。採った形で壊れたのは 33 宣言・15 ファイルである。最終の差分で `formal/` の既存のファイルの変更は 62 ファイルであり、その多くは機械的な `0` の挿入だけである。
