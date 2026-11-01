# L20: 置換・文脈・状態の葉の起動単位（r3 下書き）

2026-11-02 改訂（初稿2026-11-01）。独立レビュー [RV-L20-plan](../reviews/RV-L20-plan.md) 末尾「r2 の再確認」の重1・中2・軽3に対応した改訂である。所見の処置と短い Lean 試行は [results](results.md) に残す。計画担当の下書きである。実装の起動、独立レビュー、受け入れを済ませた文書ではない。指定ブランチは `m014/l20-plan`、B_WORK は **`841fe6ea543b84251487251dc22eefe04e6df111`**。起動依頼の値を記し、git による照合・切替・作成・コミットは行っていない。[共通依頼文](../implementation-request.md)を最初に読み、plan の指定節、L10 の受渡し、前段の記録、現行 Lean を照合した。

`R/` は `formal/Benitoite/Release/Refinement/`、`O/` は `formal/Benitoite/Release/`、`I/` は `formal/Benitoite/Interval/`、`S/` は `formal/Benitoite/Shared/` を指す。ソースのパスはリポジトリの根からの相対パスである。宣言名は断らない限り `Benitoite.Release.Refinement` に属する。「予定」は今回証明していない契約であり、Lean に未証明の定理として追加する意味ではない。

## 入口の点検

L10 全59単位の閉鎖と本書の基準は今回の依頼を正とする。[RV-L10](../reviews/RV-L10.md)は条件付き可（中5・軽6）で、取りまとめの追記は全体の再レビューを置かず修正箇所を確認すると定める。[F の結果](../l10/f/results.md)には11所見の処置と、末尾に取りまとめの work（終了0、101.53秒、RSS 1,457,127,424バイト）がある。本文冒頭の「最終work・RSS未完」はその実行前の記録であり、末尾及び今回の閉鎖指示と区別する。本書が改めて受け入れを代行したとはしない。

r0/r1/r2はRV-L20-plan で不可となった。入口の残りは本r3のDeclaredの変更と波及の再確認と、取りまとめによる plan の枠・段表・段別 O 行への追記である。それまでは L20 実装を起動しない。捕捉の全正則性の成立は L10 の受け入れに含まれず、最初の群 A の関門に残る。U01（Nat と WF）、U08（独立の内部上限なし）、U09（未設定の依存だけ CLI 継承、入口専用鍵は誤り）は回答済みである。L20 が選び直さない。

既定 import は `formal/Benitoite.lean` を読んで確認した。旧 Theorems・Model・ModelHttp・ModelTargets、新 Typing・StateTyping・TypeRegularity・TypeBounds・TypeRows・TypeArgumentRegularity 等を並置している。既存の主定理を外さない。新しいファイルを作る実装単位は、同じ単位で既定 import と実装済み規則の 01-12/07-04 の写しをそろえる。この下書きではどちらも変更していない。

### 既済みとして差し引く項目

| L20 の元の項目 | 現行ソースで読んだ定義・補題 | 差引きと残る仕事 |
|---|---|---|
| 値移動・型移動・値置換・narrowing | `R/TypingShift.lean` の `HasTypeVQ/CQ.shift_values`、`TypeShiftTyping.lean` の `shift_types`、`SubstTyping.lean` の `subst/subst_under_none`、`Narrowing.lean` の `narrow` | 相互14判断76構成子の四本304枝を再実装しない。案4に伴う既存39枝の局所修正はS12で別に計上する。型置換の別族は未実装で G03 |
| 部分型の型・行・範囲・値の移送 | `TypeSubst.lean` の `Ty.LeQ.substAt/subst/shift`、`RangeSubst.lean` の `Ty.LeQ.rawMapRanges/mapRanges/substRAt/instR/shiftR`、`EffectCover.lean` の `Covers.bind/Sub.bind` | 四族22規則と既存 Covers の証明を使う。tapp の形成とコードの型置換を G03、実表の範囲は L50 |
| 四名前空間の WF・支持・正規化 | `TypeBounds.lean` の `SubstEnv.WFImages`、`Ty/Eff/Tel.bind_wf/substAt_wf`、`TypeRegularity.lean` の `rawShift_of_wf/shift_of_wf`、`TypeRows.lean` の `rowsIn_iff_support/norm_rowsIn`、`TypeVariables.lean`、`TypeSupport.lean` | WF を作り直さない。Sorted/Declared の一般 tapp、kind/ProperApply、捕捉からの結果形成は G03/G04 |
| 文脈・捕捉の構文と移送 | `Context/WF.lean` の `Ordered/Regular/extend/extendNone`、`Context/Capture.lean` の `CaptureOk.extend/extendHidden/extendCont/extendTel`、`ClosureTyping.lean` の `CaptureOk.substOk/transport`、`DependentBeta.lean` の `CaptureOk.hideConts_any` | 強い Ctx.WF を CaptureOk に足さない。既存の延長・hide を再証明せず一般の使用先へつなぐ |
| 依存列と閉包の交換 | `ClosureTyping.lean` の `HasTypeTelArgsQ.of_arguments`、`Capture.instantiate/closeTel_instantiate_runtime`、`CaptureLocals.extendMany`、`Tel.instantiate_observations` | G02 は零・多引数への型付けの合成。構文の交換の再作成は差し引く |
| closeVal の閉性・適格性・観測 | `ClosedCapture.lean` の `closeVal_adequate/HasTypeVQ.close_ground`、`ClosureTyping.lean` の `closeVal_observation`、`LocalResolveLemmas.lean` の `closeVal_resolved` | G01 に残るのは全値の型保存と実行 view の契約。閉性や Adequate の同じ帰納は追加しない |
| ストア拡張・Reference・Lazy | `ReferenceStore.lean` の `HasTypeVQ.store_extend/ContTy.store/CellOk.store/StoreOk.write_reference/allocate_reference`、`DependentBeta.lean` の `HasTypeCQ.store_extend`、`LazyStore.lean` の `write_done/allocate_lazy/update_inv` | 定数代表に限らない既存ストア補題も再実装しない。任意 closeVal と実行の選択への合成、builder・fresh・localRefs が G07 |
| 継続・handler の葉 | `HandlerContinuation.lean` の `nil_inv/resume_append/split_handle`、`HandlerFailure.lean` の `fail_input/split_fail`、`HandlerStore.lean` の `use_continuation/allocate_continuation`、`HandlerEffects.lean` の `state_end/prepend_releases` | G05 は全操作・多相節・辞書・任意の捕捉へ接続する。`operation_one/resume_const/drop_rel_const` 等の代表を全遷移の完成と数えない |
| 分岐とパターン | `PathConditions.lean` の `if_true/if_false`、`MatchPaths.lean` の `guard_true/guard_false/match_start/match_skip/match_body_zero`、`MatchFacts.lean`、`PatternSemantics.lean`、`PatternTypeShift.lean` | δ=0 の代表と照合 facts を使い、任意 δ の束縛型保存を G06、型置換を G03。実際の PatTy9＋PatTys2=11 を使う |
| 値の意味・網羅性 | `ValueMeaning.lean` の四族と `ScopedValue`、`ValueMeaningInhabits.lean` の `valueMeaning_inhabits_normal`、`CoverageRefinement.lean` の Month/空篩/非空/長さの代表 | 定義・評価の単調性・意味から所属の系を差し引く。全部分型の意味移送、型付けから意味への全帰納は G09 |
| プログラム条件と旧入力 | `ProgramTyping.lean` の三 WellTyped と `method_body`、`ProgramWellFormed.lean`、`LegacyKinds/Input/Regularity/Tables/TableFacts/Values.lean` の kind 表、46規則の入力、四つの値の葉 | 定義を再作成しない。sig_scoped は G08、七判断と状態の全証明は G10 |
| 旧20欄と実表 | `ConstraintAssumptions.lean` の `CoreAssumptions`、`BuiltinResponse.lean`、`ExternalResponse.lean` | 移行済み19欄を再追加しない。唯一未移行の sig_scoped を G08 で移す。全モデルの充足は L50/L60 |
| 正常・return の共有近似 | `S/Approximation.lean`、`I/ApproxAdapter.lean` の `normalToShared_iff/baseToShared_mem`、`I/BudgetAnalyze.lean` の `Report.sharedFlow/shared_normal`、`R/ApproxAdapter.lean` の `constOK_toApprox` | 定義と既存の正常域の写しは差引き。独立評価から実行への接続・returned/failed の条件は .118〜.121/.122 と L40 H04 |

旧読者12件の処置は [handoff の表](../l10/f/handoff.md)を維持する。.31/.65/.66〜.68 は `wf_iff_old/varsIn_iff_old/varsInList_iff_old/Eff.varsIn_iff_old/RangesIn.opaque/WF.raw/WFList.raw/Eff.WF.raw/norm_rawWF/WF.canonical` の10種類の L20 使用先、.28/.29 は `PrimSig.scoped_iff_old/sig_scoped_iff_old_of_rangeFree` の2種類を新しい直接の条件へ置き換える。Surface の読者と `Ty.norm_legacy/Eff.norm_legacy` の旧互換の処置は L70。旧言明を復活させず、同じ名前の存在だけで読者の移行済みとはしない。

旧 `Preservation.closedArgs_of` と `PresBase.ClosedArgs.single` の二読者は .37/.83/.102/.104/.114 で `SignatureInstance.typeScope`、`method_body_typeScope`、`raise_typeScope/raise_subst_wf` を使う。旧 VarsIn から非継続を得る経路を新 VarsIn へ持ち込まない。

### L00b へ移した5〜9時間の照合

元の G 表には個別の控除先がなかった。[L00b.02 の第12.2節](../l00b.02/signatures.md)の四行に戻って対応を付ける。次表の G 行への配賦は本下書きの会計上の対応案であり、当時の行別実績を発見した意味ではない。四行の成果は上の実名で確認できる。移動全体5〜9は既存の合意を継承し、新たな短縮に数えない。

| 移動元の実際の行 | 既済みの証拠 | 今回対応する G 行と控除 |
|---|---|---:|
| `.02b-external` | TelArgs の相互移送、`Capture.closeTel_instantiate_runtime`、`HasTypeTelArgsQ.of_arguments` | G02 の構文の逐次具体化 1〜2時間 |
| `.02b-at` | `CheckedWitness` を含む四本の移送、`HeldValues.inv_checkedRequest`、観測の交換 | G03 の保持値・Request の既存相互移送 1〜2時間 |
| `.02b-handlers` | `SubstOk.hide/up/handler_clause/handler_failure`、`HasTypeCQ.subst_under_none`、腕・節の四本 | G05 の節の下の既存相互置換 1〜3時間 |
| `.02b-closures` | `CaptureOk.substOk/transport`、`Capture.instantiate`、閉包・TelBody の既存相互移送 | G02 の捕捉・依存βの構文の交換 2時間 |
| 合計 | 上記の証明を本書の残作業へ再計上しない | **5〜9時間** |

G04 の控除は **0時間**。G03 で控除するのは保持値の既存四移送だけであり、新しい型置換76枝ではない。G04 の未確認の全正則性と G03 の全型置換は、この控除の証拠に含めない。G01 の任意 closeVal の型保存も未完のままである。

## 採用済みの状態の不変条件の変更（見直しの対象）

取りまとめが r1 で案2を採用した。`StoreOk` に場所の型の sort の不変条件を追加する。これは plan が承認した新しい StateTy の範囲に属する。`StateTyE` の前提と結論の両方を強める変更として、段末の定義・言明・仮定のレビューへ出す。主定理の結論の弱化、新公理、利用者の書ける形の制限、精密な外部状態の追加はない。開始の空ストアで自明である。**以下は実装の計画であり、現行の `StoreOk` は変更していない。**

### S00: 固定した `LocTy.Sorted` と `StoreOk` の定義

```lean
def LocTy.Sorted : LocTy → Prop
  | .builder (.list a) | .ref a | .lazy a => a.Sorted []
  | .builder .string | .builder .bytes => True
  | .cont b t e _ => b.Sorted [] ∧ t.Sorted [] ∧ sortedEff [] e

def StoreTy.Sorted (Ψ : StoreTy) : Prop :=
  ∀ (l : Nat) (x : LocTy), Ψ l = some x → x.Sorted

def StoreOk (P : Program) (B : Builtins) (σ : PathEnv)
    (Ψ : StoreTy) (μ : Store) : Prop :=
  (∃ n, ∀ l, n ≤ l → μ l = none) ∧ Ψ.WF ∧ Ψ.Sorted ∧
  StoreTy.Declared P Ψ ∧ (∀ l x, Ψ l = some x → μ l ≠ none) ∧
  (∀ l c, μ l = some c → CellOk P B σ Ψ l c)
```

S00の採用の根拠は、`.used`の反例を閉じ、`.ref`で必要になり得るストアの型の大きさによる帰納を不要にし、ImageOk.contLocのSortedを供給することである。`.ref badT`は反例として扱わない。旧StoreOkにはセルの値の型付けも要り、そのセルを本稿では構成していない。旧StoreOkからの形成を型の大きさで導けるという説明は読んだ範囲の論証であり、Leanで閉じていない。

`.cont b t e r` の `r` は Sorted の対象から外す。`StateTyping.lean` の `ContTy.K_Empty` は入力の Annotation と末尾の被覆を持つが、R は任意である。`K_Handle_Fail` も R の Declared を持つだけである。この既存条件から r の Sorted は供給できず、S01 の再開の結果 t と潜在効果 e の形成には不要である（補助入力 used_annotation/used_rows で確認）。r の WF・Declared・正規形による一致は既存の `LocTy.WF/Declared`、`resume_raw_return`、各 ClosureTy の明示条件で維持する。R 自体の Annotation が新たに必要になれば J20-1 に返し、ここへ無断で足さない。

`StoreTy.Sorted.hide : ∀ {Ψ}, Ψ.Sorted → (hideBuilders Ψ).Sorted` をL20.01で追加する。既存 `StoreTy.WF.hide`（Typing.lean）と、新しい `StoreTy.Declared.hide : ∀ {P Ψ}, StoreTy.Declared P Ψ → StoreTy.Declared P (hideBuilders Ψ)` を合わせ、捕捉への系はWF/Sorted/Declaredの三つだけを受ける。hideBuildersでbuilderのセルを隠したストアにStoreOkを要求しない。両hideの形は補助Leanで確認した。

`Ty.Sorted.context`（`R/ContextMap.lean`）に空の `Ctx.TypeMap [] Γ` を渡すと、閉じた型の Sorted は任意の Γ へ移る。WF は `Ty.wf_shiftTypes` と `Ty.shiftTypes_of_wf_zero`、`Ty.wf_shiftV` と `Ty.shiftV_of_wf_zero`、Declared は既存 `Ty.Declared.closed_context` を使う。短い入力の `sorted_context/wf_context/used_annotation/locref_annotation` でこれらの合成を確認した。**Sorted の文脈変更だけには WF は不要**である。

| 新しい場所を生成する Step の全場合 | 新項と Sorted の供給元 | 受け持ち |
|---|---|---|
| E_RefNew | `.ref a`。元状態の primitive の `SignatureInstance.types` と StoreShape、又は引数の開いた S01 → 元 cap の `SubstOk.annotation`。選んだ閉じた a の `sorted` | .113/S00/S05 |
| E_Lazy | `.lazy (cap.closeTy a)`。元 `C_Lazy` が持つ `Ty.Annotation P [] Γ a` → 元 cap の `SubstOk.annotation` | .113/S00 |
| E_BuilderNew | `.builder .string/.bytes` は True、`.builder (.list a)` は元 `C_BuilderLet` の `kind.contents` の Annotation → 元 cap で閉じて list の要素へ射影 | .110/.111/S00 |
| E_Op | `.cont b t e r`。b は元操作の SignatureInstance と TelArgs、t/e は**割当て前**の `split_handle` が返す K_Handle の `Ty.Annotation … (.dependentFn (.done t e))`。r は対象外 | .101/.102/S00 |
| E_OpFail | `.cont b t e r`。b は元 raise の Annotation から得る T、t は元 K_Handle_Fail の Annotation、e は元 HasFailureClause.one の RowAnnotations を元 hcap で閉じる | .104/S00 |
| E_OpPrim | `.cont b t e r`。b は元 PrimitiveAdmissible/SignatureInstance と admits_sat、t/e は元 K_Handle の Annotation。io_op/ShapeOk は範囲の被覆へ別に使用 | .103/S00 |
| **合計** | **6生成規則、場所の4種。ほかの μ.set は同じ Ψ の内容の更新である** | E_Resume/Drop/EscDrop/ErrDrop/ExitDrop は Sorted をそのまま保持 |

S01 を使う場合も、入力は割当て**前**の `StoreOk` と元コードの導出である。新しい Ψ' の Sorted を S01 に渡してから Ψ' を作る経路は認めない。continuation の b/t/e は保存前の継続・節・呼出し側の注釈から得る。handler の全効果の境界は後の関門(a)に残す。

| 現行の構成・利用箇所（定義を読んだ名前） | 直接 `StoreOk` を組み立てる数／状態の組立て数 | 変更の中身と単位 |
|---|---:|---|
| ReferenceStore: `write_reference/allocate_reference` | 2／0 | write は既存 Sorted を保持、allocate は既存 ht : Ty.Annotation の ht.sorted を使い、引数は追加しない。raw 射影を named accessor へ。`CaptureOk.reference_write_snapshot` は上記を使う包装1件。.02/S00 |
| LazyStore: `write_done/allocate_lazy` | 2／0 | 同じ保持と新項の Sorted。allocate_lazy の既存 ht : Ty.Annotation の ht.sorted を使い、引数は追加しない。.02/S00 |
| HandlerStore: `use_continuation/allocate_continuation` | 2／0 | used でも Ψ.Sorted を保持。allocate に b/t/e の Sorted を追加、r は追加しない。.02/S00 |
| StateTyping: `StoreOk.empty` | 1／0 | empty の Sorted を証明。wf/declared/reference_read/adequate/resume_raw_return の raw 射影を追随、`StoreOk.sorted` を公開。.01/S00 |
| DependentBeta: `StateTyE.dependent_beta_one` | 0／2 | 元の hs を前後の StateTyE へ再使用する2箇所。`StateTy.dependent_beta_one` は包装1件、hs を構成し直さない。.03/S00、.84 |
| CapturedFacts: `StateTyE.captured_beta_one` | 0／2 | 同じ hs の再使用2箇所。`StateTy.captured_beta_one` は包装1件。.02/S00、.84 |
| HandlerPreservation（追加の読者） | 0／0 | StoreOk のセルを読む raw 射影5箇所（行239/294/320/339/358）を named accessor にする。.03/S00 |
| HandlerOperation（追加の読者） | 0／0 | raw 領域射影1箇所（行306）と allocate_continuation の呼出し1箇所（行302）。既存 hra.sorted/han.sorted から b/t/e の Sorted を渡す。.03/S00 |
| **合計** | **直接7構成、hs を再使用する状態4構成、包装3宣言。追加読者の raw 射影6、割当て呼出し1** | 指定の6ファイルと追加2ファイル。型付け構成子の変更0、四移送304枝の変更0 |

このほか全 `StoreOk` の使用先を `rg` で列挙し、named accessor の型を保つ利用と raw 射影の修正を分ける。.01 は定義・上記7構成と4状態・全既存ビルドまでを一つのレビュー対象にするが、実装時間は .01〜.03 に分割する。L30 の開始前にこの変更を取り込む。

## 最初の群 A と方式の確認

群 A は S00 の定義・追随を先頭に置き、四つの関門を本番に残す補題で確認する。最初の1時間の区切りで未証明枝と追加の見込みを更新する。下表の全成果物を満たすか、特定した失敗を停止票として返すまで群 B 以降の全帰納を起動しない。**本下書きでは四関門全体の通過を宣言しない。**

| 関門 | 固定する成果物と通過の判定 | 今回の確認と残るもの |
|---|---|---|
| (a) G04 | S01 の開いた motive、V29/CQ24 全53規則の Annotation 供給表、効果の境界表。最も弱い C_Let/C_BuilderLet/C_ResumeL/V_LocRef/V_Checked の case 証明又は反例。逆 shift の WF/Sorted/Declared と extendNone の版を完了条件にする | `let_annotation/builder_annotation/used_annotation/locref_annotation/checked_annotation` を Lean で確認。前二者は子の Annotation を IH とする case 証明であり、全帰納の証明ではない。新 Sorted でreviewのused反例を拒否。refは旧StoreOkの反例ではなく、型の大きさによる帰納の負担として訂正する。**全53枝・handler の効果の供給は未完** |
| (b) G03 | 固定した案4・rowKinds・Declared.tappを全読者へ反映。V_Op/V_Fun/C_Methの型引数3例に加え、escape/lambdaの注釈にtappを含む本体を新S02の結論まで閉じる。誤個数はsourceで拒否する | 新Declaredで誤個数の拒否、正しいtappの像、任意Γのlist(tvar)の像のAnnotation、値移送/norm/改名/shiftのheadのcase、実際のescapeの行先を補助Leanで確認。**本番全定義と全関門は未完**。.23で型注釈の実例を完成するまで通過しない |
| (c) G03 | `HasTypeVQ.notContCore` から、閉じた `.list k0` の値が空であり `[y]` との照合が失敗することを Lean で証明。data の欄・高カインド・capture へこの結果を使う経路も供給表へ記載 | `list_cont_empty/singleton_no_match` は任意 P/B/Ψ/Q/C/Φ・空 Γ で証明できた。`.op "o" [.list k0]` の型付けを禁止しない。全状態での使用先の照合は未完 |
| (d) G09 | S07a の外側の値の大きさ・内側の部分型導出の辞書式 motive と、`.data/.trans/.refine` の三枝。data で `variance_field_mono` が返す新導出を、元導出の IH と誤認しない | `.trans` の IH 合成を `meaning_trans` で確認。`.data/.refine` の本番に必要な全 case 証明は未確認（後掲の試行の限界）。三枝が閉じない間は通過しない |

独立の信頼条件である「全結果は形成済み」「全値は意味を持つ」を追加して関門を閉じない。特定した失敗について、定義、現行前提、導けない言明、Lean の反例又は未証明枝、代案、追加の所要時間（能動時間）と待ち、実用への影響を取りまとめへ返す。S00と、今回第一案として固定されたS12のCのkind保持・V_Raiseの変更は採用済みの見直し対象として記す。行像のkindを保持するS12.8とDeclaredのtappを読むS12.11も固定した案に含む。これを越える変更はJ表で扱う。

## 固定した署名の骨格（証明の成立とは別）

以下を単位の署名欄から参照する。S00 は採用済みの定義の形、S01/S02/S04/S05/S07/S08 はこの形を起点に検証する契約である。証明と形成入力の充足は予定であり、定理が成立済みという意味ではない。S03/S06/S09〜S11 の未固定事項は各見出しで区別する。共通の暗黙変数は各式の使用判断から型を決め、`Qempty` は `Benitoite.Release.Qempty`、`TParam/NoFailCtx` は旧と共有する名前を使う。実装で宣言する前に群 A で全引数を印字して固定する。以後の署名変更は共通依頼文に従う。命題の型検査とその証明を別に記録する。

### S01: 開いた結果形成の motive と捕捉への系

```lean
def CaptureContextRegular (P : Program) (C : TypeCtx) (Γ : Ctx) : Prop :=
  Ctx.CaptureWF 0 C.length Γ ∧
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) →
    a.CaptureSorted Γ ∧ a.CaptureDeclared P C Γ

-- この二つの開いた命題が相互帰納の motive になる。Φ の真は要求しない。
open_value_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  CaptureContextRegular P C Γ → HasTypeVQ P B Ψ Q C Γ Φ v a →
  Ty.Annotation P C Γ a
open_comp_annotation : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
    {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  CaptureContextRegular P C Γ → HasTypeCQ P B Ψ Q C Γ Φ R m a e L →
  Ty.Annotation P C Γ a

capture_value_annotation : ∀ {P B Ψ R Γ Φ cap v a},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  CaptureOk P B Ψ R Γ Φ cap →
  HasTypeVQ P B Ψ Qempty [] Γ Φ v a →
  Ty.Annotation P [] [] (cap.closeTy a)
capture_comp_annotation : ∀ {P B Ψ R Γ Φ cap Rs m a e L},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  CaptureOk P B Ψ R Γ Φ cap →
  HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L →
  Ty.Annotation P [] [] (cap.closeTy a)
```

14成分の recursor のうち結果が必要なのは V/Vs/Each/CQ/Arms/TelArgs である。Vs は `TypeAnnotations`、Each は `vs ≠ [] → Ty.Annotation … a`、Arms は末尾 nil が持つ結果 b の Annotation、TelArgs は done の Annotation を結論する。他の成分は True とし、同じ recursor を使う。Arms から結果を取るために束縛型 δ の形成を先に仮定して本体へ下りる必要はない。C_Handle は本体 m の結果を使う。C_Let は m の IH で a の三条件を得て文脈を延長し、n の IH の b.shiftV を逆 shift する。C_BuilderLet は extendNone の保存と逆 shift を使う。C_If の真偽の Φ は自由なので CaptureOk の真を作らない。空 Each の型の無条件形成は主張しない。

`Ty.wf_shiftV_rev`（NormalWellFormed）、`Ty.sorted_shiftV_rev`（ValueRegularity）、`Ty.Declared.shiftV_rev`（DeclaredTransport）が存在する。Declared の逆には束縛型の Declared を要る。BuilderLet は結果の Declared が規則にあるためそれを直接使い、Sorted は `Ctx.TypeMap Γ.extendNone (Γ.extend (.base .unit))` を介して逆にする。今回の短い試行でこの二つの case の合成を確認した。capture の二系は、上の開いた結果へ `hc.substOk.annotation` を適用する。型置換 G03 の完成をこの開いた証明の前提にしない。

### S01a: V29/CQ24 の結果の Annotation の全供給表

各行の「規則」は一つずつ数える。`既存注釈` は同じ構成子の前提、`IH` は上の開いた motive の子を指す。表を埋めたことと各枝の Lean 証明が完了したことは別である。

| 規則 | WF・Sorted・Declared の供給元 | 効果又は未確認の接続 |
|---|---|---|
| V_Var | CaptureContextRegular と Ordinary による Capture 三条件の通常形への射影 | 最上位 cont は Ordinary により除く。入れ子は禁止しない |
| V_Const | ConstOK と Core の定数型の形成 | 値自体の結果に効果なし |
| V_Lam | WF/Sorted/Declared の既存注釈 | 潜在 e も注釈に含む |
| V_DependentLam | 既存 Annotation (.dependentFn t) | t の done の e も含む |
| V_Closure | 同じ既存 Annotation | 外側の注釈を使う |
| V_Fun | SignatureInstance.result | 宣言の全 e はその result |
| V_Prim | SignatureInstance.result | 範囲具体化後の result |
| V_Op | SignatureInstance.result | 同じ |
| V_ExternalRef | SignatureInstance.result | 同じ |
| V_ExternalHandle | 既存 Annotation | 同じ |
| V_PathBases | Ty.WF/Sorted/Declared の定義 | 効果なし |
| V_ScopePattern | range.WF/Canonical/FitsKind と型の定義 | 効果なし |
| V_Checked | 固定 absolute index の WF と型の定義。checked_annotation で確認 | range の意味の所属と型の sort を混同しない |
| V_CheckedRequest | 同じ固定 absolute index と型の定義 | req の結果を外側の形成には使わない |
| V_CheckedAt | CheckedWitness と固定 range index の型の定義 | Witness の request は閉じた別枝 |
| V_AtError | ResultShape.Declared.errorType_eq と標準型 | 宣言の供給を使う |
| V_Map | a/b の既存 Annotation | 空列の IH に頼らない |
| V_Set | a の既存 Annotation | 同じ |
| V_Dict | dict 型の既存 Annotation | 同じ |
| V_Raise | fn 型の既存 Annotation | singleFail の E も含む |
| V_LocRef | Ψ.WF/Sorted/Declared の ref 射影と context | locref_annotation で確認 |
| V_LocLazy | 同じ lazy 射影 | .01〜.03 の Sorted accessor |
| V_Bytes | 型の定義 | 要素255以下とは別 |
| V_Con | data 型の既存 Annotation | 欄の形成を結果形成に足さない |
| V_Super | 子の dict の IH から a の WF/Sorted、規則の a.Declared とクラス表 | superclass 宣言の供給を照合 |
| V_List | a の WF/Sorted/Declared の既存前提 | 空 list も同じ |
| V_Sub | b の WF/Sorted/Declared の既存前提 | 元の型の形成だけでは代用しない |
| V_Normal | 子の IH と Annotation.norm | 正規化後の三条件 |
| V_Refine | 子の IH と HasSort、Pred.Sorted/WF/Declared | Entails は結果の形成に真を要求しない |
| C_BuilderLet | 子の IH の逆 shift、規則の a.Declared | e の形成は別の境界表 |
| C_BuilderOp | kind.contents の Annotation と op.resultType の射影 | Eff.empty |
| C_Return | 値の IH | Eff.empty |
| C_Let | 前半の IH で extend、後半の IH の逆 shift | e は元 ClosureTy の全体注釈から閉じる |
| C_App | f の IH の fn 結果への射影 | 潜在 e も f の IH から |
| C_DependentApp | TelArgs の done の Annotation、引数具体化 | 潜在 e も TelArgs の結果から |
| C_If | 任意 Φ の片側の IH | 型に Φ の真を仮定しない |
| C_Match | Arms の末尾 nil の既存 Annotation | 腕の e は nil だけでは形成を得ない |
| C_Lazy | a の既存 Annotation | Eff.empty |
| C_Escape | a の既存 Annotation | **任意 e の Annotation は導かない** |
| C_Use | 本体の IH | State の所属は別の前提 |
| C_Handle | 本体 m の IH | εm/handled の形成は次表の未確定点 |
| C_Handle_Fail | 本体 m の IH | eb/rest/ec は次表 |
| C_Resume | Γ の CaptureWF/Sorted から t、規則の Declared | 潜在 e は ImageOk と元 Ψ から閉じる |
| C_ResumeL | Ψ の cont の WF/Sorted/Declared の t 射影 | used_annotation で確認。CellOk の used に頼らない |
| C_ResumeNorm | C_Resume と Annotation.norm | 効果は norm 後に扱う |
| C_ResumeLNorm | C_ResumeL と Annotation.norm | R の正規形一致は別に保持 |
| C_Normal | 子の IH と Annotation.norm | e は同じ |
| C_Meth | a の既存 Annotation | SignatureInstance と Tel.arguments の e の形成は具体化補題 |
| C_External | TelArgs の IH | done の潜在 e |
| C_IssuePathBases | 型の定義 | 固定 processEnvironmentEff |
| C_CheckAt | AtCallAdmissible の shape/index と型の構成 | Eff.empty |
| C_Sub | b の明示 WF/Sorted/Declared | ε' の形成は無条件には得ない |
| C_Eff | 子の IH | 同上 |
| **合計** | **V29＋CQ24＝53規則** | 型の結果と計算の任意の効果を分ける |

