# F02とapp共通化の形成条件の供給

2026-11-03、再開2。共通化のapp_telはStoreのWF・Sorted・DeclaredとCaptureContextRegularを使い、open_value_annotationで関数のAnnotationを得る。一般適用のapplyはCtx.WFと元列のAnnotationを使う。StateTyE.app_inputsは同じStoreOkとClosureTyから閉じた呼出しを取り出し、primitive_contract_inputsは元の署名へ同じ実引数を戻す。閉ΓのCtx.WFとCaptureContextRegularは空のlookupからそれぞれ供給する。

## 共通の供給元

| 開始入力 | Ctx.WF | 共通化の形成とAnnotation | 判定・残る接続 |
|---|---|---|---|
| 閉じたHasTypeCQのapp | 空Γで自明 | Storeの三条件と空のCaptureContextRegular | app_telで供給済み |
| Ctx.Regularを持つ開いたHasTypeCQ | reg.wf | Ctx.Regular.capture_contextとStoreの三条件 | 本番の適用例で供給済み |
| Def.WellTypedの初期本体 | 空Γ。paramではannotation_inputs/Regular.extend | StoreTy.emptyと入力Annotation | L40.15（B15-Def）：全本体の開始逆転へ組み合わせる |
| ImplDecl.WellTypedのメソッド | dictTysのTypeAnnotationsとbindParams。型代入後のtelのAnnotationも必要 | 初期StoreTy.empty、method_bodyと型・行代入の既存補題 | L40.15（B15-Impl）：同じメソッドの開いた開始へ組み合わせる |
| CaptureOkの元文脈 | CaptureWFだけでは完全なCtx.WFにならない | CaptureOk.contextRegularは供給可能 | F02は閉じた呼出しへ移して使用。未接続の家族は以下で名指す |

## 値の全25形

関数の元契約のAnnotationと、共通化する関数値のAnnotationを区別する。後者は実runでStoreOkの三条件と空Γから供給済みである。元契約への一般接続は、実装したprim以外の形をL40.15へ残す。

| 値 | 元契約のAnnotation・Ctx.WFの供給 | 判定・残る接続 |
|---|---|---|
| var | 開ΓではRegularのwfとordinary変数のAnnotation。raw導出だけでは不可 | Regularの適用例あり。捕捉元を閉じる接続はB15-Capture |
| const | 自身の外側は関数列でない | 現在形へのF02適用なし |
| fnRef | inv_fnRefのSignatureInstance.result。実行の呼出しは閉Γ | B15-Fn-fnRef |
| prim | inv_primのSignatureInstance.result。実行の呼出しは閉Γ | primitive_contract_inputsで実開始から供給済み |
| op | inv_opのSignatureInstance.result。実行の呼出しは閉Γ | B15-Fn-op |
| lam | inv_lamのWF/Sorted/DeclaredをAnnotationとしtoTelを適用 | B15-Fn-lam |
| dependentLam | inv_dependentLamの元列のAnnotation | B15-Fn-dependentLam |
| closure | 既存inv_closureのAnnotationと保持したRuntimeShape | B15-Fn-closure |
| raise | inv_raiseの元注釈とtoTel。同じFailの型を保持 | B15-Fn-raise |
| con | 自身の外側は関数列でない。子を呼ぶときは別のapp | 子の選択と開始はL40.12〜.15 |
| list | 自身の外側は関数列でない。要素のappを別に読む | 同上 |
| loc | 外側はReference又はLazyであり関数列でない | L40.14/.15のセルへの接続 |
| mapV | 自身の外側は関数列でない。値のappを別に読む | L40.12〜.15 |
| setV | 自身の外側は関数列でない | 現在形への適用なし |
| bytesV | 自身の外側は関数列でない | 現在形への適用なし |
| dict | 自身の外側は関数列でない。methを別に読む | B15-Meth |
| super | 同じ上位辞書のmethを別に読む | B15-Meth |
| externalRef | V_ExternalRefのSignatureInstance.result。既存external_annotation/external_applyも同じ供給元 | B15-Fn-externalRef。L40.13の公開逆転へ |
| externalHandle | 自身の外側は関数列でない | 現在形への適用なし |
| pathBases | 自身の外側は関数列でない | 現在形への適用なし |
| scopePattern | 自身の外側は関数列でない | 現在形への適用なし |
| checked | 自身の外側は関数列でない | 現在形への適用なし |
| checkedRequest | 自身の外側は関数列でない | 現在形への適用なし |
| checkedAt | 自身の外側は関数列でない | 現在形への適用なし |
| atError | 自身の外側は関数列でない | 現在形への適用なし |

## 計算の全16形

