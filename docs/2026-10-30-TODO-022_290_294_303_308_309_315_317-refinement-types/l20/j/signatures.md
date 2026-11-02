# 群 J・K の完全署名（実装との照合版）

B_WORK は `bc518cf27fabd493c0561e7faa2230eecb179b8d`、指定ブランチは `m014/l20.j`。実装後のソースから、最終の実装の完全な宣言部分を抽出した。署名を先に固定した版は保存していない。撤回した候補と重複する暫定署名は含めない。全宣言は [declarations.json](declarations.json) のファイル・行・ソース SHA-256 と対応する。以下のコードは各本番ファイルから証明の前を抽出し、private を含む。変更を含む既存5モジュールは既存宣言も含める。名前空間は `Benitoite.Release.Refinement`、例の二モジュールはその下の同名名前空間である。

通常操作と失敗操作、resume の共通の前提は現行の WellFormed・WellTyped・CoreAssumptions と元の StateTyE である。組み込み操作は既存の `P.EffectsOk B` も受ける。呼出し側 Φ0 と節側 Φ は独立であり、実際の `s.tparams` と admits_sat から S02Internal.substC の内部入力を作る。CaptureContextRegular、行支持、結果形成、行先本体の型付けを独立の前提にしない。主な十移送・型付け規則・CoreAssumptions・ValueMeaning の定義は変更していない。

`split_handle` は同じ分割の証拠の保護本体への名前の所属・範囲被覆を、`split_fail_annotated` は同じ証拠の節・捕捉・閉じた型/効果/Rを追加で返す。いずれも内部の分割の結論の強化である。公開入口は MatchStateExamples/OperationStateExamples 又は本番の状態の葉から実際に使用する。Lean環境に登録された全定数の型・公理依存を [axioms.lean](axioms.lean) で印字し、抽出元のソースを既定ビルドで検査した。


## PatternMatchAnnotations

```lean

private def annotationType (normal : Bool) (a : Ty) : Ty


private theorem constructor_ordinary {P B Ψ c tys vs cd ts}
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.con c tys vs) (.data cd.data ts))
    (hc : P.cons c = some cd) : ∀ a ∈ ts, a.Ordinary


  private theorem annotations_aux {P B Ψ R Γ Φ cap pat a δ}
      (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hp : PatTy P pat a δ) (normal : Bool) {v ws}
      (ha : Ty.Annotation P [] Γ (annotationType normal a))
      (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
      (hm : matchVal pat v = some ws) :
      TypeAnnotations P [] Γ (δ.map (annotationType normal))


  private theorem annotations_list_aux {P B Ψ R Γ Φ cap ps as δ}
      (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hp : PatTys P ps as δ) (normal : Bool) {vs ws}
      (ha : TypeAnnotations P [] Γ (as.map (annotationType normal)))
      (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs (as.map cap.closeTy))
      (hm : matchList ps vs = some ws) :
      TypeAnnotations P [] Γ (δ.map (annotationType normal))


theorem PatTy.bindings_annotation {P B Ψ R Γ Φ cap pat a δ v ws}
    (valid : P.VarianceValid)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : PatTy P pat a δ) (ha : Ty.Annotation P [] Γ a)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hm : matchVal pat v = some ws) : TypeAnnotations P [] Γ δ


theorem AltsTy.bindings_annotation {P B Ψ R Γ Φ cap alts a δ v ws}
    (valid : P.VarianceValid)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : AltsTy P alts a δ) (ha : Ty.Annotation P [] Γ a)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hm : firstAlt v alts = some ws) : TypeAnnotations P [] Γ δ


```

## PatternBindingsAdequate

```lean

private theorem adequate_list_iff {σ : PathEnv} (vs : List Val) :
    adequateVals σ vs ↔ ∀ v ∈ vs, v.Adequate σ


  theorem pattern_bindings_adequate {σ : PathEnv} {p v ws} (hg : v.Adequate σ)
      (hm : matchVal p v = some ws) : ∀ w ∈ ws, w.Adequate σ


  theorem patterns_bindings_adequate {σ : PathEnv} {ps vs ws} (hg : ∀ v ∈ vs, v.Adequate σ)
      (hm : matchList ps vs = some ws) : ∀ w ∈ ws, w.Adequate σ


theorem alternatives_bindings_adequate {σ : PathEnv} {alts v ws} (hg : v.Adequate σ)
    (hm : firstAlt v alts = some ws) : ∀ w ∈ ws, w.Adequate σ


```

## MatchStateLeaves

```lean

theorem CaptureOk.match_extend {P B Ψ R Γ Φ cap alts a δ v ws}
    (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : AltsTy P alts a δ) (hδ : TypeAnnotations P [] Γ δ)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hg : v.Ground) (hm : firstAlt v alts = some ws) :
    CaptureOk P B Ψ R (Refinement.bindParams Γ δ) (liftMany δ.length Φ) (cap.extendMany ws)


theorem CaptureOk.paths_wellFormed {P B Ψ R Γ Φ cap vs t tests v}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ho : vs.toTerm? = some t)
    (hs : ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs) (hw : FactsWF P [] Γ (pathFacts (some t) tests)) :
    FactsWF P [] [] (pathFacts v.toTerm? tests)


theorem CaptureOk.matched_facts {P B Ψ R Γ Φ cap vs obs alts v ws}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (hw : FactsWF P [] Γ (pathFacts obs (matchedTests alts)))
    (hm : firstAlt v alts = some ws) :
    CaptureOk P B Ψ R Γ (pathFacts obs (matchedTests alts) ++ Φ) cap


theorem CaptureOk.excluded_facts {P B Ψ R Γ Φ cap vs obs alts a δ v}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs) (hp : AltsTy P alts a δ)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hw : FactsWF P [] Γ (pathFacts obs (excludedTests alts)))
    (hm : firstAlt v alts = none) :
    CaptureOk P B Ψ R Γ (pathFacts obs (excludedTests alts) ++ Φ) cap


private theorem prefix_tail {v arms n arm} (h : MatchPrefix v (arm :: arms) (n+1)) :
    MatchPrefix v arms n


theorem HasTypeArmsQ.capture_plain_success {P B Ψ Γ Φ R Rs obs arms a b e L cap vs v n alts body ws}
    (h : HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms a b e L)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hi : arms[n]? = some (.mk alts none body))
    (hpref : MatchPrefix v arms n) (hm : firstAlt v alts = some ws) :
    ∃ δ Ξ, AltsTy P alts a δ ∧ CaptureOk P B Ψ R Γ Ξ cap ∧
      HasTypeCQ P B Ψ Qempty [] (Refinement.bindParams Γ δ) (liftMany δ.length Ξ)
        (Rs.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
        (localExtend δ.length L)


theorem Capture.closeTy_shift_many (cap : Capture) (vs : List Val) (a : Ty) :
    (cap.extendMany vs).closeTy (a.shiftV vs.length 0) = cap.closeTy a


theorem Capture.closeEff_shift_many (cap : Capture) (vs : List Val) (e : Eff) :
    (cap.extendMany vs).closeEff (e.shiftV vs.length 0) = cap.closeEff e


theorem MatchPrefix.unresolve {v arms n ρ}
    (h : MatchPrefix v (Arm.resolveLocalsList ρ arms) n) : MatchPrefix v arms n


theorem StateTyE.match_body {P B σ Eb v cap arms n alts body ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts none body)) (hm : firstAlt v alts = some ws) :
    StateTyE P B σ Eb (.run (.mk (cap.extendMany ws) body) k μ)


theorem HasTypeArmsQ.capture_guard_success {P B Ψ Γ Φ R Rs obs arms a b e L cap vs v n alts guard body ws}
    (h : HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms a b e L)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (ht : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hi : arms[n]? = some (.mk alts (some guard) body))
    (hpref : MatchPrefix v arms n) (hm : firstAlt v alts = some ws) :
    ∃ δ Ξ p, AltsTy P alts a δ ∧ CaptureOk P B Ψ R Γ Ξ cap ∧
      Ty.Annotation P [] (hideConts (Refinement.bindParams Γ δ)) (.refined (.base .boolean) p) ∧
      HasTypeCQ P B Ψ Qempty [] (hideConts (Refinement.bindParams Γ δ)) (liftMany δ.length Ξ)
        none guard (.refined (.base .boolean) p) Eff.empty (localExtend δ.length L) ∧
      HasTypeCQ P B Ψ Qempty [] (Refinement.bindParams Γ δ)
        (p.open (.boolean true) :: liftMany δ.length Ξ)
        (Rs.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
        (localExtend δ.length L)


theorem MatchPrefix.guard_advance {v arms n alts guard body}
    (hp : MatchPrefix v arms n) (hi : arms[n]? = some (.mk alts (some guard) body)) :
    MatchPrefix v arms (n+1)


theorem adequateArms_guard {σ : PathEnv} {arms : List Arm} {n : Nat} {alts : List Alt} {guard body : Comp}
    (h : adequateArms σ arms) (hi : arms[n]? = some (.mk alts (some guard) body)) : guard.Adequate σ


theorem Arm.ClosedList_guard {nt nv : Nat} {arms : List Arm} {n : Nat} {alts : List Alt} {guard body : Comp}
    (h : Arm.ClosedList nt nv arms) (hi : arms[n]? = some (.mk alts (some guard) body)) :
    guard.ClosedAt nt (nv + Arm.bindersOf alts)


theorem StateTyE.err_pop_guard {P B σ Eb rs v cap arms n body k μ}
    (h : StateTyE P B σ Eb (.error rs (.guardF v cap arms n body :: k) μ)) :
    StateTyE P B σ Eb (.error rs k μ)


theorem StateTyE.exit_pop_guard {P B σ Eb code rs v cap arms n body k μ}
    (h : StateTyE P B σ Eb (.exit code rs (.guardF v cap arms n body :: k) μ)) :
    StateTyE P B σ Eb (.exit code rs k μ)


theorem Ty.Annotation.done_empty {P C Γ a} (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Γ (.dependentFn (.done a Eff.empty))


theorem Capture.closeEff_empty (cap : Capture) : cap.closeEff Eff.empty = Eff.empty


theorem StateTyE.match_guard {P B σ Eb v cap arms n alts guard body ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts (some guard) body)) (hm : firstAlt v alts = some ws) :
    StateTyE P B σ Eb (.run (.mk (cap.extendMany ws) guard)
      (.guardF v cap arms (n+1) (.mk (cap.extendMany ws) body) :: k) μ)


```