### S01b: 状態の葉が必要とする効果の供給表

| 必要箇所 | 供給元・検証する経路 | 状態 |
|---|---|---|
| E_Let/K_Let の前後 | 元 ClosureTy の閉じた全体の e 注釈、必要な b の S01、shift と元 cap の合成 | 型の逆 shift は確認。全効果の合成は未完 |
| E_Lam/V_Lam/DependentLam | 明示 fn/dependentFn Annotation → cap.substOk.telAnnotation → apply 後の done | 既存 CapturedFacts/DependentBeta の一引数は実在。全引数は未完 |
| E_Handle の本体 εm | 生の εm の形成を無条件に主張しない。`C_Eff` により `ε ∪ handled P B h` の形成済みの上限へ広げられるかを、元 clauses の eb と ClauseSig の整合も含めて検証 | **未確定の関門**。handled の効果名/範囲を Program.WellFormed/Core と元 handler から供給できない場合は J20-1 |
| E_Handle_Fail の eb/rest/ec | failure.one の E/t/RowAnnotations ec と元全体効果、`C_Eff` の上限。rest の形成・正規化と NoFail の維持を個別に証明 | **未確定の関門**。結果 t の S01 だけで閉じない |
| C_Resume の潜在 e、ImageOk.contLoc | 同じ元 Ψ の cont の sortedEff、WF/Declared、`ImageOk.contLoc` の閉じた像の等号。contVar は捕捉先の空文脈に lookup できない | 新 Sorted が供給元。一般合成は未完 |
| 新しい continuation 場所の e | 割当て前 K_Handle の done の Annotation、Fail は failure.one の行注釈。S00 の6生成表 | 既存証拠の射影案。全 split 経路の証明は未完 |
| C_Eff/C_Sub/C_Escape の任意 e | これらの構成子はそれだけで任意 e の形成を与えない。状態の元 ClosureTy と実際の上限を使用 | **独立の全効果 Annotation を仮定に追加しない** |


### S02: Q を移すコード型置換の14署名（形成入力の充足は未確認）

2026-11-02 の追記: S02 の十の移送の前提に `TypeSubstCode` を足した。完全な定義と十四署名は `l20/a3b/signatures.md` と本番の `TypeSubstContracts.lean` を正とし、本節の字面より優先する。WF 0 0 0 の型は自由な行変数を含み得るので、行置換で不変とは扱わない。反映の内容は `l20/a3b/r1-detail-handoff.md` にある。

`θ := typeEnvAt c ts es`、`A a := a.substAt c ts es`、`E e := Eff.substAt c ts es e`、`G Γ := Γ.bindTypes θ`、`Lθ L := L.map (Option.map Kθ)`、`Kθ (.list a) := .list (A a)`、他の BuilderKind は恒等、と定める。これは既存 Comp.substTyAt が使う型・行の写しそのものである。

```lean
-- 予定する閉じた型像の入口。行の WF・RowsIn・Q の条件も下の入力形で渡す。
type_subst_comp : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R m a e L ts es},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P → Ψ.WF →
  ClosedTypeSubstInput P B C0 C1 Γ ts es →
  RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
    (R.map (Ty.substAt C1.length ts es))
    (m.substTyAt C1.length ts es) (a.substAt C1.length ts es)
    (Eff.substAt C1.length ts es e) (L.map (Option.map Kθ))
```

`ClosedTypeSubstInput`の完全な定義はS12.7に置く。C0/C1はTypeCtx、SatAllの相手は(TypeCtx.constraints C0)、型像のkindは(TypeCtx.kinds C0)から固定して読む。閉じた型/行像のWF000、Annotation、kindと元ΓのCaptureContextRegularを持ち、RowTransportは公開署名の別入力とする。元コードのRowsIn/行数は実際のAdmissibleと元の型付けから維持する。型付け・形成・移送の結論を入力欄にしない。C1は残す型束縛であり、一般のcutoffでは同じ入力を接頭辞に分解する。

十四成分の完全署名を次に固定する。ここで `c := C1.length`、`I := ClosedTypeSubstInput P B C0 C1 Γ ts es` とし、`A/E/G/Kθ/Lθ` は上記の式、`V v := v.substTyAt c ts es`、`Vs := List.map V`、`T := Tel.substAt c ts es`、`AR := Arm.substTyAtList c ts es`、`CL := Clause.substTyAtList c ts es`、`RR := Option.map A` という**引数を省略しない式の略記**を使う。各行の `I` は形成の結論そのものを含まない入力である。共通前提 `F := P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF` を一度だけ略記する。実装前にはこの略記を展開した `#check/#print` を results に保存する。

```lean
S02_V : ∀ {P B Ψ Q Q' C0 C1 Γ Φ v a ts es},
  F → I → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V v) (A a)
S02_Vs : ∀ {P B Ψ Q Q' C0 C1 Γ Φ vs as ts es},
  F → I → RowTransport Q Q' es →
  HasTypeVsQ P B Ψ Q (C1 ++ C0) Γ Φ vs as →
  HasTypeVsQ P B Ψ Q' C1 (G Γ) Φ (Vs vs) (as.map A)
S02_Each : ∀ {P B Ψ Q Q' C0 C1 Γ Φ vs a ts es},
  F → I → RowTransport Q Q' es →
  HasTypeEachQ P B Ψ Q (C1 ++ C0) Γ Φ vs a →
  HasTypeEachQ P B Ψ Q' C1 (G Γ) Φ (Vs vs) (A a)
S02_C : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R m a e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R m a e L →
  HasTypeCQ P B Ψ Q' C1 (G Γ) Φ (RR R) (m.substTyAt c ts es) (A a) (E e) (Lθ L)
S02_Args : ∀ {P B Ψ Q Q' C0 C1 Γ Φ vs t a e ts es},
  F → I → RowTransport Q Q' es →
  HasTypeTelArgsQ P B Ψ Q (C1 ++ C0) Γ Φ vs t a e →
  HasTypeTelArgsQ P B Ψ Q' C1 (G Γ) Φ (Vs vs) (T t) (A a) (E e)
S02_Body : ∀ {P B Ψ Q Q' C0 C1 Γ Φ t m ts es},
  F → I → RowTransport Q Q' es →
  TelBodyTy P B Ψ Q (C1 ++ C0) Γ Φ t m →
  TelBodyTy P B Ψ Q' C1 (G Γ) Φ (T t) (m.substTyAt c ts es)
S02_Capture : ∀ {P B Ψ R Γ Φ cap},
  CaptureOk P B Ψ R Γ Φ cap → CaptureOk P B Ψ R Γ Φ cap
S02_Closure : ∀ {P B Ψ q t},
  DependentClosureTy P B Ψ q t → DependentClosureTy P B Ψ q t
S02_Witness : ∀ {P B Ψ o k r snapshot target req},
  CheckedWitness P B Ψ o k r snapshot target req →
  CheckedWitness P B Ψ o k r snapshot target req
S02_At : ∀ {P B Ψ Q Q' C0 C1 Γ Φ k o shape bases pattern input ix ts es},
  F → I → RowTransport Q Q' es →
  AtCallAdmissible P B Ψ Q (C1 ++ C0) Γ Φ k o shape bases pattern input ix →
  AtCallAdmissible P B Ψ Q' C1 (G Γ) Φ k o shape (bases.map V) (V pattern) (V input) ix
S02_Arms : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R obs arms a b e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeArmsQ P B Ψ Q (C1 ++ C0) Γ Φ R obs arms a b e L →
  HasTypeArmsQ P B Ψ Q' C1 (G Γ) Φ (RR R) obs (AR arms) (A a) (A b) (E e) (Lθ L)
S02_Clauses : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R eb clauses t e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeClausesQ P B Ψ Q (C1 ++ C0) Γ Φ R eb clauses t e L →
  HasTypeClausesQ P B Ψ Q' C1 (G Γ) Φ (RR R) (E eb) (CL clauses) (A t) (E e) (Lθ L)
S02_Failure : ∀ {P B Ψ Q Q' C0 C1 Γ Φ err R clauses t e L ts es},
  F → I → RowTransport Q Q' es →
  HasFailureClause P B Ψ Q (C1 ++ C0) Γ Φ err R clauses t e L →
  HasFailureClause P B Ψ Q' C1 (G Γ) Φ (A err) (RR R) (CL clauses) (A t) (E e) (Lθ L)
S02_Image : ∀ {P B Ψ Q C Γ Φ R ν i a},
  ImageOk P B Ψ Q C Γ Φ R ν i a → True
```

Qを移す成分はV/Vs/Each/CQ/TelArgs/TelBody/At/Arms/Clauses/Failureの**10件**である。CaptureOk/DependentClosureTy/CheckedWitnessは恒等の**3件**、ImageOkはTrueの**1件**で、恒等又はTrueは計4件である。恒等の三署名から使わないQ/Q'/RowTransportを除いた。ImageOk.contLocのR0は格納した非正規形のままなので、RR Rへの型置換を主張しない。CaptureOkの恒等は元の証拠をそのまま返し、ImageのIHを使わない。q_monoは別の族であり、ImageOkを含む11成分を移せる。

**固定した入力と未確認の成立**: S12.7の入力の全欄、S12.9の三caseの完全署名を固定した。新定義の断片でkindの反例を除けることは確認したが、全既存読者の移行と全caseの本体は未実装である。案4の波及の見込みが外れた場合の案1への切替条件はS12.6へ置く。入力の欄を供給するだけで関門(b)の通過としない。

**E_OpFail**: r1のFail用別入口を撤回する。V_RaiseにTのvalue kindを保持し、失敗節のfresh TはTypeCtx.valueParamにする。Annotation/Ordinaryからkindを推定せず、V_Raiseの新しい前提から型像[T]のkindを得て、E_Fun/Meth/Opと同じS02を使う。エラー型Eに新しいkind前提は追加しない。この規則の前提の中身の変更もS12としてレビューする。

E_Fun は元 `Def.WellTyped` の QTel と Admissible.noFailRows を `Def.QTel_eq_Qsig` で合わせて Q'=Qempty とする。E_Meth は `method_body` と MethodRowsAdmissible の代入前 Qsig、E_Op は節の Q と `sg.WF` の行境界、E_OpFail は型像[T]・行像[]を使う。4例とも元 cap で像を閉じた形と C1 の型束縛下の形を単位 .08〜.22/.37 の完了条件にする。q_mono で QTel を Qempty へ落とす経路は使わない。ここで「閉じた」は型・値・範囲の自由変数がない WF000 を意味し、行変数の支持を無条件に空へ制限する意味ではない。行支持は元宣言の sourceRows と Q/Q' の RowTransport をそのまま使う。型像と行像が WF000 なので `typeEnvAt` の `shiftRowsTypes c 0` は残す C1 の深さ c へ一度だけ移す。

開いた値依存像については、`ts.map cap.closeTy`・`es.map cap.closeEff` を用いた S02 と、`closeVal/closeTel/closeR` と `substTyAt` の交換を別の族として証明する。値束縛 n の下では `ts.map (Ty.shiftV n 0)` と `es.map (Eff.shiftV n 0)`、通常節ではさらに cutoff+k、Fail では cutoff+1 を使う。捕捉済みのコード・型注釈・R・局所 kind の交換を結論し、閉包の環境を捨てた `instantiate` との等号へ替えない。O006 の既存の開いた LeQ/Covers の入口は維持する。

### S04: Q・局所文脈・戻り先の移送と旧読者

```lean
-- 予定。q_mono は旧 QLe の同じ向き。
HasTypeCQ.q_mono : ∀ {P B Ψ Q Q' C Γ Φ R m a e L},
  HasTypeCQ P B Ψ Q C Γ Φ R m a e L →
  (∀ i, Q i → Q' i) → HasTypeCQ P B Ψ Q' C Γ Φ R m a e L

-- 旧 Surface/Lemmas/ReturnTry の条件を維持する。
HasTypeCQ.withReturn : ∀ {P B Q C Γ Φ m a e L} (R : Option Ty),
  HasTypeCQ P B StoreTy.empty Q C Γ Φ none m a e L →
  HasTypeCQ P B StoreTy.empty Q C Γ Φ R m a e L

-- G10 専用。ValueAssumptions を使わず局所文脈だけを変える。
HasTypeCQ.local_zero : ∀ {P B Ψ Q C Γ Φ R m a e L L'},
  HasTypeCQ P B Ψ Q C Γ Φ R m a e L → LocalCtx.Shift 0 0 L L' →
  HasTypeCQ P B Ψ Q C Γ Φ R m a e L'
```

q_mono は Q を持つ V/Vs/Each/CQ/TelArgs/TelBody/AtCallAdmissible/腕/節/失敗節/ImageOk の11成分を写す。CaptureOk/DependentClosureTy/CheckedWitness の3成分は恒等の motive であり、閉じた内部の Qempty を変えない。14成分の recursor の76 case を一度だけ埋める。withReturn は CQ/腕/節/失敗節の四族で、元 R=none と空ストアを維持する。R を持たない値族を再帰で変えない。local_zero は CQ/腕/節/失敗節の L だけを変え、束縛下は `LocalCtx.Shift.extend/localExtend` を使う。

store/hide/rename は既存 shift_values の k=0、SubstOk.hide、CaptureOk.hideConts_any、store_extend の特殊化で閉じる。任意の並べ替え・縮約の改名は生の Val.rename で WF を主張せず、型付きの値置換（bind で正規化）で述べる。`subst_congr` は実際に参照する some の型の位置と局所参照の一致を条件にし、snapshot の全 some slot も含める。`localRefs` は構築器場所の有効性の命題であり、local_zero と同じ意味にしない。`R/LocalResolveLemmas.lean` の resolve_id と解決済みコードの閉性を使い、旧 `O/LocalScope.lean` と `O/Lemmas/LocalInvariant.lean` の Frame/Cell/Cont/State の形を新 Capture に拡張する。

### S05: 任意 closeVal の型保存と実行 view

```lean
close_value_typed : ∀ {P B Ψ R Γ Φ cap v a},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  Ψ.WF → Ψ.Sorted → StoreTy.Declared P Ψ →
  CaptureOk P B Ψ R Γ Φ cap →
  HasTypeVQ P B Ψ Qempty [] Γ Φ v a →
  HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy a)
```

Vs/Each は結果列を closeTy で写して closeVals を結論する。V_Lam は closeVal が `.closure` を作るため、単なる `v.subst cap.env` の型付けからの等号では閉じない。`Tel.RuntimeShape`、`lambdaShape`、`DependentClosureTy.mk`、`Ty.foldFn/toTel` で同じ入力・結果・効果の契約を合わせる。V_Sub/Normal/Refine は S01 と既存 Transport、観測の同一性を使う。closeVal の観測・Ground・Adequate は既存の系を適用する。

Closure.view の契約は Comp の16構文形すべてについて、一歩で閉じる値・型・行と、そのまま cap に残す子コードを列挙する case 定義の形とする。各枝は S05 の型付き値と ClosureTy の同じ a/e/R を供給する。view 全体を捕捉を失うソース Comp の型付けへ押し込む定理は要求しない。

### S07: 全意味移送と型付けからの所属

```lean
valueMeaning_sub : ∀ {P Γ Φ a b v η},
  P.VarianceValid → Ty.LeQ P Γ Φ a b →
  (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
  ValueMeaning P η a v → ValueMeaning P η b v
typed_value_meaning_closed : ∀ {P B Ψ v a},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → ValueMeaning P (fun _ => none) a v
inhabits_of_typed : ∀ {P B Ψ v a},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → Inhabits P a.norm v
inhabits_of_typed_raw : ∀ {P B Ψ v a},
  P.VarianceValid → B.CoreAssumptions P →
  HasTypeVQ P B Ψ Qempty [] [] [] v a → Inhabits P a v
```

これは [X の最終署名](../l10/x/signatures.md)をそのまま引き継ぐ。data の欄の単調性は Annotation を独立に要求しない現在の `variance_field_mono` を使う。意味移送の相互四族と、LeQ 等の四族の帰納を同じ不変量で一度組む。型付けの側は V29/Vs2/Each2 の33場合を閉じる。閉じた変数は空 Γ から排除し、lambda の CQ 本体には意味の帰納を降ろさない。捕捉された値と任意の腕の入力は S05→閉じた型付け→本定理→`Inhabits.of_subst_values` で供給する。閉じた単純値の代表だけを全33場合の証拠にしない。

### S07a: 辞書式の motive（未確認の枝を含む）

`M v (h : Ty.LeQ P Γ Φ a b)` の完全な結論は、

```lean
∀ (η : ObservationEnvModel),
  (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
  ValueMeaning P η a v → ValueMeaning P η b v
```

である。外側は `sizeOf v` の強い帰納、内側は h の構造帰納を使う。外側の motive の完全署名は、

```lean
∀ (n : Nat), ∀ (v : Val), sizeOf v = n →
  ∀ (P : Program), P.VarianceValid →
  ∀ (Γ : Ctx) (Φ : List Pred) (a b : Ty)
    (h : Ty.LeQ P Γ Φ a b),
  ∀ (η : ObservationEnvModel),
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η a v → ValueMeaning P η b v
```

とする。Prop の導出 h を Nat へ消去する「導出サイズ関数」は定義しない。ここでの辞書式は、(1) 子値なら任意の導出へ外側の IH、(2) 同じ値なら厳密な部分導出へ内側の IH、の二段の帰納を意味する。内側の四成分の完全な motive は次である。後の三成分は True とする。ValueMeaning の関数の形は本体の意味を要求しないため、TelLe の意味を別に定義する必要はない。data の欄では TypeArgsLe の証拠そのものを variance_field_mono に渡し、その返す導出へ外側の IH を使う。

```lean
MLe {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty}
    (v : Val) (_h : Ty.LeQ P Γ Φ a b) : Prop :=
  ∀ (η : ObservationEnvModel),
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η a v → ValueMeaning P η b v
MTelLe {P : Program} {Γ : Ctx} {Φ : List Pred} {t u : Tel}
    (_h : TelLe P Γ Φ t u) : Prop := True
MTelClosure {P : Program} {Γ : Ctx} {Φ : List Pred} {t u : Tel}
    (_h : TelClosure P Γ Φ t u) : Prop := True
MTypeArgs {P : Program} {Γ : Ctx} {Φ : List Pred}
    {vs : List Variance} {as bs : List Ty}
    (_h : TypeArgsLe P Γ Φ vs as bs) : Prop := True
```

この4成分で全caseを閉じられるかは未確認であり、群 A4 で印字と三枝の証明を完了するまで H を起動しない。

| 枝 | 証明の形と下降 | 今回の確認 |
|---|---|---|
| `.trans hab hbc` | 同じ v、部分導出 hab の IH を通して中間 b の意味を作り、hbc の IH を使う。b の Annotation を追加しない | meaning_trans の Lean case 証明あり |
| `.data hargs` | ValueShapeMeaning.con を逆転。欄を `variance_field_mono` で比較し、その**新しい導出**へ `sizeOf child < sizeOf (.con c tys args)` の外側 IH を適用。ValueMeanings を再構成 | 欄単位の移送・サイズ・宣言照合の全合成は未確認。内側 hargs の IH で新導出を済ませたとしない |
| `.refine hab hp hq he` | 元の ValueMeaning から基底 a と p の全 conjunct の真を得る。hab の内側 IH で b、`Entails.sound` を selfModel に適用して q、packRefinements/norm の同値で結論 | `.trans` と異なり論理の供給が残る。selfModel と Γ.facts/lift の真、a の Ordinary の扱いを含む case 証明は未確認 |

今回 `.data` では既存 variance_field_mono を適用する試行が型像 as/bs の Ordinary の二つの未解決目標を残した。これらは一般の S07 の前提からは自動で得られず、型付けの注釈を独立入力に足さずに導く方法又は意味に直接使う補助が必要である。`.refine` では基底の IH に元の refined の意味を直接渡す試行が型不一致になった。基底の意味と述語の真の分解・再構成が未完である。いずれも反例による不成立の証明ではない。これは群 A 未通過の理由であり、定理の前提を増やす根拠にはしない。G09 の最終の typed_value_meaning_closed は V29/Vs2/Each2 の33 case を一度組み、V_Sub から上の定理を使う。

### S08: パターン束縛の型保存

```lean
pattern_bindings_typed : ∀ {P B Ψ p a δ v ws},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P → Ψ.WF →
  PatTy P p a δ → HasTypeVQ P B Ψ Qempty [] [] [] v a.norm →
  matchVal p v = some ws →
  HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm)
```

PatTys と AltsTy は対応する値列・照合・selectSlots の形で同じ結論を取る。raw δ が必要なら各型の Annotation を別に**証明して** convert する。P_Convert の9番目の枝を落とさない。CaptureOk の延長は `.extend/.extendTel` を使い、照合結果の Ground と観測 facts を供給する。MatchBody/Guard は任意の cap・δ・ρ を保つ。

List と data の値の子を取り出すために、既存 `R/Canonical.lean` の `HasTypeVQ.inv_list`、`R/ValueFacts.lean` の `inv_con/con_field_by_type/constructor_field_inputs` を使用する。これらの存在と署名を読んで確認した。L40へ残す全canonical formsをG06の先行依存にせず、不足するパターン固有の束縛の移送だけを.94〜.96で閉じる。

### S08a: 義務を検査する代表の言明（予定）

O136 の `dependent_result_close` は、閉じた宣言の結果型へ型像を代入してから捕捉で閉じる順と、型像を先に閉じる順の一致である。

```lean
dependent_result_close : ∀ {nt : Nat} {a : Ty},
  a.WF 0 nt 0 → ∀ (ts : List Ty) (cap : Capture),
  cap.closeTy (a.subst ts []) = a.subst (ts.map cap.closeTy) []
```

既存 `Ty.subst_values_closed` の公開した使用先として .83 で本体へ適用する。値依存の結果・端点・長さの契約を同じ等式で接続し、式の一致を契約の意味の保証と混同しない。

O143 の `pattern_length_relation` は元の list と保持した先頭要素・残りの list・長さを同じ照合から取り出す。

```lean
pattern_length_relation : ∀ (vs ws : List Val),
  matchVal (.list [.var] (some .bind) []) (.list vs) = some ws →
  ∃ (v : Val) (rest : List Val),
    vs = v :: rest ∧ ws = [v, .list rest] ∧ vs.length = rest.length + 1
```

.95 はこれと S08 の δ の型保存を合わせ、closeVal による同じ v/rest の観測・長さの保存も示す。例 `[v₀,v₁] → [v₀,[v₁]]` と空 list の失敗へ適用する。任意の同じ長さの別 list の標準関数の実契約は L40、Φ から n>0 を合成する規則は L30/L70 に残す。この代表だけを O143 全体の閉鎖としない。

## 未固定の署名と定義の項目

以下は形成入力又は定義の全欄が未固定である。対応する最初の単位で完全署名を印字して固定し、その定理の本体を始める。S02 の出力14成分は前節で固定したが、ClosedTypeSubstInput の全実呼出しへの適合も関門 A3 に残る。

### S03: 未固定の候補署名 — 型置換のパターンと反映

```lean
-- 予定。forming は source 型・像の WF/kind/Ordinary と実際の P の宣言の証拠。
PatTy.substAt : ∀ {P p a δ} (c : Nat) (ts : List Ty) (es : List Eff),
  P.WellFormed → PatTy P p a δ →
  PatTy P p (a.substAt c ts es) (δ.map (Ty.substAt c ts es))
PatTys.substAt : ∀ {P ps as δ} (c : Nat) (ts : List Ty) (es : List Eff),
  P.WellFormed → PatTys P ps as δ →
  PatTys P ps (as.map (Ty.substAt c ts es)) (δ.map (Ty.substAt c ts es))
AltsTy.substAt : ∀ {P alts a δ} (c : Nat) (ts : List Ty) (es : List Eff),
  P.WellFormed → AltsTy P alts a δ →
  AltsTy P alts (a.substAt c ts es) (δ.map (Ty.substAt c ts es))
Inhabits.of_substAt : ∀ {P a v} (c : Nat) (ts : List Ty) (es : List Eff),
  P.WellFormed → Inhabits P (a.substAt c ts es) v → Inhabits P a.norm v
Exhaustive.substAt : ∀ {P a ps} (c : Nat) (ts : List Ty) (es : List Eff),
  P.WellFormed → Exhaustive P a ps → Exhaustive P (a.substAt c ts es) ps
```

これらは旧 TySubstMain の候補形で、無条件の構文操作としての補題を先に試す。P_Convert は正規化との交換、P_Refined は全述語の反映、data 欄は `VarianceValid.field_annotation` と閉じた宣言の代入の合成を使う。像の追加形成が必要と判明した場合は、その供給を S02 の入力から示して署名を固定し直す。E_OpFail の T に value kind を一律に仮定できないため、この追加を自動では行わない。P.WellFormed だけで既に証明できたと扱わない。

### S06: 未固定の候補署名 — 零・多引数と閉包の適用

```lean
-- 予定。既存 ClosureTy の入力列をすべて実引数で埋める。
ClosureTy.apply_all : ∀ {P B σ Ψ μ R q ss a e vs},
  P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
  StoreOk P B σ Ψ μ → ClosureTy P B Ψ ss R q a e →
  HasTypeVs P B Ψ [] [] [] vs ss → (∀ v ∈ vs, v.Ground) →
  let ν := (Capture.empty.extendMany vs).env
  ClosureTy P B Ψ [] (R.map (substTyValues ν)) (q.apply vs)
    (substTyValues ν a) (substEffValues ν e)
```

上式は ClosureTy の ss が既に閉じた**非依存の入力列**である場合の入口である。元の a/e/R はその入力の番号を持ちうるので、結論でも実際の値で置換する。依存する引数列の本体には別に、`DependentClosureTy P B Ψ q t` と `HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e`、各実引数の Ground を取り、`ClosureTy … [] (some a) (q.apply vs) a e` を結論する入口を置く。R の値依存の代入が必要な中間の形は `cap.closeRAt n Rs` を保持する。既存 `Capture.instantiate/extendTel/capture_tel/result_tel` で結果と効果を同時に合わせる。一般形の可否と正確な ss/R の表現は .08〜.22/.79 で固定する。

### S09: 未固定の定義の項目 — 宣言と sig_scoped

