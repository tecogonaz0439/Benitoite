# RV-L20.d: L20 群 D（L20.39〜.60）の独立レビュー

2026-11-02。対象はブランチ `m014/l20.d` の未コミットの作業木、基準 `6bef5692`。依頼文 `L20.d-prompt.md`・`L20.d-r1-prompt.md` と実装の報告を読んだうえで、判定は Lean の本文と補助の入力の検査で行った。ファイルは変更していない（本書を除く）。git の操作はしていない。

## 総合判定

**条件付き可**。重 0 件、中 2 件、軽 8 件。

S02 の全14成分の本体（`type_subst_all`）は無条件に閉じており、公開の言明・型付けの規則・公理に問題はない。S02 の相互帰納はこのまま受け入れてよい。

条件は中1・中2の修正である。`TypeSubstCallSites` の4本のうち `E_OpFail` と `E_Op` の2本は、実際の `K_Handle_Fail`・`K_Handle` の入力にそのまま適用できない。S02 や規則の変更は要らず、入口の言明を一般化すれば足りる。補助の入力で、一般化した形が公理3種だけで通ることを確かめた。

## 所見

### 読めば確定する誤り（補助の入力で再現）

#### 中1: `type_subst_opfail_body` は Γ=[]・Φ=[] の失敗節しか受けず、実際の E_OpFail に適用できない

- 場所: `<repo>/formal/Benitoite/Release/Refinement/TypeSubstCallSites.lean` 125〜134 行。
- 問題点: 本体の前提 `hb` が `failureContext [] E` と Φ `[]` に固定され、`E` は `hcall` の `.raise T E` と同じ変数である。実際の前の状態では、節は `K_Handle_Fail` の `HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ Es Rs h ts ecs []` にあり、Γ・Φ は捕捉の文脈、`Es` は開いた型で `cap.closeTy Es = E` である。`E'`（raise の型引数）と `E` も `Step.E_OpFail` では別の変数である。関数の中の局所変数を捕捉した `handle` は Γ≠[] なので、この入口の適用外になる。
- 影響: D4 の完了条件「4実呼出し」のうち E_OpFail が満たされていない。results.md の「四つの本体への適用」も同じ範囲で過大である（軽1）。S02 の成立には影響しない。
- 修正案: Γ・Φ・`Es` を一般化し、`hcall` の Φ と raise の型を節と別の変数にする。次の形が公理3種で通った（`fail_input` の `toTypeSubstInput` と `S02Internal.substC` だけを使う）。

```lean
theorem rv_opfail_body {P B Ψ Q Φ0 Γ Φ T E0 Es callerTy body a e} {R : Option Ty}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeVQ P B Ψ Q [] [] Φ0 (.raise T E0) callerTy)
    (hb : HasTypeCQ P B (hideBuilders Ψ) Q [TypeCtx.valueParam] (failureContext Γ Es) (liftMany 2 Φ)
      (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) body
      ((shiftTypes 1 0 a).shiftV 2 0) (Eff.shiftV 2 0 (shiftRowsTypes 1 0 e)) []) :
    HasTypeCQ P B (hideBuilders Ψ) Q [] ((failureContext Γ Es).bindTypes (typeEnvAt 0 [T] [])) (liftMany 2 Φ)
      ((R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)).map (Ty.substAt 0 [T] []))
      (body.substTy [T] []) (((shiftTypes 1 0 a).shiftV 2 0).substAt 0 [T] [])
      (Eff.substAt 0 [T] [] (Eff.shiftV 2 0 (shiftRowsTypes 1 0 e))) []
```

さらに `HasFailureClause` の実際の前提と `hideBuilders` の冪等性から `rv_e_opfail_site` を組み立て、行先のコード `body.substTy [T] []` まで閉じた。

#### 中2: `type_subst_op_body` は呼出しの Φ を節の Φ と共有し、仮定 `hc` の供給の経路もない