## HandlerGeneral

```lean

private theorem clauses_hide_empty {P B Ψ Q C Γ Φ R eb cs t e L}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) :
    HasTypeClausesQ P B (hideBuilders Ψ) Q C Γ Φ R eb cs t e []


private theorem failure_hide_empty {P B Ψ Q C Γ Φ E R cs t e L}
    (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) :
    HasFailureClause P B (hideBuilders Ψ) Q C Γ Φ E R cs t e []


private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e


private theorem handler_tail {P B σ Ψ R e k a b Eb Re cap cs}
    (h : ContTy P B σ Ψ R e (.handleF cap cs :: k) a b Eb Re) :
    ∃ t et, Ty.LeQ P [] [] a t ∧ ContTy P B σ Ψ R et k t b Eb Re


private theorem union_left_sub (e f : Eff) : Eff.Sub e (Eff.union e f)


private theorem union_right_sub (e f : Eff) : Eff.Sub f (Eff.union e f)


theorem StateTyE.handle_step {P B σ Eb q k μ m cs}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .handle m cs) :
    StateTyE P B σ Eb (.run (.mk q.capture m) (.handleF q.capture cs :: k) μ)


theorem StateTyE.handler_return {P B σ Eb q v cap cs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ)) (hv : q.view = .ret v) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ)


private theorem shifted_type_cancel (a : Ty) (ts : List Ty) :
    (shiftTypes ts.length 0 a).substAt 0 ts [] = a.norm


private theorem shifted_eff_cancel (e : Eff) (ts : List Ty) :
    Eff.substAt 0 ts [] (shiftRowsTypes ts.length 0 e) = e.norm


private theorem shifted_context_cancel (Γ : Ctx) (ts : List Ty) :
    (Γ.shiftE ts.length).bindTypes (typeEnvAt 0 ts []) = Γ.map (Option.map Ty.norm)


private theorem norm_context_lookup {Γ : Ctx} {i : Nat} {a : Ty}
    (hi : (Γ.map (Option.map Ty.norm))[i]? = some (some a)) :
    ∃ b, Γ[i]? = some (some b) ∧ b.norm = a


private theorem norm_context_eq (Γ : Ctx) : Γ.NormEq (Γ.map (Option.map Ty.norm))


private theorem capture_normal {P B Ψ R Γ Φ cap} (hc : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R (Γ.map (Option.map Ty.norm)) Φ cap


private theorem type_env_up {ts : List Ty} (ht : ∀ t ∈ ts, t.WF 0 0 0) :
    (typeEnvAt 0 ts []).up = typeEnvAt 0 ts []


private theorem signature_inst (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    {ts : List Ty} (ht : ∀ t ∈ ts, t.WF 0 0 0) :
    Tel.bind (typeEnvAt 0 ts []) (signatureTel ns ps r e) =
      signatureTel ns (ps.map (Ty.substAt 0 ts [])) (r.substAt 0 ts []) (Eff.substAt 0 ts [] e)


private theorem signature_inputs (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : ns.length = ps.length) : (signatureTel ns ps r e).inputs = ps


private theorem signature_result (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    (signatureTel ns ps r e).result = r


private theorem tel_extend_eq (t : Tel) (Γ : Ctx) : telExtend Γ t = t.context Γ


private theorem tel_lift_eq (t : Tel) (Φ : List Pred) : telLift Φ t = liftMany t.arity Φ


private theorem clause_selected {P B Ψ Q Γ Φ R eb cs t ec o c}
    (hcs : HasTypeClausesQ P B Ψ Q [] Γ Φ R eb cs t ec [])
    (hc : findClause cs o = some c) :
    ∃ (sg : OpSig) (body : Comp), c = .mk o sg.params.length sg.tparams.length body ∧
      ClauseSig P B eb o sg ∧ NamesWF sg.names sg.params ∧ sg.WF ∧
      HasTypeCQ P B (hideBuilders Ψ) Q sg.tparams (sg.context Γ t ec)
        (liftMany (sg.params.length+1) Φ)
        (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)) body
        ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0)
        ((shiftRowsTypes sg.tparams.length 0 ec).shiftV (sg.params.length+1) 0) []


private theorem op_context_inst {P B C ts} (hi : TypeSubstInput P B C [] ts [])
    (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff) (hn : ts.length = sg.tparams.length) :
    (sg.context Γ t e).bindTypes (typeEnvAt 0 ts []) =
      (Ctx.extendMany (Γ.map (Option.map Ty.norm)) (sg.params.map (Ty.substAt 0 ts []))).extend
        (.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0)
          (e.norm.shiftV sg.params.length 0))


private theorem op_result_inst {P B C ts} (hi : TypeSubstInput P B C [] ts [])
    (a : Ty) (n : Nat) :
    ((shiftTypes ts.length 0 a).shiftV n 0).substAt 0 ts [] = a.norm.shiftV n 0


private theorem op_effect_inst {P B C ts} (hi : TypeSubstInput P B C [] ts [])
    (e : Eff) (n : Nat) :
    Eff.substAt 0 ts [] ((shiftRowsTypes ts.length 0 e).shiftV n 0) = e.norm.shiftV n 0


private theorem annotation_many {P C Γ a} (ha : Ty.Annotation P C Γ a) (ps : List Ty) :
    Ty.Annotation P C (Γ.extendMany ps) (a.shiftV ps.length 0)


private theorem declared_many {P C Γ} {a : Ty} (ha : a.Declared P C Γ) (ps : List Ty) :
    (a.shiftV ps.length 0).Declared P C (Γ.extendMany ps)


private theorem extend_many_append (Γ : Ctx) (ps qs : List Ty) :
    Γ.extendMany (ps ++ qs) = (Γ.extendMany ps).extendMany qs


private theorem operation_capture {P B Ψ Ψ' R Γ Φ Rs cap ts t ec tb ecb body l r f ws} {sg : OpSig} {srcEff : Eff}
    (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hp : (hideBuilders Ψ).Extends Ψ')
    (hcap : CaptureOk P B (hideBuilders Ψ) R Γ Φ cap)
    (inp : TypeSubstInput P B sg.tparams [] ts [])
    (hinst : Ty.Annotation P [] [] (.dependentFn (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts [])))
    (hargs : HasTypeTelArgsQ P B Ψ' Qempty [] [] [] ws (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts []) r f)
    (hg : ∀ w ∈ ws, w.Ground)
    (hb : HasTypeCQ P B Ψ' Qempty []
      (sg.context Γ t ec |>.bindTypes (typeEnvAt 0 ts []))
      (liftMany (sg.params.length+1) Φ)
      ((Rs.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)).map (Ty.substAt 0 ts []))
      body (((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0).substAt 0 ts [])
      (Eff.substAt 0 ts [] ((shiftRowsTypes sg.tparams.length 0 ec).shiftV (sg.params.length+1) 0)) [])
    (hn : sg.names.length = sg.params.length)
    (hR : cap.closeR Rs = R) (ht : cap.closeTy t = tb) (he : cap.closeEff ec = ecb)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done tb ecb)))
    (has : Ty.Annotation P [] Γ t) (hrs : ∀ a, Rs = some a → a.Declared P [] Γ)
    (hl : Ψ' l = some (.cont r tb ecb R))
    (hrw : ∀ a, R = some a → a.WF 0 0 0) :
    ClosureTy P B Ψ' [] R (.mk (cap.extendMany (ws ++ [.loc l])) body) tb ecb


private theorem clauses_no_fail {P B Ψ Q C Γ Φ R eb cs t ec L}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ec L) : handles cs .fail = false


private theorem covers_state {outer inner : Eff} (h : Eff.Covers [] [] outer inner)
    (hm : inner.mem (.name stateEff (.fixed .top))) : outer.mem (.name stateEff (.fixed .top))


private theorem handle_no_failure {P B σ Ψ R e frames a b Eb Re cap cs k1 k2} {o : OpRef}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = k1 ++ .handleF cap cs :: k2) (hne : o ≠ .fail) (hopen : handles cs o = true) :
    handles cs .fail = false


private theorem clause_closed {cs : List Clause} {op ar nty body nt nv}
    (h : Clause.ClosedList nt nv cs) (hc : Clause.mk op ar nty body ∈ cs) :
    body.ClosedAt (nt+nty) (nv+ar+1)


private theorem clause_adequate {cs : List Clause} {c : Clause} {σ}
    (h : adequateClauses σ cs) (hc : c ∈ cs) : c.body.Adequate σ


private theorem tel_args_store {P B Ψ Ψ' vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasTypeTelArgsQ P B Ψ' Qempty [] [] [] vs t a e


theorem StateTyE.operation_all {P B σ Eb q o ts ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.op o ts) ws)
    (hsp : SplitAt (.user o) k k1 hcap cs k2) (hc : findClause cs (.user o) = some c)
    (hf : μ l = none) :
    StateTyE P B σ Eb (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs]))))


private theorem close_return_contract {Ψ : StoreTy} {cap : Capture} {Rs R Rs' : Option Ty} {l x t e}
    (hw : Ψ.WF) (hp : Ψ l = some (.cont x t e Rs'))
    (hR : cap.closeR Rs = R) (he : Rs'.map Ty.norm = Rs.map Ty.norm) :
    Rs'.map Ty.norm = R.map Ty.norm


private theorem close_resume_aux {P B Ψ Q C Γ Φ Rs m a e L cap R kv v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hr : cap.closeR Rs = R)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .resume kv v) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.resume (closeVal cap kv) (closeVal cap v))
      (cap.closeTy a) (cap.closeEff e) []


private theorem resume_resolve {P B Ψ Q C Γ Φ R code a e L kv v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (he : code = .resume kv v) (ρ) :
    code.resolveLocals ρ = code


private theorem resume_inv {P B Ψ Q C Γ Φ R code a e L l v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (he : code = .resume (.loc l) v) :
    ∃ x t ec r, Ψ l = some (.cont x t ec r) ∧ r.map Ty.norm = R.map Ty.norm ∧
      HasTypeVQ P B Ψ Q C Γ Φ v x.norm ∧ Ty.LeQ P Γ Φ t.norm a ∧ Eff.Covers Γ Φ e ec


private theorem closed_set {μ : Store} {l c} (h : μ.Closed) (hc : c.Closed) :
    (μ.set l c).Closed


private theorem resume_view_typed {P B Ψ R q a e l v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .resume (.loc l) v) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.resume (.loc l) v) a e []


theorem StateTyE.resume_all {P B σ Eb q l v k μ saved}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .resume (.loc l) v)
    (hl : μ l = some (.cont saved)) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) (saved ++ k) (μ.set l .used))


theorem StateTyE.operation_failure {P B σ Eb q T E0 v k μ k1 E body k2 l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.raise T E0) [v])
    (hsp : SplitAt .fail k k1 hcap [.fail E body] k2) (hf : μ l = none) :
    StateTyE P B σ Eb (.run (.mk (hcap.extendMany [v,.loc l]) (body.substTy [T] []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap [.fail E body]]))))


private theorem widen_opaque_value {P B Ψ v o inner outer}
    (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.opaque o (.fixed inner)))
    (hcov : outer.Covers inner) :
    HasTypeVQ P B Ψ Qempty [] [] [] v (.opaque o (.fixed outer))


private inductive TargetWiden : Ty → Ty → Prop where
  | same (a : Ty) : TargetWiden a a
  | opaque {o inner outer} : RangeExpr.Covers outer inner →
      TargetWiden (.opaque o (.fixed inner)) (.opaque o (.fixed outer))
  | scoped {o k inner outer} : RangeExpr.Covers outer inner →
      TargetWiden (.scoped o k (.fixed inner)) (.scoped o k (.fixed outer))


private theorem target_bind {a b : Ty} (h : TargetWiden a b) (θ : SubstEnv) (hr : θ.ranges = []) :
    TargetWiden (a.bind θ) (b.bind θ)


private theorem target_value {P B Ψ v a b} (valid : P.VarianceValid) (h : TargetWiden a b)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a) : HasTypeVQ P B Ψ Qempty [] [] [] v b


private noncomputable def TelTargetWiden (t u : Tel) : Prop


private theorem tel_target_bind {t u : Tel} (h : TelTargetWiden t u) (θ : SubstEnv) (hr : θ.ranges = []) :
    TelTargetWiden (Tel.bind θ t) (Tel.bind θ u)


private theorem tel_target_arguments {P B Ψ vs t u a e}
    (valid : P.VarianceValid) (h : TelTargetWiden t u)
    (ha : Ty.Annotation P [] [] (.dependentFn u))
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e) :
    ∃ f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs u a f


private theorem map_atoms_closed (ats : Atom → Bool) (ρ : Nat → RangeIx)
    (h : ∀ l ix, ats (.name l ix) = true → ix.WF 0) : mapRangeAtoms ρ ats = ats


  private theorem ranges_closed (a : Ty) (h : a.RangesScoped 0) (ρ : Nat → RangeIx) :
      a.rawMapRanges ρ = a


  private theorem ranges_types_closed (as : List Ty) (h : rangesScopedTypes 0 as) (ρ : Nat → RangeIx) :
      mapRangesTys ρ as = as


  private theorem ranges_eff_closed (e : Eff) (h : e.RangesScoped 0) (ρ : Nat → RangeIx) :
      Eff.rawMapRanges ρ e = e


  private theorem ranges_tel_closed (t : Tel) (h : t.RangesScoped 0) (ρ : Nat → RangeIx) :
      Tel.rawMapRanges ρ t = t


private theorem operation_param_map {p : Ty}
    (h : (∃ o ix, p = .opaque o ix) ∨ (∃ o k ix, p = .scoped o k ix) ∨ p.RangesScoped 0)
    (rs : List RangeExpr) : p.rawMapRanges (rangeAt 0 rs) = p.instTarget rs


private theorem map_signature (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (ρ : Nat → RangeIx) :
    Tel.rawMapRanges ρ (signatureTel ns ps r e) =
      signatureTel ns (ps.map (fun p => p.rawMapRanges ρ)) (r.rawMapRanges ρ) (Eff.rawMapRanges ρ e)


private noncomputable def erase_effect : Tel → Tel
  | .done a _ => .done a Eff.empty
  | .param n a t => .param n a (erase_effect t)

private theorem erase_effect_norm (t : Tel) : erase_effect t.norm = (erase_effect t).norm


private theorem erase_effect_norm (t : Tel) : erase_effect t.norm = (erase_effect t).norm


private theorem erase_effect_annotation {P C Γ t}
    (h : Ty.Annotation P C Γ (.dependentFn t)) : Ty.Annotation P C Γ (.dependentFn (erase_effect t))


private theorem erase_signature (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    erase_effect (signatureTel ns ps r e) = signatureTel ns ps r Eff.empty


private theorem operation_param_widen {p : Ty} {nr nt nv : Nat} {rs : List RangeExpr} {S : RangeExpr}
    (hp : (∃ o ix, p = .opaque o ix) ∨ (∃ o k ix, p = .scoped o k ix) ∨ p.RangesScoped 0)
    (hw : p.TargetWF nr nt nv) (hn : rs.length = nr) (hc : ∀ r ∈ rs, S.Covers r) :
    TargetWiden (p.rawMapRanges (rangeAt 0 rs)) (p.instTarget (List.replicate nr S))


private theorem signature_target_widen {nr nt nv : Nat} (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    {rs : List RangeExpr} {S : RangeExpr} (hn : rs.length = nr) (hc : ∀ r ∈ rs, S.Covers r)
    (hp : ∀ p ∈ ps, (∃ o ix, p = .opaque o ix) ∨ (∃ o k ix, p = .scoped o k ix) ∨ p.RangesScoped 0)
    (hw : BinderTypes.TargetWF nr nt nv ps) (hr : r.RangesScoped 0) :
    TelTargetWiden (Tel.rawMapRanges (rangeAt 0 rs) (signatureTel ns ps r e))
      (signatureTel ns (ps.map (Ty.instTarget (List.replicate nr S))) r Eff.empty)


private theorem handler_signature_annotation {P B} {Ψ : StoreTy} {s : PrimSig} {ts S}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B s.tparams [] ts []) (hsource : s.Scoped P) (ho : s.opEff ≠ none) :
    Ty.Annotation P [] [] (.dependentFn (instantiatedTel
      (signatureTel s.names (s.params.map (Ty.instTarget (List.replicate s.rkinds.length S))) s.ret Eff.empty) ts []))


private theorem tel_effect_atoms_bind (t : Tel) (θ : SubstEnv) (hr : θ.rows = []) (hg : θ.ranges = []) :
    (Tel.bind θ t).effect.atoms = t.effect.atoms


private theorem arguments_effect_atoms {P B Ψ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e) : e.atoms = t.effect.atoms


private theorem signature_effect (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    (signatureTel ns ps r e).effect = e


private theorem inst_effect_mem {e : Eff} {l ix} (rs : List RangeExpr) (h : e.mem (.name l ix)) :
    (Eff.instR rs e).mem (.name l (ix.inst rs))


private theorem primitive_effect_shape {P : Program} {B : Builtins} {b : PrimName} {s : PrimSig} (hB : B.CoreAssumptions P)
    (hs : B.sig b = some s) (hk : s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) :
    ∃ l bs, s.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧ s.neffs = 0 ∧
      ((s.rkinds = [] ∧ s.eff = Eff.single l) ∨
       ∃ k, s.rkinds = [k] ∧ s.eff = .mk (fun a => decide (a = .name l (.rvar 0))) [])


private theorem primitive_inst_member {s : PrimSig} {l : EffName} {rs : List RangeExpr}
    (hshape : (s.rkinds = [] ∧ s.eff = Eff.single l) ∨
      ∃ k, s.rkinds = [k] ∧ s.eff = .mk (fun a => decide (a = .name l (.rvar 0))) [])
    (hn : rs.length = s.rkinds.length) :
    ∃ rr, (Eff.instR rs s.eff).mem (.name l (.fixed rr)) ∧
      (∀ S, RangeIx.Covers (.fixed S) (.fixed rr) → ∀ r ∈ rs, S.Covers r)


private theorem tel_effect_norm (t : Tel) : t.norm.effect = t.effect.norm


private theorem primitive_arguments_atoms {P B Ψ rs ts ws r f} {s : PrimSig}
    (h : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel (Tel.instR rs s.tel) ts []) r f) :
    f.atoms = (Eff.instR rs s.eff).atoms


private theorem covered_name_general {outer inner : Eff} {l ix}
    (h : Eff.Covers [] [] outer inner) (hm : inner.mem (.name l ix)) :
    ∃ jx, outer.mem (.name l jx) ∧ jx.Covers ix


theorem StateTyE.operation_primitive {P B σ Eb q b s ts es rs ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hdecl : P.EffectsOk B)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases)
    (hsp : SplitAt (.prim b) k k1 hcap cs k2) (hc : findClause cs (.prim b) = some c)
    (hf : μ l = none) :
    StateTyE P B σ Eb (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs]))))


```