`PrimSig.Scoped P s` の定義の形は、`NamesWF s.names s.params`、型パラメータ kind/制約の長さと宣言表の一致、`s.tel` の範囲深さ `s.rkinds.length`・型深さ `s.tparams.length`・行深さ `s.neffs`・値深さ0の SourceScoped、依存する各束縛位置での WF/Sorted/Declared と HasKind、`params/ret/eff` と tel の一致である。範囲は普通の `SignatureScoped` の0へ潰さない。`PrimSig.inst` 又は `Tel.instR` と `RangeAdmissible` から範囲深さ0で同じ条件を導く。旧 `TargetRangesOnly` と instTarget はその実読者で必要な部分だけ射影し、依存列を旧 params の一括写像へ戻さない。

`Builtins.CoreAssumptions.sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s` を既存の束へ加えるのが予定する移行である。旧20欄の欠けを埋める承認済みの作業として差を明記する。独立の新しい型置換・捕捉・意味の信頼条件は加えない。実表・三モデルの充足は L50/L60、主定理での使用は L70 に残る。L20 の埋め込みの前提 LegacyTables へ sig_scoped を足してはならない。

宣言入力の形は `LegacyDeclarationsInput` に加え、写した各本体の `SourceScoped`、[handoff](../l10/f/handoff.md) の `declarationBodyInputs`（関数・メソッド・上位辞書）とする。新 WellTyped を入力の欄にしない。`op_dictionaryInputs/impl_dictionaryKinds` を供給元にし、メソッドの Q は代入前の `QTel ms.tel` とする。

### S10: 未固定の定義の項目 — 状態の葉と継続

各遷移の葉の定義の形を `LeafInputs_r → StateTyE P B σ Eb destination_r` とする。r は後の全76遷移表の規則であり、`destination_r` は **Semantics.lean のその構成子の結論に書かれた行先そのもの**である。σ/Eb は固定する。`LeafInputs_r` は次の実際の入口の証拠を束ねる。

- 元 StoreOk とソースの ClosureTy/ContTy、元状態の Closed/Adequate、規則の lookup/応答/空き場所。
- 呼出しなら、呼び出す値の種別に応じた **ソース側**の `DependentClosureTy`、`Def.WellTyped`、`ImplDecl.WellTyped.method_body`、`BuiltinArgs/ExternalArgs` と実引数の型付け。C_Sub 等をはがしてこれを得る一般逆転は L40。結論の型付き行先を入力へ含めない。
- 腕なら元 HasTypeArmsQ・AltsTy・Exhaustive・照合成功、節なら元 HasTypeClausesQ/HasFailureClause・分割した ContTy・型付きの操作の入力。行先のコードの型付けは S02/S06/S08 で作る。

これは L40 の canonical forms を先取りせず、L70 で一般のソース状態の逆転と合成できる葉の形である。`∀ Step, StateTyE → StateTyE` という全保存の証明を L20 で一度作って L70 で作り直す計画にはしない。各 LeafInputs の供給元と不足を .115 の一覧で照合し、L40 で供給できない独立前提が残れば完了にしない。

ContTy の逆転は10構成子を覆い、K_Sub で LeQ の導出を推移させる。`name_end/name_end_ix/mono_end/framesOk/drop_releases` 相当を新しい固定 σ と RangeIx に合わせる。StoreOk の finite/domain/WF/Sorted/Declared と Store.Closed と CellOk6形、ContTy の同じ b/Eb/Re を保存する。解放の進行は `CoreAssumptions.release_exists` の全資源値の量化を保ち、Ground/Adequate を存在の新しい前提にしない。step_sound 全体は L70。

### S11: 未固定の定義の項目 — 区間の normal/returned/failed

独立評価 `I/Eval.lean` の `EvalPartial/EvalBlock/EvalArms/EvalWidthArms/EvalResultArms` と Release の計算を結ぶ構文・値・環境の関係を定義し、Let/Return/腕の境界で `S/EvalResult.normal/returned/failed` の構成子を保つ。型付きの数値と `Const.toApprox` の元の値の一致は、七幅ごとに値そのものの等号を結論する補題を必要な葉で作る。既存 `constOK_toApprox` の存在だけを値一致へ読み替えない。

L20 は .118〜.121 で return/let/腕の束縛と戻り先の対応、.122 で failed の入力条件を固定し、L40 が arithmetic/δ と具体評価からの所属を証明、L70 が表層・交換へ合成する。J04 の候補は、解析の対象内で同じ入力・同じ評価・同じ失敗理由に対して `mayFail=true` が導ける範囲を明示する条件付きの補題である。`h : mayFail=true → ResultMem (.failed e)` の定義展開だけを健全性の証明にしない。対象外境界が許す任意の失敗について旧 NormalSoundness/WarningSoundness から failed 所属を導かない。条件を決めるために新しい主定理の前提や提供範囲を変える必要があれば J04 で停止する。

## G10: 適格な旧導出の全埋め込み

**r2のCの変更**: 以下の旧導出のCはList Release.TParamであり、targetのCはS12.5の`legacyTypeCtx C κ`とする。既存のDeclarationKindsとLegacyJudgmentのκから供給し、裸のconstraintsを新しい判断へ渡さない。下の`Cκ`はこの完全な式の略記である。

L10F当時の完全署名は [型検査済み契約](../l10/f/handoff.md)と [handoff.lean](../l10/f/handoff.lean)にある。r2は新判断のCを変えるので、それをそのまま新定義の型検査済み契約とは呼ばない。以下にtargetのCを替えた七署名を展開する。L20の該当単位はこれらの契約を実際の定理として証明する。ファイルの存在や Prop の型検査を証明の代わりにしない。

```lean
def embedHasTypeVQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValueInput K P0 B0 B Δ v →
      LegacyOutputInput K P0 B0 B (.value Δ.kinds Ψ Q C Γ v a) →
      Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a →
      ∀ Φ : List Pred, HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedVal v) (embedTy a)

def embedHasTypeVsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {ts : List Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.values Δ.kinds Ψ Q C Γ vs ts) →
      Benitoite.Release.HasTypeVsQ P0 B0 Ψ Q C Γ vs ts →
      ∀ Φ : List Pred, HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTys ts)

def embedHasTypeEachQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.each Δ.kinds Ψ Q C Γ vs a) →
      Benitoite.Release.HasTypeEachQ P0 B0 Ψ Q C Γ vs a →
      ∀ Φ : List Pred, HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTy a)

def embedHasTypeCQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyCompInput K P0 B0 B Δ m →
      LegacyOutputInput K P0 B0 B (.comp Δ.kinds Ψ Q C Γ R m a e L) →
      Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L →
      ∀ Φ : List Pred, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeArmsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {xs : List Benitoite.Release.Arm}
      {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyArmsInput K P0 B0 B Δ xs →
      LegacyOutputInput K P0 B0 B (.arms Δ.kinds Ψ Q C Γ R xs a b e L) →
      Benitoite.Release.HasTypeArmsQ P0 B0 Ψ Q C Γ R xs a b e L →
      ∀ Φ : List Pred, HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) none
        (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeClausesQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.clauses Δ.kinds Ψ Q C Γ R eb cs a e L) →
      Benitoite.Release.HasTypeClausesQ P0 B0 Ψ Q C Γ R eb cs a e L →
      ∀ Φ : List Pred, HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) (embedEff eb)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasFailureClause : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {E : Benitoite.Release.Ty} {R : Option Benitoite.Release.Ty}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.failure Δ.kinds Ψ Q C Γ E R cs a e L) →
      Benitoite.Release.HasFailureClause P0 B0 Ψ Q C Γ E R cs a e L →
      ∀ Φ : List Pred, HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C Δ.kinds)
        (Γ.map (Option.map embedTy)) Φ (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))
```

| 予定する定理 | 入力と結論（handoff の引数を省かず引き継ぐ） | 担当 |
|---|---|---|
| embedHasTypeVQ | K/Δ、K.WF、LegacyTables、LegacyContextInput、LegacyValueInput、value の LegacyOutputInput、旧 HasTypeVQ → **∀Φ** 新 HasTypeVQ。Ψ/Γ/v/a は埋め込み | .123/.129〜.134 |
| embedHasTypeVsQ | 同上で LegacyValuesInput、values の全 node、旧 HasTypeVsQ → ∀Φ 新 HasTypeVsQ、embedVals/embedTys | .135 |
| embedHasTypeEachQ | 同上で each の全 node、旧 HasTypeEachQ → ∀Φ 新 HasTypeEachQ | .135 |
| embedHasTypeCQ | LegacyCompInput、comp の全 node の Γ/R/a/e/L と旧 HasTypeCQ → ∀Φ 新 HasTypeCQ、R/L も写す | .136〜.140 |
| embedHasTypeArmsQ | LegacyArmsInput、arms の全 node と旧 HasTypeArmsQ → ∀Φ 新 HasTypeArmsQ、入口 obs=none | .141 |
| embedHasTypeClausesQ | LegacyClausesInput、clauses の全 node、eb/R/L と旧 HasTypeClausesQ → ∀Φ 新 HasTypeClausesQ | .142 |
| embedHasFailureClause | LegacyClausesInput、failure の全 node、E/R/L と旧 HasFailureClause → ∀Φ 新 HasFailureClause | .142 |
| embedPatTy/PatTys/AltsTy | K.WF/LegacyTables、κ/C/nv、入力型と全束縛型の LegacyNodeTypes、旧判断 → 新判断。PatTys の入力は as++δ | .125 |
| embedExhaustive | K.WF/LegacyTables、範囲深さ0の LegacyNodeTypes [a]、旧 Exhaustive → 新 Exhaustive。無条件の含意を要求しない | .126〜.128 |
| embedStateTyE | K.WF/LegacyTables/σ.Valid/LegacyStateInput/旧 StateTyE → 新 StateTyE、同じ embedEff Eb/embedState s | .144〜.147 |
| 三つの親判断 | 全 lookup の functionBodyInput/methodBodyInput/superBodyInput と宣言形成 → Def/Impl/Program の新しい条件 | .29/.148 |

七判断の主帰納は `LegacyOutputInput.node` の children の IH を任意 Φ で受ける。C_If の子は boolCond を足した Φ、lam/let/腕/節は liftMany の Φ、checkedRequest の保持内容は空 Φ へ直接特殊化する。空 Φ 版は系である。既存 weaken_conditions は ValueAssumptions と StoreTy.WF を要求するため埋め込みの経路に使わない。

C_Let/腕の旧 `LocalCtx.extend n []=[]` と新 `localExtend n []` の差は .124 の local_zero で閉じる。`LocalCtx.Shift.empty 0 c (localExtend n [])`、`shiftV_zero/shiftIndex_zero` を使い、非空 L の先頭 none と位置の移動も照合する。L10 の一般 shift_values の前提を LegacyTables に追加しない。

パターンの中間の δ は、C_Match の LegacyNodeRegular と腕の子の拡張Γから適格性を構成する。constructor の欄・arity・kind は LegacyTables、元の通常節の署名は `LegacyClausesInput.signature_wf`、範囲 S への opSigAt を使う。checkedAt/atError は旧像にない新 Inhabits の場合まで覆う。checkedAt の照合を checked/opaque へ、atError を同じ七文字列の At 構成子へ対応させる経路は L10 で未検証であり、.126/.127 で一般の入れ子まで証明する。範囲深さ0を外した旧 Exhaustive の含意の反例は `l10/f/rv-f-t2.lean` を保持する。

LegacyStateInput は本番で未定義である。.144 で**旧状態の型付けの証拠を伴う、入力の構造検査**として定義する。状態4形、frame7形、cell6形の全コードと保持値を再帰的に検査し、各コードの LegacyOutputInput、各中間型/Γ/R/L/kind/数値の表現可能性、同じ対象/要求/端点、型注釈の閉性と Adequate の供給条件を持つ。新 StateTyE/新 HasType/新 Step/行先の等号を欄にしない。有限ストアの各セルで検査を全称化し、保存継続のコードは旧 ContTy の構造へ下降する。循環するストアを値の展開で無限に辿らない。

三親判断では、関数は `Qsig d.params d.ret d.eff`、メソッドは代入前の `Qsig ms.params ms.ret ms.eff`、新判断の型文脈は `ms.tparams ++ TypeCtx.values id.tparams`（旧sourceの列は`ms.tparams++id.tparams`）、値文脈は辞書の後に実引数、上位辞書は空 Q/R の値判断である。SourceScoped は旧型付けから自動では得られないので宣言入力として明示する。利用者がソースに書けない checked 等を持つ旧本体を、適格なソース本体と混同しない。

L70 に残すのは新主定理、表層checker/脱糖、同じ篩付き a/e、消去、交換、旧読者の切替である。旧 E_Fun 等は instantiate、新は Capture を延長した Closure へ進み、embedState と行先が一致しないため **embedStep は撤回済み**である。新たな LegacyRuntimeRelation の信頼欄で一般の実行の模倣を仮定しない。

S00 の新しい Ψ.Sorted は、旧の場所型の各像へ `LegacyValues.lean` の `embedTy_sorted/embedEff_sorted` を適用して得る。.146 の旧全ストアの埋め込みの完了条件に、この4場所種の射影を含める。旧導出の適格性の入力へ新しい型付けの結論や独立の Sorted の信頼欄を追加しない。

## 全文脈変更の棚卸し

数え方を三つに分ける。第一は相互判断の構成子（14判断76）、第二は子の判断へ Γ/Φ/C/R/Ψ/L 又は依存列を変更して入る位置、第三は実行の Step76 である。同じ76という数を相互の別の集合の件数として区別する。四本304枝は既済みであり、以下の表を新規304証明の予算にしない。

### 子の文脈又は依存列が変わる位置

同じ規則で子が二つ変わる場合は2と数える。C_Match の obs の共有と C_Handle/Fail の eb の共有は、Γ/Φ の変更数に足さず後の全規則表で照合する。型・行置換の入力像を値束縛下へ lift する位置もこの表に含める。

| 規則（Typing.lean） | 子の位置数 | 変えるもの | 補題・単位 |
|---|---:|---|---|
| V_Lam | 1 | hideBuilders Ψ、hideConts Γ、bindParams ps、liftMany Φ、R/結果/効果の shift、L=[] | S02/S05、.38/.39〜.41/.72〜.73 |
| V_DependentLam | 1 | hideBuilders Ψ、hideConts Γ、TelBody | S02/S05、.39〜.41/.72〜.73 |
| V_Closure | 1 | 閉じた実行の DependentClosureTy と外の Γ/Φ の分離 | S02/S05、.55〜.60/.72〜.73 |
| V_CheckedRequest | 1 | req の Q/C/Γ/Φ をすべて空へ | 既存保持要求、.42〜.45/.74〜.77 |
| V_CheckedAt | 1 | Q/C/Γ/Φ を持たない閉じた CheckedWitness への子 | S02/S05、.42〜.45/.55〜.60/.74〜.77 |
| CheckedWitness.request | 1 | 同上 | 既存 Witness、.55〜.60/.74〜.77 |
| C_BuilderLet | 1 | Γ.extendNone、Φ.lift、R/a/e の shift、LocalCtx.extend some kind | S02/S04、.38/.46〜.51/.69〜.70/.110 |
| C_Let | 1 | Γ.extend a、Φ.lift、R/b/e の shift、localExtend 1 L | S02/S04/S06、.38/.46〜.51/.82 |
| C_If | 2 | true/false の boolCond::Φ | Entails.conditions_cons、.46〜.51/.74〜.77/.115 |
| C_Lazy | 1 | hideBuilders Ψ、hideConts Γ、R=none、L=[] | S04/S05、.46〜.51/.64/.113 |
| C_External | 1 | Tel.bind (typeEnv ts) d.parameters という具体化した依存列 | S02/S06、.46〜.51/.55〜.60 |
| C_Meth | 1 | Tel.arguments の結果 as を読む HasTypeVsQ ws as | S02/S06、.46〜.51/.83 |
| HasTypeTelArgsQ.param | 1 | rest を Tel.argumentsEnv v で具体化 | S02/S06、.32/.55〜.60/.80 |
| TelBodyTy.param | 1 | Γ.extend a、Φ.lift、値深さ+1 | S02/S06、.38/.55〜.60/.81 |
| CaptureOk.mk | 1 | 有限 cap の像を空 Γ/Φ で検査、元の facts を閉じる | S01/S05、.04〜.07/.55〜.60/.66〜.68 |
| DependentClosureTy.mk | 2 | capture と TelBody の hideBuilders、hideConts Γ、R=none | S02/S05、.55〜.60/.64/.72〜.73 |
| HasTypeArmsQ.plain | 2 | 本体は bindParams δ/liftMany、後続腕は excludedFacts++Φ | S02/S08、.52〜.54/.97/.98 |
| HasTypeArmsQ.guarded | 2 | guard の hideConts/R=none、本体の真の p。元 Φ のままの後続は0 | S02/S08、.52〜.54/.97/.99 |
| HasTypeClausesQ.cons | 1 | C=sg.tparams++C、sg.context、n+1値束縛、型 k と値 n+1 の shift、hideBuilders、L=[] | S02/S10、.38/.52〜.54/.102 |
| HasFailureClause.one | 1 | TypeCtx.valueParamによる型+1、failureContext の値+2、liftMany 2、hideBuilders、L=[] | S02/S10、.38/.52〜.54/.104 |
| ImageOk.ordinary | 1 | ソース a を型付きの像の Δ/Ξ へ | S01/S02、.04〜.07/.55〜.60/.66〜.68 |
| ClosureTy.mk（14判断の外） | 3 | capture、bindParams Γ ss と閉じた出力文脈、局所参照ρ、closeRAt | S01/S06、.66〜.68/.79〜.84 |
| GuardBodyTy.mk（14判断の外） | 3 | capture、真の p.open true::Φ の body、cap で閉じた結果文脈・局所参照 | S01/S08/S10、.66〜.68/.99 |
| **合計** | **31** | 14判断の内25位置＋ClosureTyの3＋GuardBodyTyの3 | 同じ操作の補題を共有 |

ImageOk.contVarは子の判断を持たないため位置数0。S02_ImageはTrueにするので型置換のcaseはtrivialとし、像とΔ[j]の等号の照合は捕捉の使用先とq_monoへ残す。後続の文脈が同じ guarded/Clauses.cons は0、excluded facts が増える plain の後続は1と数える。値を増やさない `use` は nv を増やさない。通常節 n+1 と Fail の型1・値2、メソッドの辞書→引数の順を取り違えない。Regular の保存は .65 で hideConts/bindParams/extendNone/shiftE/OpSig.context/failureContext を一つの表で閉じる。narrowing は既存の各補題と Ordered の供給を照合し、型の入れ替えだけで参照順序を証明したことにしない。


### 相互14判断と部分型四族の全規則

表の全76構成子に対して、既存の四本304枝は継承、S02 の型置換は一度の相互族で閉じる。文脈を変えない規則も V_Sub/C_Sub/C_Eff/Normal/Refine を含めて残す。下表の単位は新しい型置換の担当である。G04 の結果形成と G09 の意味移送は同じ定義を読む別の命題であり、型付け規則を作り直さない。

| 判断 | 場合数と全構成子 | S02 の担当 |
|---|---|---|
| `HasTypeVQ` | 29：`V_Var`、`V_Const`、`V_Lam`、`V_DependentLam`、`V_Closure`、`V_Fun`、`V_Prim`、`V_Op`、`V_ExternalRef`、`V_ExternalHandle`、`V_PathBases`、`V_ScopePattern`、`V_Checked`、`V_CheckedRequest`、`V_CheckedAt`、`V_AtError`、`V_Map`、`V_Set`、`V_Dict`、`V_Raise`、`V_LocRef`、`V_LocLazy`、`V_Bytes`、`V_Con`、`V_Super`、`V_List`、`V_Sub`、`V_Normal`、`V_Refine` | L20.39〜.45 |
| `HasTypeVsQ` | 2：`nil`、`cons` | L20.55〜.60 |
| `HasTypeEachQ` | 2：`nil`、`cons` | L20.55〜.60 |
| `HasTypeCQ` | 24：`C_BuilderLet`、`C_BuilderOp`、`C_Return`、`C_Let`、`C_App`、`C_DependentApp`、`C_If`、`C_Match`、`C_Lazy`、`C_Escape`、`C_Use`、`C_Handle`、`C_Handle_Fail`、`C_Resume`、`C_ResumeL`、`C_ResumeNorm`、`C_ResumeLNorm`、`C_Normal`、`C_Meth`、`C_External`、`C_IssuePathBases`、`C_CheckAt`、`C_Sub`、`C_Eff` | L20.46〜.51 |
| `HasTypeTelArgsQ` | 2：`done`、`param` | L20.55〜.60 |
| `TelBodyTy` | 2：`done`、`param` | L20.55〜.60 |
| `CaptureOk` | 1：`mk` | L20.55〜.60 |
| `DependentClosureTy` | 1：`mk` | L20.55〜.60 |
| `CheckedWitness` | 2：`plain`、`request` | L20.55〜.60 |
| `AtCallAdmissible` | 1：`mk` | L20.55〜.60 |
| `HasTypeArmsQ` | 3：`nil`、`plain`、`guarded` | L20.52〜.54 |
| `HasTypeClausesQ` | 2：`nil`、`cons` | L20.52〜.54 |
| `HasFailureClause` | 1：`one` | L20.52〜.54 |
| `ImageOk` | 4：`ordinary`、`hidden`、`contLoc`、`contVar` | L20.55〜.60 |

| 部分型の族 | 場合数と全規則 | L20 の使用先 |
|---|---|---|
| `Ty.LeQ` | 14：`refl`、`convert`、`trans`、`fn_effect`、`list`、`lazy`、`map_value`、`forget`、`introduce`、`refine`、`dependentFn`、`scoped`、`scoped_forget`、`data` | .30〜.60 は既存の bind/subst を使用、.85〜.88 は意味移送を一度証明 |
| `TelLe` | 2：`done`、`param` | .30〜.60 は既存の bind/subst を使用、.85〜.88 は意味移送を一度証明 |
| `TelClosure` | 2：`refl`、`tail` | .30〜.60 は既存の bind/subst を使用、.85〜.88 は意味移送を一度証明 |
| `TypeArgsLe` | 4：`nil`、`covariant_cons`、`contravariant_cons`、`invariant_cons` | .30〜.60 は既存の bind/subst を使用、.85〜.88 は意味移送を一度証明 |

部分型は14+2+2+4=22規則である。Eff.Covers/Sub はこの22規則に含まれず既存 EffectCover の証明を使用する。

### 継続・セル・状態で変える文脈

| 対象 | 全場合と変えるもの | 担当 |
|---|---|---|
| ContTy（10） | K_Empty：末尾被覆／K_Let：入力1・Rのshift・ClosureTy／K_Mark：R=some／K_Update：R=noneとlazy型／K_Release：資源値とState／K_Handle：capture・hideBuilders・eb/ec／K_Handle_Fail：型E・NoFail・capture／K_Drop：保存継続のStateの含意／K_Guard：観測・腕・真の本体・R=none／K_Sub：入力LeQ | .82/.100〜.109/.112。K_Sub を各逆転で閉じる |
| Frame（7） | letF/mark/update/release/handleF/drop/guardF。letFの入力1、handleF/guardFのcap・コード・局所参照、releaseの保持値 | .110〜.116/.145 |
| Cell（6） | builder/val/thunk/done/cont/used。型を増やすのはallocateだけ、書換えは同じ場所型、usedも型を消さない | .110/.111/.113/.146 |
| State（4） | run/matchRun/error/exit。同じσ/Eb、StoreOkとContTyを保つ。matchRunはMatchPrefix・Ground・armsの捕捉を保持 | .115/.147 |
| ストアの操作（5） | freshなbuilder/ref/lazy/contの4種の追加と、既存型を保つ書換え1種（builder/val/done/used） | .110/.111/.103/.105/.113。型と内容の移送を分離 |
| 実行の関数と本体（3親） | functionBody/methodBody/superBody。型文脈・辞書・Q・Rを先のG10契約に合わせる | .29/.83/.148 |

### 全76遷移の葉の分担

全 Step 構成子を下表に一度ずつ置く。葉は S10 の入力分解を受け取り、開始状態からの全逆転は L40、全保存/進行/step_sound の合成は L70 に残す。現行 Step/step に場合を追加する計画はない。σを変更する遷移は0である。

| 規則群 | 件数と全規則名 | 葉の単位／他段との境界 |
|---|---|---|
| builder | 3：`E_BuilderNew`、`E_BuilderOp`、`E_BuilderErr` | .110。内容の型と上限、局所kind |
| 呼出し | 4：`E_Lam`、`E_Fun`、`E_Meth`、`E_Super` | .83/.84。値の種別の逆転はL40 |
| At・PathBases・external | 8：`E_ExternalApply`、`E_External`、`E_ExternalErr`、`E_PathBasesApply`、`E_IssuePathBases`、`E_AtOk`、`E_AtError`、`E_AtPrepareError` | .114。準備・対象・応答の葉はL50/L60 |
| 分岐・照合 | 10：`E_IfT`、`E_IfF`、`E_Match`、`E_MatchSkip`、`E_MatchBody`、`E_MatchGuard`、`E_GuardT`、`E_GuardF`、`E_ErrPopGuard`、`E_ExitPopGuard` | .98/.99/.115。true/false/unknownのfacts |
| δ・IO | 5：`E_Prim`、`E_Err`、`E_IO`、`E_IOErr`、`E_Exit` | .114。具体の正常結果・対象・存在はL40/L50 |
| Reference | 4：`E_RefNew`、`E_RefGet`、`E_RefSet`、`E_RefUpdate` | .113。既存の四葉をS05へ合成 |
| Lazy | 6：`E_Lazy`、`E_ForceDone`、`E_Force`、`E_Update`、`E_ErrPopUpdate`、`E_ExitPopUpdate` | .113。thunk/done双方、R=none |
| use・解放 | 9：`E_Use`、`E_Release`、`E_RelErr`、`E_EscRel`、`E_EscRelErr`、`E_ErrRel`、`E_ErrRelErr`、`E_ExitRel`、`E_ExitRelErr` | .108。解放の存在は既存release_exists |
| handler・操作 | 17：`E_Handle`、`E_HRet`、`E_Op`、`E_OpFail`、`E_OpPrim`、`E_Resume`、`E_ResumeErr`、`E_Drop`、`E_DropRel`、`E_EscDrop`、`E_EscDropRel`、`E_ErrDrop`、`E_ErrDropRel`、`E_ExitDrop`、`E_ExitDropRel`、`E_ErrPopHandle`、`E_ExitPopHandle` | .100〜.109。多相/辞書/used/Stateの全場合 |
| let・戻り先・残るpop | 10：`E_Let`、`E_Return`、`E_Mark`、`E_EscLet`、`E_EscHandle`、`E_EscMark`、`E_ErrPopLet`、`E_ErrPopMark`、`E_ExitPopLet`、`E_ExitPopMark` | .82/.115。同じ結果契約とR/Eb |

照合は 3+4+8+10+5+4+6+9+17+10=76。上表の全規則の集合は Semantics.Step の構成子集合と一致する。step の選択の存在と応答関係の適合は .116 の葉へ渡し、全 step_sound の完了とは呼ばない。

## S12: kind を C の要素に持たせる案4（第一の案・見直しの対象）

取りまとめの r2 の判断に従い、C を `List TParamDecl` に改める案4を第一にする。14判断の引数の個数を増やさず、型パラメータの宣言の kind と constraints を同じ位置から読む。既存の主定理の言明の字面は変えず、Program.WellTyped/HasType 等が読む C と署名の中身を変更する。定義・言明・仮定のレビューで見直す対象であり、本計画担当は formal を変更していない。

### S12.1: C と TypeArgsKinded の完全な定義

`R/Types.lean` の既存 `TParamDecl`（constraints と kind）を使う。値型の既定の宣言は既存 `embedTParam` と同じである。

```lean
abbrev TypeCtx := List TParamDecl
namespace TypeCtx
  def constraints (C : TypeCtx) : List Benitoite.Release.TParam :=
    C.map TParamDecl.constraints
  def kinds (C : TypeCtx) : KindCtx := C.map TParamDecl.kind
  def values (ps : List Benitoite.Release.TParam) : TypeCtx := ps.map embedTParam
  def valueParam : TParamDecl := ⟨{}, .value⟩
end TypeCtx

def TypeArgsKinded (P : Program) (C : TypeCtx)
    (ts : List Ty) (ks : List TyKind) : Prop :=
  ts.length = ks.length ∧ ∀ (i : Nat) (a : Ty) (k : TyKind),
    ts[i]? = some a → ks[i]? = some k →
      a.HasKind P (TypeCtx.kinds C) k ∧ (k = .value → Ordinary a)
```