- 場所: 同ファイル 94〜123 行。98 行の `hc`、96 行の `hcall` と 100 行の `liftMany … Φ`。
- 問題点1（確定）: `hcall` の Φ と本体の Φ が同じ変数である。実際の呼出しの値の事実の列と、`K_Handle` の Φ（捕捉元の経路条件）は別物である。補助の入力で実際の `K_Handle` の入力から組み立てると、ここで型が合わず止まった。`hcall` は `op_body_input` で `V_Op` を逆転するだけなので、Φ を別にしても証明は変わらない。
- 問題点2（確定）: `hc : CaptureContextRegular P sg.tparams (sg.context Γ t e)` は証明に要らない。公開の `toPublic` は `ClosedTypeSubstInput.context` を捨て（`TypeSubstContracts.lean` 154〜164 行、`TypeSubstMain.lean` 42〜58 行）、`S02Internal.substC` は `TypeSubstInput` だけを読む。`hc` を除いた形が公理3種で通った。
- 問題点3（推測）: `hc` の実呼出しでの供給は既存の補題の組合せでは得られない。材料は `CaptureOk.contextRegular`、`K_Handle` の `Ty.Annotation P [] Γ ts`、`OpDecl.Scoped` の `SignatureScoped` にある。`CaptureContextRegular.extend` は `Ty.Annotation` を要求するが、`K_Handle` は `ecs` の開いた注釈を持たないため、継続の項は別の証明が要る。`Γ.shiftE k` への移送と、`signatureTel` の Annotation から `Γ.extendMany` の各項への移送も未証明である。成立しそうだが今回は証明していない。results.md の「公開の既存の context 欄として明示」は、未確認の前提を残した状態である。
- 修正案: Φ を分け、`hc` を除く（`rv_op_body`）。計画の L20.60 は「公開入口を使用」と書くので、`S02Internal.substC` を使うのは計画からのずれとして記録し、取りまとめが判断する。公開入口に固執するなら、供給の補題を同じ変更で証明する。
- 確認: 次の組立てが公理3種で通った。`rv_clause_lookup` は `HasTypeClausesQ` と `findClause` から選ばれた節の `ClauseSig` と本体を返す。結論のコードは `Step.E_Op` の行先と同じ `c.body.substTy ts []` である。

```lean
theorem rv_e_op_site {P B Ψ Φ0 Γ Φ Rs ebs h t ecs o ts c callerTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeVQ P B Ψ Qempty [] [] Φ0 (.op o ts) callerTy)
    (hcs : HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs ebs h t ecs [])
    (hc : findClause h (.user o) = some c) :
    ∃ sg : OpSig, HasTypeCQ P B (hideBuilders Ψ) Qempty []
      ((sg.context Γ t ecs).bindTypes (typeEnvAt 0 ts []))
      (liftMany (sg.params.length+1) Φ)
      ((Rs.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)).map (Ty.substAt 0 ts []))
      (c.body.substTy ts [])
      (((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0).substAt 0 ts [])
      (Eff.substAt 0 ts [] ((shiftRowsTypes sg.tparams.length 0 ecs).shiftV (sg.params.length+1) 0)) []
```

組立てでは節が `hideBuilders (hideBuilders Ψ)` を読むので、冪等の補題（`hideBuilders (hideBuilders Ψ) = hideBuilders Ψ`、`cases` で閉じた）を使った。本番の接続にもこの補題が要る。

#### 軽1: 中1・中2に連動する文書の過大な記述

- 場所: `docs/design/01-spec/01-12-core-calculus.md` 3155 行、`docs/design/07-quality/07-04-formal-semantics.md` 106 行、`l20/d/results.md` 5 行の「本体への公開入口の適用」と 56・57 行の表。
- 問題点: 通常節と失敗節の本体へ公開 S02 を適用したと書くが、失敗節は Γ=[]・Φ=[] に限られ、通常節は仮定 `hc` を残す。
- 修正案: 中1・中2の修正後の言明に合わせて直す。

#### 軽2: 07-04 の `S02Internal` の置き場の記述

- 場所: 07-04 100 行。
- 問題点: `TypeSubstContracts` の説明の中で「S02Internal の十の移送」と書くが、同ファイルの `S02Internal` は C・Body・Arms・Clauses の四つで、残り六つは `TypeSubstMain.lean` にある。
- 修正案: 「S02Internal の十の移送（`TypeSubstContracts` と `TypeSubstMain`）」とする。

#### 軽3: `bridge_tvar0` の報告の範囲

