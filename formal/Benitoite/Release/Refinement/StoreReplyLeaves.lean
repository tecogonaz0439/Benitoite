import Benitoite.Release.Refinement.SourcePreparation

/-! # Reference/Lazy と応答の23遷移への分配 -/
namespace Benitoite.Release.Refinement

/-- この担当の葉のソース入力。各構成子は同名の Step の前提を受け取る。 -/
inductive StoreReplyInputs (P : Program) (B : Builtins) (σ : PathEnv) :
    State → Option Event → State → Prop where
  | E_RefNew {b ts es rs v k μ s l} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) [v]) →
      B.sig b = some s → s.kind = .refNew → μ l = none →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))
  | E_RefGet {b ts es rs l k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) [.loc l]) →
      B.sig b = some s → s.kind = .refGet → μ l = some (.val v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_RefSet {b ts es rs l v k μ s} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) [.loc l, v]) →
      B.sig b = some s → s.kind = .refSet →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))
  | E_RefUpdate {b ts es rs l f k μ s} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) [.loc l, f]) →
      B.sig b = some s → s.kind = .refUpdate →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
                (.letIn (.app (f.rename (· + 1)) [.var 0])
                  (.app (.prim B.refSet ts [] []) [.loc l, .var 0])))) k μ)
  | E_Lazy {m k μ l} {q : Closure} :
      q.view = (.lazyC m) →
      μ l = none →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (Closure.mk q.capture m))))
  | E_ForceDone {b ts es rs l k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) [.loc l]) →
      B.sig b = some s → s.kind = .force → μ l = some (.done v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_Force {b ts es rs l k μ s m} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) [.loc l]) →
      B.sig b = some s → s.kind = .force → μ l = some (.thunk m) →
      StoreReplyInputs P B σ (.run q k μ) none (.run m (.update l :: k) μ)
  | E_Update {v l k μ} {q : Closure} :
      q.view = (.ret v) →
      StoreReplyInputs P B σ (.run q (.update l :: k) μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.done v)))
  | E_ErrPopUpdate {rs l k μ} : StoreReplyInputs P B σ (.error rs (.update l :: k) μ) none (.error rs k μ)
  | E_ExitPopUpdate {n rs l k μ} : StoreReplyInputs P B σ (.exit n rs (.update l :: k) μ) none (.exit n rs k μ)
  | E_Prim {b ts es rs ws k μ s v} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) ws) →
      B.sig b = some s → s.kind = .pure → B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.val v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_Err {b ts es rs ws k μ s r} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) ws) →
      B.sig b = some s → s.kind = .pure → B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws = some (.err r) →
      StoreReplyInputs P B σ (.run q k μ) none (.error [r] k μ)
  | E_IO {b ts es rs ws k μ s v obs} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) ws) →
      B.sig b = some s → s.kind = .io → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.val v) obs →
      StoreReplyInputs P B σ (.run q k μ) (some (.io b ws (.val v) obs)) (.run (Closure.pure (.ret v)) k μ)
  | E_IOErr {b ts es rs ws k μ s r obs} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) ws) →
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.err r) obs →
      StoreReplyInputs P B σ (.run q k μ) (some (.io b ws (.err r) obs)) (.error [r] k μ)
  | E_Exit {b ts es rs ws k μ s n obs} {q : Closure} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) ws) →
      B.sig b = some s → s.kind = .exit → NoHandler k (.prim b) →
      B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.exit n) obs →
      StoreReplyInputs P B σ (.run q k μ) (some (.io b ws (.exit n) obs)) (.exit n [] k μ)
  | E_ExternalApply {q : Closure} {f ts ws k μ} :
      q.view = .app (.externalRef f ts) ws →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.externalCall f ts ws)) k μ)
  | E_External {q : Closure} {f ts ws k μ decl v obs out} :
      q.view = .externalCall f ts ws → P.externalFunction f = some decl →
      B.externalResponse f ts ws out obs → externalReceive P decl ts ws out = some (.val v) →
      StoreReplyInputs P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ)
  | E_ExternalErr {q : Closure} {f ts ws k μ decl r obs out} :
      q.view = .externalCall f ts ws → P.externalFunction f = some decl →
      B.externalResponse f ts ws out obs → externalReceive P decl ts ws out = some (.err r) →
      StoreReplyInputs P B σ (.run q k μ) none (.error [r] k μ)
  | E_PathBasesApply {q : Closure} {b sg k μ} :
      q.view = .app (.prim b [] [] []) [] → B.sig b = some sg → sg.kind = .pathBases →
      StoreReplyInputs P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ)
  | E_IssuePathBases {q : Closure} {b sg k μ} :
      q.view = .issuePathBases b → B.sig b = some sg → sg.kind = .pathBases →
      sg.opEff = some processEnvironmentEff → σ.Valid →
      StoreReplyInputs P B σ (.run q k μ) (some (.pathBases b σ))
        (.run (Closure.pure (.ret (.pathBases σ))) k μ)
  | E_AtOk {q : Closure} {kind name shape bases pattern input index snapshot pat target bound t k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
      (∀ ρ, snapshot = some ρ → ρ = σ) → checkAt snapshot kind pat target bound = .ok t →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.ok
          [.scoped name kind (.fixed bound), q.capture.closeTy shape.errorType]
          [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ)
  | E_AtError {q : Closure} {kind name shape bases pattern input index snapshot pat target bound detail k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound →
      (∀ ρ, snapshot = some ρ → ρ = σ) → checkAt snapshot kind pat target bound = .error detail →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.error
          [.scoped name kind (.fixed bound), q.capture.closeTy shape.errorType] [.atError (AtError.fromCheck (closeVal q.capture pattern) (closeVal q.capture input) snapshot pat target detail)]))) k μ)
  | E_AtPrepareError {q : Closure} {kind name shape bases pattern input index detail k μ} :
      q.code = .checkAt kind name shape bases pattern input index →
      AtPrepare B q.capture kind name bases pattern input index = .error detail →
      StoreReplyInputs P B σ (.run q k μ) none
        (.run (Closure.pure (.ret (.con shape.error
          [.scoped name kind index, q.capture.closeTy shape.errorType] [.atError detail]))) k μ)