## MatchStateExamples

```lean

private def unit : Val


private def root : Val


private def result : Comp


private def pairs : List Alt


private def wild : List Alt


private def plainArms : List Arm


private def guardArms (b : Bool) : List Arm


private theorem unit_annotation {P C Γ} : Ty.Annotation P C Γ (.base .unit)


private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e


private theorem ret_unit {P B Ψ Q C Γ Φ R L} (e : Eff) :
    HasTypeCQ P B Ψ Q C Γ Φ R result (.base .unit) e L


private theorem pair_alts (P : Program) (a : Ty) : AltsTy P pairs (.list a) [a,.list a]


private theorem wild_alts (P : Program) (a : Ty) : AltsTy P wild a []


private theorem boolean_typed {P B Ψ Q C Γ Φ} (b : Bool) :
    HasTypeVQ P B Ψ Q C Γ Φ (.const (.boolean b)) (.refined (.base .boolean) .truth)


private theorem boolean_annotation {P C Γ} : Ty.Annotation P C Γ (.refined (.base .boolean) .truth)


private theorem root_typed (P : Program) (B : Builtins) :
    HasTypeVQ P B StoreTy.empty Qempty [] [] [] root (.list (.base .unit))


private theorem plain_code (P : Program) (B : Builtins) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none (.match root plainArms) (.base .unit) Eff.empty []


private theorem guard_code (P : Program) (B : Builtins) (b : Bool) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none (.match root (guardArms b)) (.base .unit) Eff.empty []


private theorem initial {P B σ m}
    (h : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none m (.base .unit) Eff.empty [])
    (hc : m.ClosedAt 0 0) (ha : m.Adequate σ) :
    StateTyE P B σ Eff.empty (.run (Closure.pure m) [] Store.empty)


theorem two_bindings {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty
      (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) [] Store.empty)


private theorem guard_prepared {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (b : Bool) :
    StateTyE P B σ Eff.empty
      (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) (.ret (.const (.boolean b))))
        (.guardF root Capture.empty (guardArms b) 1 (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) :: []) Store.empty)


theorem guard_execution {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (b : Bool) :
    if b then
      StateTyE P B σ Eff.empty (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) [] Store.empty)
    else
      StateTyE P B σ Eff.empty (.matchRun root Capture.empty (guardArms b) 1 [] Store.empty)


theorem handler_returned {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (Closure.pure result) [] Store.empty)


theorem guard_propagation {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.error [] [] Store.empty) ∧
    StateTyE P B σ Eff.empty (.exit 0 [] [] Store.empty)


private def unknownGuardType : Ty


private theorem unknown_guard_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] [] [] none (.ret (.const (.boolean true))) unknownGuardType Eff.empty []


theorem reject_guard_unknown_elimination (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] [] [] none (.ret (.const (.boolean true))) unknownGuardType Eff.empty [] ∧
    TypedMeaningExamples.unknownPredicate.evalWith (fun _ => none) = none ∧
    (∀ g : Comp, ¬ Exhaustive P (.base .boolean)
      (unguardedPats [.mk wild (some g) result])) ∧
    Exhaustive P (.base .boolean) (unguardedPats [.mk wild none result])


theorem reject_false_fact_to_tail {P B Ψ} (valid : P.VarianceValid) :
    HasTypeCQ P B Ψ Qempty [] [] [] none (.ret (.const (.boolean false)))
      (.refined (.base .boolean) .truth) Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] [] [.falsity] none (.ret TypedMeaningExamples.thirteen) monthType Eff.empty [] ∧
    ¬ HasTypeArmsQ P B Ψ Qempty [] [] [] none none
      [.mk wild (some (.ret (.const (.boolean false)))) (.ret TypedMeaningExamples.five),
       .mk wild none (.ret TypedMeaningExamples.thirteen)] (.base .boolean) monthType Eff.empty []


```

