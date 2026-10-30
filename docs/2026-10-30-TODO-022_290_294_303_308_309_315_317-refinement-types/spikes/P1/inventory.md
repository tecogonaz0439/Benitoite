# 現行の宣言の棚卸し

直接参照の再集計であり、修正必須数や推移的な依存の数ではない。追加候補は型・効果の構造を読む宣言の文字列検索である。

| 範囲 | Ty.Le | 逆転等 | 直接の和集合 | 追加の構造の候補（定理） | 追加候補の定義等 |
|---|---:|---:|---:|---:|---:|
| Release | 56 | 30 | 75 | 515 | 143 |
| Surface | 20 | 2 | 20 | 159 | 44 |

## Release の直接参照

| ファイル | 行 | 宣言 | 参照 |
|---|---:|---|---|
| formal/Benitoite/Release/CoverCompat.lean | 33 | `Ty.LeOld.le` | Ty.Le |
| formal/Benitoite/Release/CoverCompat.lean | 39 | `Ty.le_iff_leOld` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 63 | `refl` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 65 | `trans` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 74 | `fn_left` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 81 | `fn_right` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 88 | `eq_of_not_fn` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Basic.lean | 94 | `eq_of_not_fn_left` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Basic.lean | 99 | `substAt` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 106 | `subst` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Basic.lean | 109 | `shift` | Ty.Le |
| formal/Benitoite/Release/Lemmas/BuilderTyping.lean | 26 | `HasTypeVQ.canonical_bytes` | inversion |
| formal/Benitoite/Release/Lemmas/Canonical.lean | 63 | `HasTypeVQ.canonical_boolean` | inversion |
| formal/Benitoite/Release/Lemmas/Canonical.lean | 99 | `HasTypeVQ.canonical_ref` | inversion |
| formal/Benitoite/Release/Lemmas/Canonical.lean | 135 | `HasTypeVQ.canonical_lazy` | inversion |
| formal/Benitoite/Release/Lemmas/Canonical.lean | 227 | `HasTypeVQ.inv_list_wf` | inversion |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 133 | `ContTy.inv_nil` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 141 | `ContTy.inv_let` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 152 | `ContTy.inv_mark` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 162 | `ContTy.inv_update` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 184 | `ContTy.inv_handle` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 202 | `ContTy.inv_handle_tail` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 227 | `ContTy.inv_guard` | Ty.Le |
| formal/Benitoite/Release/Lemmas/ContLemmas.lean | 260 | `ContTy.resume_append` | Ty.Le |
| formal/Benitoite/Release/Lemmas/EffectSound.lean | 103 | `no_unhandledOp` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/FailureCont.lean | 240 | `HasTypeVQ.inv_raise` | Ty.Le |
| formal/Benitoite/Release/Lemmas/FailureCont.lean | 255 | `HasTypeCQ.inv_handle_failure` | Ty.Le |
| formal/Benitoite/Release/Lemmas/FailureCont.lean | 274 | `HasTypeCQ.inv_raise_app` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 25 | `HasTypeVQ.inv_var` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 43 | `HasTypeVQ.inv_const` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 59 | `HasTypeVQ.inv_fnRef` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 95 | `HasTypeVQ.inv_prim` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 116 | `HasTypeVQ.inv_op` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 135 | `HasTypeVQ.inv_lam_wf` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 156 | `HasTypeVQ.inv_lam` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 163 | `HasTypeVQ.inv_con` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 182 | `HasTypeVQ.inv_list` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 200 | `HasTypeVQ.inv_loc` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 223 | `HasTypeCQ.inv_ret` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 243 | `HasTypeCQ.inv_let` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 266 | `HasTypeCQ.inv_app` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 289 | `HasTypeCQ.inv_ite` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 312 | `HasTypeCQ.inv_match` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 328 | `HasTypeCQ.inv_lazy` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 366 | `HasTypeCQ.inv_use` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 389 | `HasTypeCQ.inv_handle` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 417 | `HasTypeCQ.inv_resumeL` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 440 | `HasTypeCQ.inv_resumeVar` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 466 | `HasTypeVQ.inv_mapV` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 476 | `HasTypeVQ.inv_setV` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 486 | `HasTypeVQ.inv_bytesV` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 500 | `HasTypeVQ.inv_checked` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 513 | `HasTypeVQ.inv_checkedRequest` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 523 | `HasTypeVQ.inv_dict` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 534 | `HasTypeVQ.inv_super` | inversion |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 545 | `HasTypeCQ.inv_meth` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 575 | `HasTypeCQ.inv_builderLet` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Inversion.lean | 591 | `HasTypeCQ.inv_builderOp` | Ty.Le |
| formal/Benitoite/Release/Lemmas/MembershipBase.lean | 70 | `HasTypeVQ.canonical_opaque` | inversion |
| formal/Benitoite/Release/Lemmas/PresBase.lean | 155 | `stE_ret` | Ty.Le |
| formal/Benitoite/Release/Lemmas/PresBase.lean | 178 | `store_prim_inv` | Ty.Le |
| formal/Benitoite/Release/Lemmas/PresHelpers.lean | 145 | `ContTy.markPush` | Ty.Le |
| formal/Benitoite/Release/Lemmas/PresMain.lean | 19 | `preservationE` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Preservation.lean | 17 | `Ty.Le.fn_fn'` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Preservation.lean | 24 | `inv_prim_app` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Preservation.lean | 36 | `inv_op_app` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/Preservation.lean | 133 | `pres_op_common` | Ty.Le |
| formal/Benitoite/Release/Lemmas/Progress.lean | 17 | `HasTypeVQ.canonical_fn_or_raise` | inversion |
| formal/Benitoite/Release/Lemmas/Progress.lean | 55 | `HasTypeVQ.canonical_dict` | inversion |
| formal/Benitoite/Release/Lemmas/Progress.lean | 421 | `progress_app` | Ty.Le, inversion |
| formal/Benitoite/Release/Lemmas/StepSound.lean | 102 | `step_soundE` | Ty.Le, inversion |
| formal/Benitoite/Release/Model.lean | 290 | `super_call_typed` | Ty.Le |
| formal/Benitoite/Release/TargetStepExamples.lean | 64 | `inv_prim_app_eff` | Ty.Le, inversion |
| formal/Benitoite/Release/TypeRegularity.lean | 70 | `Ty.Le.wf` | Ty.Le |
| formal/Benitoite/Release/TypeRegularity.lean | 76 | `Ty.Le.wf_rev` | Ty.Le |

