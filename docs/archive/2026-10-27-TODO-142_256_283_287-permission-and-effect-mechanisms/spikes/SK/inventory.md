# SK: 本番の直接参照の集計

基準版: `ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c`。対象: Release・Surface・Exchange・SurfaceCheck。

コメント・文字列・宣言自身の名前を除く字句上の直接参照である。推移的な依存数でも、書き換える定理の確定数でもない。

| 対象 | grep 一致行／ファイル | 直接参照する定理／ファイル | 例・Model を除く定理／ファイル |
|---|---:|---:|---:|
| `io_op` | 5／5 | 4／4 | 3／3 |
| `io_typed` | 3／3 | 2／2 | 1／1 |
| `io_exists` | 4／4 | 3／3 | 2／2 |
| `effect_ops` | 2／2 | 1／1 | 0／0 |
| `io_kind` | 3／3 | 2／2 | 1／1 |
| `opEff_io` | 3／3 | 2／2 | 1／1 |
| `ioResponse` | 19／14 | 2／2 | 2／2 |
| `Event` | 10／5 | 4／3 | 4／3 |
| `NoHandler` | 19／5 | 10／4 | 10／4 |
| `name_end` | 4／3 | 3／3 | 3／3 |
| `end_of_noHandler` | 2／1 | 1／1 | 1／1 |
| `opSig` | 23／11 | 7／7 | 7／7 |
| `handled` | 53／19 | 19／12 | 15／11 |
| `HasTypeClausesQ` | 62／16 | 29／15 | 29／15 |
| `C_Handle` | 35／16 | 30／15 | 30／15 |
| `K_Handle` | 20／6 | 14／5 | 14／5 |
| `BuiltinOnly` | 12／4 | 7／3 | 7／3 |

## 群の和集合

- `contracts`: 7宣言／7ファイル、うち定理6件／6ファイル。
- `events`: 22宣言／17ファイル、うち定理6件／5ファイル。
- `propagation`: 100宣言／33ファイル、うち定理89件／29ファイル。
- `groups_union`: 120宣言／44ファイル、うち定理94件／31ファイル。

## 主な定理の言明

### formal/Benitoite/Release/Theorems.lean:35 progress

```lean
theorem progress (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {s : State} :
    StateTy P B s → s.Final ∨ ∃ l s', Step P B s l s'
```

### formal/Benitoite/Release/Theorems.lean:42 preservation

```lean
theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {s : State} {l : Option Event} {s' : State} :
    StateTy P B s → Step P B s l s' → StateTy P B s'
```

### formal/Benitoite/Release/Theorems.lean:52 effect_soundness

```lean
theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {m : Comp} {a : Ty} :
    HasTypeC P B StoreTy.empty [] [] none m a Eff.empty → m.ClosedNoEffVars →
    ∀ s, Steps P B (.run m [] Store.empty) s →
      (∀ ev s', ¬ Step P B s (some ev) s') ∧ ¬ UnhandledOp s
```

### formal/Benitoite/Surface/Theorems.lean:19 desugar_typed

```lean
theorem desugar_typed {p : Program} {B : Builtins} {opPrim : OpPrim}
    (hwf : p.WellFormed) (hwt : p.WellTyped B opPrim)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) :
    (desugarProgram opPrim p).WellFormed ∧
      (desugarProgram opPrim p).WellTyped B ∧
      (desugarProgram opPrim p).EffectsOk B
```

## 直接参照する宣言の一覧