## RuntimeTypeSubst

```lean

private theorem type_inst_wf {ts : List Ty} {es : List Eff} {c nv : Nat} {a : Ty}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (h : a.WF 0 (c+ts.length) nv) :
    (a.substAt c ts es).WF 0 c nv


private theorem types_inst_wf {ts as : List Ty} {es : List Eff} {c nv : Nat}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (h : ∀ a ∈ as, a.WF 0 (c+ts.length) nv) :
    ∀ a ∈ as.map (substTypeAt c ts es), a.WF 0 c nv


private theorem rows_inst_wf {ts : List Ty} {es fs : List Eff} {c nv : Nat}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (h : ∀ f ∈ fs, f.WF 0 (c+ts.length) nv ∧ f.Canonical) :
    ∀ f ∈ fs.map (substRowAt c ts es), f.WF 0 c nv ∧ f.Canonical


  theorem Val.ClosedAt.runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {v : Val}
      (h : v.ClosedAt (c+ts.length) nv) {σ : PathEnv} (had : v.Adequate σ)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      (v.substTyAt c ts es).ClosedAt c nv ∧ (v.substTyAt c ts es).Adequate σ


  theorem closedValues_runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {vs : List Val}
      (h : Val.ClosedList (c+ts.length) nv vs) {σ : PathEnv} (had : adequateVals σ vs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      Val.ClosedList c nv (Val.substTyAtList c ts es vs) ∧ adequateVals σ (Val.substTyAtList c ts es vs)


  theorem Comp.ClosedAt.runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {m : Comp}
      (h : m.ClosedAt (c+ts.length) nv) {σ : PathEnv} (had : m.Adequate σ)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      (m.substTyAt c ts es).ClosedAt c nv ∧ (m.substTyAt c ts es).Adequate σ


  theorem closedArms_runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {arms : List Arm}
      (h : Arm.ClosedList (c+ts.length) nv arms) {σ : PathEnv} (had : adequateArms σ arms)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      Arm.ClosedList c nv (Arm.substTyAtList c ts es arms) ∧ adequateArms σ (Arm.substTyAtList c ts es arms)


  theorem closedClauses_runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {cs : List Clause}
      (h : Clause.ClosedList (c+ts.length) nv cs) {σ : PathEnv} (had : adequateClauses σ cs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      Clause.ClosedList c nv (Clause.substTyAtList c ts es cs) ∧ adequateClauses σ (Clause.substTyAtList c ts es cs)


```