## Surface の直接参照

| ファイル | 行 | 宣言 | 参照 |
|---|---:|---|---|
| formal/Benitoite/Surface/CheckLemmas.lean | 133 | `accept_sound` | Ty.Le |
| formal/Benitoite/Surface/CheckLemmas.lean | 176 | `join_sound` | Ty.Le |
| formal/Benitoite/Surface/CheckSupport.lean | 11 | `tyJoin_sound` | Ty.Le |
| formal/Benitoite/Surface/CheckTools.lean | 59 | `tyLe_sound` | Ty.Le |
| formal/Benitoite/Surface/ClauseIxExamples.lean | 128 | `top_clause_typed` | Ty.Le |
| formal/Benitoite/Surface/CoverExamples.lean | 173 | `writeE_bound` | Ty.Le |
| formal/Benitoite/Surface/CoverExamples.lean | 180 | `writeE_narrow` | Ty.Le |
| formal/Benitoite/Surface/CoverExamples.lean | 187 | `callGE_bound` | Ty.Le |
| formal/Benitoite/Surface/CoverExamples.lean | 338 | `main_typed` | Ty.Le |
| formal/Benitoite/Surface/Examples.lean | 238 | `program_effect_soundness` | Ty.Le, inversion |
| formal/Benitoite/Surface/FiniteTools.lean | 234 | `tyLe_sound` | Ty.Le |
| formal/Benitoite/Surface/FiniteTools.lean | 253 | `tyJoin_sound` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/CallHead.lean | 76 | `HasTypeQ.inv_funDicts` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/CallHead.lean | 110 | `HasTypeQ.inv_opDicts` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/CallHead.lean | 145 | `HasTypeQ.inv_methName` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/CallHead.lean | 188 | `directCallee_typed` | Ty.Le, inversion |
| formal/Benitoite/Surface/Lemmas/Invariants.lean | 31 | `clean_le` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/Invariants.lean | 39 | `clean_data_le` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/Typing.lean | 168 | `HasTypeQ.desugar_partialCall` | Ty.Le |
| formal/Benitoite/Surface/Lemmas/Typing.lean | 210 | `HasTypeQ.desugar_partialCon` | Ty.Le |