r3の短い入力で`d.tparams.kinds`はList.kindsがなく失敗し、`TypeCtx.kinds d.tparams`は成功した。以下はリストの式でも同じ名前解決になるよう、kind/constraintsの射影を明示した関数適用へ統一する。

新定義は既存 `Context/Declarations.lean` の `TypeArgsKindedAt` の式と同じである。At は新 TypeArgsKinded の別名として残す。`TypeArgsKindedAt.forget` は恒等になる。存在量化した K を返す互換の結論は残さない。型の形成の C、CaptureDeclared、SubstOk、ContextMap 等も TypeCtx に改める。`Ty.WF` の Nat の深さは C.length のまま、Pred/Γ/Φ の操作は変えない。

短い補助入力で、constructor と宣言した tvar を value の位置へ渡す場合と、その逆を新定義が拒否し、正しい value/constructor の tvar と bytes/ctor list の像を受けることを確認した。これは14判断の全移行又は S02 の本体の証明ではない。

### S12.2: constraints の射影と署名

`Builtins.sat` と `PrimSig.admits` のデータの型は、旧と共有する生の constraints の列のままにする。kind を捨てる箇所はこの二つへ渡す射影に限り、型付けの C 自体を constraints に戻さない。

```lean
-- Builtins/PrimSig の既存の二欄は型を維持する。
Builtins.sat : List Benitoite.Release.TParam → Ty → Benitoite.Release.TParam → Prop
PrimSig.admits : List Benitoite.Release.TParam → List Ty → Prop

def SatAll (B : Builtins) (C : TypeCtx) (ts : List Ty)
    (ps : List Benitoite.Release.TParam) : Prop :=
  ts.length = ps.length ∧ ∀ (i : Nat) (t : Ty) (p : Benitoite.Release.TParam),
    ts[i]? = some t → ps[i]? = some p → B.sat (TypeCtx.constraints C) t.norm p

structure Admissible (B : Builtins) (C : TypeCtx) (nv : Nat)
    (ps : List Benitoite.Release.TParam) (ne : Nat) (Qs Qt : NoFailCtx)
    (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : SatAll B C ts ps
  typeScope : ∀ t ∈ ts, Ty.WF 0 C.length nv t ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, Eff.WF 0 C.length nv f
  sourceRows : Eff.RowsIn (· < es.length) e
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Qt es
```

PrimitiveAdmissible の admits は `s.admits (TypeCtx.constraints C) (Ty.normTys ts)`、その typeScope/rowScope は C.length。MethodRowsAdmissible は C:TypeCtx、式は従来どおり。SignatureInstance の types/rows/result は新 C を読む Annotation、kinds は S12.1 の固定した (TypeCtx.kinds C) とする。行像の固定した条件はS12.8に記す。

制約を読む全使用先の書換えは `B.sat C … → B.sat (TypeCtx.constraints C) …`、`sg.admits C … → sg.admits (TypeCtx.constraints C) …` とする。ValueAssumptions/TypeAssumptions/CoreAssumptions の束の名前と欄の個数は増やさない。各欄で型付けと Annotation が読む C は TypeCtx、sat/admits の実引数だけ constraints にする。`sat_subst` は `SatAll B C1 ts (TypeCtx.constraints C0)`、`sat_unconstrained` は閉じた C=[] なので従来の字面のままである。新しい sat/admits 保存則は追加しない。

### S12.3: 宣言・失敗節・実装の C

| 定義・使用先 | 新しい C と constraints の読み方 |
|---|---|
| Def.WellTyped/Def.Scoped | C=`d.tparams`。HasKind は `(TypeCtx.kinds d.tparams)`、TelBodyTy/Annotation は同じ C。Admissible/SatAll の相手は `(TypeCtx.constraints d.tparams)` |
| MethSig.Scoped | C=`ms.tparams ++ [⟨{}, argumentKind⟩]`。SignatureScoped の別引数 K は (TypeCtx.kinds C) に統合する |
| ImplDecl.WellTyped/method_body | `C := ms.tparams ++ TypeCtx.values id.tparams`。辞書の型は従来の shift 後の列、Q は代入前 QTel/Qsig を保つ |
| ImplDecl の target/dictTys/super | C=`TypeCtx.values id.tparams`、kind 文脈は replicate .value。既存の value 限定を維持する |
| OpDecl/通常節 | 利用者操作は `TypeCtx.values od.tparams`。`OpSig.tparams` は TypeCtx に変更し、user はこの列、prim は `s.tparams` をそのまま保持する。従来の `map constraints` による primitive kind の消失を残さない |
| ExternalSignature | 格納欄 `tparams : List TParam` と `kinds : KindCtx` は維持。呼出し元の C は TypeCtx。SatAll の相手は既存 d.tparams、SignatureInstance の期待 kind は d.kinds。宣言自体は既存の monomorphic 条件を保つ |
| HasFailureClause.one | `TypeCtx.valueParam :: C`。他の型束縛も実際の TParamDecl を接頭辞にする。fresh T の kind は .value に固定される |
| V_Raise | 既存の Annotation/Ordinary 二つに加え、**結果型 T の** `T.HasKind P (TypeCtx.kinds C) .value` を最後の前提に加える。エラー型 E に新しい kind 前提は加えない。型像として代入するのは T だけである |

現行 Lean の名前は `ImplDecl` であり、`InstanceDecl` という型はない。依頼の実装宣言はこの ImplDecl として点検した。id.tparams の kind は任意に推論し直さず、L10の固定した「操作・implの型パラメータはvalue」を出どころにする（l10/detail のkind表の説明、LegacyInput の dict の入力）。Rust の型パラメータからこの形式化の範囲への照合は L70/R10b のままであり、案4に便乗して impl の範囲を拡張しない。

`E_OpFail` の実型 T の kind は **V_Raise 側で保持**する。失敗節の側は fresh T を .value と宣言して本体を検査する。閉じた raise の T の新前提から `TypeArgsKinded P [] [T] [.value]` を得て、通常の S02 の同じ入口へ渡す。`sat_unconstrained` は従来の WF から SatAll の constraints を供給する。r1 の「Fail 用の別入口」「fresh な T の出現条件で補う」は撤回する。裸の ctor を T に持つ旧 V_Raise の例は新定義で拒否する。

完全な宣言側の定義の形を次に固定する。`ConDecl`のvalue型束縛もrich Cへ統一し、constructor位置のkindを新しく選ばない。

```lean
def SignatureScoped (P : Program) (C : TypeCtx) (ne : Nat) (t : Tel) : Prop :=
  (Ty.dependentFn t).SourceScoped 0 C.length ne 0 ∧ t.RowsIn (· < ne) ∧
    Ty.HasKind P (TypeCtx.kinds C) (.dependentFn t) .value ∧ Ty.Annotation P C [] (.dependentFn t)

def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (TypeCtx.kinds d.tparams) (.dependentFn d.tel) .value ∧
  Ty.Annotation P d.tparams [] (.dependentFn d.tel) ∧
  TelBodyTy P B StoreTy.empty (QTel d.tel) d.tparams [] [] d.tel d.body

def Def.Scoped (P : Program) (d : Def) : Prop :=
  NamesWF d.names d.params ∧ SignatureScoped P d.tparams d.neffs d.tel ∧
    d.body.SourceScoped 0 d.ntys d.neffs d.params.length

def MethSig.Scoped (P : Program) (argumentKind : TyKind) (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    SignatureScoped P (ms.tparams ++ [⟨{}, argumentKind⟩]) ms.neffs ms.tel

def ConDecl.Scoped (P : Program) (cd : ConDecl) : Prop :=
  ∀ a ∈ cd.args, a.SourceScoped 0 cd.ntys 0 0 ∧
    Ty.Annotation P (List.replicate cd.ntys TypeCtx.valueParam) [] a ∧
    a.HasKind P (List.replicate cd.ntys .value) .value

def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (TypeCtx.kinds (TypeCtx.values id.tparams)) id.target cd.argumentKind ∧
    TypeAnnotations P (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams ++ TypeCtx.values id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty (TypeCtx.values id.tparams) (bindParams [] id.dictTys) []
        u (.dict s id.target))
```

`ImplDecl.Scoped`のtarget/dictTysのAnnotationも`TypeCtx.values id.tparams`を使い、残りのSourceScoped・dictionary位置・bodyの深さの式は変えない。`OpDecl.Scoped`は`SignatureScoped P (TypeCtx.values od.tparams) 0 od.tel`。`OpSig`は`tparams : TypeCtx`、残るnames/params/ret/effの型と順序は現行どおり、`opSigAt.user`は`TypeCtx.values d.tparams`、`opSigAt.prim`は`s.tparams`を格納する。`HasTypeClausesQ.cons`のCは`sg.tparams ++ C`、`HasFailureClause.one`は`TypeCtx.valueParam :: C`である。`InstanceDecl`を新設しない。

`V_Raise`の完全な形は、現行の三前提を保って次とする。

```lean
| V_Raise {Ψ Q C Γ Φ T E} :
    Ty.Annotation P C Γ (.fn ["error"] [E] T (Eff.singleFail E)) →
    Ordinary T → Ordinary E → T.HasKind P (TypeCtx.kinds C) .value →
    HasTypeVQ P B Ψ Q C Γ Φ (.raise T E) (.fn ["error"] [E] T (Eff.singleFail E))
```

### S12.4: 改名と既存四移送

Declaredの型shiftがkindの照合を使うので、KindRenamingとrawRenameTypesList_lengthはTypeShiftKindsから低いTypeRenamingへ、同じ名前・同じ式/証明のまま移す。TypeParamRenaming.kindRenamingもTypeRenamingへ置く。現在はTypeShiftKinds→TypeShiftContextなので、逆向きのimportを足すと循環するためである。二宣言の配置変更であり、意味の変更又は新しい再帰の族ではない。TypeShiftSyntaxが既にTypeRenamingをimportすることを読んで確認した。

```lean
def KindRenaming (K L : KindCtx) (ρ : Nat → Nat) : Prop :=
  ∀ (i : Nat) (ki : TyKind), K[i]? = some ki → L[ρ i]? = some ki

def TypeParamRenaming (C C' : TypeCtx) (ρ : Nat → Nat) : Prop :=
  ∀ (i : Nat) (p : TParamDecl), C[i]? = some p →
    ∃ q, C'[ρ i]? = some q ∧ q.kind = p.kind ∧
      TParam.Contains q.constraints p.constraints

TypeParamRenaming.kindRenaming : ∀ {C C' ρ},
  TypeParamRenaming C C' ρ → KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') ρ
TypeArgsKinded.shiftTypes : ∀ {P C C' ts ks k c},
  TypeArgsKinded P C ts ks → TypeParamRenaming C C' (shiftIndex k c) →
  TypeArgsKinded P C' (ts.map (shiftTypes k c)) ks
```

`TParam.Contains` は生の constraints の包含であり変更しない。実在する改名の名前は `TypeParamRenaming` である。id/prefix/under/suffix/insert の五つは、新しい kind の等号を同じ lookup から供給する。長さだけで別の K を作る `insertKinds` の経路は廃止する。値の shift/subst/narrowing は C を変えないため、HasKind の既存の shift_values/bind_values を使える。型の shift は `kindRenaming` と既存 `Ty.HasKind.renameTypes` を使う。

r2では四移送の12枝を特定したが、Declaredのheadのkindを保つため型shiftのDeclared/Annotation読者へ既存hCを渡す必要がある。S12.11の全名表では型shift36枝、他の三移送のV_Raise各1で、**四移送304枝中39枝、残265枝**である。39にはr2の12枝を含み、新たな27枝を追加計上する。新しい14判断の引数を増やさず、既存のTypeParamRenamingから供給する。全本番コンパイルは未確認で、39を上限としない。

四移送の外では、ClosedCapture/TypingDeclared/LazyPreservation/TypeArgumentRegularity の V_Raise の明示した引数の並びを4枝追随する。`..` の枝を新しい証明の作成件数へ数えない。基盤では TypeArgsKinded の ordinary/shift/subst/norm/shiftTypes の5、SignatureInstanceの構成9、TypeParamRenamingの五包装、TypeArgsKindedAt.forget、LegacyKindArgs.kindedの計21宣言を追随対象とする。SignatureInstance の9構成は ShiftMap.signature、TypeCtxMap.signature、TypedImages.signature、ContextMap.signature、norm_images、legacy_signatureInstance、関数/メソッドの二包装、SignatureInstanceAt.forgetである。SignatureInstanceAtのtypes/rows/resultもDをそのままCへ渡し、rowKindsを同じ式で追加する。forgetの結論はSignatureInstance P D Γ …へ改める。

### S12.5: G10 の旧 C の埋め込み

```lean
def legacyTypeCtx (C : List Benitoite.Release.TParam) (κ : KindCtx) : TypeCtx :=
  embedTParamsWithKinds C κ
legacyTypeCtx_constraints : ∀ {C κ}, κ.length = C.length →
  (TypeCtx.constraints (legacyTypeCtx C κ)) = C
legacyTypeCtx_kinds : ∀ {C κ}, κ.length = C.length →
  (TypeCtx.kinds (legacyTypeCtx C κ)) = κ
```

既存 `embedTParamsWithKinds_constraints/kinds` を使う。旧七判断の source の C は変更せず、target を `legacyTypeCtx C κ` に替える。κ は各 LegacyJudgment が既に持つ列で、入口の関数は DeclarationKinds.functionParams、メソッドは methodParams と既存の value の実装パラメータ、クラスの引数は classArgument から供給する。Fail は `.value :: κ`、通常節は実際の宣言の kind の接頭辞を加える。実装と user 操作へ新しい DeclarationKinds の設定は足さない。

`LegacyKindArgs.kinded` の長さだけの引数は不十分になるため、target の C を上の legacyTypeCtx と固定するか、`(TypeCtx.kinds C)=κ` の等号を受ける。等号は上の既存の補題から導く。新しい独立の kind 入力を LegacyOutputInput に足さない。LegacyTypeInput の Declared の使用、LegacyTypeInput.annotation/annotation_at/annotation_normal、LegacyKindArgs.kinded、legacy_signatureInstance と関数/メソッドの二包装の8定義・宣言と、S12.11のcontext三宣言を合わせた**11橋**を追随する。LegacyRowsInput は各行の fn 型について既に value kind を持つので、S12.8 の rowKinds もここから供給する。

L10の handoff は当時の署名の記録として保持し、L20.123 が `LegacyTyping.lean` の骨格に七つの完全署名を Cκ で展開して固定する。旧 Release の定義・主定理を変えず、新旧 import を保つ。

### S12.6: 明示した型注記の全出現と案1との比較

依頼の71箇所を検索の目安にしたが、現行 `R/` に対する単語境界付きの `List TParam` の全検索は **75行・76出現**である（AdmissibleのSatAllの行にCとpsの2出現）。`List TParamDecl`の6出現（LegacyKinds.embedTParamsWithKinds、SyntaxのDef/MethSig/PrimSig、Context/DeclarationsのTypeArgsKindedAt/SignatureInstanceAt）は別集合であり、型自体の置換件数へ加えない。既存Atの射影とforgetは追随対象に数える。省略せず全76出現を次表に分類する。変更69、保持7であり、69のうち57は型注記・constraints射影の機械追随、12は固定kindの意味又は改名/旧contextの証拠を変える箇所である。

| ファイル（R/） | 全行番号（同じ行の二出現は二度記す） | 注記/射影の変更 | kindの意味/証拠の変更 | 保持 |
|---|---|---:|---:|---:|
| `Admissible.lean` | 16, 21, 24, 24（保持）, 79, 80（保持）, 90, 101, 109, 116 | 8 | 0 | 2 |
| `ConstraintAssumptions.lean` | 18, 27, 39, 46 | 4 | 0 | 0 |
| `Context/Declarations.lean` | 13 | 1 | 0 | 0 |
| `Context/Facts.lean` | 32 | 1 | 0 | 0 |
| `Context/WF.lean` | 208, 214 | 2 | 0 | 0 |
| `Declared.lean` | 38, 44, 53, 56, 65, 79, 93, 96, 99 | 8 | 1 | 0 |
| `DeclaredTransport.lean` | 91, 275, 373 | 3 | 0 | 0 |
| `External.lean` | 124 | 1 | 0 | 0 |
| `HandlerContracts.lean` | 13 | 0 | 1 | 0 |
| `KindValues.lean` | 153 | 0 | 1 | 0 |
| `LegacyValues.lean` | 8, 81, 87, 91 | 1 | 3 | 0 |
| `Narrowing.lean` | 95, 144, 328, 659 | 4 | 0 | 0 |
| `PathFacts.lean` | 32, 37 | 2 | 0 | 0 |
| `ProgramWellFormed.lean` | 104 | 1 | 0 | 0 |
| `SubstTyping.lean` | 19, 743, 806, 961 | 4 | 0 | 0 |
| `SubstitutionContracts.lean` | 8, 48 | 2 | 0 | 0 |
| `Syntax.lean` | 109（保持）, 252（保持）, 312（保持）, 386（保持）, 414（保持） | 0 | 0 | 5 |
| `TypeRenaming.lean` | 46, 49, 52, 61, 72, 80 | 0 | 6 | 0 |
| `Typing.lean` | 119, 148, 255, 261, 267, 371, 381, 422, 435, 461, 475, 485, 555 | 13 | 0 | 0 |
| `TypingDeclared.lean` | 13 | 1 | 0 | 0 |
| `VarianceValidation.lean` | 52 | 1 | 0 | 0 |
| 合計 | 75行・76出現 | 57 | 12 | 7 |

「変更」は全ての行の証明を組み直すという意味ではない。Declared.tappと旧contextの三宣言は今回kindの照合を加えるため、元の機械追随から意味/証拠の変更へ分類を移した。注記/射影だけの部分と区別し、NatのWF/支持/正規化は再帰の形を保つ。上の明示注記の外にも暗黙の C の読者があるので、既定buildと全使用先の照合を必要とする。Legacyの追加11橋、ProgramTyping/Scopedの3種の親判断、四移送の39枝、V_Raiseの外側4枝、r2の基盤21宣言とDeclaredのshift補助7署名/旧context3署名を別に名指しした。

| 案 | Cの引数の変更 | 固有の再帰の仕事 | 共通して必要な仕事 | 判断 |
|---|---|---|---|---|
| 案4 | 引数の個数は同じ。上記69注記をTypeCtxへ | 四移送の局所39枝、外のarity4。新しい76場合の本体kind族は0 | S12.7のkind像47枝、S02全76枝とtapp形成、V_RaiseとFailの接続、行像のkindの供給 | 第一。既存の同じrecursorを保てる見込み。全体で未確認 |
| 案1 | Cは生のconstraintsのまま | 宣言のKを固定して本体を読む新しい76場合の族、S02の入力と全76caseへの接続。四移送のkind検査の保持も必要 | 左と同じ。案4固有の69型注記の変更は不要 | 現時点では新しい族を追加する方が大きい。案4が大きいと判明した時の戻り先 |

型注記の文字置換69を、新しい証明の76枝と同じ単価で比較しない。新Declaredの固定後も固有の移送の手修正は39枝の見込みで、案1の新しい76場合の族より大きいという根拠を得ていないため、案4を維持する。全304枝の作り直し又は案4に固有の手修正が76枝を上回ると判明した場合は、数字を添えて案1を第一へ替え、取りまとめへ返す。

r3ではDeclaredの修正とrowKindsも切替の時間へ含める。対象はL20.08〜.14/.16〜.18（C/射影/宣言/改名、Declaredの値・型移送と型置換、rowKinds、既存移送）。所要時間（能動時間）**8時間15分〜21時間20分**、上端の2倍は**42時間40分**である。r2の21時間20分を置き換える。超過時は原因と案1との比較を報告し、buildが通る区切りで停止する。HasKindの共通47枝と本体の関門は合計の見込みには含めるが、この定義/追随の切替時間へ二重加算しない。独立のkindの前提で案4を延命しない。

### S12.7: kind の像の完全署名と ClosedTypeSubstInput

```lean
Ty.HasKind.closed_context : ∀ {P K K' a k nr nv},
  a.WF nr 0 nv → a.HasKind P K k → a.HasKind P K' k
kindsEff.closed_context : ∀ {P K K' e nr nv},
  e.WF nr 0 nv → kindsEff P K e → kindsEff P K' e
Ty.HasKind.substAt : ∀ {P C0 C1 a k ts es},
  a.HasKind P (TypeCtx.kinds (C1 ++ C0)) k →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) →
  (a.substAt C1.length ts es).HasKind P (TypeCtx.kinds C1) k
Tel.kinded_substAt : ∀ {P C0 C1 t ts es},
  kindsTel P (TypeCtx.kinds (C1 ++ C0)) t → TypeArgsKinded P [] ts (TypeCtx.kinds C0) →
  (∀ e ∈ es, kindsEff P [] e) → kindsTel P (TypeCtx.kinds C1) (t.substAt C1.length ts es)
TypeArgsKinded.substAt : ∀ {P C0 C1 as ks ts es},
  TypeArgsKinded P (C1 ++ C0) as ks →
  TypeArgsKinded P [] ts (TypeCtx.kinds C0) → (∀ e ∈ es, kindsEff P [] e) →
  TypeArgsKinded P C1 (as.map (Ty.substAt C1.length ts es)) ks
```

Ty/Tel/List/Effの4族26構文形、Tyでconstructor/valueを分ける47枝を一つの共通族として証明する予定である。型引数の列の長さはTypeArgsKindedの第一射影、像のkindは固定した(TypeCtx.kinds C0)から取る。constructor位置の像はHasKind.constructor_shapeでctor又は同じkindのtvarに限定できる。閉じたWF000を併用すれば自由なtvar像は除ける。HasKindの`.tapp`ではこの像と引数のvalue kindを使う。Annotationの形成ではsourceのHasKindを要求せず、S12.11のDeclaredのheadのkindと引数のAnnotationをProperApplyへ渡す。任意のrawApplyの既定枝を適格性の証拠にしない。

新 `ClosedTypeSubstInput` の形は次とする。Qの移送は公開署名で別に受ける。ここに型付けの結論は入れない。

```lean
structure ClosedTypeSubstInput (P : Program) (B : Builtins)
    (C0 C1 : TypeCtx) (Γ : Ctx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = C0.length
  typeWF : ∀ t ∈ ts, t.WF 0 0 0
  typeKinds : TypeArgsKinded P [] ts (TypeCtx.kinds C0)
  typeAnnotations : TypeAnnotations P [] [] ts
  constraints : SatAll B C1 ts (TypeCtx.constraints C0)
  rowWF : ∀ e ∈ es, e.WF 0 0 0
  rowAnnotations : RowAnnotations P [] [] es
  rowKinds : ∀ e ∈ es, kindsEff P [] e
  context : CaptureContextRegular P (C1 ++ C0) Γ
```

OrdinaryはtypeKinds.ordinaryから供給する。行像のCanonicalはrowAnnotationsのfn型のwfから射影するため、別の信頼欄を加えない。C1下の実呼出しがまず `TypeArgsKinded P C1 ts (TypeCtx.kinds C0)` を返す場合は、typeWFの閉性からkind文脈を空へ落とす `HasKind.closed_context` の補題を先に証明する。行もrowWFから同様に閉じる。sourceRows/rowCount/RowTransportは実際のAdmissibleと呼出しの行数を維持し、閉じた行像の自由なrhoの支持を無条件に空へ狭めない。元の型と像の形成はこの入力と既存の宣言の形成から証明し、全中間型のkindを独立の信頼欄へ追加しない。

### S12.8: 固定した行像のkind

案4でTypeArgsKindedのCを固定するだけでは、一般の `HasKind.substAt` に行像のkindを供給できない。短い入力で、`A := .fn [] [] .bytes (Eff.row 0)` はvalue kindだが、行像 `Eff.singleFail (.ctor .list)` を代入した型はvalue kindではないことを確認した。これは値型のtvarの問題とは別であり、行像のWF/Sorted/Declaredだけでは除けない。

取りまとめのr3の判断に従い、SignatureInstance.rowKindsを**固定した案4の一部**とする。単独の追加承認を待つ条件は置かない。RowAnnotations一般やTy.Annotationの意味は強めない。完全な六欄の定義は次である。

```lean
structure SignatureInstance (P : Program) (C : TypeCtx) (Γ : Ctx)
    (t : Tel) (ks : List TyKind) (ts : List Ty) (es : List Eff) : Prop where
  source : (Ty.dependentFn t).WF 0 ks.length 0
  types : TypeAnnotations P C Γ ts
  kinds : TypeArgsKinded P C ts ks
  rows : RowAnnotations P C Γ es
  rowKinds : ∀ e ∈ es, kindsEff P (TypeCtx.kinds C) e
  result : Ty.Annotation P C Γ (.dependentFn (instantiatedTel t ts es))
```

型付けの構成子の引数の個数は変わらないが、SignatureInstanceの欄が5から6になる。9構成にこの証拠を供給する。value shift/substは既存HasKindの値移送、type shiftはkindRenaming、normはHasKind.norm、legacyは既存LegacyRowsInputのvalue kindから得る。CoreAssumptionsへ新しい公理を足さない。sourceにkindが適合しない行像を拒む構造条件であり、主な定理の言明の字面は維持する。元の読者から供給できない場合は、この欄を独立の信頼条件へ格上げせずJ20-2で停止する。

### S12.9: 関門(b)の型引数3caseと型注釈の例

群A3で定義・全既存読者の変更を閉じた**後**に、次の制限したS02の定理を本番の新判断で証明し、入力全文と終了・公理依存を保存する。Propの定義又は呼出しの入力欄の射影だけでは通過しない。

```lean
gate_op_case : ∀ {P B Ψ Q Q' C0 C1 Γ Φ o us a ts es},
  F → ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.op o us) a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V (.op o us)) (A a)
gate_fun_case : ∀ {P B Ψ Q Q' C0 C1 Γ Φ f us fs a ts es},
  F → ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.fnRef f us fs) a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V (.fnRef f us fs)) (A a)
gate_meth_case : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R v m ss fs ws a e L ts es},
  F → ClosedTypeSubstInput P B C0 C1 Γ ts es → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R (.meth v m ss fs ws) a e L →
  HasTypeCQ P B Ψ Q' C1 (G Γ) Φ (RR R)
    ((Comp.meth v m ss fs ws).substTyAt c ts es) (A a) (E e) (Lθ L)
```

F/A/E/G/V/RR/Lθ/cはS02の同じ式である。V_Op/V_FunはSub/Normal/Refineの包装を含めて結論まで閉じる。C_MethはV/Vsの子の明示したIHを受けるcase補題から、実際の型付きtvarの子を使う例で最終の新HasTypeCQまで合成する。未証明のmainを使わない。

例は(1) C0=[valueParam]、`.op o [.tvar 0]`に型像[bytes]、(2) C0=[constructor 1の宣言]、同じconstructorの引数を取る`.fnRef f [.tvar 0] []`に型像[ctor list]、(3)メソッドのss又はτにtvarを含む本体へ同じkindの像を代入するものを固定する。逆のkindの使い方は拒否する。(1)〜(3)の本体のcaseを閉じるLeanは今回未実施であり、補助入力のkindの受理/拒否だけでこれらの通過を宣言しない。

型注釈の関門を加える。F/I/A/E/G/V/RR/LθはS02と同じ完全な式の略記である。

```lean
gate_annotation_escape : ∀ {P B Ψ Q Q' C0 C1 Γ Φ R v a e L ts es},
  F → I → RowTransport Q Q' es →
  HasTypeCQ P B Ψ Q (C1 ++ C0) Γ Φ R (.escape v) a e L →
  HasTypeCQ P B Ψ Q' C1 (G Γ) Φ (RR R) (.escape (V v)) (A a) (E e) (Lθ L)
gate_annotation_lam : ∀ {P B Ψ Q Q' C0 C1 Γ Φ ns ps body a ts es},
  F → I → RowTransport Q Q' es →
  HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.lam ns ps body) a →
  HasTypeVQ P B Ψ Q' C1 (G Γ) Φ (V (.lam ns ps body)) (A a)
```

例(4)はC0=[constructor 1]、sourceの結果型`.tapp 0 [bytes]`とdata arity 1のctor像を持つ`.escape`、例(5)は同じtappを引数の注釈に持つlambdaである。arity 2の誤ったtappはsourceのDeclaredから拒否する。例(6)はconstructorのままの`.tvar 0`を要素型に持つListであり、型像のHasKindから像のAnnotationを構成する。補助Leanのescapeの証明は閉じたdataの行先と子のIHの合成であり、(4)(5)の新しい全判断の証明と同一視しない。