## OperationStateExamples

```lean

private def unit : Val


private def rowType : Ty


private def argument : Val


private def actualArgument : Val


private def declaration : OpDecl


private def opEffect : Eff


private def outputEffect : Eff


private def clauses : List Clause


private def call : Comp


private def source : Comp


private def opState : State


private def resumeState : State


private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e


private theorem row_annotation {P C Γ} : Ty.Annotation P C Γ rowType


private theorem argument_typed {P B Ψ Q C Γ Φ} : HasTypeVQ P B Ψ Q C Γ Φ argument rowType


private theorem call_signature {P} : SignatureInstance P [] [] declaration.tel [.value] [rowType] []


private theorem source_code {P B} (hB : B.CoreAssumptions P)
    (hop : P.ops "Example.identity" = some declaration) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none source rowType outputEffect []


private theorem initial {P B σ m a e}
    (h : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none m a e [])
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e)))
    (hn : a.Normal) (hc : m.ClosedAt 0 0) (had : m.Adequate σ) :
    StateTyE P B σ e (.run (Closure.pure m) [] Store.empty)


private theorem row_initial {P B σ} (hB : B.CoreAssumptions P)
    (hop : P.ops "Example.identity" = some declaration) :
    StateTyE P B σ outputEffect (.run (Closure.pure source) [] Store.empty)


theorem row_handle_operation_resume {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hop : P.ops "Example.identity" = some declaration) :
    StateTyE P B σ outputEffect opState ∧ StateTyE P B σ outputEffect resumeState


theorem noFail_cutoff_accept :
    NoFail (fun i => i = 9) (Eff.substAt 2 [rowType] [] (Eff.row 9))


theorem noFail_cutoff_reject :
    ¬ NoFail Qempty (Eff.substAt 2 [rowType] [] (Eff.row 9))


private theorem unit_annotation {P C Γ} : Ty.Annotation P C Γ (.base .unit)


private theorem left_sub (e f : Eff) : Eff.Sub e (Eff.union e f)


theorem failure_state {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ (Eff.union Eff.empty (Eff.single stateEff))
      (.run (.mk (Capture.empty.extendMany [unit,.loc 0]) (.ret unit)) [.drop 0]
        (Store.empty.set 0 (.cont [.handleF Capture.empty [.fail (.base .unit) (.ret unit)]])))


private def primitiveSig : PrimSig


private def primitiveEffect : Eff


private def primitiveClauses (σ : PathEnv) : List Clause


theorem primitive_pathBases {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hdecl : P.EffectsOk B) (hsig : B.sig "Example.pathBases" = some primitiveSig) (hσ : σ.Valid) :
    StateTyE P B σ primitiveEffect
      (.run (.mk (Capture.empty.extendMany [.loc 0]) (.ret (.pathBases σ))) [.drop 0]
        (Store.empty.set 0 (.cont [.handleF Capture.empty (primitiveClauses σ)])))


private def modelProgram : Program


private def modelGet : PrimSig


private def modelSet : PrimSig


private def modelBuiltins : Builtins


private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet


private theorem model_external : modelProgram.ExternalWF


private theorem model_wellFormed : modelProgram.WellFormed


private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins


private theorem model_core : modelBuiltins.CoreAssumptions modelProgram


theorem row_concrete_model (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ outputEffect opState ∧
    StateTyE modelProgram modelBuiltins σ outputEffect resumeState


```

## HandlerCalls

```lean

private theorem toTel_annotation {P ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e)) :
    Ty.Annotation P [] [] (.dependentFn (Ty.toTel ns ps r e))


private theorem bind_shift_ty (a : Ty) (v : Val) :
    (a.shiftV 1 0).bind (Tel.argumentsEnv v) = a.norm


private theorem bind_shift_eff (e : Eff) (v : Val) :
    Eff.bind (Tel.argumentsEnv v) (e.shiftV 1 0) = e.norm


private theorem vs_normal {P B Ψ Q C Γ Φ vs ps}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs ps) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (Ty.normTys ps)


private theorem vs_toTel {P B Ψ vs ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e)


private theorem op_annotation {P B Ψ Q C Γ Φ v T o ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .op o ts) :
    Ty.Annotation P C Γ T


private theorem op_inv {P B Ψ Q C Γ Φ v T o ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .op o ts) :
    ∃ od u, P.ops o = some od ∧
      SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts [] ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel od.tel ts []) u


theorem HasTypeVQ.op_signature {P B Ψ Q C Γ Φ o ts a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) a) :
    ∃ od, P.ops o = some od ∧
      SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts []


theorem HasTypeVQ.op_typeScope {P B Ψ Q C Γ Φ o ts a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) a) :
    ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t


private theorem operation_call_aux {P B Ψ Q C Γ Φ R code a e L o ws od ts}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .app (.op o ts) ws) (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
      (instantiatedTel od.tel ts []) r f ∧ Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem HasTypeCQ.operation_call {P B Ψ R o v a e L od ts}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o ts) [v]) a e L)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem HasTypeCQ.operation_call_all {P B Ψ R o ws a e L od ts}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o ts) ws) a e L)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


private theorem operation_signature_aux {P B Ψ Q C Γ Φ R code a e L o v od ts}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hc : code = .app (.op o ts) [v]) (hd : P.ops o = some od) :
    Ty.Annotation P C Γ (.dependentFn (instantiatedTel od.tel ts []))


private theorem operation_annotation {P B Ψ Q C Γ Φ R code a e L o v ts}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hc : code = .app (.op o ts) [v]) : Ty.Annotation P C Γ a


private theorem app_resolve {P B Ψ Q C Γ Φ R code a e L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .app f ws) (ρ) :
    code.resolveLocals ρ = code


theorem ClosureTy.pure_operation {P B Ψ R a e o v od ts}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem ClosureTy.pure_operation_signature {P B Ψ R a e o v od ts}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (hd : P.ops o = some od) :
    Ty.Annotation P [] [] (.dependentFn (instantiatedTel od.tel ts []))


private theorem operation_typeScope_aux {P B Ψ Q C Γ Φ R m a e D o ts v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e D) (hm : m = .app (.op o ts) [v]) :
    ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t


theorem ClosureTy.pure_operation_typeScope {P B Ψ R a e o v ts}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e) :
    ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t


private theorem raise_inv {P B Ψ Q C Γ Φ v A T E}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v A) (hv : v = .raise T E) :
    ∃ u, A.fnCore = some u ∧
      TelClosure P Γ Φ (Ty.toTel ["error"] [E] T (Eff.singleFail E)) u


private theorem raise_annotation {P B Ψ Q C Γ Φ v A T E}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v A) (hv : v = .raise T E) :
    Ty.Annotation P C Γ A


private theorem raise_source_annotation {P B Ψ Q C Γ Φ v A T E}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v A) (hv : v = .raise T E) :
    Ty.Annotation P C Γ (.fn ["error"] [E] T (Eff.singleFail E))


private theorem failure_call_aux {P B Ψ Q C Γ Φ R code a e L T E v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .app (.raise T E) [v]) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (Ty.toTel ["error"] [E] T (Eff.singleFail E)) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem HasTypeCQ.failure_call {P B Ψ R T E v a e L}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.raise T E) [v]) a e L) :
    HasTypeVQ P B Ψ Qempty [] [] [] v E.norm ∧
      Ty.LeQ P [] [] T.norm a ∧ Eff.Covers [] [] e (Eff.singleFail E)


```