| 計算 | 形成の供給・適用位置 | 判定・L40.15への行 |
|---|---|---|
| app | 閉じた実開始のStoreOkと元関数Annotation | app_inputsで供給済み。primの元列も本番化。他の関数形は上表 |
| ret | 現在位置は呼出しでない。返却した関数の次のappへ | B15-Ret |
| letIn | inv_letが同じΓ/Φ/Rと束縛した後半を保持。入力AnnotationからRegular.extend | B15-Let：letFを型付き実値で開いたClosureTyへ |
| ite | 枝は同じΓ、Φだけ追加。Γの形成を保持 | B15-If：ite_branch/if_true/if_falseの選択後 |
| match | HasTypeArmsQとobs/sort/Exhaustiveを逆転し、選択した本体へ | B15-Match：MatchStateLeavesの選択後 |
| lazyC | Store三条件のhide、文脈のRegular.hideConts | B15-Lazy：thunkの実開始へ |
| escape | inv_escapeで同じRと値を保持。現在位置はappでない | B15-Escape：mark後の開始 |
| use | 現在位置はappでない。bodyは同じΓとStore形成 | B15-Use：release枠へ進む本体 |
| handle | CaptureOk.contextRegularを使う。元Γの完全WFは仮定しない | B15-Handle：通常節/Fail節をそれぞれ閉じる |
| resume | 変数/場所の生/正規形の4規則を区別しContTyの選択先へ | B15-Resume：選択された閉じたClosureTyへ |
| externalCall | HasTypeTelArgsQが直接前提。app共通化の位置でない | 外部応答はL60。externalRefのappは上表 |
| issuePathBases | 現在位置はappでない | 適用なし。L40.13/L50 |
| checkAt | 現在位置はappでない | 適用なし。L40.13/L50 |
| meth | 辞書/SignatureInstance/Tel.arguments/値列を直接逆転で受ける | B15-Meth：実メソッド本体への形成を組み合わせる |
| builderLet | Regular.extendNone。localのkindは別に保持 | B15-BuilderLet：セルと本体の開始へ |
| builderOp | 現在位置はappでない。組込みの実引数は元HasTypeVsQ | F02適用なし。セルの接続はL40.14/.15 |

## 状態・枠・セル

| 開始入力 | 形成の供給・適用位置 | 判定・L40.15への行 |
|---|---|---|
| State.run | StoreOkの三条件とClosureTy.app_view_typedで閉Γへ | app_inputsとprimitive_contract_inputsを本番化 |
| State.matchRun | 同じStoreOkで保持値/腕/ClosureTyを逆転し選択後のrunへ | B15-Match |
| State.error | 現在位置にappなし。ContTyとStoreOkは保持 | 適用なし |
| State.exit | 現在位置にappなし。ContTyとStoreOkは保持 | 適用なし |
| Frame.letF | K_Letの一引数ClosureTyを同じ型付き実値で開く | B15-Let |
| Frame.mark | K_Markの型と同じ値を使う。枠自身にappなし | B15-Escape。次のrunで供給 |
| Frame.update | K_Updateの同じlazyセルと入力型。枠自身にappなし | B15-Lazy |
| Frame.release | 保持値は閉ΓのHasTypeV。解放の応答は別条件 | B15-Use |
| Frame.handleF | 通常/Fail節のCaptureOk.contextRegular。元Γの完全WFは未保証 | B15-Handle：閉じた呼出しへ |
| Frame.drop | 継続セルとContTyを保持。枠自身にappなし | B15-Resume |
| Frame.guardF | GuardBodyTyのCaptureOk.contextRegularと真の条件下の本体 | B15-Guard：選択本体を閉じたClosureTyへ |
| Cell.builder | BuilderCellOkの値列は閉Γ。セル自身にappなし | L40.14/.15。取り出した関数のrunで供給 |
| Cell.val | HasTypeVのΓは[]。StoreOkの同じΨから三条件 | L40.14/.15 |
| Cell.thunk | 閉じたClosureTy。hideBuildersのStore三条件は既存hideで保持 | B15-Lazy |
| Cell.done | HasTypeVのΓは[]。StoreOkの同じΨから三条件 | B15-Lazy |
| Cell.cont | ContTyは捕捉元Γの完全WFを要求しない。選択された枠/閉包へ | B15-Resume/B15-Handle/B15-Let/B15-Guard |
| Cell.used | 現在位置に実行する本体なし | 適用なし。usedの逆転はL40.14/.15 |

L40.15へ渡す行は、既存の保存葉を再証明する依頼ではなく、実際の選択後の開始と今回の入口との接続である。全25値・16計算・4状態・7枠・6セルを区別した。全開始から供給済みと呼ぶのは、実装したrunとRegular文脈の読者の範囲だけである。残る接続を進行・保存の完了や独立レビュー済みへ繰り上げない。