### S12.10: Rust側の検査の所在と書ける形

`crates/benitoite/src/typeck/decls.rs` の `Scope` は `(index, ParamKind)` を保持し、`Decls::parameters` が宣言のValue/Ctor/arityをここへ保存する。`Decls::named` はこの同じ表を読み、valueは引数0、constructorは宣言したarityを `Decls::arity` で検査し、`Ty::Param` と `Ty::App` を分ける。`generate.rs::check_function` は保存したscopeとschemeで本体を `Body::block` へ渡し、`generate.rs::name` は呼出し先を `Body::instantiate` で具体化する。

`context.rs::Body::instantiate` は呼出し先の `TypeParamInfo.kind` に従い `IArg::Ty(fresh_ty)` と `IArg::Head(fresh_head)` を別々に作る。`context.rs::substitute` は前者をTy::Param、後者をTy::Appのheadへ代入する。`infer.rs` のITy::ParamとIHead::Paramは別の形で、`solve.rs::Solver::equal_with_outer/bind_head` はconstructorのheadを値型のParamと等しいものとして扱わず、arityも適用の引数列の長さで照合する。したがって本体の型引数のkindは、宣言時の固定した表と、推論変数/単一化の形の両方で制約される。独立の同名の「本体kind検査関数」があるという意味ではない。

`traits/collect.rs::collect_impl`は`parameters(..., true)`でconstructorを含む型パラメータを保存し、同じscope/schemeを各実装メソッドの`d.signature`へ渡すことまで読んだ。Leanの`TypeCtx.values id.tparams`はvalue固定なので、implのconstructorパラメータを**本体の型引数として使う経路**では新しい受理差があり得る。targetに現れる形のHasKindによる既存の制限と、本体の型引数の新しい制限を混同しない。合法な表層の具体例の受理と新coreへの変換は今回未確認である。

操作の経路も読んだ。`decls.rs::check_declarations`の`Item::Effect`は各操作をFnDeclへ写し、`d.signature → signature_with_file → parameters(..., true)`を通る。したがって収集のこの経路はconstructor kindを保存できる。alias/data/recordの直接のparametersはfalseで、signatureのtrueとは別である。`traits/collect.rs::check_parameters`のallowedは制約の可否にも使われ、constructorそのものを一律に拒否するフラグではない。操作のconstructorパラメータの構文・呼出し・handler本体と、Leanのuser操作のvalue固定との全対応は未確認である。

既存`typeck/tests.rs::effect_inference_names_and_stubs`の裸のFの拒否、`higher_kinded_instantiation_and_equatable_declaration_summaries`の正しい適用とarity不一致を読んだ。テストは実行していない。裸のconstructorを値型へ使う不適合の検査を読んだことから、impl本体とeffect操作の全合法ソースの対応を推定しない。この二つをJ20-7へ名指しし、L70/R10b/R50の照合へ残す。Rustの書ける形をこの計画担当が狭める変更は行っていない。

### S12.11: 固定したDeclaredのtappと、値の位置のtvar

取りまとめのr3の判断に従い、Ty.Declaredの`.tapp`が宣言のkindと引数数を読む形を案4に含める。CはTypeCtxであり、判断の引数の個数を増やさない。相互四定義の完全な形は次とする。Term/Pred/FieldRefのCも既にS12.2のTypeCtxであり、ここでは式を変えない。

```lean
mutual
  def Ty.Declared (P : Program) (C : TypeCtx) (Γ : Ctx) : Ty → Prop
    | .base _ | .bytes | .opaque _ _ | .scoped _ _ _ | .pathBases | .scopePattern _ | .tvar _ => True
    | .data d as => (∃ n, P.DataArity d n ∧ as.length = n) ∧ declaredTys P C Γ as
    | .external id as => (∃ td, P.externalType id = some td ∧ td.id = id ∧ as.length = td.arity) ∧
        declaredTys P C Γ as
    | .tapp i as => (TypeCtx.kinds C)[i]? = some (.constructor as.length) ∧ declaredTys P C Γ as
    | .ctor (.data d) => ∃ n, P.DataArity d n
    | .ctor _ => True
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Ty.Declared P C Γ a
    | .fn _ ps r e => declaredTys P C Γ ps ∧ Ty.Declared P C Γ r ∧ declaredEff P C Γ e
    | .dependentFn t => Tel.Declared P C Γ t
    | .cont b t e => Ty.Declared P C Γ b ∧ Ty.Declared P C Γ t ∧ declaredEff P C Γ e
    | .map a b => Ty.Declared P C Γ a ∧ Ty.Declared P C Γ b
    | .refined a p => Ty.Declared P C Γ a ∧ Pred.Declared P C Γ (some a) p
  def Tel.Declared (P : Program) (C : TypeCtx) (Γ : Ctx) : Tel → Prop
    | .done r e => Ty.Declared P C Γ r ∧ declaredEff P C Γ e
    | .param _ a t => Ty.Declared P C Γ a ∧ Tel.Declared P C (Γ.extend a) t
  def declaredTys (P : Program) (C : TypeCtx) (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => Ty.Declared P C Γ a ∧ declaredTys P C Γ as
  def declaredEff (P : Program) (C : TypeCtx) (Γ : Ctx) : Eff → Prop
    | .mk _ fs => declaredTys P C Γ fs
end
```

`.tvar`の枝はTrueを保つ。constructorと宣言したtvarを値型の位置に置く`.list (.tvar 0)`は、このAnnotationでは形成でき、HasKind.valueは満たさない。型像`.ctor c`が宣言と同じconstructor kindなら、`.list (.ctor c)`のWF/Sorted/Declaredは得られる。dataのctorのDeclaredは、像のHasKindとTyCon.arityからDataArityを得る。他のctorはDeclaredがTrueである。任意Γでこの像の新Annotation、置換の等号、閉じた空Listの型付けを補助Leanで証明した。したがってこの例はS02の結論を偽にせず、**Ty.AnnotationにHasKind.valueの欄は追加しない**。これが全型置換の証明になったとはしない。

誤った`.tapp 0 [bytes,bytes]`はC=[constructor 1]で新Declaredから拒否される。正しい`.tapp 0 [bytes]`は形成でき、arity 1のdata ctorの像は`.data d [bytes]`として形成できる。その型を結果に持つ`.escape`と、正しい像を引数型に持つlambdaの行先も、子の型付けをIHとして現行の実構成子で閉じた。新しい14判断へ全移行した証明は、後述の関門の完了条件に残す。

#### 作る場所・読む場所と移送の波及

| 対象（R/以下） | 数と処置 | 単位 |
|---|---|---|
| Declared.leanのTy.Declared | 意味を変える枝1。Tel/list/Effの三定義の形は同じ。Ty.Annotationは三欄のまま | L20.10 |
| Typing.leanの直接の受入口 | Annotation/TypeAnnotations/RowAnnotations/SignatureInstance又はTy.Declaredを直接受ける36構成子。V19、CQ11、TelArgs2、DependentClosure1、Arms2、Failure1。下に全名を列挙。引数の個数の追加0、元の証拠を再使用する規則は再証明しない | L20.10、S01a、S02/S05 |
| DeclaredTransport.lean | Ty.Declared.rawSubstV/normのtappの2枝。kind lookupを保持し、像の引数列の長さだけmap/normで合わせる。値のbind/shift/逆shift/contextはこの二族を使用し、Cを変えない | L20.12 |
| TypeShiftContext.lean | 現行のTy.Declared.shiftTypesのtappの1枝。一般ρのheadの照合をKindRenamingで証明し、既存四族26構文形のshiftへ適用。型全体の別の一般改名recursorは増やさない | L20.14 |
| TypeParamRenamingと配置 | KindRenaming/rawRenameTypesList_lengthの二宣言を同名同式でTypeRenamingへ移し、import循環を避ける。r2で追加したq.kind=p.kindからkindRenamingを供給。五包装はr2のまま。Declaredのための新しいkindの選択又は公理0 | L20.14/S12.4 |
| 宣言/注釈のshiftの公開補助 | Ty.Declared.shiftTypes/Tel.Declared.shiftTypes/declaredTys_shiftTypes/declaredEff_shiftTypes、TypeCtxMap.annotation/annotations/rowsの**7署名**にhCを追加。methodRowsは既存のrowScopeとEff.wf_shiftTypesからWFを直接作り、署名を変えず本体1箇所を置き換える。signatureはr2の追加と同じhCを再使用。SatAll/admissible/primitiveの既存hCを各呼出しへ渡す | L20.14 |
| TypeShiftTyping.leanの読者 | 下表の**36枝**へ既存hCを渡す。C_Externalのhw.annotationは閉じた宣言の射影なのでこの集合へ足さない。新しい14判断の引数又は移送の入口は増やさない | L20.14/ L20.18 |
| LegacyValues/LegacyInput | embedTy_declared_contextのtappの1枝を変更。context三署名にC/Dのkind列の等号を要求する。旧Cの既存8橋にこの3宣言を加えて**11橋**。LegacyTypeInputの既存HasKindからheadのkindを供給し、annotation_atは同じCκでΓだけを変える。独立のLegacy入力欄は追加しない | L20.10/S12.5 |
| TypeFormation.lean | NoTappを要求するtypesOnly四族はtappをFalseで除いているため、headの証明の追加0。新しい一般型置換は次の四族として別に閉じる | L20.16 |
| 新しいTy/Tel/list/EffのDeclared型置換 | 四族26構文形の一つのmotive。tvar像はTypeAnnotations、tapp headは元DeclaredとTypeArgsKinded、各引数はWF/Sorted/DeclaredのIH。HasKind.valueを全中間注釈へ要求しない | L20.16/S12.7 |
| S00・捕捉の閉じた型 | C=[]かつWFの型にtappはない。閉じた場所の4種/生成6規則の定義の追加変更0。Ty.Declared.closed_contextとNoTappの読者を再検査する | L20.12 |

現行で直接手修正するtappの枝は**4枝**（rawSubstV、norm、shiftTypes、embedTy_declared_context）である。これは新しいDeclared型置換の26構文形や、公開補助7署名、読者36枝とは別の集合であり、合算したユニーク総数にはしない。全本番ソースのコンパイルは未確認であり、下の数を上限とはしない。

直接の受入口36構成子の全名は次である。

`HasTypeVQ.V_Lam`、`HasTypeVQ.V_DependentLam`、`HasTypeVQ.V_Closure`、`HasTypeVQ.V_Fun`、`HasTypeVQ.V_Prim`、`HasTypeVQ.V_Op`、`HasTypeVQ.V_ExternalRef`、`HasTypeVQ.V_ExternalHandle`、`HasTypeVQ.V_Map`、`HasTypeVQ.V_Set`、`HasTypeVQ.V_Dict`、`HasTypeVQ.V_Raise`、`HasTypeVQ.V_LocRef`、`HasTypeVQ.V_LocLazy`、`HasTypeVQ.V_Con`、`HasTypeVQ.V_Super`、`HasTypeVQ.V_List`、`HasTypeVQ.V_Sub`、`HasTypeVQ.V_Refine`、`HasTypeCQ.C_BuilderLet`、`HasTypeCQ.C_BuilderOp`、`HasTypeCQ.C_Let`、`HasTypeCQ.C_Lazy`、`HasTypeCQ.C_Escape`、`HasTypeCQ.C_Resume`、`HasTypeCQ.C_ResumeL`、`HasTypeCQ.C_ResumeNorm`、`HasTypeCQ.C_ResumeLNorm`、`HasTypeCQ.C_Meth`、`HasTypeCQ.C_Sub`、`HasTypeTelArgsQ.done`、`HasTypeTelArgsQ.param`、`DependentClosureTy.mk`、`HasTypeArmsQ.nil`、`HasTypeArmsQ.guarded`、`HasFailureClause.one`。

TypeShiftTypingの36枝は次の全名である。r2の型shiftの8枝とFailureの1枝を含み、追加は27枝。他の三移送のV_Raise各1と合わせ、四移送304枝の局所修正の見込みは**39枝**、残265枝は同じrecursorを保つ。r2の12枝という見込みを置き換える。

| 相互の成分 | 全枝 | 数 |
|---|---|---:|
| HasTypeVQ | `V_Lam`, `V_DependentLam`, `V_Closure`, `V_List`, `V_Fun`, `V_Prim`, `V_Op`, `V_ExternalRef`, `V_ExternalHandle`, `V_Map`, `V_Set`, `V_Dict`, `V_Raise`, `V_LocRef`, `V_LocLazy`, `V_Con`, `V_Super`, `V_Sub`, `V_Refine` | 19 |
| HasTypeCQ | `C_BuilderLet`, `C_BuilderOp`, `C_Lazy`, `C_Escape`, `C_Resume`, `C_ResumeNorm`, `C_ResumeLNorm`, `C_ResumeL`, `C_Meth`, `C_Sub`, `C_Let` | 11 |
| HasTypeArmsQ | `nil`, `plain`, `guarded` | 3 |
| HasFailureClause | `one` | 1 |
| HasTypeTelArgsQ | `done`, `param` | 2 |
| 合計 | 型shiftの76枝の内 | 36 |

#### 固定した補助の完全署名

次のrename_tappは一般ρのheadのcase補題であり、型全体の新しい改名の族を置く意味ではない。shiftの元の四族は同じ再帰の形を使う。下はTyの代表、Tel/list/Effも同じhCを最後の引数へ加える。

```lean
Ty.Declared.rename_tapp : ∀ {P C C' Γ Δ i as ρ},
  Ty.Declared P C Γ (.tapp i as) →
  KindRenaming (TypeCtx.kinds C) (TypeCtx.kinds C') ρ →
  declaredTys P C' Δ (rawRenameTypesList ρ as) →
  Ty.Declared P C' Δ ((Ty.tapp i as).rawRenameTypes ρ)
Ty.Declared.shiftTypes : ∀ {P C C' Γ Δ a k c},
  Ty.Declared P C Γ a → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  Ty.Declared P C' Δ (shiftTypes k c a)
Tel.Declared.shiftTypes : ∀ {P C C' Γ Δ t k c},
  Tel.Declared P C Γ t → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  Tel.Declared P C' Δ (shiftTelTypes k c t)
declaredTys_shiftTypes : ∀ {P C C' Γ Δ as k c},
  declaredTys P C Γ as → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  declaredTys P C' Δ (shiftTypesList k c as)
declaredEff_shiftTypes : ∀ {P C C' Γ Δ e k c},
  declaredEff P C Γ e → TypeCtxMap k c Γ Δ →
  TypeParamRenaming C C' (shiftIndex k c) →
  declaredEff P C' Δ (shiftRowsTypes k c e)
TypeCtxMap.annotation : ∀ {P C C' Γ Δ a k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → Ty.Annotation P C Γ a →
  TypeParamRenaming C C' (shiftIndex k c) → Ty.Annotation P C' Δ (shiftTypes k c a)
TypeCtxMap.annotations : ∀ {P C C' Γ Δ as k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → TypeAnnotations P C Γ as →
  TypeParamRenaming C C' (shiftIndex k c) →
  TypeAnnotations P C' Δ (as.map (shiftTypes k c))
TypeCtxMap.rows : ∀ {P C C' Γ Δ es k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → RowAnnotations P C Γ es →
  TypeParamRenaming C C' (shiftIndex k c) →
  RowAnnotations P C' Δ (es.map (shiftRowsTypes k c))
TypeCtxMap.methodRows : ∀ {P C C' Γ Δ ms Q es k c},
  TypeCtxMap k c Γ Δ → C'.length = C.length + k → RowAnnotations P C Γ es →
  MethodRowsAdmissible C Γ.length Q ms es →
  MethodRowsAdmissible C' Δ.length Q ms (es.map (shiftRowsTypes k c))
```


```lean
embedTy_declared_context : ∀ (a : Benitoite.Release.Ty) (P : Program)
    (C D : TypeCtx) (Γ Δ : Ctx), TypeCtx.kinds C = TypeCtx.kinds D →
  ((embedTy a).Declared P C Γ ↔ (embedTy a).Declared P D Δ)
embedTys_declared_context : ∀ (as : List Benitoite.Release.Ty) (P : Program)
    (C D : TypeCtx) (Γ Δ : Ctx), TypeCtx.kinds C = TypeCtx.kinds D →
  (declaredTys P C Γ (embedTys as) ↔ declaredTys P D Δ (embedTys as))
embedEff_declared_context : ∀ (e : Benitoite.Release.Eff) (P : Program)
    (C D : TypeCtx) (Γ Δ : Ctx), TypeCtx.kinds C = TypeCtx.kinds D →
  (declaredEff P C Γ (embedEff e) ↔ declaredEff P D Δ (embedEff e))
```

Ty.Declared.substAtは、子の束縛の形成を作れるよう元のWF/Sortedも受ける。Declaredだけからそれを推定しない。FはS02の同じ四前提、IはS12.7のClosedTypeSubstInput、A/E/G/Tは同じ完全な式の略記である。以下の四署名は同じ相互のmotiveとして固定する。

```lean
Ty.Declared.substAt : ∀ {P B Ψ C0 C1 Γ a ts es},
  F → I → Ty.Annotation P (C1 ++ C0) Γ a →
  Ty.Declared P C1 (G Γ) (A a)
Tel.Declared.substAt : ∀ {P B Ψ C0 C1 Γ t ts es},
  F → I → Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t) →
  Tel.Declared P C1 (G Γ) (T t)
declaredTys_substAt : ∀ {P B Ψ C0 C1 Γ as ts es},
  F → I → TypeAnnotations P (C1 ++ C0) Γ as →
  declaredTys P C1 (G Γ) (as.map A)
declaredEff_substAt : ∀ {P B Ψ C0 C1 Γ e ts es},
  F → I → RowAnnotations P (C1 ++ C0) Γ [e] →
  declaredEff P C1 (G Γ) (E e)
```

これらは完全署名の計画であり、今回の補助Leanが閉じたのはtappの値移送・norm・一般ρのhead・shiftのcaseと上の具体例までである。methodRowsはDeclaredを使わないWFの直接の証明も補助Leanで閉じ、余計なhCの引数追加を避ける。四族26構文形全体、Pred/FieldRefの具体化との合成、SignatureInstanceの全読者は本番の完了条件に残る。型像のkindの四族47枝とDeclaredの四族26構文形を一つずつ作り、14判断76caseの本証明を作り直さない。



## 起動単位と群の完了条件

**148単位・32群、所要時間（能動時間）97時間45分〜219時間45分**を積み上げた。r2の143単位93時間30分〜209時間5分へ、Declaredの定義/旧橋45〜100分、値移送/norm30〜60分、型改名/shiftと読者60〜150分、Declared全型置換60〜180分、注釈の関門60〜150分の5単位を追加した。追加は255〜640分。rowKindsの45〜150分はr2から計上済みで、固定案へ移したことだけでは二重加算しない。

固定枠47〜109時間との差は下端＋50時間45分、上端＋110時間45分である。枠へ合わせて他を削らない。方式の成否、新しいDeclaredとkindの構造条件、所要時間の見直しを区別する。

| 性質 | 件数 | 幅を置く根拠 | 所要時間（能動時間） |
|---|---:|---|---:|
| 方式 | 16 | 弱い規則・反例・新motiveと全型置換の成否。最初の60分で未証明枝を点検 | 13時間〜34時間55分 |
| 移行 | 5 | C/constraints・Declaredの供給と既存shift読者。暗黙引数を含む全体buildは未確認 | 4時間30分〜11時間40分 |
| 定型 | 3 | q_monoの一つのrecursor。共通補助と再構成の種類で測り、76caseを単価へ掛けない | 1時間45分〜2時間50分 |
| 証明 | 31 | 既存WF/Sorted/Declared/LeQのcase補題と全読者の照合 | 19時間〜37時間15分 |
| 包装 | 22 | 既存定理の射影・恒等・既知の入力の結合 | 11時間〜16時間30分 |
| 接続 | 71 | closeVal/実行/意味/旧導出の新しい合成と正規化・捕捉・依存列の不確かさ | 48時間30分〜116時間35分 |

基本の起動は30〜60分。不確かな接続は30〜75/45〜100分、関門・新しい帰納の方式は最大150〜180分の幅とし、最初の60分でcase補題・完全署名・未証明枝を保存して残りを見直す。単位ごとの幅の理由はr2を維持する。q_monoはmotive/定型の本体/公開接続の3単位、closeは通常lambda・依存lambda/closure・Sub・Normal・Refine・全33case合成へ分割したままである。群Dは22単位14時間〜27時間10分、G01は8単位7時間〜16時間40分。case数は漏れの検査へ使う。

次表のファイルはR/以下、未作成のファイルは配置案である。実装時は既定importと01-12/07-04の写しも同じ単位でそろえる。結果は`l20/<IDの数字>/results.md`、群は`l20/<群の小文字>/results.md`へ残す予定であり、今回は作らない。全群の完了条件に、全単位の固有条件・公開署名と全読者の一致・既定build・定義/言明/仮定のレビューと所見処置を含む。独立レビュー実行の待ちは能動時間に混ぜない。

| 群 | 単位 | 固有の完了条件（全単位・既定build・定義/言明/仮定レビューを含む） | 所要時間（能動時間） |
|---|---|---|---:|
| A1 | L20.01〜.03 | S00、直接7構成・状態4構成・包装3。Sorted.hide/Declared.hideと全読者 | 1時間30分〜2時間15分 |
| A2 | L20.04〜.07 | S01の開いたmotive、53規則の表と弱い5case・効果の供給。関門(a) | 2時間45分〜6時間45分 |
| A3a | L20.08〜.13 | C/TAK、Declaredのtapp、全69変更7保持、宣言/旧Cの11橋、改名、Declaredの値移送/normを固定 | 4時間30分〜10時間20分 |
| A3b | L20.14〜.19 | Declaredの型shiftと36読者、kind像47枝とDeclared型置換26構文形、固定rowKindsの9構成、四移送39枝、全契約 | 5時間30分〜15時間30分 |
| A3c | L20.20〜.24 | 型引数の3本体と型注釈のescape/lambda/tappを新S02の結論まで閉じ、OpFailと入れ子を照合。関門(b)(c) | 4時間15分〜11時間 |
| A4 | L20.25〜.27 | 辞書式motiveとdata/trans/refineの三枝。関門(d) | 2時間30分〜7時間10分 |
| B | L20.28〜.32 | 宣言の条件と形成・交換 | 3時間〜6時間20分 |
| C | L20.33〜.38 | パターンと全束縛の型置換 | 3時間30分〜7時間35分 |
| D1 | L20.39〜.45 | V29の型置換case補題 | 4時間30分〜8時間45分 |
| D2 | L20.46〜.51 | CQ24の型置換case補題 | 3時間45分〜7時間15分 |
| D3 | L20.52〜.54 | 腕3・節2・失敗1の型置換case補題 | 2時間〜3時間55分 |
| D4 | L20.55〜.60 | 残り17caseと14成分76caseの単一recursor合成 | 3時間45分〜7時間15分 |
| E1 | L20.61〜.63 | q_monoのmotive/定型相互帰納/公開接続 | 1時間45分〜2時間50分 |
| E2 | L20.64〜.70 | 全文脈移送・開いた正則性・捕捉の系・合同の閉鎖表 | 3時間30分〜7時間 |
| F1 | L20.71〜.73 | 保持値と通常/依存lambda・closureのclose | 3時間〜7時間30分 |
| F2 | L20.74〜.77 | closeのSub/Normal/Refineと全33caseの合成 | 3時間〜6時間40分 |
| F3 | L20.78 | 任意closeValから全実行view | 1時間〜2時間30分 |
| G | L20.79〜.84 | 零・多引数と依存β | 3時間30分〜7時間50分 |
| H | L20.85〜.88 | 全部分型の意味移送22規則 | 2時間45分〜6時間15分 |
| I1 | L20.89〜.93 | 型付け33caseとInhabitsの全入口 | 2時間30分〜6時間15分 |
| I2 | L20.94〜.96 | パターン束縛の全保存 | 1時間45分〜3時間55分 |
| J | L20.97〜.100 | 照合・guardとhandler入口 | 2時間〜4時間 |
| K | L20.101〜.105 | 操作・多相節・resume | 3時間15分〜7時間30分 |
| L | L20.106〜.109 | used・drop・解放と効果 | 2時間〜3時間30分 |
| M | L20.110〜.114 | 全ストアと実行の葉・開始準備 | 3時間30分〜7時間55分 |
| N1 | L20.115〜.117 | 全76葉・stepの選択・関数view | 1時間45分〜4時間10分 |
| N2 | L20.118〜.122 | 独立評価の関係・return/let/腕・failedの入力 | 3時間45分〜12時間30分 |
| O | L20.123〜.128 | 埋め込みの骨格と条件付きパターン/網羅性 | 3時間45分〜7時間30分 |
| P | L20.129〜.134 | 旧値19規則の埋め込みと本番追随の通常記録 | 4時間〜8時間10分 |
| Q | L20.135〜.140 | 旧列4・CQ17の埋め込み | 3時間45分〜7時間15分 |
| R | L20.141〜.144 | 旧腕・節・46規則合成と状態入力 | 2時間45分〜5時間45分 |
| S | L20.145〜.148 | 旧継続・ストア・状態・三親判断、公理監査と段末資料 | 3時間〜6時間40分 |

群AはA1/A2/A3a/A3b/A3c/A4の総称、21時間〜53時間。各群がレビューと取込みの単位である。四関門が閉じる前に群B以降の全帰納を起動しない。