## ReferenceCalls

```lean

private theorem narrow_transport {Γ Φ a b} (h : Ty.LeQ P Γ Φ b a) :
    Transport (renEnv id) (Γ.extend a) (Φ.map Pred.lift) (Γ.extend b) (Φ.map Pred.lift)


private theorem tel_narrow {Γ Φ a b t u} (h : Ty.LeQ P Γ Φ b a)
    (ht : TelClosure P (Γ.extend a) (Φ.map Pred.lift) t u) :
    TelClosure P (Γ.extend b) (Φ.map Pred.lift) t u


private theorem param_inv_aux {Γ Φ s u} (h : TelClosure P Γ Φ s u) :
    ∀ n a t, s = .param n a t →
      ∃ b v, u = .param n b v ∧ Ty.LeQ P Γ Φ b a ∧
        TelClosure P (Γ.extend b) (Φ.map Pred.lift) t v


private theorem param_inv {Γ Φ n a t u} (h : TelClosure P Γ Φ (.param n a t) u) :
    ∃ b v, u = .param n b v ∧ Ty.LeQ P Γ Φ b a ∧
      TelClosure P (Γ.extend b) (Φ.map Pred.lift) t v


private theorem done_inv_aux {Γ Φ s u} (h : TelClosure P Γ Φ s u) :
    ∀ a e, s = .done a e →
      ∃ b f, u = .done b f ∧ Ty.LeQ P Γ Φ a b ∧ Eff.Covers Γ Φ f e


private theorem done_inv {Γ Φ a e u} (h : TelClosure P Γ Φ (.done a e) u) :
    ∃ b f, u = .done b f ∧ Ty.LeQ P Γ Φ a b ∧ Eff.Covers Γ Φ f e


theorem HasTypeTelArgsQ.pullback {P B Ψ ws t u a e}
    (ht : Ty.Annotation P [] [] (.dependentFn t))
    (hr : TelClosure P [] [] t u)
    (ha : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t b f ∧
      Ty.LeQ P [] [] b a ∧ Eff.Covers [] [] e f


private theorem toTel_annotation {P ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e)) :
    Ty.Annotation P [] [] (.dependentFn (Ty.toTel ns ps r e))


private theorem bind_shift_ty (a : Ty) (v : Val) :
    (a.shiftV 1 0).bind (Tel.argumentsEnv v) = a.norm


private theorem bind_shift_eff (e : Eff) (v : Val) :
    Eff.bind (Tel.argumentsEnv v) (e.shiftV 1 0) = e.norm


private theorem vs_normal {P B Ψ Q C Γ Φ vs ps}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs ps) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (Ty.normTys ps)


private theorem vs_toTel {P B Ψ vs ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e)


private theorem prim_annotation {P B Ψ Q C Γ Φ v T b ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b ts es rs) :
    Ty.Annotation P C Γ T


private theorem prim_inv {P B Ψ Q C Γ Φ v T b ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b ts es rs) :
    ∃ s u, B.sig b = some s ∧ B.RangeAdmissible b s rs ∧
      PrimitiveAdmissible C Γ.length s Q ts es ∧
      SignatureInstance P C Γ (Tel.instR rs s.tel) (s.tparams.map TParamDecl.kind) ts es ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u


theorem HasTypeVQ.primitive_inputs {P B Ψ Q C Γ Φ b s ts es rs a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es rs) a) (hs : B.sig b = some s) :
    B.RangeAdmissible b s rs ∧ PrimitiveAdmissible C Γ.length s Q ts es ∧
      SignatureInstance P C Γ (Tel.instR rs s.tel) (s.tparams.map TParamDecl.kind) ts es


private theorem primitive_call_aux {P B Ψ Q C Γ Φ R code a e L b ts es rs ws s}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hg : ∀ v ∈ ws, v.Ground)
    (hc : code = .app (.prim b ts es rs) ws) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem HasTypeCQ.primitive_call {P B Ψ R code a e L b ts es rs ws s}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hg : ∀ v ∈ ws, v.Ground)
    (hc : code = .app (.prim b ts es rs) ws) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


private theorem primitive_annotation {P B Ψ Q C Γ Φ R code a e L b ts es rs ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hc : code = .app (.prim b ts es rs) ws) : Ty.Annotation P C Γ a


private theorem app_resolve {P B Ψ Q C Γ Φ R code a e L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .app f ws) (ρ) :
    code.resolveLocals ρ = code


private def isApp : Comp → Bool | .app .. => true | _ => false

/-- 空の捕捉でも導出に存在しうる Φ を閉じた事実から除去し、呼出しの葉を得る。 -/
theorem ClosureTy.pure_primitive {P B Ψ R a e b ts es rs ws s}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.prim b ts es rs) ws)) a e)
    (hg : ∀ v ∈ ws, v.Ground) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem ClosureTy.pure_primitive {P B Ψ R a e b ts es rs ws s}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.prim b ts es rs) ws)) a e)
    (hg : ∀ v ∈ ws, v.Ground) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f


theorem HasTypeVsQ.toTel_normal {P B Ψ vs ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs
      (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e)


```

## HandlerContinuation

```lean

def HandlerFrameTy (P : Program) (B : Builtins) (Ψ : StoreTy) (R : Option Ty)
    (cap : Capture) (h : List Clause) (t : Ty) (ec eb : Eff) : Prop


theorem ContTy.nil_inv {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hk : k = []) :
    Ty.LeQ P [] [] a b ∧ Eff.Sub ε Eb ∧ R = Re ∧ Ty.Annotation P [] [] b


private theorem end_tail {f : Frame} {k : Cont} (h : EndsWithHandle (f :: k)) (hk : k ≠ []) :
    EndsWithHandle k


private theorem end_tail' {f : Frame} {k : Cont} (h : EndsWithHandle (f :: k))
    (hf : ∀ cap cs, f ≠ .handleF cap cs) : EndsWithHandle k


theorem ContTy.resume_append {P B σ Ψ R ε saved a t ec Rh}
    (hs : ContTy P B σ Ψ R ε saved a t ec Rh) (hend : EndsWithHandle saved)
    {k u b Eb Re e} (hl : Ty.LeQ P [] [] t u)
    (hk : ContTy P B σ Ψ Rh e k u b Eb Re) (he : Eff.Covers [] [] e ec) :
    ContTy P B σ Ψ R ε (saved ++ k) a b Eb Re


private theorem failure_handles {P B Ψ Q C Γ Φ E R cs t ec L}
    (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t ec L) : handles cs .fail = true


private theorem covered_name {outer inner : Eff} {l ix}
    (hc : Eff.Covers [] [] outer inner) (hm : inner.mem (.name l ix)) :
    ∃ jx, outer.mem (.name l jx) ∧ jx.Covers ix


private theorem union_name_mem {e f : Eff} {a : Atom}
    (hm : (Eff.union e f).mem a) : e.mem a ∨ f.mem a


private theorem handle_name {eb ec et : Eff} {P B cs l ix}
    (hb : Eff.Sub eb (Eff.union ec (handled P B cs)))
    (hc : Eff.Covers [] [] et ec) (hm : eb.mem (.name l ix))
    (hn : ∀ jx, ¬ (handled P B cs).mem (.name l jx)) :
    ∃ jx, et.mem (.name l jx) ∧ jx.Covers ix


private theorem failure_name {rest ec : Eff} {E l ix}
    (hc : Eff.Covers [] [] ec rest)
    (hm : (Eff.union (Eff.singleFail E) rest).mem (.name l ix)) :
    ∃ jx, ec.mem (.name l jx) ∧ jx.Covers ix


theorem ContTy.split_handle {P B σ Ψ R ε k a b Eb Re cap cs k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap cs :: k2) (hn : handles cs .fail = false) :
    ∃ t ec eb et Rh,
      ContTy P B σ Ψ R ε (k1 ++ [.handleF cap cs]) a t ec Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧
      Eff.Sub eb (Eff.union ec (handled P B cs)) ∧
      HandlerFrameTy P B Ψ Rh cap cs t ec eb ∧
      (∀ l ix, ε.mem (.name l ix) →
        (∀ cap' cs' jx, Frame.handleF cap' cs' ∈ k1 → ¬ (handled P B cs').mem (.name l jx)) →
        ∃ jx, eb.mem (.name l jx) ∧ jx.Covers ix)


```