/-- ソース入力から実遷移と型付きの行先を作る。全76遷移の保存は含めない。 -/
theorem StateTyE.store_reply {P B σ Eb s event dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb s) (inputs : StoreReplyInputs P B σ s event dest) :
    Step P B σ s event dest ∧ StateTyE P B σ Eb dest ∧ LocalStateInvariant P B σ dest := by
  obtain ⟨hs,hd⟩ : Step P B σ s event dest ∧ StateTyE P B σ Eb dest := by
    cases inputs with
    | E_RefNew hv hs hk hl => exact (h.reference_new_all hP hPB hB hv hs hk hl)
    | E_RefGet hv hs hk hl => exact (h.reference_get_all hP hPB hB hv hs hk hl)
    | E_RefSet hv hs hk => exact (h.reference_set_all hP hPB hB hv hs hk)
    | E_RefUpdate hv hs hk => exact (h.reference_update_all hP hPB hB hv hs hk)
    | E_Lazy hv hl => exact (h.lazy_transition hB hv hl)
    | E_ForceDone hv hs hk hl => exact (h.force_done_all hP hPB hB hv hs hk hl)
    | E_Force hv hs hk hl => exact (h.force_thunk_all hP hPB hB hv hs hk hl)
    | E_Update hv => exact (h.lazy_update_all hP hPB hB hv)
    | E_ErrPopUpdate => exact h.lazy_update_pop_error
    | E_ExitPopUpdate => exact h.lazy_update_pop_exit
    | E_Prim hv hs hk hr => exact (h.primitive_value_all hP hPB hB hσ hv hs hk hr)
    | E_Err hv hs hk hr => exact (h.primitive_error_all hv hs hk hr)
    | E_IO hv hs hk hnh hr => exact (h.io_value_all hP hPB hB hσ hv hs hk hnh hr)
    | E_IOErr hv hs hk hnh hr => exact (h.io_error_all hv hs hk hnh hr)
    | E_Exit hv hs hk hnh hr => exact (h.io_exit_all hv hs hk hnh hr)
    | E_ExternalApply hv => exact (h.external_apply_all hP hPB hB hv)
    | E_External hv hs hr hrec => exact (h.external_value_all hP hPB hB hv hs hr hrec)
    | E_ExternalErr hv hs hr hrec => exact (h.external_error_all hv hs hr hrec)
    | E_PathBasesApply hv hs hk => exact (h.path_bases_apply_all hP hPB hB hv hs hk)
    | E_IssuePathBases hv hs hk hop hvalid => exact (h.issue_path_bases_all hv hs hk hop hvalid)
    | E_AtOk hv hp hc ha => exact (h.at_ok_all hP hPB hB hσ hv hp hc ha)
    | E_AtError hv hp hc ha => exact (h.at_error_all hv hp hc ha)
    | E_AtPrepareError hv ha => exact (h.at_prepare_error_all hv ha)
  exact ⟨hs,hd,hd.local_invariant⟩

end Benitoite.Release.Refinement