| ID・G行 | 目的 | 触るファイル（R/） | 完全署名又は定義の形 | 手順と固有の完了条件 | 依存 | 所要時間（能動時間） | 検査 |
|---|---|---|---|---|---|---:|---|
| L20.01・G04 | LocTy.Sorted/StoreTy.Sorted と StoreOk の変更 | `StoreTransport.lean`、`StateTyping.lean` | S00 | b/t/e を Sorted とし r を外す。empty/sorted accessor/context とused反例の拒否とrefの帰納の不要化、usedの結果形成を閉じる。新公理・規則変更0。StoreTy.Sorted.hideを証明し、hideBuildersへの三条件を供給する | 入口 | 30〜45分（包装） | K/W-L |
| L20.02・G04 | Reference/Lazy/Handler の Sorted 追随 | `ReferenceStore.lean`、`LazyStore.lean`、`HandlerStore.lean` | S00 | 6直接構成に Sorted を保持又は供給する。ref/lazyは既存Annotationを使い、continuationだけ新しいSorted引数を追加する。named accessorに統一する | .01 | 30〜45分（包装） | K/W-L |
| L20.03・G04 | 全既存の StoreOk 読者の追随 | `DependentBeta.lean`、`CapturedFacts.lean`、`StateTyping.lean`、`HandlerPreservation.lean`、`HandlerOperation.lean` | S00 | 状態4構成と包装3件、追加2読者のraw射影6箇所とallocate_continuation呼出し1箇所を含む全raw射影を照合して既定buildを閉じる。S00変更一式をこの時点でレビュー可能にする | .02 | 30〜45分（包装） | K/W-L |
| L20.04・G04 | 開いた S01 motive と文脈の延長 | `CaptureRegularity.lean` | S01 | CaptureContextRegularを定義し、C_Let/BuilderLet/IfでCaptureOkを子へ要求しないmotiveを印字する | .03 | 30〜75分（方式） | K/W-L |
| L20.05・G04 | 逆 shift と弱い5規則の case | `CaptureRegularity.lean` | S01/S00 | WF/Sorted/Declaredの逆、extendNoneの版、C_Let/C_BuilderLet/C_ResumeL/V_LocRef/V_Checkedの5証明又は反例を完成する | .04 | 45〜90分（方式） | K/W-L |
| L20.06・G04 | V29/CQ24 の注釈供給表 | `CaptureRegularity.lean` | S01a | 全53規則を一行ずつ照合し型の形成の全供給元を固定。全53枝の本証明を行ったとはしない | .05 | 30〜60分（方式） | K/W-L |
| L20.07・G04 | handler と潜在効果の関門 | `CaptureRegularity.lean` | S01b | E_Handle/Fail/Let/LamとcontLocの全効果を照合。形成済み上限へのC_EffとClauseSigの整合をLeanで閉じるか失敗の言明を返す | .06 | 60〜180分（方式） | K/W-L |
| L20.08・G03 | TypeCtxと固定したTypeArgsKinded | `Types.lean`、`KindValues.lean`、`Admissible.lean`、`TypeSubstContracts.lean` | S12.1/S12.2 | CをList TParamDeclにし、kindはC.kindsだけから読む。TypeArgsKindedAtを同じ定義の別名にし、双方向の不適格tvarを拒否する。S12.7/S12.11の全motiveとClosedTypeSubstInputの定義を本体より先に固定する | .04〜.07 | 45〜90分（方式） | K/W-L |
| L20.09・G03 | constraints射影と全C読者 | `Declared.lean`、`SubstitutionContracts.lean`、`ConstraintAssumptions.lean`、S12の全注記表 | S12.2/S12.6 | 69変更/7保持の全出現を追随。B.sat/admitsはC.constraints、SatAllの相手は生のconstraints。旧Releaseを変えない | .08 | 60〜150分（移行） | K/W-L |
| L20.10・G03 | Declaredのtappと旧文脈の橋 | `Declared.lean`、`LegacyInput.lean`、`LegacyValues.lean` | S12.11・Ty.Declared | tappのheadの固定kindと個数を定義。誤個数を拒否。旧context三署名はkind列の等号を取り、HasKindから旧Cκへ供給する。Annotationの欄は増やさない | .09 | 45〜100分（移行） | K/W-L |
| L20.11・G03 | 宣言・節・旧Cの具体化 | `ProgramTyping.lean`、`ProgramWellFormed.lean`、`HandlerContracts.lean`、`LegacyInput.lean`、`LegacyDeclarations.lean`、`LegacyValues.lean` | S12.3/S12.5 | Def/Methは実際の宣言、Op/Implは既存value宣言をlift、OpSigはprimitive kindを保持。旧Cκと8橋の供給を固定。新kindの選択をしない | .10 | 45〜120分（移行） | K/W-L |
| L20.12・G03 | Declaredの値移送・norm・閉じた型 | `DeclaredTransport.lean`、`StateTyping.lean`、`TypeFormation.lean` | S12.11・rawSubstV/norm/closed_context | 既存tappの2枝でlookupを保持し長さを合わせる。bind/shift/逆shift/contextとNoTappの全読者を検査。WF0の閉じた型とS00への定義の追加変更0を確認 | .11 | 30〜60分（証明） | K/W-L |
| L20.13・G03 | kindを保つ改名の橋 | `TypeRenaming.lean`、`TypeShiftKinds.lean`、`TypeShiftContracts.lean` | S12.4 | TypeParamRenamingにkind一致を加え、5包装とTAK.shiftTypes/TypeCtxMap.signatureに正しいKindRenamingを供給する。KindRenamingとrawRenameTypesList_lengthの二宣言を同名同式でTypeRenamingへ移し、Declaredのshiftから循環せず使う | .12 | 45〜100分（証明） | K/W-L |
| L20.14・G03 | Declaredの改名・型shiftと全読者 | `TypeShiftContext.lean`、`TypeShiftContracts.lean`、`TypeShiftExchange.lean`、`TypeShiftTyping.lean` | S12.11・rename_tapp/shiftTypes | 一般ρのheadをKindRenamingで閉じ、既存四族へ適用。公開補助7署名・methodRowsの本体1箇所と新たな27枝へ既存hCを渡す。元の9枝を含む型shift36枝を照合し、別の26枝の改名族を作らない | .13 | 60〜150分（移行） | K/W-L |
| L20.15・G03 | 型像のkindとtapp形成 | `KindTypeSubst.lean`、`TypeSubstFormation.lean` | S12.7 | Ty/Tel/Tys/Effの26構文形、kind別47枝の共通族を固定しHasKind.substAtを閉じる。tappのHasKindを保存する。AnnotationのDeclaredはS12.11の別の四族と合成する | .14 | 60〜180分（方式） | K/W-L |
| L20.16・G03 | Declaredの全型置換とtapp形成 | `TypeSubstFormation.lean` | S12.11・Ty/Tel/list/EffのsubstAt四署名 | WF/Sorted/Declaredを持つ入力から四族26構文形を一度閉じる。tappのkindはDeclared、像は固定TypeArgsKindedから読む。各注釈にHasKind.valueを要求しない。`TyCon.arity`から`DataArity`への逆の補題を含める。Telの束縛の下では`Ty.Declared.substAt`の`I.context`のΓを延ばす | .15 | 60〜180分（方式） | K/W-L |
| L20.17・G03 | 行像のkindの供給 | `Admissible.lean`、`Context/Declarations.lean`、署名の9構成読者 | S12.8 | 固定した案4のSignatureInstance.rowKindsを9構成へ供給し、SignatureInstanceAtもそろえる。RowAnnotations一般とCore公理は強めない | .16 | 45〜150分（方式） | K/W-L |
| L20.18・G03 | 既存移送とV_Raiseの追随 | `Typing.lean`、`TypingShift.lean`、`TypeShiftTyping.lean`、`SubstTyping.lean`、`Narrowing.lean`、S12.6の追加読者 | S12.4/S12.6 | V_RaiseのTのvalue kind、元の四移送12枝、外のarity4枝と21基盤包装を追随する。Declaredの新27枝と合わせ全39枝、残265枝を同じrecursorで閉じる。全読者と既定buildを確認 | .17 | 60〜180分（移行） | K/W-L |
| L20.19・G03 | S02の公開契約と実読者の照合 | `TypeSubstContracts.lean` | S02/S12.7 | 先に固定した閉じた型/行像・Declared・kindの入力と10移送/3恒等/1Trueの全署名を印字。全形成補題と公開読者の引数を合わせる | .18 | 45〜90分（証明） | K/W-L |
| L20.20・G03 | V_Opの型置換caseの関門 | `TypeSubstContracts.lean`、予定の関門入力 | S12.9・gate_op_case | 定義の変更後、宣言valueのtvarを含む.op本体とbytes像でS02_Vの結論を証明する。宣言constructorのtvarをvalueに使う源を拒否する | .08〜.19 | 45〜100分（方式） | K/W-L |
| L20.21・G03 | V_Funの型置換caseの関門 | `TypeSubstContracts.lean`、予定の関門入力 | S12.9・gate_fun_case | 宣言constructorのtvarを含むfnRef本体とctor list像でS02_Vの結論を証明する。入力の欄の供給だけでは通過させない | .20 | 60〜150分（方式） | K/W-L |
| L20.22・G03 | C_MethとE_OpFailの関門 | `TypeSubstContracts.lean`、予定の関門入力 | S12.9・gate_meth_case/fail_image_kind | C_Methのτ/ssにtvarを持つ本体をS02_Cの結論まで証明。E_OpFailはV_RaiseのT.kindを使い同じ族を適用。Fail用別入口は作らない | .21 | 60〜180分（方式） | K/W-L |
| L20.23・G03 | 型注釈のescape・lambda・tappの関門 | `TypeSubstContracts.lean`、予定の関門入力 | S12.9/S12.11・gate_annotation_escape/lam | 正しいtappを結果/引数に持つescape/lambdaを新S02の結論まで閉じ、誤個数はsourceで拒否する。constructor宣言のlist(tvar)の像の形成と実際の型付けも確認。入力欄の型検査だけで通過させない | .22 | 60〜150分（方式） | K/W-L |
| L20.24・G03 | 入れ子の継続の確認 | `TypeSubstContracts.lean` | S02 | notContCore→list_cont_empty→singleton_no_matchをLeanで閉じ、data/高kind/捕捉の使用先を追う。reject_nested_cont_valueも残す。Ordinaryを再帰化しない | .23 | 30〜80分（方式） | K/W-L |
| L20.25・G09 | 値の大きさと導出の二段の motive | `MeaningTransport.lean` | S07a | 4相互成分の完全署名を印字する。証明からNatのサイズを作らず、子値と部分導出の下降を分ける | .04〜.24 | 45〜100分（方式） | K/W-L |
| L20.26・G09 | data の欄の意味移送の関門 | `MeaningTransport.lean` | S07a | variance_field_monoのOrdinary/Sorted/VarianceOKを既存入力から供給し、新導出へ子値のIHを適用するcaseを閉じる | .25 | 60〜180分（方式） | K/W-L |
| L20.27・G09 | trans/refine の意味移送の関門 | `MeaningTransport.lean` | S07a | transは中間注釈なし、refineはselfModelのfactsとEntails.soundを供給してLeanのcaseを閉じる。未証明なら停止 | .26 | 45〜150分（方式） | K/W-L |
| L20.28・G08 | PrimSig.Scopedとsig_scoped | `SourceScope.lean`、`PrimitiveScoped.lean`、`ProgramWellFormed.lean`、`ConstraintAssumptions.lean` | S09 | 範囲深さrkinds.lengthのtelの形成とinst後の深さ0を定義する。旧20欄の残1を新束へ接続し実表の後段義務を固定する | .25〜.27 | 45〜100分（接続） | K/W-L |
| L20.29・G08 | 宣言入力と三親判断 | `LegacyDeclarationInputs.lean` | S09/G10 | SourceScopedとdeclarationBodyInputs、辞書の二供給元、代入前Qを射影する。G10後に証明する親判断の入力を固定する | .28 | 30〜60分（証明） | K/W-L |
| L20.30・G03 | tappを含む全形成 | `TypeSubstFormation.lean` | S02の形成成分 | NoTapp限定のない別補題を置き、constructor_shape/rawApply_properからSorted/Declaredを導く。全nodeへの供給を照合する。O167拒否例reject_unsorted_tapp_imageを名指しし、正しいkind/Annotationの入力と対照する | .08〜.22/.24/.28 | 45〜100分（接続） | K/W-L |
| L20.31・G03 | 範囲・行・WFの旧読者 | `RangeFormation.lean`、`TypeSubstFormation.lean` | S02/S09 | instR/shiftRと値・型・行の交換をbindで結ぶ。旧WF/VarsIn/RawWFの読者を直接のWF/RowsIn/Referencesへ移す | .30 | 30〜45分（包装） | K/W-L |
| L20.32・G03 | 型像と値像の交換 | `TypeValueExchange.lean` | S02の開いた像の交換族 | 型・行像の外の値依存を残し、束縛下upとcloseの順を合わせる。R/LocalCtx/捕捉コードもbindを通す | .30/.31 | 30〜75分（接続） | K/W-L |
| L20.33・G03 | PatTyの型置換 | `PatternTypeSubst.lean` | S03・PatTy9場合 | Refined/Convertの正規形と相互IH付きcase補題を閉じる。型注釈をrawBindへ戻さない | .32 | 30〜60分（証明） | K/W-L |
| L20.34・G03 | PatTys/AltsTyの型置換 | `PatternTypeSubst.lean` | S03・PatTys2/AltsTy | append/selectSlots/長さを照合し、全パターン移送を閉じる。値置換の既済み分と区別する | .33 | 30〜45分（包装） | K/W-L |
| L20.35・G03 | Inhabitsの型置換反映 | `PatternTypeSubst.lean` | S03・24/All2/Each2場合 | refinedの全述語、checkedAt/atError、data/Listの子を覆う反映を証明し、coreだけから篩を戻さない | .32/.34 | 45〜100分（接続） | K/W-L |
| L20.36・G03 | Exhaustiveの型置換 | `PatternTypeSubst.lean` | S03・Exhaustive.substAt | a.normの入口から全反映を使い、同じpsの照合成功を結論する。型と値の双方の境界を確認する | .35 | 30〜75分（接続） | K/W-L |
| L20.37・G03 | Signatureと型像の供給 | `TypeSubstCalls.lean` | S02のSignature/Admissible成分 | typeScope/method_body_typeScope/raise結果Tの像[t]、NoFail/SatAll/admitsの向きと行個数を閉じる | .28/.30/.32 | 45〜100分（接続） | K/W-L |
| L20.38・G03 | 全束縛の型置換マップ | `TypeSubstContracts.lean`、`TypeSubstCalls.lean` | S02のextend/hide/params/clause/failure | 値+1/n/n+1/2と型+k/1、Phi/R/Lのマップを作り、31位置表を同じ相互族のIHへ渡す | .34/.36/.37 | 30〜75分（接続） | K/W-L |
| L20.39・G03 | 型置換 V_Var/Const と閉じた単純値 | `TypeSubstTyping.lean` | S02_V | V_Var/V_Const/V_PathBases/V_ScopePattern/V_Bytes の5caseをIH付きで閉じる | .38 | 30〜55分（証明） | K/W-L |
| L20.40・G03 | 型置換 lambda と実行閉包 | `TypeSubstTyping.lean` | S02_V/S02_Closure | V_Lam/V_DependentLam/V_Closure の3case。値束縛と閉じた実行データを分ける | .39 | 45〜90分（証明） | K/W-L |
| L20.41・G03 | 型置換 関数参照と操作 | `TypeSubstTyping.lean` | S02_V | V_Fun/V_Prim/V_Op/V_ExternalRef の4case、Admissible等をQ'へ移す | .40 | 45〜90分（証明） | K/W-L |
| L20.42・G03 | 型置換 保持値と外部値 | `TypeSubstTyping.lean` | S02_V/S02_Witness | V_ExternalHandle/V_Checked/V_CheckedRequest/V_CheckedAt/V_AtError の5case。外のQと閉じたreqを分離 | .39〜.41 | 30〜55分（証明） | K/W-L |
| L20.43・G03 | 型置換 data/Map/Set/Dict | `TypeSubstTyping.lean` | S02_V | V_Con/V_Map/V_Set/V_Dict の4case。tappの実型像とnominal欄を形成補題で合わせる | .42 | 45〜90分（証明） | K/W-L |
| L20.44・G03 | 型置換 場所・raise・super | `TypeSubstTyping.lean` | S02_V | V_Raise/V_LocRef/V_LocLazy/V_Super の4case。Ψの閉じた型の不変性を使う | .43 | 30〜55分（証明） | K/W-L |
| L20.45・G03 | 型置換 List/Sub/Normal/Refine | `TypeSubstTyping.lean` | S02_V | V_List/V_Sub/V_Normal/V_Refine の4case。toTerm/Pred.open/正規化の交換を使う | .44 | 45〜90分（証明） | K/W-L |
| L20.46・G03 | 型置換 CQ builder/ret/let | `TypeSubstTyping.lean` | S02_C | C_BuilderLet/C_BuilderOp/C_Return/C_Let の4case。Q'/RowTransportを結論へ渡す。C_MethのTel.argumentsのasとC_ExternalのTel.bindも名指しで移す | .42〜.45 | 30〜55分（証明） | K/W-L |
| L20.47・G03 | 型置換 CQ app/if/match | `TypeSubstTyping.lean` | S02_C | C_App/C_DependentApp/C_If/C_Match の4case。Q'/RowTransportを結論へ渡す。C_MethのTel.argumentsのasとC_ExternalのTel.bindも名指しで移す | .46 | 45〜90分（証明） | K/W-L |
| L20.48・G03 | 型置換 CQ lazy/escape/use/handle | `TypeSubstTyping.lean` | S02_C | C_Lazy/C_Escape/C_Use/C_Handle の4case。Q'/RowTransportを結論へ渡す。C_MethのTel.argumentsのasとC_ExternalのTel.bindも名指しで移す | .47 | 45〜90分（証明） | K/W-L |
| L20.49・G03 | 型置換 CQ Fail/resume | `TypeSubstTyping.lean` | S02_C | C_Handle_Fail/C_Resume/C_ResumeL/C_ResumeNorm の4case。Q'/RowTransportを結論へ渡す。C_MethのTel.argumentsのasとC_ExternalのTel.bindも名指しで移す | .48 | 45〜90分（証明） | K/W-L |
| L20.50・G03 | 型置換 CQ norm/meth/external | `TypeSubstTyping.lean` | S02_C | C_ResumeLNorm/C_Normal/C_Meth/C_External の4case。Q'/RowTransportを結論へ渡す。C_MethのTel.argumentsのasとC_ExternalのTel.bindも名指しで移す | .49 | 30〜55分（証明） | K/W-L |
| L20.51・G03 | 型置換 CQ issue/at/Sub/Eff | `TypeSubstTyping.lean` | S02_C | C_IssuePathBases/C_CheckAt/C_Sub/C_Eff の4case。Q'/RowTransportを結論へ渡す。C_MethのTel.argumentsのasとC_ExternalのTel.bindも名指しで移す | .50 | 30〜55分（証明） | K/W-L |
| L20.52・G03 | 型置換 腕 nil/plain | `TypeSubstTyping.lean` | S02_Arms | nil/plainの2case。excludedFactsとδのbindParamsを区別する | .46〜.51 | 30〜55分（証明） | K/W-L |
| L20.53・G03 | 型置換 guard と真の本体 | `TypeSubstTyping.lean` | S02_Arms | guardedの1case。元Φの後続、真のpの本体、hideContsのguardを移す | .52 | 45〜90分（証明） | K/W-L |
| L20.54・G03 | 型置換 操作節とFail節 | `TypeSubstTyping.lean` | S02_Clauses/S02_Failure | Clauses nil/consとFailure oneの3case、k/n+1/2と元sg.WFを供給する | .53 | 45〜90分（証明） | K/W-L |
| L20.55・G03 | 型置換 Vs/Each の4case | `TypeSubstTyping.lean` | S02_Vs/S02_Each | 各nil/consの4caseをIH付きで閉じる | .39〜.54 | 30〜55分（証明） | K/W-L |
| L20.56・G03 | 型置換 TelArgs/TelBody の4case | `TypeSubstTyping.lean` | S02_Args/S02_Body | 各done/paramの4case。Tel.argumentsEnvとΓ.extendを移す | .55 | 45〜90分（証明） | K/W-L |
| L20.57・G03 | 型置換 Capture/DependentClosure | `TypeSubstTyping.lean` | S02_Capture/S02_Closure | 各mkの2caseは恒等結論。内側Qemptyと閉じたt/bodyを変更しない | .56 | 30〜55分（証明） | K/W-L |
| L20.58・G03 | 型置換 Witness/AtCall | `TypeSubstTyping.lean` | S02_Witness/S02_At | plain/request/mkの3case。Atの型付き3子はQ'、Witnessは恒等 | .57 | 30〜55分（証明） | K/W-L |
| L20.59・G03 | 型置換 ImageOk 四場合 | `TypeSubstTyping.lean` | S02_Image（True） | ImageOkの4caseのmotiveはTrueとする。contLocの格納Rを正規化した型へ写す言明を作らない。CaptureOkの恒等は元の証拠を返す | .58 | 45〜90分（証明） | K/W-L |
| L20.60・G03 | 14成分76case の一括合成 | `TypeSubstTyping.lean` | S02 全署名 | 先の全case補題を単一recursorへつなぎ、4実呼出しで公開入口を使用する。未証明mainを仮置きしない | .59 | 45〜90分（証明） | K/W-L |
| L20.61・G04 | q_monoの14成分のmotive | `ContextTransport.lean` | S04 | Qを持つ11成分/閉じた3成分の署名とNoFail/Admissibleの単調性を固定する。型置換のImage=Trueと混同しない | .25〜.27 | 30〜45分（定型） | K/W-L |
| L20.62・G04 | q_monoの定型の相互帰納 | `ContextTransport.lean` | S04 | 一つのrecursorの76caseを定型の規則再構成で埋める。Qemptyの固定成分は恒等。時間はcase数でなく補助の種類で見積もる | .61 | 45〜75分（定型） | K/W-L |
| L20.63・G04 | q_monoの全入口と接続 | `ContextTransport.lean` | S04 | 11公開入口と閉じた成分の恒等を合成しC_CheckAtと節のNoFailに実際に適用する。全既定buildと署名を確認する | .62 | 30〜50分（定型） | K/W-L |
| L20.64・G04 | 捕捉のhideとrename | `ContextTransport.lean`、`CaptureRegularity.lean` | S04/S05 | hideConts_any/store_extend/shift0からhideBuilders、Rの変更、閉じた実行データを分ける。任意改名は正規化値置換で述べる。normConts/builderBody_image_norm/CaptureOk.normContsを予定する補題として明示し、旧の正規化と任意captureの結果を接続する | .61〜.63 | 30〜45分（包装） | K/W-L |
| L20.65・G04 | Regularの全形成 | `ContextRegularity.lean` | S01/S04・Ctx.Regular保存 | hideConts/bindParams/extendNone/shiftE/OpSig.context/failureContextの6操作を閉じる。OrderedとNoneの非可読性を維持する。O167拒否例reject_forward_or_cyclic_contextを置く | .38/.64 | 30〜60分（証明） | K/W-L |
| L20.66・G04 | 開いた値と列の全結果形成 | `CaptureRegularity.lean` | S01/S01a | 群AのmotiveでV29/Vs2/Each2を完成。空Eachへ形成を要求しない | .04〜.07/.65 | 30〜75分（接続） | K/W-L |
| L20.67・G04 | 開いた計算と腕の全結果形成 | `CaptureRegularity.lean` | S01/S01a | CQ24/Arms3/TelArgs2の全結果形成を完成。型置換本体に依存しない補助で閉じる | .66 | 30〜75分（接続） | K/W-L |
| L20.68・G04 | 捕捉による結果と効果の合成 | `CaptureRegularity.lean` | S01/S01b | cap.substOk.annotationによる閉じた系と全状態葉への効果供給を閉じる。CaptureOk.normContsも全使用先で確認 | .67 | 30〜75分（接続） | K/W-L |
| L20.69・G04 | 局所文脈と戻り先の橋 | `ContextTransport.lean`、`LocalTyping.lean` | S04 | local_zero4/withReturn4を閉じ、ValueAssumptionsを足さない。最初19件の標本には数えない | .61〜.68 | 30〜45分（包装） | K/W-L |
| L20.70・G04 | 合同と文脈補題の閉鎖表 | `ContextTransport.lean`、`LocalTyping.lean` | S04/subst_congr | 本番のsubst_congrを証明し、q_mono/store/hide/rename/localRefs/withReturn/K_Subの全読者・根拠の閉鎖表をresultsに置く | .69 | 30〜45分（包装） | K/W-L |
| L20.71・G01 | closeValの通常値とcallable | `CloseTyping.lean` | S05・通常値の枝 | 捕捉した型・行の注釈と既存V葉を使い、fnRef/prim/op/raiseの同じ契約を返す。Vs/EachのIHを用意する | .66〜.68/.69〜.70 | 60〜150分（接続） | K/W-L |
| L20.72・G01 | 通常lambdaのcloseから実行閉包 | `CloseTyping.lean` | S05 | V_Lamの元body/cap、NamesWF/RuntimeShape、入出力注釈と局所参照を保持して閉包を構成する | .71 | 60〜150分（接続） | K/W-L |
| L20.73・G01 | 依存lambdaと既存closureのclose | `CloseTyping.lean` | S05 | V_DependentLam/V_ClosureをcloseTel/DependentClosureTyの同じ契約に合わせ、捕捉を捨てない | .72 | 60〜150分（接続） | K/W-L |
| L20.74・G01 | close型保存のSub | `CloseTyping.lean` | S05 | V_Subの元のIH・LeQのbind・閉じた結果の形成を合わせる。意味の包含で代用しない | .72〜.73/.55〜.60 | 45〜90分（接続） | K/W-L |
| L20.75・G01 | close型保存のNormal | `CloseTyping.lean` | S05 | V_Normalの正規化とcloseの交換を既存補題で閉じる。恒等と正規形の等号を区別する | .74 | 30〜55分（証明） | K/W-L |
| L20.76・G01 | close型保存のRefine | `CloseTyping.lean` | S05 | V_RefineのtoTerm/Pred.open/観測/factsの真を移し、結果の篩を保つ。新Cのkindを捨てない | .75 | 60〜150分（接続） | K/W-L |
| L20.77・G01 | close V/Vs/Eachの一括合成 | `CloseTyping.lean` | S05 | 全33caseのcase補題を一つの族へ合成する。空Eachの形成を要求せず、保持値・Witness・V_Raiseの新前提を全読者へ渡す | .76 | 45〜105分（接続） | K/W-L |
| L20.78・G01 | Closure.viewの全契約 | `ClosureViewTyping.lean` | S05・Comp16構文形 | 一歩で閉じる値と残す子コードを各形で分ける。closeVal_observation/closeVal_resolvedから実行との一致を得る | .74〜.77 | 60〜150分（接続） | K/W-L |
| L20.79・G02 | 零引数と残る入力列 | `ClosureApply.lean` | S06・arity0 | ss/Rの具体化を固定し、零引数の同じcap/codeを保つ。Rの代入と非依存列の限定を確認する | .78 | 30〜75分（接続） | K/W-L |
| L20.80・G02 | 多引数の逐次具体化 | `ClosureApply.lean` | S06・TelArgs done/param | Capture.instantiate/extendTelで全vsのTelArgsと結果a/eを合わせる。依存する後続を実引数ごとに具体化する | .79 | 30〜75分（接続） | K/W-L |
| L20.81・G02 | 任意捕捉のClosure.apply | `ClosureApply.lean` | S06・TelBody2/CaptureLocals | 任意Γ/Φ/capでapply_allと依存版を閉じる。ρ/RsをcloseRAtで移し、入力のない結果も扱う | .80 | 45〜100分（接続） | K/W-L |
| L20.82・G02 | let/returnとmark | `ClosureStateLeaves.lean` | S06/S10・Let/Return/Mark | 任意の型付きvでK_Letを適用しret_value/markPushへ接続する。依存Rのshiftを消す根拠を示す | .81/.69〜.70 | 30〜45分（包装） | K/W-L |
| L20.83・G02 | 関数・メソッドと辞書 | `ClosureStateLeaves.lean` | S02/S06・Fun/Meth/Super | Def/Implの本体にts又はss++tsと辞書vs++wsを正順で渡す。QTelの代入前後を等号で合わせる。O136用dependent_result_closeを公開し、値依存端点とΦのlen関係がclose/substの両順で同じになることを証明する | .55〜.60/.81/.29 | 45〜100分（接続） | K/W-L |
| L20.84・G02 | 依存βの全葉 | `ClosureStateLeaves.lean` | S06/S10・E_Lam | 任意cap/零・多引数の葉を固定σ/Ebへ戻す。L40のcallable逆転とL70へ各前提の供給元を渡す | .82/.83 | 30〜75分（接続） | K/W-L |
| L20.85・G09 | 意味移送のrefl/convert/trans | `MeaningTransport.lean` | S07・四族のmotive | 正規化と相互IH付きcase補題を閉じる。transの中間型の注釈を新しい入力にしない | .25〜.27/.55〜.60 | 30〜75分（接続） | K/W-L |
| L20.86・G09 | 意味移送のdata/List | `MeaningTransport.lean` | S07・data/list/TypeArgs | variance_field_monoと値の子への下降を合わせる。kindと欄形成を新しい信頼条件にしない | .85 | 45〜100分（接続） | K/W-L |
| L20.87・G09 | 意味移送の篩と範囲 | `MeaningTransport.lean` | S07・forget/introduce/refine/scoped | Entails.soundにfacts/Φの真を渡す。既存ScopedValue.covers/forgetを再使用し、評価不能を真にしない | .86 | 45〜100分（接続） | K/W-L |
| L20.88・G09 | 全部分型の意味移送 | `MeaningTransport.lean` | S07・全22規則 | fn_effect/lazy/map_value/TelLe/TelClosureの残枝を閉じ、一つの相互帰納を完成する | .85〜.87 | 45〜100分（接続） | K/W-L |
| L20.89・G09 | 型付けから意味の基本値 | `TypedMeaning.lean` | S07 | V29の基本/定数/保持/場所のcaseを既存の意味の定義で閉じる | .88 | 30〜75分（接続） | K/W-L |
| L20.90・G09 | 型付けから意味の構造値 | `TypedMeaning.lean` | S07 | data/List/Map/Set/DictとVs2/Each2の子を使う。RootShapeを新しく仮定しない | .89 | 30〜75分（接続） | K/W-L |
| L20.91・G09 | 型付けから意味の篩と部分型 | `TypedMeaning.lean` | S07 | V_Refineは観測/Entails.sound、V_Subは全意味移送、Normalはnorm_iff。33caseを一度合成 | .90 | 30〜75分（接続） | K/W-L |
| L20.92・G09 | 捕捉・腕の意味の入力 | `TypedMeaning.lean` | S05/S07/S08 | 任意closeValの閉じた型付けから意味を供給しmeaning_coverage/variable_coverageへ接続する。進行を循環使用しない | .74〜.77/.89〜.91 | 30〜75分（接続） | K/W-L |
| L20.93・G09 | Inhabitsの全入口 | `TypedMeaning.lean` | S07・inhabits_of_typed/raw | 意味からの既存系とnorm_all_iffで二系を閉じる。Month/空型/非空List/unknownへ全定理を実際に適用する | .89〜.91/.92 | 30〜75分（接続） | K/W-L |
| L20.94・G06 | 変数・篩・変換の束縛 | `PatternBindings.lean` | S08・Var/Refined/Convert | v:a.normからδ.map normを結論する。rawδへ不当に強めず、変換前後のprefixの事実を供給する。既存RootShape/rootShape_of_typingを使い、PatTy前提から必要なrootの形を供給する | .93/.66〜.68 | 30〜60分（証明） | K/W-L |
| L20.95・G06 | List・dataの束縛 | `PatternBindings.lean` | S08・残PatTy/PatTys | before/rest/afterと欄に下降し値の型付け・長さ・Groundを得る。型の大きさと導出への下降を分ける。O143用pattern_length_relationとして元list・保持element・lenの同じ観測の関係を結論する | .94 | 45〜100分（接続） | K/W-L |
| L20.96・G06 | 代替パターンの全束縛 | `PatternBindings.lean` | S08・AltsTy/selectSlots | 選択した代替の束縛列と名前の順列を型に写す。全照合成功に正規形の値列を供給する | .95 | 30〜75分（接続） | K/W-L |
| L20.97・G06 | 照合結果から捕捉を延長 | `MatchStateLeaves.lean` | S08・CaptureOk延長 | δの注釈と閉じた値・factsでextendManyを構成する。既存extend/extendTelを使う | .96/.81 | 30〜45分（包装） | K/W-L |
| L20.98・G06 | 任意束縛のMatchBody | `MatchStateLeaves.lean` | S10・Match/Skip/Body | δ=0の代表を任意δ/ρ/capへ一般化しMatchPrefix/Closed/Adequateと同じobsを保持する | .97 | 30〜45分（包装） | K/W-L |
| L20.99・G06 | guardと後続腕の全葉 | `MatchStateLeaves.lean` | S10・MatchGuard/GuardT/F/Err/Exit | GuardBodyTyを任意δで構成し真のpは本体だけへ渡す。guardの否定を後続の事実にしない。O167拒否例 reject_guard_unknown_elimination/reject_false_fact_to_tail を本番の補助入力へ置く | .98/.69〜.70 | 30〜75分（接続） | K/W-L |
| L20.100・G05 | handlerの分割 | `HandlerGeneral.lean` | S10・ContTy/HandlerFrameTy | split_handle/split_fail/resume_appendを任意capへ適用しK_Subの連鎖と同じ末尾Eb/Reを保つ | .84/.99 | 30〜75分（接続） | K/W-L |
| L20.101・G05 | 通常操作の全引数 | `HandlerGeneral.lean` | S10・Handle/HRet/Op | operation_oneを任意引数列へ広げcapture_tel/result_telとclose型保存を使う。ret_constの限定を外す | .100 | 30〜75分（接続） | K/W-L |
| L20.102・G05 | 多相節・辞書の入力 | `HandlerGeneral.lean` | S02/S10・E_Op | 実際のts/dictParamsを節のC/contextへ代入しn+1/kのshiftとOrdinaryを実際の呼出しから得る。範囲外変数を行に持つHandle→Opの全保存の葉を含め、NoFailのcutoffを実像で確認する | .101/.55〜.60 | 45〜100分（接続） | K/W-L |
| L20.103・G05 | 組込み操作の範囲と効果 | `HandlerGeneral.lean`、`BuiltinEffects.lean` | S09/S10・E_OpPrim | ShapeOk/BuiltinArgsからinst_eff_mem相当を導く。ClauseRangeIs/opSigAtのSと具体化後e、末尾被覆を合わせる。Core.admits_satとio_opをE_OpPrimの全保存へ実際に使用する | .102/.28 | 45〜100分（接続） | K/W-L |
| L20.104・G05 | 失敗節と結果型の像 | `HandlerGeneral.lean` | S02/S10・E_OpFail | V_Raiseの新前提から結果型Tのvalue kind、像[T]にsat_unconstrainedを供給し型1/値2とNoneのlocをextendHiddenで保つ | .102 | 45〜100分（接続） | K/W-L |
| L20.105・G05 | 任意保存継続のresume | `HandlerGeneral.lean` | S10・E_Resume | StoreOkのcont/resume_raw_returnと正規形からR一致を供給する。usedへ書き換えても場所型を保つ | .103/.104 | 30〜75分（接続） | K/W-L |
| L20.106・G05 | usedと再開失敗 | `HandlerGeneral.lean` | S10・E_ResumeErr | 使用済みセルの任意入力でerrorと残継続を型付ける。resume_constの成功を全場合の結果にしない | .105 | 30〜45分（包装） | K/W-L |
| L20.107・G05 | dropと解放継続 | `HandlerGeneral.lean` | S10・Drop/Esc/Err/Exit各2形 | used/cont双方でreleasesの順とStateの含意を閉じる。保存継続の型と末尾Ebを保つ | .106 | 30〜45分（包装） | K/W-L |
| L20.108・G05 | 解放とerror/exitのpop | `HandlerGeneral.lean` | S10・use/relとhandleのpop | 既存DropRel葉とrelease_existsを使い任意資源値/元Rへ一般化する。正常/escape/error/exitと解放エラーを分ける | .107 | 30〜45分（包装） | K/W-L |
| L20.109・G05 | handlerの効果と全葉 | `HandlerGeneral.lean` | S10・handler17遷移 | EffectsOk/state_effectからnoStateHandledを供給し、宣言効果→具体化後効果をL70のeffect/target両読者へ渡す | .103〜.108 | 30〜75分（接続） | K/W-L |
| L20.110・G07 | builderの全セルと局所参照 | `BuilderStateLeaves.lean`、`LocalTyping.lean` | S04/S10・builder3遷移 | string/list/bytesと上限・localRefsを閉じ、resolveLocals_builderSubstで元codeと実行codeを結ぶ | .69〜.70/.74〜.77/.109 | 45〜100分（接続） | K/W-L |
| L20.111・G07 | fresh・領域・セル更新 | `StoreGeneral.lean` | S10・StoreOkの5操作 | finite/domain/Declared/WF/Sortedを保つ汎用putを作る。既存allocateは引用し空き場所の存在を供給する | .110 | 45〜100分（接続） | K/W-L |
| L20.112・G07 | 継続とセルの全不変条件 | `ContinuationGeneral.lean` | S10・ContTy10/CellOk6 | name_end_ix/mono_end/framesOk/drop_releasesとFrame/Cont/Cell.localRefsをcapへ接続し既存ContTy.storeを使う | .111/.109 | 45〜100分（接続） | K/W-L |
| L20.113・G07 | Reference/Lazyの一般値 | `StateLeaves.lean` | S05/S10・Reference4/Lazy6 | closeValされた任意値とclosureを既存四葉/Lazy葉へ渡し、done再書戻しとerror/exitを覆う | .112/.84 | 30〜75分（接続） | K/W-L |
| L20.114・G07 | δ・At・externalの接続 | `StateLeaves.lean` | S10・δ5/At等8遷移 | BuiltinArgs/ExternalArgs/AtPreparedのソース入力から同じStoreOk/ContTyへ戻す。実応答の葉はL40/L50/L60で供給する。G08のPreparation.leanのInitialPrepared/InitialPrepared.ready/PathEnv.Readyを固定σ/Program.ExternalWFの下で接続する。外部応答の存在はL60、表層から開始への合成はL70 | .113/.28 | 45〜100分（接続） | K/W-L |
| L20.115・G07 | 全76葉と開始分解の対応 | `StateLeaves.lean` | S10・let/if/mark/pop等全表 | 残りの制御葉を閉じ、LeafInputsとL40の逆転を突き合わせる。行先の型付けを仮定した葉を受け入れない | .82/.99/.109/.114 | 30〜75分（接続） | K/W-L |
| L20.116・G07 | stepの応答・空き場所 | `StepLeafSelection.lean` | S10・選択の補助 | step_prim_val/step_prim_err/io群とoracle条件、release_exists/freshを接続する。全step_soundはL70、逆の完全性は追加しない | .115/.111 | 30〜75分（接続） | K/W-L |
| L20.117・G07 | 関数viewの支持条件 | `FunctionViewGeneral.lean` | S05/S10・fnViewWith/foldFnWith | 支持付き一致を使う。支持なし版は同位置の原子関数の等号で閉じる場合だけ追加し、他は支持を供給する。NamesWF/名前の一意性を保持し、観測のtermBind?成功/getD既定値非到達を証明する | .116 | 45〜100分（接続） | K/W-L |
| L20.118・G07 | 独立評価と実行の関係の署名 | `IntervalConnection.lean` | S11 | EvalPartial/Block/Arms と実行環境・コード・値の関係を定義しnormal/returnedを分ける。主定理を仮定にしない | .115/.93 | 45〜150分（接続） | K/W-L |
| L20.119・G07 | 独立評価の return の接続 | `IntervalConnection.lean` | S11 | returnedの型/値/戻り先とmarkを対応づける。既存normalToSharedとの同値を保持 | .118 | 45〜150分（接続） | K/W-L |
| L20.120・G07 | 独立評価の let の接続 | `IntervalConnection.lean` | S11 | 束縛環境とcapture.extendを合わせ、後続の関係を実評価で証明する | .119 | 45〜150分（接続） | K/W-L |
| L20.121・G07 | 独立評価の腕の接続 | `IntervalConnection.lean` | S11 | 照合/guard/nextと独立評価の腕を合わせる。算術/δの葉とfailedはL40 H04への入力を残す | .120 | 45〜150分（接続） | K/W-L |
| L20.122・G07 | failedの条件と引継ぎ | `IntervalConnection.lean` | S11・J04 | failed所属の量化・入力・未証明箇所を固定し束縛/戻り先の対応を閉じる。L40 H04へ完全署名を渡し、前提変更が必要なら停止 | .118〜.121 | 45〜150分（接続） | K/W-L |
| L20.123・G10 | 埋め込みの帰納の骨格 | `LegacyTyping.lean` | G10・LegacyOutputInput.node | 七結論を∀Φに一般化したmotiveと全46caseのIHを固定し、root/childのkind/nvをnodeから射影する | .55〜.60/.69〜.70/.29 | 30〜60分（証明） | K/W-L |
| L20.124・G10 | 空の局所文脈のk=0橋 | `LegacyTyping.lean` | S04/G10・local_zero | 旧extend空と新none列を合わせ、ValueAssumptionsなしの入口を実際のlet/腕へ適用する | .123/.69〜.70 | 30〜45分（包装） | K/W-L |
| L20.125・G10 | 旧から新のパターン | `LegacyPatterns.lean` | G10・PatTy/PatTys/AltsTy | NodeTypesとconstructor表から三定理を証明し、子の拡張Γからδの適格性を作る | .124/.34 | 45〜100分（接続） | K/W-L |
| L20.126・G10 | checkedAtの照合の対応 | `LegacyPatterns.lean` | G10・Inhabitsの対応 | checkedAtOpaqueと入れ子List/dataで旧checked/opaqueと同じ成否を示す。範囲深さ0を外さない | .125/.93 | 45〜100分（接続） | K/W-L |
| L20.127・G10 | atErrorの七文字列 | `LegacyPatterns.lean` | G10・atErrorの対応 | 標準At構成子と七文字列、constructor名・型引数・束縛列を照合する。値の像の等号に替えない | .126 | 30〜45分（包装） | K/W-L |
| L20.128・G10 | 条件付き旧網羅性 | `LegacyPatterns.lean` | G10・embedExhaustive | 全新Inhabitsを.126/.127へ渡し、旧Exhaustiveから同じpsの成功を構成する。無条件の含意の反例を保つ | .127 | 45〜100分（接続） | K/W-L |
| L20.129・G10 | 旧var/const/bytes | `LegacyTyping.lean` | G10・V_Var/V_Const/V_Bytesの3枝 | 元nodeと既存embed_const/embed_bytesを使い、任意Φでcase補題を閉じる | .128 | 30〜45分（包装） | K/W-L |
| L20.130・G10 | 旧fun/prim/op | `LegacyTyping.lean` | G10・V_Fun/V_Prim/V_Opの3枝 | kind表・片方向の表対応・署名の置換を供給し、dependentFnと旧fn像を正規化等号で合わせる | .129/.37 | 30〜45分（包装） | K/W-L |
| L20.131・G10 | 旧lambdaの本体 | `LegacyTyping.lean` | G10・V_Lamの1枝 | 子の∀ΦのIHをbindParams/hide/liftへ特殊化しNamesWFとarityを供給する | .130/.124 | 45〜100分（接続） | K/W-L |
| L20.132・G10 | 旧集合と辞書 | `LegacyTyping.lean` | G10・Con/List/Map/Set/Dictの5枝 | 各子の形成/SatAllをnodeと表から取り、正規化鍵の制約と名目data欄を合わせる | .131 | 45〜100分（接続） | K/W-L |
| L20.133・G10 | 旧場所・保持値・raise | `LegacyTyping.lean` | G10・LocRef/LocLazy/Checked/CheckedRequest/Raiseの5枝 | Ψと同じ対象/要求/端点を保ち、CheckedRequestの子を空Φへ直接特殊化する | .132 | 45〜100分（接続） | K/W-L |
| L20.134・G10 | 旧superと部分型 | `LegacyTyping.lean` | G10・V_Super/V_Subの2枝 | embedLeと結果のAnnotationで任意Φの値19枝をそろえる。意味の包含で代用しない | .133 | 45〜100分（接続） | K/W-L |
| L20.135・G10 | 旧値列と同型列 | `LegacyTyping.lean` | G10・Vs_nil/cons・Each_nil/consの4枝 | 子のIHを同じΦへ適用し長さを合わせる。空Eachの型の形成はnodeから得る | .134 | 30〜45分（包装） | K/W-L |
| L20.136・G10 | 旧returnとlet | `LegacyTyping.lean` | G10・C_Return/C_Letの2枝 | 中間型・拡張Γ/R/Lをnodeから取り、k=0で新localExtendへ移す | .135/.124 | 30〜45分（包装） | K/W-L |
| L20.137・G10 | 旧appとmeth | `LegacyTyping.lean` | G10・C_App/C_Methの2枝 | 旧fnを新依存呼出し又は正規化fnに合わせ、辞書・ss/ts・代入前Qを一致させる | .136/.37 | 45〜100分（接続） | K/W-L |
| L20.138・G10 | 旧ifとmatch | `LegacyTyping.lean` | G10・C_If/C_Matchの2枝 | 追加ΦへIHを直接特殊化し、obs=none/条件付き網羅性/束縛δのnode入力を使う | .137/.128 | 45〜100分（接続） | K/W-L |
| L20.139・G10 | 旧lazy/escape/use | `LegacyTyping.lean` | G10・3枝 | hide/R=noneと実際のR、資源値の保持を合わせる。useのnvは増やさない | .138 | 30〜45分（包装） | K/W-L |
| L20.140・G10 | 旧builder/handler/resume/Sub/Eff | `LegacyTyping.lean` | G10・残CQ8枝 | BuilderLet/Op、Handle/Fail、Resume/ResumeL、Sub/Effを閉じ、新結論を入力へ足さず形成を供給する | .139/.36/.37/.69〜.70 | 45〜100分（接続） | K/W-L |
| L20.141・G10 | 旧腕の3規則 | `LegacyTyping.lean` | G10・Arms_nil/plain/guarded | 空腕の注釈、guardの真の篩、任意Φ、obs=noneの空factsとlocalExtendを照合する | .140/.124 | 30〜45分（包装） | K/W-L |
| L20.142・G10 | 旧節と失敗節 | `LegacyTyping.lean` | G10・Clauses_nil/cons・Failure_one | 元署名を操作自身のC/κで検査し実際のSへ渡す。Failの型1/値2を∀ΦのIHで閉じる | .141/.37 | 45〜100分（接続） | K/W-L |
| L20.143・G10 | 七判断46規則の合成 | `LegacyTyping.lean` | G10・七つの完全署名 | case補題を一つのnode帰納へつなぎhandoffの全引数で七定理を閉じる。空Φは系とし欠け0を確認する | .129〜.142 | 45〜100分（接続） | K/W-L |
| L20.144・G10 | LegacyStateInputの全定義 | `LegacyStateInputs.lean` | G10・状態4/frame7/cell6 | 旧導出に沿いコードと全中間型を検査し循環ストアを展開し続けない。新StateTy/HasType/Stepを欄にしない | .143/.29 | 45〜100分（接続） | K/W-L |
| L20.145・G10 | 旧frameと継続 | `LegacyStateTyping.lean` | G10・Frame7/旧ContTy10 | Closure.pureと空Captureでコードを型付け、Sub/Guard/handleの契約を合わせる。σ/Adequate/Lは入力から導く | .144/.112 | 45〜100分（接続） | K/W-L |
| L20.146・G10 | 旧セルと全ストア | `LegacyStateTyping.lean` | G10・Cell6/StoreOk | 全6形とfinite/domain/WF/Sorted/Declared/保持値を保つ。旧valと新a.normの差をconvertで閉じる | .145 | 45〜100分（接続） | K/W-L |
| L20.147・G10 | 旧状態4形 | `LegacyStateTyping.lean` | G10・embedStateTyE | run/matchRun/error/exitで同じEbとσ.Validを保ち、高階入力を具体化した完全定理を閉じる | .146 | 45〜100分（接続） | K/W-L |
| L20.148・G10 | 三親判断と段末照合 | `LegacyProgramTyping.lean` | G10/S09・関数/メソッド/上位辞書 | 全lookupで七定理を適用し、WellTyped/WellFormedの担当分と28+37行、A-L、段末レビュー・受入資料を完成する | .147/.29 | 45〜100分（接続） | K/W-L |