- `formal/Benitoite/Exchange/Builtins.lean:236` `mkBuiltins` (def): ioResponse, events
- `formal/Benitoite/Release/Assumptions.lean:40` `Builtins.Assumptions` (structure): io_op, io_typed, io_exists, effect_ops, io_kind, opEff_io, ioResponse, contracts, events
- `formal/Benitoite/Release/Examples.lean:26` `builtins` (def): ioResponse, events
- `formal/Benitoite/Release/Examples.lean:169` `summarize` (def): Event, events
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:19` `ContTy.store` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:36` `ContTy.name_end` (theorem): handled, K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:62` `handled_state` (theorem): handled, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:74` `ContTy.state_end` (theorem): name_end, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:131` `ContTy.inv_handle` (theorem): handled, K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:148` `ContTy.inv_handle_tail` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:206` `ContTy.resume_append` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:240` `ContTy.split` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/ContLemmas.lean:335` `ContTy.framesOk` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/EffectSound.lean:15` `builtinOnly_empty` (theorem): BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/EffectSound.lean:20` `ContTy.end_of_noHandler` (theorem): NoHandler, name_end, handled, propagation
- `formal/Benitoite/Release/Lemmas/EffectSound.lean:39` `no_event` (theorem): io_op, NoHandler, end_of_noHandler, contracts, events, propagation
- `formal/Benitoite/Release/Lemmas/EffectSound.lean:82` `no_unhandledOp` (theorem): BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/FailureBase.lean:16` `opSig_ne_fail` (theorem): opSig
- `formal/Benitoite/Release/Lemmas/FailureBase.lean:22` `HasTypeClausesQ.no_failure` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/FailureBase.lean:54` `handled_noFail` (theorem): handled, propagation
- `formal/Benitoite/Release/Lemmas/FailureCont.lean:16` `ContTy.handler_kind` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/FailureCont.lean:47` `ContTy.fail_end` (theorem): NoHandler, K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/FailureCont.lean:66` `ContTy.failure_prefix` (theorem): NoHandler, K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/FailureCont.lean:142` `ContTy.split_failure` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/FailureCont.lean:231` `splitAt_failure_prefix` (theorem): NoHandler, propagation
- `formal/Benitoite/Release/Lemmas/FailureCont.lean:251` `HasTypeCQ.inv_handle_failure` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:211` `HasTypeCQ.inv_ret` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:231` `HasTypeCQ.inv_let` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:254` `HasTypeCQ.inv_app` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:277` `HasTypeCQ.inv_ite` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:300` `HasTypeCQ.inv_match` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:316` `HasTypeCQ.inv_lazy` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:336` `HasTypeCQ.inv_escape` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:354` `HasTypeCQ.inv_use` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:377` `HasTypeCQ.inv_handle` (theorem): handled, HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:405` `HasTypeCQ.inv_resumeL` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:428` `HasTypeCQ.inv_resumeVar` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:502` `HasTypeCQ.inv_meth` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:521` `HasTypeCQ.ret_value` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:532` `HasTypeCQ.inv_builderLet` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Inversion.lean:548` `HasTypeCQ.inv_builderOp` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Irrelevant.lean:108` `HasTypeCQ.subst_congr` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Irrelevant.lean:156` `HasTypeClausesQ.subst_congr` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/LocalInvariant.lean:41` `ContTy.localRefs` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Names.lean:165` `HasTypeCQ.lambdaNamesWF` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Names.lean:194` `HasTypeClausesQ.lambdaNamesWF` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/NoFailContext.lean:43` `HasTypeCQ.q_mono` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/NoFailContext.lean:75` `HasTypeClausesQ.q_mono` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/OuterC.lean:100` `HasTypeCQ.outer` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/OuterC.lean:161` `HasTypeClausesQ.outer` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/PresHelpers.lean:31` `stateTy_iff` (theorem): BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/PresHelpers.lean:95` `ContTy.R_wf` (theorem): K_Handle, propagation
- `formal/Benitoite/Release/Lemmas/PresHelpers.lean:122` `HasTypeClausesQ.find` (theorem): opSig, HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/PresMain.lean:18` `preservationE` (theorem): io_op, io_typed, Event, opSig, K_Handle, contracts, events, propagation
- `formal/Benitoite/Release/Lemmas/Preservation.lean:111` `pres_op_common` (theorem): opSig
- `formal/Benitoite/Release/Lemmas/Progress.lean:114` `HasTypeCQ.resume_form` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Progress.lean:168` `split_of_not_noHandler` (theorem): NoHandler, propagation
- `formal/Benitoite/Release/Lemmas/Progress.lean:200` `no_unhandled_user` (theorem): NoHandler, name_end, handled, BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/Progress.lean:327` `progress_io` (theorem): io_exists, io_kind, NoHandler, contracts, events, propagation
- `formal/Benitoite/Release/Lemmas/Progress.lean:417` `progress_app` (theorem): NoHandler, BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/Progress.lean:459` `progress_run` (theorem): BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/Progress.lean:505` `progressE` (theorem): BuiltinOnly, propagation
- `formal/Benitoite/Release/Lemmas/Regularity.lean:204` `HasTypeCQ.wf` (theorem): C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:163` `handled_of_ops` (theorem): handled, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:176` `handled_renameList` (theorem): handled, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:224` `HasTypeCQ.rename` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:284` `HasTypeClausesQ.rename` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:371` `HasTypeCQ.store` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:404` `HasTypeClausesQ.store` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/Rename.lean:424` `HasTypeClausesQ.hideBuilders` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/StepSound.lean:56` `splitHandler_none` (theorem): NoHandler, propagation
- `formal/Benitoite/Release/Lemmas/StepSound.lean:102` `step_soundE` (theorem): io_exists, ioResponse, Event, contracts, events
- `formal/Benitoite/Release/Lemmas/SubstTyping.lean:238` `HasTypeCQ.subst` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/SubstTyping.lean:301` `HasTypeClausesQ.subst` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Lemmas/TySubst.lean:118` `handled_substRho` (theorem): handled, propagation
- `formal/Benitoite/Release/Lemmas/TySubst.lean:145` `handled_substAt` (theorem): handled, propagation
- `formal/Benitoite/Release/Lemmas/TySubstMain.lean:341` `opSig_scoped` (theorem): io_op, opEff_io, opSig, contracts
- `formal/Benitoite/Release/Lemmas/TySubstMain.lean:652` `HasTypeCQ.substTy` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Lemmas/TySubstMain.lean:823` `HasTypeClausesQ.substTy` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/LocalScope.lean:102` `HasTypeCQ.localRefs` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/LocalScope.lean:135` `HasTypeClausesQ.localRefs` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Model.lean:38` `builtins` (def): ioResponse, events
- `formal/Benitoite/Release/Model.lean:61` `assumptions` (theorem): io_op, io_typed, io_exists, effect_ops, io_kind, opEff_io, contracts
- `formal/Benitoite/Release/Semantics.lean:87` `UnhandledOp` (def): NoHandler, propagation
- `formal/Benitoite/Release/Semantics.lean:94` `SplitAt` (def): NoHandler, propagation
- `formal/Benitoite/Release/Semantics.lean:116` `Step` (inductive): ioResponse, Event, NoHandler, events, propagation
- `formal/Benitoite/Release/Semantics.lean:350` `releaseStep` (def): Event, events
- `formal/Benitoite/Release/Semantics.lean:358` `step` (def): Event, events
- `formal/Benitoite/Release/Semantics.lean:532` `run` (def): Event, events
- `formal/Benitoite/Release/Semantics.lean:545` `ContTy` (inductive): handled, K_Handle, propagation
- `formal/Benitoite/Release/Semantics.lean:647` `StateTy` (def): BuiltinOnly, propagation
- `formal/Benitoite/Release/Theorems.lean:23` `step_sound` (theorem): ioResponse, Event, events
- `formal/Benitoite/Release/Theorems.lean:42` `preservation` (theorem): Event, events
- `formal/Benitoite/Release/Typing.lean:62` `Builtins` (structure): ioResponse, events
- `formal/Benitoite/Release/Typing.lean:447` `HasTypeCQ` (inductive): handled, HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Release/Typing.lean:533` `HasTypeClausesQ` (inductive): opSig, HasTypeClausesQ, propagation
- `formal/Benitoite/Release/Typing.lean:604` `HasTypeClauses` (abbrev): HasTypeClausesQ, propagation
- `formal/Benitoite/Surface/Check.lean:206` `checkExprR` (def): handled, propagation
- `formal/Benitoite/Surface/Check.lean:742` `checkClausesR` (def): opSig
- `formal/Benitoite/Surface/Check.lean:766` `inferClauseTypesR` (def): opSig
- `formal/Benitoite/Surface/CheckComputeControl.lean:140` `computes_handle` (theorem): handled, propagation
- `formal/Benitoite/Surface/CheckCounterexamples.lean:20` `builtins` (def): ioResponse, events
- `formal/Benitoite/Surface/CheckExamples.lean:443` `builtins` (def): ioResponse, events
- `formal/Benitoite/Surface/CheckLemmas.lean:240` `opSig_atoms` (theorem): opSig
- `formal/Benitoite/Surface/CheckLemmas.lean:329` `acceptEff_handled_sound` (theorem): handled, propagation
- `formal/Benitoite/Surface/CheckSoundControl.lean:302` `handle_case` (theorem): handled, propagation
- `formal/Benitoite/Surface/CheckTables.lean:97` `builtins` (def): ioResponse, events
- `formal/Benitoite/Surface/CheckToolsExamples.lean:202` `stringBuiltins` (def): ioResponse, events
- `formal/Benitoite/Surface/FailureExamples.lean:41` `builtins` (def): ioResponse, events
- `formal/Benitoite/Surface/Lemmas/BuilderCapture.lean:134` `HasTypeCQ.reads` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Surface/Lemmas/BuilderCapture.lean:185` `HasTypeClausesQ.reads` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Surface/Lemmas/BuilderCapture.lean:322` `builderClauses_no_capture` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Surface/Lemmas/BuilderNoCapture.lean:16` `HasTypeQ.captures` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Surface/Lemmas/Calls.lean:67` `desugarClauses_handled` (theorem): handled, propagation
- `formal/Benitoite/Surface/Lemmas/Invariants.lean:260` `opSig_clean` (theorem): opSig
- `formal/Benitoite/Surface/Lemmas/ReturnTry.lean:15` `HasTypeCQ.withReturn` (theorem): HasTypeClausesQ, C_Handle, propagation
- `formal/Benitoite/Surface/Lemmas/ReturnTry.lean:50` `HasTypeClausesQ.withReturn` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Surface/Lemmas/Typing.lean:390` `HasTypeQ.desugar` (theorem): C_Handle, propagation
- `formal/Benitoite/Surface/Lemmas/Typing.lean:880` `HasClausesQ.desugar` (theorem): HasTypeClausesQ, propagation
- `formal/Benitoite/Surface/LogExamples.lean:102` `handled_checked` (theorem): handled, propagation
- `formal/Benitoite/Surface/LogExamples.lean:105` `forwarded_checked` (theorem): handled, propagation
- `formal/Benitoite/Surface/LogExamples.lean:109` `console_remains_checked` (theorem): handled, propagation
- `formal/Benitoite/Surface/LogExamples.lean:123` `programMaterials` (def): handled, propagation
- `formal/Benitoite/Surface/LogExamples.lean:137` `console_pure_rejected` (theorem): handled, propagation
- `formal/Benitoite/Surface/Typing.lean:84` `HasTypeQ` (inductive): handled, propagation
- `formal/Benitoite/Surface/Typing.lean:491` `HasClausesQ` (inductive): opSig
- `formal/SurfaceCheck/Validation.lean:8` `q` (def): ioResponse, events