## CaptureRegularity

```lean

def CaptureContextRegular (P : Program) (C : TypeCtx) (Γ : Ctx) : Prop


theorem CaptureContextRegular.extend {P C Γ a}
    (h : CaptureContextRegular P C Γ) (ha : Ty.Annotation P C Γ a) :
    CaptureContextRegular P C (Γ.extend a)


theorem CaptureContextRegular.extendNone {P C Γ} (h : CaptureContextRegular P C Γ) :
    CaptureContextRegular P C Γ.extendNone


theorem CaptureContextRegular.variable {P C Γ a} {i : Nat}
    (h : CaptureContextRegular P C Γ) (hi : Γ[i]? = some (some a)) (ho : Ordinary a) :
    Ty.Annotation P C Γ a


theorem CaptureOk.contextRegular {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureContextRegular P [] Γ


theorem let_annotation {P C Γ a b} (hn : Ty.Annotation P C (Γ.extend a) (b.shiftV 1 0))
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Γ b


private theorem none_typeMap (Γ : Ctx) :
    Ctx.TypeMap Γ.extendNone (Γ.extend (.base .unit))


theorem Ty.wf_shiftV_rev_extendNone {a : Ty} {nr nt : Nat} {Γ : Ctx}
    (h : (a.shiftV 1 0).WF nr nt Γ.extendNone.length) : a.WF nr nt Γ.length


theorem Ty.sorted_shiftV_rev_extendNone {a : Ty} {Γ : Ctx}
    (h : (a.shiftV 1 0).Sorted Γ.extendNone) : a.Sorted Γ


theorem Ty.Declared.shiftV_rev_extendNone {P C Γ} {a : Ty}
    (h : (a.shiftV 1 0).Declared P C Γ.extendNone) : a.Declared P C Γ


theorem builder_annotation {P C Γ a} (hn : Ty.Annotation P C Γ.extendNone (a.shiftV 1 0))
    (hd : a.Declared P C Γ) : Ty.Annotation P C Γ a


theorem used_annotation {P Ψ l b t e R C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e R)) : Ty.Annotation P C Γ t


theorem locref_annotation {P Ψ l a C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ (.reference a)


theorem checked_annotation (P : Program) (C : TypeCtx) (Γ : Ctx)
    (o : OpaqueName) (k : Scope.Domain.Kind) (r : Scope.Domain.Range) :
    Ty.Annotation P C Γ (.scoped o k (.fixed (.absolute r)))


private theorem arms_annotation {P B Ψ Q C Γ Φ R obs arms a b e L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) : Ty.Annotation P C Γ b


  private theorem value_annotation {P B Ψ Q C Γ Φ v a}
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hΓ : CaptureContextRegular P C Γ) : Ty.Annotation P C Γ a


  private theorem comp_annotation {P B Ψ Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hΓ : CaptureContextRegular P C Γ) : Ty.Annotation P C Γ a


theorem open_value_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    Ty.Annotation P C Γ a


theorem open_comp_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
    {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    Ty.Annotation P C Γ a


theorem open_values_annotation {P B Ψ Q C Γ Φ vs as}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
    TypeAnnotations P C Γ as


theorem open_each_annotation {P B Ψ Q C Γ Φ vs a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a)
    (hne : vs ≠ []) : Ty.Annotation P C Γ a


theorem open_arms_annotation {P B Ψ Q C Γ Φ R obs arms a b e L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) : Ty.Annotation P C Γ b


theorem open_telArgs_annotation {P B Ψ Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) :
    Ty.Annotation P C Γ (.dependentFn (.done a e))


theorem capture_value_annotation {P B Ψ R Γ Φ cap v a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a)


theorem capture_comp_annotation {P B Ψ R Γ Φ cap Rs m a e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a)


private theorem done_union_annotation {P C Γ a} {e f : Eff}
    (he : Ty.Annotation P C Γ (.dependentFn (.done a e)))
    (hf : Ty.Annotation P C Γ (.dependentFn (.done a f))) :
    Ty.Annotation P C Γ (.dependentFn (.done a (Eff.union e f)))


private theorem noFail_done_annotation {P C Γ Q a e}
    (ha : Ty.Annotation P C Γ a) (hn : NoFail Q e) :
    Ty.Annotation P C Γ (.dependentFn (.done a e))


private theorem fail_done_annotation {P C Γ a E}
    (ha : Ty.Annotation P C Γ a) (hE : Ty.Annotation P C Γ E) :
    Ty.Annotation P C Γ (.dependentFn (.done a (Eff.singleFail E)))


private theorem done_annotation_of_fail_sub {P a} {outer inner : Eff}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a outer)))
    (hsub : ∀ x, inner.memFail x → outer.memFail x) (hn : inner.Canonical) :
    Ty.Annotation P [] [] (.dependentFn (.done a inner))


theorem capture_handle_body_annotation {P B t eb ec h} {cap : Capture}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))))
    (hb : Eff.Sub eb (Eff.union ec (handled P B h))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb)))


theorem failure_effect_upper_annotation {P C Γ Q t E rest}
    (ha : Ty.Annotation P C Γ t) (hE : Ty.Annotation P C Γ E) (hn : NoFail Q rest) :
    Ty.Annotation P C Γ (.dependentFn (.done t (Eff.union (Eff.singleFail E) rest)))


theorem capture_failure_body_annotation {P B Ψ cap Γ Φ R Rs t E eb rest ec h L}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hf : HasFailureClause P B Ψ Qempty [] Γ Φ E Rs h t ec L)
    (hn : NoFail Qempty rest) (hb : Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb)))


theorem CaptureOk.continuation_annotation {P B Ψ R Γ Φ cap} {i : Nat} {b t e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hw : Ψ.WF) (hs : Ψ.Sorted)
    (hd : StoreTy.Declared P Ψ) (hi : Γ[i]? = some (some (.cont b t e))) :
    Ty.Annotation P [] [] (cap.closeTy (.cont b t e))


theorem CaptureOk.continuation_result_effect {P B Ψ R Γ Φ cap} {i : Nat} {b t e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hw : Ψ.WF) (hs : Ψ.Sorted)
    (hd : StoreTy.Declared P Ψ) (hi : Γ[i]? = some (some (.cont b t e))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff e)))


theorem capture_let_effect_annotations {P B Ψ R Rs Γ Φ cap m a b e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy b) (cap.closeEff e)))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) ∧
    Ty.Annotation P [] (bindParams [] [cap.closeTy a])
      (.dependentFn (.done (cap.closeTyAt 1 (b.shiftV 1 0)) (cap.closeEffAt 1 (e.shiftV 1 0))))


theorem capture_tel_annotation {P B Ψ R Γ Φ cap t}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ha : Ty.Annotation P [] Γ (.dependentFn t)) :
    Ty.Annotation P [] [] (.dependentFn (cap.closeTel t))


theorem capture_function_result_effect {P B Ψ R Γ Φ cap ns ps r e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ha : Ty.Annotation P [] Γ (.fn ns ps r e)) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy r) (cap.closeEff e)))


theorem HasFailureClause.capture_result_effect {P B Ψ cap Γ Φ R Rs E t ec h L}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hf : HasFailureClause P B Ψ Qempty [] Γ Φ E Rs h t ec L) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec)))


private theorem cover_close {Γ Φ outer inner} (cap : Capture) (h : Eff.Covers Γ Φ outer inner) :
    Eff.Covers [] [] (cap.closeEff outer) (cap.closeEff inner)


theorem done_inner {P cap Γ Φ a b outer inner}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a (Capture.closeEff cap outer))))
    (hb : Ty.Annotation P [] [] b) (hc : Eff.Covers Γ Φ outer inner) :
    Ty.Annotation P [] [] (.dependentFn (.done b (Capture.closeEff cap inner)))


theorem handle_inv {P B Ψ Q C Γ Φ Rs code m h a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .handle m h) :
    (∃ t εm ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m t εm L ∧
      Eff.Sub εm (Eff.union ε (handled P B h)) ∧
      HasTypeClausesQ P B Ψ Q C Γ Φ Rs εm h t ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ t a) ∨
    (∃ t E eb rest ec, HasTypeCQ P B Ψ Q C Γ Φ Rs m t eb L ∧
      Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Q rest ∧
      HasFailureClause P B Ψ Q C Γ Φ E Rs h t ec L ∧
      Eff.Covers Γ Φ e (Eff.union rest ec) ∧ Ty.LeQ P Γ Φ t a)


theorem e_handle_supply {P B Ψ R q m h a e1}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hv : q.view = .handle m h) :
    ∃ cap Γ Φ Rs m0 h0 L ρ, q = .mk cap (Comp.handle m0 h0 |>.resolveLocals ρ) ∧
      CaptureOk P B Ψ R Γ Φ cap ∧ CaptureLocals Ψ cap.env L ρ ∧
      ((∃ t εm ε, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t εm L ∧
          Eff.Sub εm (Eff.union ε (handled P B h0)) ∧
          HasTypeClausesQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs εm h0 t ε L ∧
          Eff.Covers [] [] e1 (cap.closeEff ε) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ε))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff εm)))) ∨
       (∃ t E eb rest ec, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t eb L ∧
          Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Benitoite.Release.Qempty rest ∧
          HasFailureClause P B Ψ Benitoite.Release.Qempty [] Γ Φ E Rs h0 t ec L ∧
          Eff.Covers [] [] e1 (cap.closeEff (Eff.union rest ec)) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb)))))


private theorem let_inv {P B Ψ Q C Γ Φ Rs code m n a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .letIn m n) :
    ∃ a0 b ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m a0 ε L ∧
      HasTypeCQ P B Ψ Q C (Γ.extend a0) (Φ.map Pred.lift) (Rs.map (Ty.shiftV 1 0))
        n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L) ∧
      Ty.Declared P C Γ b ∧ HasTypeCQ P B Ψ Q C Γ Φ Rs (.letIn m n) b ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ b a


theorem ContTy.return_wf {P B σ Ψ R ε k a b Eb Re} (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (hRe : Re = none) : ∀ r, R = some r → r.WF 0 0 0


theorem e_let_post {P B σ Ψ R q m n a e1 e k b Eb}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hsub : Eff.Sub e1 e)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hv : q.view = .letIn m n) (had : (Closure.mk q.capture n).Adequate σ) :
    ∃ a' e1', ClosureTy P B Ψ [] R (.mk q.capture m) a' e1' ∧ Eff.Sub e1' e ∧
      ContTy P B σ Ψ R e (.letF (.mk q.capture n) :: k) a' b Eb none


theorem split_fail_annotated {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) :
    ∃ t ec et Rh, ContTy P B σ Ψ R ε (k1 ++ [.handleF cap [.fail E0 body]]) a t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧ Eff.Sub (.mk et.atoms ec.fails) et ∧
        Ty.Annotation P [] [] (.dependentFn (.done t ec)) ∧
        ∃ Γ Φ Rs Es ts ecs,
          CaptureOk P B (hideBuilders Ψ) Rh Γ Φ cap ∧
          HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ Es Rs [.fail E0 body] ts ecs [] ∧
          cap.closeR Rs = Rh ∧ cap.closeTy ts = t ∧ cap.closeEff ecs = ec ∧
          (∀ r, Rs = some r → r.Declared P [] Γ)


```