### G01〜G10の固定枠と積上げの対応

移管5〜9は固定枠へ一度だけ控除し、既済み分を含まない積上げから再控除しない。

| G行 | 単位 | 差引き前の固定枠 | 移管控除 | 固定枠の残分 | 本書の積上げ・所要時間（能動時間） |
|---|---|---:|---:|---:|---:|
| G01 | .71〜.78 | 4〜9時間 | 0時間 | 4〜9時間 | 7時間〜16時間40分 |
| G02 | .79〜.84 | 4〜8時間 | 3〜4時間 | 1〜4時間 | 3時間30分〜7時間50分 |
| G03 | .08〜.24、.30〜.60 | 8〜18時間 | 1〜2時間 | 7〜16時間 | 33時間30分〜75時間15分 |
| G04 | .01〜.07、.61〜.70 | 4〜10時間 | 0時間 | 4〜10時間 | 9時間30分〜18時間50分 |
| G05 | .100〜.109 | 6〜14時間 | 1〜3時間 | 5〜11時間 | 5時間45分〜12時間15分 |
| G06 | .94〜.99 | 3〜7時間 | 0時間 | 3〜7時間 | 3時間15分〜6時間40分 |
| G07 | .110〜.122 | 5〜12時間 | 0時間 | 5〜12時間 | 9時間〜24時間35分 |
| G08 | .28〜.29 | 1〜3時間 | 0時間 | 1〜3時間 | 1時間15分〜2時間40分 |
| G09 | .25〜.27、.85〜.93 | 4〜8時間 | 0時間 | 4〜8時間 | 7時間45分〜19時間40分 |
| G10 | .123〜.148 | 13〜29時間 | 0時間 | 13〜29時間 | 17時間15分〜35時間20分 |

固定枠はG01〜G09の39〜89から移管5〜9を控除して34〜80、G10の13〜29を加えた47〜109時間。積上げは97時間45分〜219時間45分。G04控除0、.02b-atはG03の保持値、.02b-closuresはG02を維持する。

| G10の区分 | 単位 | 元の配分 | 本書の積上げ・所要時間（能動時間） |
|---|---|---:|---:|
| 七判断46規則と合成 | L20.129〜.143 | 7〜14時間 | 9時間45分〜19時間30分 |
| 条件付きパターン・網羅性 | L20.125〜.128 | 2〜5時間 | 2時間45分〜5時間45分 |
| ∀Φ/局所文脈/子の入力 | L20.123〜.124 | 1〜3時間 | 1時間〜1時間45分 |
| 状態入力・frame/store/状態・三親判断 | L20.144〜.148 | 3〜7時間 | 3時間45分〜8時間20分 |




## 義務の一行ずつの対応

plan の担当にL20を含む28行と、L10Fの37行を照合する。証明・実装の完了ではなく**L20で何を閉じるかの判定案**である。証拠は担当単位の定理・入力・通常results、群のレビューと段末 `l20/results.md` へ集め、取りまとめがplanのO行へ段別に転記する。後段が残る義務を全体の閉鎖へ繰り上げない。

### plan のL20担当28行

| 義務 | 単位 | L20分の完了判定と証拠 | L20の後に残る段 |
|---|---|---|---|
| O002 | .30〜.60 | S02。四族22規則とCoversの既存移送を再使用し、コードの型/行/範囲/値の全接続を閉じる | L70の読者切替 |
| O003 | .61〜.63/.64/.69〜.70/.110〜.116 | S04/subst_congr と閉鎖表。q_mono/store/hide/rename/subst_congr/localRefs/withReturnとK_Subの閉鎖表（全読者・署名・供給元・使用先）で欠け0、.69〜.70でsubst_congr本体を証明 | L70の表層読者 |
| O004 | .08〜.22/.31/.32/.38 | S02。Nat/cutoffの束縛下交換、開いた像を閉じる交換を維持。時間と検査待ちを分離 | L70の切替。Natの再選択はしない |
| O006 | .08〜.22/.30/.32/.55〜.60 | S02。値依存の型/行像を除外せず、捕捉による閉じ方と型置換を全本体で接続 | L40の利用葉、L70の合成 |
| O007 | .31/.32/.55〜.60/.113 | S02/S05。Reference/Failの正規化後の等号をbind/置換が保つ。格納と読出しへ適用 | L40の構文逆転とδ |
| O008 | .66〜.68/.71〜.84/.110〜.115 | S05/S06/S10。任意closeVal/閉包/StoreOk/ContTyの葉を閉じる。環境を捨てる旧反例を保つ | L40の開始逆転、L70の主定理 |
| O029 | .32/.38/.61〜.70 | S02/S04。Γ/facts/ΦとNone、参照順序、型像による事実の移送を同じTransportへ供給 | L70の表層、R10bの収集 |
| O031 | .30〜.60 | S02。既存Le/Covers/V_Sub/C_Subと新コード型置換の相互族を全場合で閉じる | L70の主定理と読者 |
| O032 | .31/.32/.55〜.60 | S02。正規化と値代入の交換をReference/Failの等号位置へ接続 | L40の逆転の葉 |
| O038 | .01〜.03/.66〜.84/.97〜.116 | S00/S10。Store/Cell/Lazy/Cont/Stateの全葉を同じσ/Ebで閉じ、used/drop/builder/辞書/多相を覆う | L40/L50/L60の各応答の葉、L70の全保存 |
| O039 | .66〜.68/.74〜.77/.85〜.93 | S01/S07。構文Γから型付き像・観測・factsの真を導き、全値の意味の独立仮定を主定理へ足さない | L40のcanonical forms |
| O042 | .123〜.148 | S09/G10・embedStateTyE。適格な旧七判断46規則と全状態の片方向埋め込み。既定新旧importを保つ | L70の切替。embedStepは要求しない |
| O046 | .74〜.77/.92/.97〜.99/.115 | S05/S08/S10。閉じたif/Not/guard/matchのfactsと評価器の既存健全性を任意捕捉へ接続 | L40の算術/length/δの結果、L30の有限規則 |
| O050 | .30〜.60/.74〜.77 | S02/S05。全sortの観測と置換を交換し、関数/Reference/資源のeqを追加しない。Not noneはnone | L30の論理規則、L40の標準葉 |
| O051 | .01〜.03/.04〜.07/.24/.66〜.68/.74〜.77/.100〜.109 | S00/S01。三条件とImageOkからReference/Lazy/節/resumeの全使用先へ供給。導けなければ停止 | L40の逆転、L70の合成 |
| O053 | .38/.65/.66〜.68 | S01/S04。hideConts/bindParams/shiftE/OpSig.context/failureContextを含むRegularの6操作。後方依存と循環を通さない | L70/R10bのソース順序の照合 |
| O056 | .74〜.77/.82〜.84/.97〜.99 | S05/S06/S08。任意捕捉/一変数依存β/guard/腕の導出を構成。最外アダプタの代表に限定しない | L70の全表層 |
| O058 | .66〜.84/.100〜.116 | S02/S06/S10。依存代入・反変/共変・ストア拡張・全継続の固定Ebの葉を閉じる | L40/L50/L60の葉→L70保存 |
| O065 | .28〜.32/.66〜.68/.123〜.148 | S02/S09/G10。唯一未移行sig_scopedと全入力/全文脈/全埋め込み。旧読者12種と別枠二読者を処置 | L40の利用葉、L50/L60実表、L70切替 |
| O090 | 会計表/.118〜.121/.122 | S11 の配分表。運用：returnと共通値の余裕を既存G07/H04内へ一度割当て、段間の重複加算0 | L40/L70/R10b/R50。H04を全てL20へ移さない |
| O136 | .32/.55〜.60/.80〜.84 | S08a・dependent_result_close。依存列・結果代入・値依存端点/線形関係の移送を閉じる | L30含意、L40契約、L70→R10b/R20/R50→V10 |
| O138 | .74〜.77/.92/.97〜.99/.115 | S08/S10。真偽/構成子/非空factsと任意捕捉の閉じ方を保持。unknownで除かず暗黙動的検査なし | L30証明書、L40標準facts、L70/R10b静的合成→R50/V10 |
| O139 | .55〜.60/.72〜.73/.80〜.84 | S02/S05/S06。名前付き関数/lamの同じ依存引数・結果・潜在効果を型置換/捕捉/適用が保つ | L40逆転/反変、L70→R10b/R50→V10 |
| O140 | .55〜.60/.72〜.73/.83/.84 | S02_V/S02_C/S05/S06。高階の各位置の型/行/値の移送と名前/個数を維持。新しい不変位置の変換を許さない | L40 F3/canonical、L70→R10b/R40/R50→V10 |
| O143 | .32/.55〜.60/.80/.94〜.99 | S08a・pattern_length_relation。長さの関係を置換/引数具体化/束縛が保持する。任意の同長別listへの実契約は後段 | L40の標準契約、L70→R10b/R40/R50→V10 |
| O160 | .129〜.134/本番追随表 | G10・embedHasTypeVQ。運用：値19規則を本番に残し通常resultsでAと待ちを分ける。同種残27規則を区別 | L40は別種の通常記録を使用。比の一律適用なし |
| O167 | .08/.20〜.24/.30/.65/.66〜.68/.89〜.91/.99 | S01/S02/S07/S08/S12の拒否例。宣言value/constructorのtvarの双方向の不適合をS12.9で拒否し、DET-Lの移送に関する制限（非観測/None/循環/不変/unknown）を受理と拒否の対照で保持 | L30/L40/L70→各R段/V10。構文の拒否はL70/R60 |
| O169 | .118〜.121/.122 | S11。独立評価との束縛/戻り先の対応を閉じ、returned/failedの入力と数値一致の必要な葉を固定 | L40 H04の算術/δ/所属→L70主定理→R10b/R50 |

この28行は、証明・葉の担当26行、配分と通常結果の運用2行（O090/O160）である。26行をL20だけで全体閉鎖する意味ではない。O143の標準API、O138の表層での静的合成、O169の算術/δの本体は、L20の置換の完了だけでは閉じない。

### L10Fの37行の処分

A12/B16/C6/D1/E2はL10での分類として保存する。L20で再分類してその既済み分を消さない。L20への実作業は重複する7行とO005、共通の監査はEの2行、ほか27行は既済みの定義・葉・契約の継承又は他段の担当である。