- 場所: `l20/d/results.md` 13 行、`l20/d/normeq-check.lean`。
- 問題点: `OpSig.typeSubst_body` の文の直後に「`bridge_tvar0` は結果型 `tvar 0` で通る」とあるが、この例は `Ctx.NormEq.comp` を直接適用しており、`typeSubst_body` も `HasTypeClausesQ.cons` も通らない。例の実体はある（`ret` は `dependentFn` で正規形が異なる）。
- 確認: 補助の入力 `rv_clause_tvar0` で、`tvar 0` を結果型とする節を実際の `HasTypeClausesQ.cons` に入れ、`S02Internal.substClauses` まで通した（公理3種）。主張そのものは成り立つ。
- 修正案: 記述を「`NormEq.comp` の例」と改めるか、cons を通す例を `normeq-check.lean` に足す。

#### 軽4: `signatures.md` が 172 KB ある

- 場所: `l20/d/signatures.md` 172,385 バイト。他の群は最大 48 KB である。`TypeSubstTyping.lean` 92 KB は 100 KB 未満である。
- 問題点: 依頼文の「改造に置く検査の記録を小さく保つ」に照らして大きい。76 case の署名は `TypeSubstTyping.lean` の本文の複製である。
- 修正案: case 補題は件数・名前の一覧と SHA-256 に減らし、定義と公開の言明だけを残す。

#### 軽5: 「裸の cont」の語

- 場所: 01-12 3153 行、07-04 104 行、`l20/d/results.md`。
- 問題点: 用語集の「裸の」は別の概念（裸の型・裸の try）に使われている。ここは refined で包まない `.cont` の意味で、定義がない。`Ctx.NormEq` の呼び方は「正規形が等しい文脈の対応」で、新しい術語は作っていない。
- 修正案: 「最上位が `.cont` である位置」と書く。

#### 軽6: 設計書の否定の文が経緯に読める

- 場所: 01-12 3157 行「追加の kind 又は行支持の前提は要求しない」、07-04 108 行「型付けの規則又は CoreAssumptions の欄を追加しない」。
- 問題点: 比較の相手が書かれておらず、今回の作業で足さなかったという経緯に読める。
- 修正案: 「前提は元の述語と `TypeSubstInput` だけである」と現在の決定で書く。

### 実行しないと分からない振る舞いと確認事項

#### 軽7: E_Fun の入口に呼出しからの逆転がない

- 場所: `TypeSubstCallSites.lean` 21〜26 行。
- 問題点: Op・Meth・Fail の入口は型付きの呼出しを受けるが、Fun は `SignatureInstance` と `Admissible` を直接受ける。results.md は「実際の defs の lookup… から入力を構成」と書くが、`.fnRef` の型付けからの逆転の補題は本番にない。
- 確認: `HasTypeVQ.rv_fun_inv`（`op_body_input` と同じ形、`V_Sub`・`V_Normal`・`V_Refine` を通す）が公理3種で通った。適用の妨げにはならない。
- 修正案: 同じ補題を入口に加える。

#### 軽8: E_OpPrim は4実呼出しの外にある

- 場所: `Semantics.lean` 312 行。行先は `c.body.substTy ts []` で、E_Op と同じ形である。
- 問題点（推測）: 計画は L20.103 へ回しており、今回の範囲外である。後続で `type_subst_op_body` を写すと、中2の Φ の共有と `hc` を引き継ぐ。`sg.tparams` が `TypeCtx.values` でなく `s.tparams` である点で入力の構成が異なる。
- 修正案: 中2の修正を先に行い、L20.103 の依頼文に申し送る。

## 観点ごとの確認結果

