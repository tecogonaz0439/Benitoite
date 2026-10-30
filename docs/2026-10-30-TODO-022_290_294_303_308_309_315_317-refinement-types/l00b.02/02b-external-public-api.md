# `.02b-external` の追加した公開宣言

名前の共通接頭辞は `Benitoite.Release.Refinement.` である。手で名前を付けた追加は62名であり、構成子・射影・recursor等の生成宣言をこの一覧へ重ねて数えない。変更した既存宣言は [全ファイルとハッシュ](02b-external-source-changes.json) と [差分](02b-external-production.patch)、公理依存の全67モジュールの検査を参照する。

| 本番ファイル | 追加した宣言 |
|---|---|
| [Embedding](../../../formal/Benitoite/Release/Refinement/Embedding.lean) | `embedProgram_externals` |
| [External](../../../formal/Benitoite/Release/Refinement/External.lean) | `typeEnv`、`ExternalScalar`、`ExternalMapKey`、`ExternalValueType`、`ExternalOccurrence`、`ExternalUseAt`、`ExternalTelWF`、`ExternalSignature.WF`、`Program.ExternalWF`、`Program.ExternalWF.type_lookup`、`Program.ExternalWF.function_lookup`、`ExternalCallAdmissible`、`ExternalCallAdmissible.types_nil`、`ExternalCallAdmissible.map` |
| [ExternalResponse](../../../formal/Benitoite/Release/Refinement/ExternalResponse.lean) | `ExternalSignature.instantiate`、`ExternalArgs`、`Outcome.Typed`、`Builtins.ExternalAssumptions` |
| [Ground](../../../formal/Benitoite/Release/Refinement/Ground.lean) | `Val.ClosedAt`、`Val.ClosedList`、`Comp.ClosedAt`、`Arm.ClosedList`、`Clause.ClosedList`、`Capture.Closed`、`captureSlotsClosed`、`Closure.ClosedAt`、`Val.Ground` |
| [MethodArguments](../../../formal/Benitoite/Release/Refinement/MethodArguments.lean) | `Tel.bind_norm`、`Tel.bind_renaming`、`Tel.open_shift`、`Tel.open_subst`、`Tel.instantiate_eq_arguments`、`Tel.instantiate_subst`、`Tel.instantiate_shift` |
| [Narrowing](../../../formal/Benitoite/Release/Refinement/Narrowing.lean) | `HasTypeTelArgsQ.narrow` |
| [SubstTyping](../../../formal/Benitoite/Release/Refinement/SubstTyping.lean) | `Tel.shiftV_zero`、`HasTypeTelArgsQ.hide_context`、`HasTypeTelArgsQ.subst`、`HasTypeTelArgsQ.subst_under_none` |
| [Syntax](../../../formal/Benitoite/Release/Refinement/Syntax.lean) | `ExternalMode`、`ExternalTypeDecl`、`ExternalPosition`、`ExternalPathStep`、`ExternalUse`、`ExternalSignature`、`ExternalDecl`、`ExternalKey`、`ExternalHandle`、`Program.externalType`、`Program.externalFunction` |
| [TelTyping](../../../formal/Benitoite/Release/Refinement/TelTyping.lean) | `HasTypeTelArgsQ.normal`、`HasTypeTelArgsQ.instantiate`、`HasTypeTelArgsQ.length`、`HasTypeTelArgsQ.arguments`、`ExternalArgs.instantiate` |
| [Typing](../../../formal/Benitoite/Release/Refinement/Typing.lean) | `HasTypeTelArgsQ`、`HasTypeTelArgs` |
| [TypingDeclared](../../../formal/Benitoite/Release/Refinement/TypingDeclared.lean) | `HasTypeTelArgsQ.result_annotation`、`HasTypeTelArgsQ.declared` |
| [TypingShift](../../../formal/Benitoite/Release/Refinement/TypingShift.lean) | `HasTypeTelArgsQ.shift_values` |
| [ValueBinding](../../../formal/Benitoite/Release/Refinement/ValueBinding.lean) | `Ty.bind_external` |