## HandlerOperation

```lean

private theorem typeEnv_nil : typeEnvAt 0 [] [] = renEnv id


private theorem mono_tel (name : String) (x y : Ty) (eff : EffName)
    (hxn : x.Normal) (hyn : y.Normal) :
    instantiatedTel (OpDecl.tel ⟨eff, [], [name], [x], y, []⟩) [] [] =
      .param name x (.done y (Eff.single eff))


private theorem annotation_closed {P Γ x} (hx : Ty.Annotation P [] [] x) : Ty.Annotation P [] Γ x


private theorem annotation_one {P x y} {Γ : Ctx} (hx : Ty.Annotation P [] [] x)
    (hy : Ty.Annotation P [] (Ctx.extend [] x) y) : Ty.Annotation P [] (Γ.extend x) y


private theorem close_one (cap : Capture) (name : String) (eff : EffName) {P x y} (v : Val)
    (hx : Ty.Annotation P [] [] x) (hy : Ty.Annotation P [] (Ctx.extend [] x) y)
    (hxn : x.Normal) (hyn : y.Normal) :
    (cap.extend v).closeTy y = substTyValues (openValue v) y


private theorem clauses_no_fail {P B Ψ Q C Γ Φ R eb cs t ec L}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ec L) : handles cs .fail = false


private theorem clause_one {P B Ψ Q C Γ Φ R eb cs t ec L o name x y eff body}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ec L)
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hc : findClause cs (.user o) = some (.mk (.user o) 1 0 body)) :
    HasTypeCQ P B (hideBuilders Ψ) Q C
      ((Γ.extend x).extend (.cont y (t.shiftV 1 0) (ec.shiftV 1 0)))
      (liftMany 2 Φ) (R.map (Ty.shiftV 2 0)) body (t.shiftV 2 0) (ec.shiftV 2 0) []


private theorem closeEff_shift (cap : Capture) (v : Val) (e : Eff) :
    (cap.extend v).closeEff (e.shiftV 1 0) = cap.closeEff e


private theorem closeTy_two (cap : Capture) (v w : Val) (a : Ty) :
    ((cap.extend v).extend w).closeTy (a.shiftV 2 0) = cap.closeTy a


private theorem closeEff_two (cap : Capture) (v w : Val) (e : Eff) :
    ((cap.extend v).extend w).closeEff (e.shiftV 2 0) = cap.closeEff e


private theorem covers_state {outer inner : Eff} (h : Eff.Covers [] [] outer inner)
    (hm : inner.mem (.name stateEff (.fixed .top))) : outer.mem (.name stateEff (.fixed .top))


private theorem handle_no_fail {P B σ Ψ R e frames a b Eb Re cap cs k1 k2 o}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = k1 ++ .handleF cap cs :: k2) (hopen : handles cs (.user o) = true) :
    handles cs .fail = false


theorem ContTy.guard_effect {P B σ Ψ R e frames a b Eb Re v cap arms next body k}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = .guardF v cap arms next body :: k) : R = none ∧ e = Eff.empty


theorem StateTyE.operation_under_guard_false
    {P B σ Eb o name x y eff arg v cap arms next body k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o []) [arg]))
      (.guardF v cap arms next body :: k) μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hxn : x.Normal) (hyn : y.Normal) : False


private theorem clause_closed {cs : List Clause} {op ar nty body nt nv}
    (h : Clause.ClosedList nt nv cs) (hc : Clause.mk op ar nty body ∈ cs) :
    body.ClosedAt (nt+nty) (nv+ar+1)


private theorem clause_adequate {cs : List Clause} {c : Clause} {σ}
    (h : adequateClauses σ cs) (hc : c ∈ cs) : c.body.Adequate σ


theorem ClosureTy.widen_atoms {P B Ψ R q a ec et}
    (hq : ClosureTy P B Ψ [] R q a ec) (he : Eff.Covers [] [] et ec) :
    ClosureTy P B Ψ [] R q a (.mk et.atoms ec.fails) ∧ Eff.Sub (.mk et.atoms ec.fails) et


theorem StateTyE.operation_one {P B σ Eb o name x y eff v cap cs k1 k2 k μ body l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o []) [v])) k μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hxn : x.Normal) (hyn : y.Normal)
    (hsp : SplitAt (.user o) k k1 cap cs k2)
    (hc : findClause cs (.user o) = some (.mk (.user o) 1 0 body))
    (hbn : body.substTy [] [] = body) (hf : μ l = none)
    (hv : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.app (.op o []) [v])) k μ) none
      (.run (.mk (cap.extendMany [v, .loc l]) body) (.drop l :: k2)
        (μ.set l (.cont (k1 ++ [.handleF cap cs])))) ∧
    StateTyE P B σ Eb
      (.run (.mk (cap.extendMany [v, .loc l]) body) (.drop l :: k2)
        (μ.set l (.cont (k1 ++ [.handleF cap cs]))))


theorem StateTyE.operation_typeScope {P B σ Eb o ts v k μ}
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o ts) [v])) k μ)) :
    ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t


```