1. **公開の S02**: `TypeSubstContracts.lean` は基準から変更なし（`git diff` が空）。`type_subst_all` は仮定なしの14連言で、順序も14定義のとおりである。十の移送は `S02Internal.subst* .toPublic`、恒等3成分は `deriveCapture`・`deriveClosure`・`deriveWitness`、True 成分は `deriveImage` を通る。`Prop` の定義の型検査で済ませた成分はない。`#print axioms type_subst_all` は `propext`・`Classical.choice`・`Quot.sound` である。
2. **相互帰納**: `exact @case_` は76箇所で重複なし、`theorem case_` は76件、内訳は V29・C24・Vs2・Each2・Args2・Body2・Capture1・Closure1・Witness2・At1・Arms3・Clauses2・Failure1・Image4 である。各枝は構成子の引数と `derive*` だけを渡し、case 補題の前提は構成子の前提と帰納の仮定に限られる。隠れた前提はない。Image の4枝は True、恒等3成分は元の証拠を返す。入力 `hf` などは Goal の側にある。
3. **`Ctx.NormEq`**: 定義と `length`・`lookup`・`substOk`・`comp` を読んだ。`hc` は元の文脈の `.cont` の位置に移送先の `.cont` を要求する。`OpSig.context_continuations` は `sg.WF` から `Ty.cont_of_norm_wf`（`refined` は WF の `NotContCore` で排除、`dependentFn` は `foldFn` が `.fn` を返す）で供給する。`sg.WF` は `HasTypeClausesQ.cons` の欄であり、`case_Clauses_cons` の `hw` から実際に渡る。追加の入力はない。`captureWF_not_invariant` の例は、`CaptureWF` を任意の NormEq で移す命題を置かない理由である。本番の証明は `CaptureWF` を移さず、`.subst` の内部で捕捉を変更しない。影響はない。`Ctx.NormEq.annotation`・`facts`・`variable`・`resume`・`lambda`・`hide`・`params` は本番の主証明からは呼ばれない（r1 の確認の範囲の補題であり、誤りではない）。
4. **実呼出し**: コードは4本とも `Step` の行先と一致する（`d.body.substTy ts es`、`body.substTy (ss++us) fs`、`body.substTy ts []`、`body.substTy [T] []`）。`Capture.empty.extendMany ws`・`extendMany (vs ++ ws)`・`hcap.extendMany (ws ++ [.loc κ])`・`extendMany [v, .loc κ]` の順は、`Γ.extend` の連なり・`bindParams`・`OpSig.context`・`failureContext` の順と対応する。メソッドの `ss ++ us` は `ms.tparams ++ TypeCtx.values id.tparams` の順と一致し、`Qsig` の行対応も正しい。Fun と Meth は適用できる。Op と Fail は中1・中2のとおりである。`StoreTy.empty` から実際の Ψ への移送は後続の担当である。
5. **包装と特殊な枝**: `case_V_Sub`・`case_C_Sub`・`case_V_Normal`・`case_C_Normal`・`case_V_Refine`・`case_C_Eff` は既存の `LeQ.substAt`・`Covers.substAt`・`Ty.substAt_norm_source` で閉じ、追加の前提がない。`case_V_Refine` は `V_Normal` で包んで述語の恒等を使う。`case_V_CheckedAt` は証拠を恒等で返す。`case_At_mk` は `inputTy.substAt = inputTy.norm` を `RowsIn (· < 0)` から得る。`case_C_External` は `types_nil` で `ts=[]` に帰着する。`case_C_ResumeLNorm` は `.loc` が SourceScoped でないことから `fs=[]` を得る。
6. **言明と検査**: 追跡中の `formal/` の変更は `Benitoite.lean` の import と `TypeSubstFormation.lean` への補題の追記だけで、既存の言明は変わらない。主な10言明と `ValueMeaning`・`Typing.lean` は変更なし。新しいファイルは `Release/Refinement/` だけで、旧 `Release` は不変である。8 ファイルに `sorry`・`axiom`・`native_decide`・`implemented_by` はない。既定の `lake build` は成功、新モジュールは既定の import に入る。`l20/d/axioms.lean`（475 定数、`sorryAx` 0 件）、`normeq-check.lean`、`clause-bridge.lean` は終了0である。
7. **写し**: 76 の内訳、NormEq の定義、`Sub`・`Normal`・`Refine`・`Eff` の扱い、`TypeSubstCodeNormal` の説明は Lean と一致する。例外は軽1・軽2である。
8. **規約**: 手元の絶対パス・docs/todo へのリンク・`work/` を出どころとする参照・「費用」の語は、対象の範囲で0件である。100 KB を超えるのは軽4だけである。

## 補助の入力

scratchpad に置き、`formal/` で `lake env lean -M 12288` により確かめた（いずれも終了0、依存は公理3種）。`ax.lean`（公開の入口の公理依存）、`site.lean`（`rv_op_body`・`rv_opfail_body`・`rv_clause_lookup`・`rv_e_op_site`・`rv_e_opfail_site`）、`site2.lean`（`HasTypeVQ.rv_fun_inv`・`rv_clause_tvar0`）。本番に取り込むときは、言明は本書のとおり、証明は `op_body_input`・`fail_input`・`S02Internal.substC` の適用で足りる。

## 取りまとめの追記

実呼出しの入口は `S02Internal.substC` を直接使う判断とし、公開の S02 と `type_subst_all` はそのまま残した。中2件と軽8件を群 D の再開で処置した。
