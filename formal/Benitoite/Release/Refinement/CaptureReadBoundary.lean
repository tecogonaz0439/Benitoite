import Benitoite.Release.Refinement.StoreReplyLeaves
import Benitoite.Release.Refinement.ContinuationGeneral

/-! # 抽象的な組み込みの応答が捕捉を読む境界 -/
namespace Benitoite.Release.Refinement.CaptureReadBoundary
noncomputable section
private def modelProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def inspectSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["function"]
  params := [.fn [] [] (.base .unit) Eff.empty]
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ ts => ts.length = 0
  kind := .pure
  opEff := none

private def hiddenTag : List Val → ErrKind
  | [Val.closure _ (Closure.mk cap _)] => match cap.values[0]? with
    | some (some (Val.closure _ (Closure.mk _ (Comp.builderOp _ _ (LocalRef.loc l) _)))) =>
        if l = 7 then "HiddenBuilder7" else "HiddenBuilderOther"
    | _ => "Other"
  | _ => "Other"

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet
    else if b = "Example.inspect" then some inspectSig else none
  delta := fun _ _ _ _ ws => some (.err (hiddenTag ws))
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => True
  isResource := fun _ => true
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet ∨ s = inspectSig := by
  simp only [modelBuiltins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr (Or.inl rfl)
    · split at h
      · cases h; exact Or.inr (Or.inr rfl)
      · cases h

private theorem model_external : modelProgram.ExternalWF := by
  constructor
  · simp [modelProgram]
  · intro key decl h; cases h

private theorem model_wellFormed : modelProgram.WellFormed where
  defs := by intro f d h; cases h
  cons := by intro c cd h; cases h
  ops := by intro o od h; cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := model_external

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance := ⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩
  external := model_external
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl | rfl <;> simpa [modelGet,modelSet,inspectSig] using ha
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hl _ _ ha
    rcases model_sig_cases hl with rfl | rfl | rfl <;> simpa [modelGet,modelSet,inspectSig] using ha
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl | rfl <;> simpa [modelGet,modelSet,inspectSig] using ha
  admits_subst := by
    intro b s C0 C1 ts ts' es' hl ha _ _ _
    rcases model_sig_cases hl with rfl | rfl | rfl <;> simpa [modelGet,modelSet,inspectSig] using ha
  external_typed := by intro Ψ f d ts vs a e out obs hw hd; cases hd
  external_exists := by intro Ψ f d ts vs a e hw hd; cases hd
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hd; cases hd
  delta_typed := by
    intro Ψ b s ts es rs ws a e hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl <;> try cases hk
    intro ha
    exact ⟨.err (hiddenTag ws),rfl,(by intro n h; cases h),trivial,(by intro σ h hws; trivial)⟩
  io_typed := by intro Ψ b s ts es rs ws a e out obs hl hk ha hr; cases hr
  io_kind := by intro Ψ b s ts es rs ws a e out obs hl ha hr; cases hr
  io_exists := by
    intro Ψ b s ts es rs ws a e hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  sig_scoped := by
    intro b s hl
    rcases model_sig_cases hl with rfl | rfl | rfl <;>
      constructor <;>
      simp [modelGet,modelSet,inspectSig,PrimSig.tel,signatureTel,NamesWF,
        Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,Ty.RowsInList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,
        Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
        Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF,TypeCtx.kinds,
        Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
        Eff.WF,Eff.Canonical,Eff.norm,Eff.single,Eff.empty,Ty.normTys]
  sat_unconstrained := by intros; trivial
  admits_sat := by
    intro b s C ts hl ha
    rcases model_sig_cases hl with rfl | rfl | rfl <;>
      exact ⟨by simpa [modelGet,modelSet,inspectSig,Ty.normTys_eq_map] using ha,by intros; trivial⟩
  release_exists := by intro Ψ v o hv hr; exact ⟨none,trivial⟩
  pathBases_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl <;> cases hk
  io_op := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  opEff_io := by
    intro b s l hl he
    rcases model_sig_cases hl with rfl | rfl | rfl <;> cases he
  effect_ops := by
    intro l bs b hl hb
    simp only [modelBuiltins] at hl
    split at hl
    · cases hl; cases hb
    · cases hl
  state_effect := by simp [modelBuiltins]
  ref_get := ⟨modelGet,by simp [modelBuiltins],rfl⟩
  ref_set := ⟨modelSet,by simp [modelBuiltins],rfl⟩
  store_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl | rfl <;>
      simp [PrimSig.StoreShape,modelGet,modelSet,inspectSig]
  store_admits := by
    intro b s C ts hl hp hi he hb ha
    rcases model_sig_cases hl with rfl | rfl | rfl
    · exact ha
    · exact ha
    · cases hk : (PrimSig.kind inspectSig) <;> simp [inspectSig] at hp

private def hiddenValue (l : Nat) : Val := .closure (.done (.base .unit) Eff.empty)
  (.pure (.builderOp .string .copy (.loc l) []))
private def unreadCapture (l : Nat) : Capture := Capture.empty.extend (hiddenValue l)
private def argument (l : Nat) : Val := .closure (.done (.base .unit) Eff.empty)
  (.mk (unreadCapture l) (.ret (.const .unit)))
private def call (l : Nat) : Comp := .app (.prim "Example.inspect" [] [] []) [argument l]

private theorem hidden_ground (l : Nat) : (hiddenValue l).Ground := by
  simp [hiddenValue,Val.Ground,Val.ClosedAt,Closure.ClosedAt,Closure.pure,Capture.empty,
    Capture.values,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,telBinders,
    Tel.WF,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WF,Ty.WFList] <;> trivial
private theorem unread_capture_ok (l : Nat) : CaptureOk modelProgram modelBuiltins
    StoreTy.empty none [none] [] (unreadCapture l) :=
  (CaptureOk.empty _ _ _ _).extendHidden _ (hidden_ground l)
private theorem unit_annotation {Γ : Ctx} : Ty.Annotation modelProgram [] Γ (.base .unit) :=
  ⟨trivial,trivial,trivial⟩
private theorem argument_typed (l : Nat) : HasTypeV modelProgram modelBuiltins StoreTy.empty
    [] [] [] (argument l) (.fn [] [] (.base .unit) Eff.empty) := by
  have hc : CaptureOk modelProgram modelBuiltins (hideBuilders StoreTy.empty) none [none] [] (unreadCapture l) := by
    have he : hideBuilders StoreTy.empty = StoreTy.empty := by funext i; rfl
    rw [he]; exact unread_capture_ok l
  have hb : TelBodyTy modelProgram modelBuiltins (hideBuilders StoreTy.empty) Qempty []
      (hideConts ([none] : Ctx)) [] (.done (.base .unit) Eff.empty) (.ret (.const .unit)) :=
    .done (.C_Return (.V_Const trivial))
  have he : (unreadCapture l).closeTel (.done (.base .unit) Eff.empty) =
      .done (.base .unit) Eff.empty := by
    simp [Capture.closeTel,Tel.bind_done,Eff.bind,Eff.rawBind,Eff.empty,Eff.norm,rowFails,
      instAtoms_nil,substAtoms_nil,Ty.normTys,valEnv,Ty.bind,Ty.rawBind,Ty.norm]
  have hd := DependentClosureTy.mk hc hb unit_annotation.done_empty (by rw [he]; exact unit_annotation.done_empty)
  have hv : HasTypeV modelProgram modelBuiltins StoreTy.empty [] [] [] (argument l)
      (.dependentFn (.done (.base .unit) Eff.empty)) :=
    .V_Closure unit_annotation.done_empty
      ⟨by trivial,by trivial,trivial⟩ (by rw [he] at hd; exact hd)
  have hn : (.dependentFn (.done (.base .unit) Eff.empty) : Ty).norm =
      .fn [] [] (.base .unit) Eff.empty := by
    change Ty.foldFn (.done (.base .unit) Eff.empty) = _
    exact Ty.foldFn_toTel ⟨[],[],.base .unit,Eff.empty,⟨rfl,by decide⟩⟩
  exact hn ▸ hv.V_Normal

private theorem inspect_signature : SignatureInstance modelProgram [] [] (Tel.instR [] inspectSig.tel) [] [] [] := by
  constructor
  · exact ((model_core.sig_scoped _ _ (show modelBuiltins.sig "Example.inspect" = some inspectSig from by simp [modelBuiltins])).inst (rs := []) rfl).2.2.2.wf
  · intro a ha; cases ha
  · exact ⟨rfl,by intro i a k ha hk; cases ha⟩
  · intro e he; cases he
  · intro e he; cases he
  · have ht : instantiatedTel (Tel.instR [] inspectSig.tel) [] [] =
        .param "function" (.fn [] [] (.base .unit) Eff.empty) (.done (.base .unit) Eff.empty) := by
      rw [Tel.instR_eq_bind]
      simp [SubstEnv.rangesOnly,inspectSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.bind,Tel.rawBind,
        typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,SubstEnv.up,Eff.rawBind,rowFails,
        instAtoms_nil,substAtoms_nil,Ty.normTys,Ty.shiftV,Eff.empty,Eff.norm]
    rw [ht]
    exact ⟨by trivial,by trivial,by trivial⟩


private theorem call_typed (l : Nat) : HasTypeC modelProgram modelBuiltins StoreTy.empty
    [] [] [] none (call l) (.base .unit) Eff.empty := by
  have hp : PrimitiveAdmissible [] 0 inspectSig Qempty [] [] := by
    constructor <;> simp [inspectSig,RowTransport,
      
      PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  have hv : HasTypeV modelProgram modelBuiltins StoreTy.empty [] [] []
      (.prim "Example.inspect" [] [] [])
      (.dependentFn (instantiatedTel (Tel.instR [] inspectSig.tel) [] [])) :=
    .V_Prim (P := modelProgram) (B := modelBuiltins) (b := "Example.inspect") (rs := []) (s := inspectSig) (by simp [modelBuiltins]) (by simp [Builtins.RangeAdmissible,inspectSig])
      (by simp [inspectSig,NamesWF]) hp inspect_signature
  apply HasTypeCQ.C_DependentApp hv
  have ht : instantiatedTel (Tel.instR [] inspectSig.tel) [] [] =
      .param "function" (.fn [] [] (.base .unit) Eff.empty) (.done (.base .unit) Eff.empty) := by
    rw [Tel.instR_eq_bind]
    simp [SubstEnv.rangesOnly,inspectSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.bind,Tel.rawBind,
      typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,SubstEnv.up,Eff.rawBind,rowFails,
      instAtoms_nil,substAtoms_nil,Ty.normTys,Ty.shiftV,Eff.empty,Eff.norm]
  rw [ht]
  refine .param ?_ (argument_typed l) ?_
  · exact ⟨by trivial,by trivial,by trivial⟩
  · have he : Tel.bind (Tel.argumentsEnv (argument l)) (.done (.base .unit) Eff.empty) =
        .done (.base .unit) Eff.empty := by
      simp [Tel.bind,Tel.rawBind,Tel.argumentsEnv,valEnv,Ty.rawBind,Ty.norm,Tel.norm,
        Eff.rawBind,Eff.empty,Eff.norm,Ty.normTys,rowFails,substAtoms_nil,instAtoms_nil]
    rw [he]
    exact .done unit_annotation.done_empty

private theorem call_closed (l : Nat) : (call l).ClosedAt 0 0 := by
  change Val.ClosedAt 0 0 (.prim "Example.inspect" [] [] []) ∧
    Val.ClosedList 0 0 [argument l]
  exact ⟨⟨(by intro a ha; cases ha),(by intro e he; cases he),(by intro r hr; cases hr)⟩,
    ⟨⟨by trivial,⟨hidden_ground l,trivial⟩,by trivial⟩,trivial⟩⟩

private theorem call_adequate (l : Nat) (σ : PathEnv) : (call l).Adequate σ := by trivial
private theorem source_typed (l : Nat) (σ : PathEnv) : StateTyE modelProgram modelBuiltins σ Eff.empty
    (.run (Closure.pure (call l)) [] Store.empty) := by
  have hq := ClosureTy.pure (call_typed l) unit_annotation.done_empty
    (by intros; contradiction) rfl (by intros; contradiction)
  exact ⟨StoreTy.empty,none,.base .unit,.base .unit,Eff.empty,Eff.empty,
    StoreOk.empty _ _ _,hq,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ unit_annotation,
    ⟨trivial,call_adequate l σ⟩,⟨trivial,call_closed l⟩,
    (by intro f hf; cases hf),(by intro l c hc; cases hc)⟩

/-- 同じ適格な表で、未使用の捕捉位置の専用場所の番号がエラーの選択に使われる。 -/
theorem primitive_reads_hidden_capture (σ : PathEnv) :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
    modelBuiltins.CoreAssumptions modelProgram ∧
    CaptureOk modelProgram modelBuiltins StoreTy.empty none [none] [] (unreadCapture 7) ∧
    CaptureOk modelProgram modelBuiltins StoreTy.empty none [none] [] (unreadCapture 8) ∧
    modelBuiltins.delta "Example.inspect" [] [] [] [argument 7] ≠
      modelBuiltins.delta "Example.inspect" [] [] [] [argument 8] ∧
    StateTyE modelProgram modelBuiltins σ Eff.empty (.run (Closure.pure (call 7)) [] Store.empty) ∧
    StateTyE modelProgram modelBuiltins σ Eff.empty (.run (Closure.pure (call 8)) [] Store.empty) ∧
    Step modelProgram modelBuiltins σ (.run (Closure.pure (call 7)) [] Store.empty) none
      (.error ["HiddenBuilder7"] [] Store.empty) ∧
    Step modelProgram modelBuiltins σ (.run (Closure.pure (call 8)) [] Store.empty) none
      (.error ["HiddenBuilderOther"] [] Store.empty) := by
  refine ⟨model_wellFormed,model_wellTyped,model_core,unread_capture_ok 7,unread_capture_ok 8,
    ?_,source_typed 7 σ,source_typed 8 σ,?_,?_⟩
  · simp [modelBuiltins,hiddenTag,argument,unreadCapture,hiddenValue,Capture.extend,Capture.empty,Capture.values,
      Closure.pure]
  · exact .E_Err (s := inspectSig) rfl (by simp [modelBuiltins]) rfl rfl
  · exact .E_Err (s := inspectSig) rfl (by simp [modelBuiltins]) rfl rfl

/-- 番号を選ぶ δ の例でも、専用セルに触れず同じストアと継続へ戻る。 -/
theorem hidden_capture_reply_states (σ : PathEnv) (hσ : σ.Valid) :
    (StateTyE modelProgram modelBuiltins σ Eff.empty (.error ["HiddenBuilder7"] [] Store.empty) ∧
      LocalStateInvariant modelProgram modelBuiltins σ (.error ["HiddenBuilder7"] [] Store.empty)) ∧
    (StateTyE modelProgram modelBuiltins σ Eff.empty (.error ["HiddenBuilderOther"] [] Store.empty) ∧
      LocalStateInvariant modelProgram modelBuiltins σ (.error ["HiddenBuilderOther"] [] Store.empty)) := by
  have h7 := (source_typed 7 σ).store_reply model_wellFormed model_wellTyped model_core hσ
    (StoreReplyInputs.E_Err (s := inspectSig) rfl (by simp [modelBuiltins]) rfl rfl)
  have h8 := (source_typed 8 σ).store_reply model_wellFormed model_wellTyped model_core hσ
    (StoreReplyInputs.E_Err (s := inspectSig) rfl (by simp [modelBuiltins]) rfl rfl)
  exact ⟨h7.2,h8.2⟩

private theorem unit_prepared (P B σ) (hσ : σ.Valid) :
    InitialPrepared P B σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  let root : PreparationNode := .state (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)
  have nodes : ∀ n, PreparationNode.Reachable P B root n →
      n = root ∨ n = .closure (Closure.pure (.ret (.const .unit))) ∨
      n = .capture Capture.empty ∨ n = .comp (.ret (.const .unit)) ∨ n = .val (.const .unit) := by
    intro n hn
    induction hn with
    | root => exact Or.inl rfl
    | @child parent node hp hedge ih =>
      rcases ih with rfl | rfl | rfl | rfl | rfl
      · change node = .closure (Closure.pure (.ret (.const .unit))) ∨
          (∃ f∈([] : Cont), node = .frame f) ∨
          (∃ l c, Store.empty l = some c ∧ node = .cell c) at hedge
        simp only [List.not_mem_nil,false_and,exists_false,Store.empty,reduceCtorEq,or_false] at hedge
        exact Or.inr (Or.inl hedge)
      · change node = .capture Capture.empty ∨ node = .comp (.ret (.const .unit)) at hedge
        rcases hedge with h | h
        · exact Or.inr (Or.inr (Or.inl h))
        · exact Or.inr (Or.inr (Or.inr (Or.inl h)))
      · change ∃ v, some v ∈ ([] : List (Option Val)) ∧ node = .val v at hedge
        obtain ⟨v,hv,_⟩ := hedge; cases hv
      · change node = .val (.const .unit) at hedge
        exact Or.inr (Or.inr (Or.inr (Or.inr hedge)))
      · change False at hedge; exact False.elim hedge
  constructor
  refine ⟨hσ,?_⟩
  intro r hr
  cases hr with
  | base hp =>
    rcases nodes _ hp with h | h | h | h | h <;> first | cases h | (dsimp [root] at h; cases h)
  | secrets hp =>
    rcases nodes _ hp with h | h | h | h | h <;> first | cases h | (dsimp [root] at h; cases h)

/-- 開始準備と型付きソースを、具体の適格な同じ表で同時に満たす。 -/
theorem prepared_unit_source (σ : PathEnv) (hσ : σ.Valid) :
    modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
    modelBuiltins.CoreAssumptions modelProgram ∧
    StateTy modelProgram modelBuiltins σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
    σ.Ready modelProgram modelBuiltins (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
    modelProgram.ExternalWF := by
  have h := (unit_prepared modelProgram modelBuiltins σ hσ).source_state model_external
    (.C_Return (.V_Const trivial)) unit_annotation.done_empty trivial (by trivial)
    (show BuiltinOnly modelProgram modelBuiltins Eff.empty from ⟨rfl,by intro a ha; cases ha⟩)
  exact ⟨model_wellFormed,model_wellTyped,model_core,h⟩

/-- 有効な σ も具体化し、表の条件と開始状態の証拠を同時に構成する。 -/
theorem prepared_unit_concrete :
    ∃ σ, σ.Valid ∧ modelProgram.WellFormed ∧ modelProgram.WellTyped modelBuiltins ∧
      modelBuiltins.CoreAssumptions modelProgram ∧
      StateTy modelProgram modelBuiltins σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      σ.Ready modelProgram modelBuiltins (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      modelProgram.ExternalWF := by
  let σ : PathEnv := ⟨[],[],[],none,none,none⟩
  have hv : σ.Valid := by simp [PathEnv.Valid,σ,Scope.Domain.PathWordWF]
  exact ⟨σ,hv,prepared_unit_source σ hv⟩

end
end Benitoite.Release.Refinement.CaptureReadBoundary