| 義務・L10分類 | L20の処分・単位 | 完了の判定／後段へ分ける理由と残る段 |
|---|---|---|
| O011・A | 既済み継承・他段（新規L20単位なし） | 既存 LegacyValues.embed_const/embed_bytes。L40 の標準δ/正常結果の葉。新前提を置いただけでδを閉じない |
| O013・C | 既済み継承・他段（新規L20単位なし） | 既存 LegacyValues.embed_checked_opaque。本体は L50：typed shapeAt・TargetAgreement・io_exists と三モデル。L10 が全モデルを閉じる配分を訂正する |
| O015・B | 既済み継承・他段（新規L20単位なし） | S09 の入力の sort 対応。L30 の有限規則・論理への接続、L50 の所属と具体化の意味 |
| O035・C | 既済み継承・他段（新規L20単位なし） | S02_V/S10 の保持要求の入力。本体は L40 のδ・節、L50 の全δ/拡大/対象一致と存在。構成子追加は既済み |
| O042・A | 担当・.123〜.148 | S09/G10・embedStateTyE。適格な旧七判断46規則と全状態の片方向埋め込み。既定新旧importを保つ。残る段：L70の切替。embedStepは要求しない |
| O044・A | 既済み継承・他段（新規L20単位なし） | S09 の提供範囲の記録。L50 の対象の葉、D10 の公開文書の最終照合 |
| O049・A | 既済み継承・他段（新規L20単位なし） | 既存 LegacyValues.embed_checkedRequest。L50 のσ/対象の具体化、L60 の全モデル。L00b.13 の葉を作り直さない |
| O050・B | 担当・.30〜.60/.74〜.77 | S02/S05。全sortの観測と置換を交換し、関数/Reference/資源のeqを追加しない。Not noneはnone。残る段：L30の論理規則、L40の標準葉 |
| O065・A | 担当・.28〜.32/.66〜.68/.123〜.148 | S02/S09/G10。唯一未移行sig_scopedと全入力/全文脈/全埋め込み。旧読者12種と別枠二読者を処置。残る段：L40の利用葉、L50/L60実表、L70切替 |
| O076・A | 既済み継承・他段（新規L20単位なし） | S09 の新旧名前空間の区分。D10 の最終文書。旧名前空間の説明を誤って新規則へ書き換えない |
| O087・C | 既済み継承・他段（新規L20単位なし） | S09/S10 の Program.ExternalWF の入力。本体は L60/R50：実表、三条件、名目IDの交換と両除外0。L10へ実表実装を重ねない |
| O116・A | 既済み継承・他段（新規L20単位なし） | 既存 Budget.checkLimit_ok/checkLimit_error。L70 の最終切替と残る全読者検索 |
| O124・B | 既済み継承・他段（新規L20単位なし） | 既存 constOK_toApprox。L40→R10a/R10b/R40/R50→V10 の規則・実装・交換・CLI |
| O125・B | 既済み継承・他段（新規L20単位なし） | S09/S10 の Byte の入力。L40→R10b/R40/R50→V10 |
| O126・B | 既済み継承・他段（新規L20単位なし） | S09/S10 の character の入力。L40 の値域/比較の葉→R10b/R40/R50→V10 |
| O127・B | 既済み継承・他段（新規L20単位なし） | S09/S10 の charactersIn の入力。L30/L40 の有限規則/葉→R10b/R40/R50→V10。正規表現の一般判定を足さない |
| O128・B | 既済み継承・他段（新規L20単位なし） | S09/S10 の浮動小数の入力。L40 の特殊値/比較の葉→R10b/R40/R50→V10。一般算術を実数線形にしない |
| O129・B | 既済み継承・他段（新規L20単位なし） | 既存 constOK_toApprox。L40 の正常結果/丸めの葉→R10b/R40/R50→V10 |
| O130・B | 既済み継承・他段（新規L20単位なし） | S02/S05 の二つの文字列の観測。L30/L40 の関係と葉→R10b/R40/R50→V10 |
| O131・B | 既済み継承・他段（新規L20単位なし） | 既存 length_refinement_coverage。L30/L40 のmap/reverse/append/filter等の契約→R10b/R40/R50→V10 |
| O132・B | 既済み継承・他段（新規L20単位なし） | S02/S05 の bytesLength の観測。L30/L40 の非負/標準契約→R10b/R40/R50→V10 |
| O133・B | 既済み継承・他段（新規L20単位なし） | S02/S05 の mapSize の観測。L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10 |
| O134・B | 既済み継承・他段（新規L20単位なし） | S02/S05 の setSize の観測。L30/L40 の鍵の等値・大きさ/標準契約→R10b/R40/R50→V10 |
| O135・B | 既済み継承・他段（新規L20単位なし） | 既存 variance_field_mono。L30/L40 の合同・data変性・decode契約→R10b/R40/R50→V10 |
| O144・B | 既済み継承・他段（新規L20単位なし） | 既存 empty_refinement_exhaustive。L30/L40/L50→R20/R10b/R40/R50→V10。一般UF/SMT/量化/非線形/入れ子measureは追加しない |
| O159・A | 既済み継承・他段（新規L20単位なし） | 既存ImplDecl.WellTyped.method_bodyの定義は再実装しない。S12/.11のCの機械追随はL20で閉じ、L70 の主定理/交換/規範の切替と旧互換の利用者の確定 |
| O160・D | 担当・.129〜.134/本番追随表 | G10・embedHasTypeVQ。運用：値19規則を本番に残し通常resultsでAと待ちを分ける。同種残27規則を区別。残る段：L40は別種の通常記録を使用。比の一律適用なし |
| O167・B | 担当・.08/.20〜.24/.30/.65/.66〜.68/.89〜.91/.99 | S01/S02/S07/S08/S12の拒否例。宣言value/constructorのtvarの双方向の不適合をS12.9で拒否し、DET-Lの移送に関する制限（非観測/None/循環/不変/unknown）を受理と拒否の対照で保持。残る段：L30/L40/L70→各R段/V10。構文の拒否はL70/R60 |
| O169・A | 担当・.118〜.121/.122 | S11。独立評価との束縛/戻り先の対応を閉じ、returned/failedの入力と数値一致の必要な葉を固定。残る段：L40 H04の算術/δ/所属→L70主定理→R10b/R50 |
| O005・A | 追加の使用先・.55〜.60/.86/.102 | S02/S07 の既存 P.VarianceValid の使用。P.VarianceValidを全型置換/意味移送/全保存の葉で使用する。定義と欄単調性を再実装しない。L40利用葉、L70/R10bの収集の一致が残る |
| O033・A | 既済み継承・他段（新規L20単位なし） | 既存 VarianceValid.field_annotation。L40標準data/δ。L70/R10bで元の辞書制約/公開境界の全収集と変性を照合し、R50で接続。planのL10/L70追記は取りまとめ |
| O016・E | 共通・.148と各群 | S00〜S11 と G10 の A-L。A-Lで既存と新宣言の全依存を監査し許可三公理だけとする。独立レビューとL70合成は取りまとめ |
| O084・E | 共通・.148と各群 | S09/S10 の未完の区分。方式/前提/σ/externalの差と未完を記録し、例外と範囲を拡張しない。全L/R/Kの最終受入が残る |
| O037・C | 既済み継承・他段（新規L20単位なし） | S08/S09 と G10 の受渡し契約。担当はL70のまま。全表層literal/checker/脱糖の証明をL10で完了としない |
| O066・C | 既済み継承・他段（新規L20単位なし） | S03/S08 の受渡し契約。担当はL70/R50のまま。表層/交換の全実証と消去の観測は後段 |
| O079・A | 既済み継承・他段（新規L20単位なし） | 既存 CaptureOk.variable_coverage。L70/R10bはΓのlen(l)=nとΦのn>0から静的にscrutineeを強める。L30は有限の論理の証明書、R50は受理/拒否の接続 |
| O138・C | 担当・.74〜.77/.92/.97〜.99/.115 | S08/S10。真偽/構成子/非空factsと任意捕捉の閉じ方を保持。unknownで除かず暗黙動的検査なし。残る段：L30証明書、L40標準facts、L70/R10b静的合成→R50/V10 |

二つの元の表だけの小計は28+37−重複7＝**58義務**（追加の全L2行は次表）。重複はO042/O050/O065/O138/O160/O167/O169である。L20の証明・葉27（28行中26＋追加O005）、運用2、全L共通2、継承・他段27、合計58である。O037/O066/O079は同じ篩付き結果/効果と静的合成の契約を継承するが、表層の実装をL20へ移さない。O159の三WellTypedの定義は既済みであり、G08/G10がそれを使用することと、L70の最終切替を別に判定する。


### 全 L の追加の共通義務

| 義務 | 担当・完了の判定 | 残る段 |
|---|---|---|
| O027 | S10の葉の検査と各単位/群、 .148。検査表の RSS を本体と計測器・機械/OS・原単位・採取/引用/未取得へ分けて results へ記録する | 全 L の各段の記録。L20 で他段の未取得を埋めた扱いにしない |
| O118 | S00〜S11/G10の各実装と各単位/群、 .148。新 Lean コメントに作業IDを残さないことを文字検索し、説明は役割/規則/不変条件で書く | 全 L の最終の共通点検 |

28行＋37行−重複7＝58行に、O027/O118 を加えた対象は **60行**。L20 の証明・葉27行（plan26＋O005）、運用2行（O090/O160）、共通4行（O016/O084/O027/O118）、既済み継承又は他段27行である。L10F の元の A12/B16/C6/D1/E2 は変更しない。

## 本番追随の最初の同種19規則と残り27規則

最初の同種10〜20件は **G10 の旧値19規則**（群 P、.129〜.134）にする。旧七判断から新七判断へ同じ片方向の導出を構成する作業として、残り27規則と比較できる。旧値の全規則を前掲の G10 の規則表へ一対一に対応づける。q_mono14成分・local_zero4・withReturn4 は必要な通常の証明であり、この標本には加えない。

| 作業 | 同種の規則の数 | 単位・通常の results |
|---|---:|---|
| 値: Var/Const/Bytes | 3 | .129 |
| 値: Fun/Prim/Op | 3 | .130 |
| 値: Lam | 1 | .131 |
| 値: Con/List/Map/Set/Dict | 5 | .132 |
| 値: LocRef/LocLazy/Checked/CheckedRequest/Raise | 5 | .133 |
| 値: Super/Sub | 2 | .134 |
| **最初の本番分** | **19** | 群 P の結果から読む |
| 残り: Vs/Each4、CQ17、Arms3、Clauses2、Failure1 | **27** | .135〜.143。親判断/状態は別種類で外挿しない |

kind/表対応、∀Φ の帰納の骨格、条件付き PatTy/Exhaustive、局所文脈の橋が必要なので、この19規則は後の群 P で実装する。**依存がそろう前は、前半の補題や関門の時間で本番追随の見込みを更新しない。** .123 の骨格は区間接続 .118〜.121/.122 を待つ必要がなく、型置換/文脈・宣言入力から起動できる。群 P の19規則が完成したら、通常結果の外側の時間 E と分離できる待ち W を読み、能動時間 A=E−W とする。分離不能なら能動時間の実測値を作らない。共通骨格/パターンの時間を規則の単価へ重ねない。

n=19、N=27、c=A/19 は同じ移植群の通常の更新の入力になる。値と CQ で形が違えば内訳を示して相談し、平均を機械的に使わない。全型置換・意味の全帰納・全状態を N へ混ぜない。旧 L10 の支持の17件とは別在庫である。

残る通常の移植は、.110〜.117 の builder/fresh/localRefs と継続の全不変条件、.69〜.70 の subst_congr と閉鎖表、.135〜.148 の残27規則・全状態・三親判断である。既存 public store_extend と ContTy.store は新規移植の件数に足さない。

形が合わず旧言明をそのまま移せない場合は、旧言明・新判断の差、代替の完全署名・供給元・追加の見込みを取りまとめへ相談する。これは (1) 同種の通常記録による見込み更新、(2) 未承認の前提/結論変更・新公理・精密な外部状態・未知の旧除外の不一致による即時停止、(3) 各単位上端の2倍で原因を調べ報告しbuildが通る区切りで止める時間超過、を区別する。相談待ちに条件を強めて進めない。

## 骨格を固定する順序とL30との分離

群 A で入力・出力と相互の motive、群 B で sig_scoped と形成/交換、群 C でパターンの型置換を固定する。その後で一つのコード型置換族（D）、捕捉からの形成（E）、closeVal（F）、適用（G）、意味（H/I）、束縛と状態の葉（J〜N）、旧全埋め込み（O〜S）の順に進める。四族22規則の定義は変更しない。四本304枝は同じrecursorを保ち、S12の39枝の局所修正を先に閉じる。型置換・意味・埋め込みの各帰納を、数値/σ/external別に複製しない。

本書で予定する既存定義の実質的な変更は、採用済みS00のStoreOkの強化、S12の案4とV_Raiseのkind保持、固定したSignatureInstance.rowKinds、承認済みの未移行欄sig_scopedの追加である。実装前に次表を署名と一緒に確認する。

| 対象 | 変更の理由と範囲 | 波及する場合と防止するやり直し |
|---|---|---|
| LocTy.Sorted/StoreTy.Sorted/StoreOk（S00、.01〜.03） | 欠けていた場所の sort を状態の不変条件へ追加。r は対象外 | 8ファイル、直接7構成・hs再使用4状態・包装3宣言。typing構成子0/四移送304枝0。StateTyEの入力と出力に同じ条件。L30開始前に一括取込み |
| SourceScoped の配置（.28） | PrimSig.Scoped を ConstraintAssumptions より下に置く。現在 SourceScoped/RangesScoped は ProgramWellFormed にあり、そこから引くと ClosureTyping→SubstTyping→ConstraintAssumptions の循環を作る | `Ty.RangesScoped/Tel.RangesScoped/Eff.RangesScoped/rangesScopedTypes` と `Ty.SourceScoped/Eff.SourceScoped/BuilderKind.SourceScoped` の7定義を低い `SourceScope.lean` へ**同名・同じ式のまま**移す配置案。相互4関数のTy21/Tel2/List2/Eff1=26構文場合とBuilderKind3場合は意味不変。ProgramWellFormedと新PrimitiveScopedがそれをimport。全ての旧完全名を保つ |
| PrimSig.Scoped / CoreAssumptions（.28） | 型/行/範囲/値の深さとkindを持つ旧sig_scopedの移行 | 旧20欄の残1。新三モデルの全構築はL50/L60、主定理のCore射影はL70。既存の局所入力の構造体の構築と正例は同じ群で追随する。定義しただけでモデル充足を主張しない |
| VQ/CQ相互14判断76構成子（S12、L20.08〜.22） | CをTypeCtxに変更。V_RaiseにTのvalue kindを追加、Failureの型束縛をvalueParamへ | 新規構成子0、判断の引数の個数の追加0。四移送304枝中39枝の局所修正、外の明示arity4枝、基盤21宣言。再帰の族の作り直し0の見込みであり、全体のコンパイルは未確認。S02は10移送＋3恒等＋1Trueとして76場合を一度だけ証明 |
| TypeCtx/constraints/TypeArgsKinded/OpSig/TypeParamRenaming（S12） | kindを出現ごとに選べる穴を除く。生constraintsの保持7と型付けCの変更69を分ける | 全76出現と旧Cの11橋をS12.6で列挙。Ty/Tel/List/Effのkind像47枝は案1/4共通の一族。主な定理の言明の字面は変えず、前提が読む定義の中身をレビューする |
| SignatureInstance.rowKinds（S12.8、L20.17、固定した案） | 行像の.failにconstructorが入る欠けを防ぐ | 5から6欄へ、9構成で供給。型付け構成子の引数の追加0。RowAnnotations/Annotation一般とCore公理は強めない。元の読者で供給できなければJ20-2で停止 |
| Ty.Declared.tapp（S12.11、L20.10〜.16） | kind/引数数が注釈でも固定されるようにする | 意味を変える枝1、既存tapp証明4枝、公開shift補助7署名、旧context3署名と計11橋。型shift読者36枝、四移送の合計39枝。新しいAnnotation欄0。C=[]/WF0の捕捉とS00の追加変更0 |
| 部分型四族22規則、Inhabits/PatTy/Exhaustive、ContTy10 | 変更予定なし | **規則追加0**。意味の移送や既存正規化を補助補題で閉じる。捕捉の形成を理由にここを強める場合は群Aの停止条件 |
| 既存の十の主な移送の言明 | 値/型移動、値置換、None下、narrowingのV/C | 主な定理の言明の字面は維持する。CとTypeParamRenamingの中身のkind保持はS12の採用済みの変更としてレビューする。これを越える名前・引数の変更が必要と分かった時点で取りまとめへ返す。S02の新族の都合で置き換えない |

SourceScope の配置は低い層の import を点検した案である。今回、現行 `TypeRows→Admissible→KindValues` と `TypeSupport→TypeSubst` からの推移importを列挙し、TypeRowsの到達86モジュール、Admissibleの84、TypeSupportの73のいずれにも ProgramWellFormed/ConstraintAssumptions がないことを確認した。実装時は新しいimportを加えた後にも循環がないことを検査する。式を移すだけの変更と新しい Scoped の条件は別々に記録する。

| L20/L30の共有物又は分離できる物 | 扱い |
|---|---|
| Logic/Entails、Certificate、有限規則、EqProof | L30が担当。L20は既存 Entails.bind/cut/sound/closed と Transport を使用し、規則を増やさない。L30が規則を増やせばbind/sound等の読者の責任をL30の詳細へ名指しする |
| Types/KindValues/Typing/Admissible/HandlerContracts/TypeRenamingとS12の全C読者 | 群A3a〜A3cを先に取り込み、TypeCtxと署名が固定するまでL30と共有物の並行変更は不可。移送304枝の局所追随もここで閉じる |
| StoreTransport/StateTyping と StoreOk の全追随8ファイル | 群A1の変更を先に取り込み、新B_WORKをL30へ渡す。ここが重なる期間は並行不可 |
| SourceScope/PrimitiveScoped/ConstraintAssumptions、TypeSubstFormation/TypeValueExchange | 群Bの取込みと新しいB_WORKを先に固定。双方が同じファイルを変更する期間は並行不可 |
| 新しい TypeSubstTyping/CloseTyping/ClosureApply/HandlerGeneral/LegacyTyping 等 | 群Bの契約が固定され、L30の変更集合と交差がない部分だけ別機で並行できる候補。群Aの未確認を残したまま並行開始しない |
| Context/WF、Declared、Observation、ValueMeaning | 共有定義を変えると移送とL30の合同に両方波及する。変更を先に取り込み、基準を渡す。並行作業中に同じ定義を編集しない |
| formal/Benitoite.lean、01-12/07-04 | 共有の取り込み箇所。取りまとめが各群の更新を順に統合する。別機の担当には変更対象の正確な集合を渡す |
| L40 | L20の状態葉とL30の証明書/論理の双方を待つ。L20のLeafInputsとL40の逆転をL70で合成し、L20がL40の完成を待つ循環を作らない |

並行の可否は取りまとめの別機配置の判断である。本書が同じワークスペースで二担当を同時に動かす指示ではない。並行しても所要時間（能動時間）の合計を減らさない。

## 採用済みのkind変更・固定した案と分岐する判断

本下書きは新しい公理、提供範囲の変更、利用者の書ける形の制限、精密な外部状態を採用していない。StoreOkのS00と、Cへkindを保持する案4・V_RaiseのTのvalue kindは採用済みの見直し対象として独立に記録した。S12.8のrowKindsとS12.11のDeclaredのtappは、取りまとめが固定した案4の一部である。いずれも主な定理の言明の字面は変えず、前提が読む定義の中身をレビューする。独立の新しい信頼条件は追加しない。次は、方式の確認の結果次第で設計者へ戻す**条件付きの判断**であり、既に採用した変更ではない。

| ID | 分岐と判断を戻す条件 | 境界・実用への影響 |
|---|---|---|
| J20-1 | CaptureOk/ImageOk/StoreOkと既存の本体条件からS01を導けない。採用済みS00/S12の範囲を越える型付け規則・StoreOkの定義の変更、強いCtx.WF、継続効果の新条件、結果形成を主定理の独立入力にする必要が出る | StateTy/Program.WellTyped又は主定理の前提に触れる。単なる補助の署名の修正と区別する。現実の捕捉・resume・Lazyのどこが作れなくなるか反例とともに提示し停止 |
| J20-2 | S02の閉じた型置換と開いた像を閉じる交換では、全呼出しの実際の型/行像・tappの形成を供給できない | 案4・V_Raiseの変更自体は採用済みでありこの条件付き判断に留めない。S12.8の行像kindとS12.11のDeclaredの構造条件も固定した案に含む。新しいsat/admits保存則、S03の像の形成の独立前提、全中間型のkindの信頼入力、値依存像の禁止は未承認。禁止なら依存端点・長さ・高階の契約に影響し得るので対象例を添える。前提/提供範囲を勝手に変更しない |
| J20-3 | 入れ子の継続を含む像で保存が成り立たず、Ordinaryを再帰的に強める必要が出る | 型付けの受理範囲に触れる。contはソースの記法にないが、内部の入れ子を制限してもソースに影響しないことは別途証明が必要。多相関数・空List/data欄の具体的な受理差を示す。単純に「書けないから無害」として採らない |
| J20-4 | J04のfailed所属を述べるため、計画済みの入力条件では足りず主定理の前提追加・結論弱化・外部状態の精密化が必要になる | 正常値と警告の既存保証を維持する。全失敗の所属を新保証として追加しない。対象内の失敗と対象外境界の許す失敗を分け、候補条件・反例・L40への波及を示す |
| J20-5 | G10の子のLegacyNodeTypes、checkedAt/atErrorの照合、全状態/親判断を既存入力から構成できない | 適格な旧導出の範囲をさらに狭める、ValueAssumptions/sig_scoped/新型付けの結論を橋の入力に足す変更は未承認。既存の合法ソースの辞書・保持値・網羅性に及ぶ受理差を示して停止 |
| J20-6 | G09のS07aのdata/trans/refine又は型付けの33caseで全意味移送・inhabits_of_typedを閉じられない | 網羅性の健全性の根拠が欠ける。型付けに全値の意味を仮定として足す、Exhaustiveの保証を弱める、受理する型/パターンを狭める変更は採らず停止。どの合法ソースの網羅性・診断が変わるか反例と候補署名を示す |
| J20-7 | 案4/Declared/rowKindsがRustの合法ソースを新しく拒む場合。特にimplのconstructorパラメータを本体の型引数として使う経路と、effectの操作の型パラメータの経路 | collect_implのparameters(..., true)とメソッドへのscope継承、check_declarationsのItem::Effect→signature→signature_with_file→parameters(..., true)までは読んだ。Leanのimpl/user操作はvalue固定。targetの既存HasKindによる制限と本体の新しい制限を区別する。両経路の合法な具体例の受理・構文/handler・新coreへの全変換は未確認。L70/R10b/R50で具体のソース・診断・保証の差を照合し、受理差が出れば停止。Rustの書ける形の縮小をこの担当で決めない |

sig_scopedの旧欄の移行と、L10で既に明示した操作の辞書の先頭/添字、実装辞書のvalue kind、Ordinaryの最上位条件、代入前Qは継承する判断であり、再度の選択を求めない。今回選ぶ補助の名前・配置・帰納のmotiveは、上記の境界に触れない限り担当が具体化できる。変更が必要になった場合は、plan「全L作業の停止条件」とD71に従い、篩/σ/externalを切り分け、反例又は未証明の言明と追加の所要時間（能動時間）・待ちを返す。

## 検査・レビュー・受け入れの割り当て

以下は**実装時の予定**である。今回の計画担当はgitを使うwork と dry-runを実行しない。本書の静的照合と短い補助Leanだけを実施する。

| 記号・担当・時期 | コマンドと中身 | 見込み・保存先 |
|---|---|---|
| K・各単位の途中 | `formal/` で `lake env lean -M 12288 Benitoite/Release/Refinement/<関係ファイル>.lean`。case補題・署名・境界の関係するものだけを検査 | 直近のL10Fの単一入力は約0.7秒。今回の成功を各新ファイルの時間へ一律に使わず、通常resultsで更新 |
| W-L・各単位の作業末に一度 | 起動時に渡された完全B_WORKを使い、根で `scripts/check.sh --level work --base B_WORK --dry-run` 後、同じ引数の `scripts/check.sh --level work --base B_WORK`。既定全Leanと写しの読者を確認。text例を変えればspec_examples、構文を変えれば生成Skill/skill_docs/spec_tallyも方針どおり選ぶ。LeanだけへRust全libを足さない | 初回は直近の段末約102秒を参考に更新。増分/cleanの差を記す。単位の通常resultsへ終了・外側の時間・選択した実体を保存 |
| A-L・.148/段末 | 改造内の `l20/axioms.lean` に既定新旧モジュールをimportし、新葉と使用定義・private/生成宣言、旧主定理/旧三モデル、十の移送を全名で `#print axioms`。`formal/` で `lake env lean -M 12288 ../docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/axioms.lean` | 計画の1〜5分案。対象名一覧と生出力・件数を保存。許可はpropext/Quot.sound/Classical.choiceだけ。sorryAx/独自公理/未承認依存0を確認 |
| 群末レビュー・取りまとめ | A1/A2/A3a/A3b/A3c/A4/B〜Sの32群の定義・言明・仮定・供給元・未完を確認。失敗例や都合の悪い読者をimportから外さない。所見への応答・修正は当該群の能動時間内、レビュー実行の待ちは別 | 不明。`reviews/` と群resultsへ取りまとめが保存。担当の自己点検を独立レビューと呼ばない |
| 段末work・RSS・取りまとめ | 最後の同じworkにsandbox外でmacOSの `/usr/bin/time -l` 等を付ける。余分のbuildを追加しない。本体/計測器の終了・機械/OS/原単位を分離 | workに包含。ほかの単位のRSSは未取得（計画上の非採取）。L10の数値をL20へ引用しない |
| 段末レビューと受け入れ | 28行と37行の段別証拠、方式の四関門、G10全46規則/状態、七つの条件付き判断、実表/主定理/表層/交換の残りを確認。取りまとめがplanへ転記し設計者が受け入れる | 待ちは不明。L70の全比較、Rustの検査、releaseはこの段に前倒ししない |

各結果は完全なB_WORK、コマンド・終了・外側の時間、待ちと能動時間の分離可否、入力/構成、差と申し送り、失敗・修正・再確認を保存する。前の実行を引用するときは07-03の全引用欄を満たす。build成功だけで定義/言明/仮定のレビューや全比較の成功を主張しない。

## 見込みの根拠と取りまとめへの転記

本書は148単位・32群、所要時間（能動時間）97時間45分〜219時間45分。固定枠47〜109時間に対して下端＋50時間45分、上端＋110時間45分である。性質ごとの件数・分の積上げは前表とresultsへ記す。69型注記を69証明の単価として掛けず、四移送の再設計は0、局所追随39枝を計上する。G04の未確認の正則性も減額しない。

[effort-ledger](../effort-ledger.md)では、L10のV〜Aは初回216分＋修正111分＝327分、Fは20＋24＝44分、計**約371分（6時間11分）**である。レビューはV〜A102分＋段末15分＝**約117分（1時間57分）**で、担当の時間へ混ぜない。計画担当の15＋63＋60分とそのレビュー13＋9分も別である。これらは丸めた外側の時間で、能動時間とビルド等の待ちは未分離である。59単位で速かったことを、未経験の捕捉の全正則性・全型置換・全埋め込みの単価にしない。


L00a/L00b の代表の比も本書の全帰納の単価へ掛けない。L10の支持の最初17件と残2件は既に閉じた在庫である。今回は後半のG10の値19規則から、同種の残27規則だけを通常のresultsで見直す。そこへ達するまでは見込みを更新しない。


| 残る手順 | 検査・レビュー・受け入れを含む担当と内容 | 見込み |
|---|---|---:|
| r3の再確認とplanへの転記 | 取りまとめ。案4のC/射影/Declared/39枝、S00、固定したrowKinds/Declared.tapp、10移送＋4恒等/True、31位置、60義務、148単位と控除。枠の見直し・起動を判断 | 不明 |
| 最初の群Aの6群 | S00/案4/Declared/rowKindsの全追随・型引数3本体と型注釈の実例・四関門。関係Leanと既定Lean、群の定義/言明/仮定レビュー。不成立なら停止票 | 所要時間（能動時間）21時間〜53時間。待ちは別 |
| 群B〜Sの26群 | 本番証明・状態葉・G10の値19規則の通常記録と残27規則、状態と三親判断。単位末の既定Lean、群レビューと所見処置 | 所要時間（能動時間）76時間45分〜166時間45分。待ちは不明 |
| 段末の依存監査・最後のworkとRSS | 群Sに含む。新旧全対象の公理依存と同じ最後のworkでのRSSの区分を保存 | 公理監査の実行1〜5分案、workは通常結果で更新。待ちは不明 |
| 段末レビューと受け入れ | 取りまとめ/設計者。四関門、S00/案4/Declared/rowKindsの見直し、28＋37＋共通2の段別証拠、G10、J20-1〜7を確認 | 不明 |

取りまとめへは、S00と案4・V_Raiseの採用済み変更、固定したrowKinds/Declared.tappと波及数、28行のL20分、追加O005と共通O016/O084/O027/O118、他段へ残す27行、G04控除0と移管5〜9、本番の値19規則の依存後の通常更新、七つの条件付き判断を転記する。今回はplan・レビュー・formal・Rustを変更していない。

