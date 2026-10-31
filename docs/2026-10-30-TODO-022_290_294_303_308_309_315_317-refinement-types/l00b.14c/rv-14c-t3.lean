import Lean
import Benitoite.Release.Refinement.ReferencePreservation
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.ReferenceBoundary
noncomputable section
local instance : OfNat Integer64Value 3 := ⟨⟨3,by decide⟩⟩
local instance : OfNat Integer64Value 9 := ⟨⟨9,by decide⟩⟩

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
abbrev I : Ty := .base .integer
abbrev U : Ty := .base .unit
def E : Eff := Eff.single stateEff
def σ : PathEnv := ⟨[],[],[],none,none,none⟩
def sg (k : PrimKind) : PrimSig :=
  match k with
  | .refNew => ⟨[{}],0,["value"],[.tvar 0],.reference (.tvar 0),E,fun _ _ => True,k,none,[],.untargeted⟩
  | .refGet => ⟨[{kind := .constructor 1}],0,["reference"],[.reference (.tvar 0)],.tvar 0,E,fun _ _ => True,k,none,[],.untargeted⟩
  | .refSet => ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,E,fun _ _ => True,k,none,[],.untargeted⟩
  | _ => ⟨[{}],0,["reference","f"],[.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty],
      U,E,fun _ _ => True,k,none,[],.untargeted⟩
def B : Builtins :=
  { sig := fun b => if b = "new" then some (sg .refNew) else
      if b = "get" then some (sg .refGet) else if b = "set" then some (sg .refSet) else
      if b = "update" then some (sg .refUpdate) else none,
    delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False,
    releaseResponse := fun _ _ => True, isResource := fun _ => false,
    effects := fun _ => none, sat := fun _ _ _ => True, refGet := "get",refSet := "set" }

theorem sig_cases {b s} (hs : B.sig b = some s) :
    s = sg .refNew ∨ s = sg .refGet ∨ s = sg .refSet ∨ s = sg .refUpdate := by
  change (if b = "new" then _ else if b = "get" then _ else if b = "set" then _ else
    if b = "update" then _ else none) = some s at hs
  split at hs
  · exact Or.inl (Option.some.inj hs).symm
  · split at hs
    · exact Or.inr (Or.inl (Option.some.inj hs).symm)
    · split at hs
      · exact Or.inr (Or.inr (Or.inl (Option.some.inj hs).symm))
      · split at hs
        · exact Or.inr (Or.inr (Or.inr (Option.some.inj hs).symm))
        · cases hs

theorem assumptions : Builtins.CoreAssumptions P B where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> trivial
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> trivial
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> trivial
  admits_subst := by
    intro b s C0 C1 ts ts' es' hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> trivial
  external_typed := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  external_exists := by intro Ψ f d ts vs a e hw hs; cases hs
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  delta_typed := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> cases hk
  io_typed := by intro Ψ b s ts es rs ws a e out obs hs hk ha hi; cases hi
  io_kind := by intro Ψ b s ts es rs ws a e out obs hs ha hi; cases hi
  io_exists := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  pathBases_shape := by
    intro b s hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> cases hk
  opEff_io := by
    intro b s l hs ho
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> cases ho
  effect_ops := by intro l bs b hs; cases hs
  store_shape := by
    intro b s hs _
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> simp [sg,PrimSig.StoreShape,E]
  store_admits := by
    intro b s C ts hs
    rcases sig_cases hs with rfl | rfl | rfl | rfl <;> intros <;> trivial

theorem i_ann {Γ : Ctx} : Ty.Annotation P [] Γ I := ⟨trivial,trivial,trivial⟩
theorem u_ann {Γ : Ctx} : Ty.Annotation P [] Γ U := ⟨trivial,trivial,trivial⟩
theorem ref_ann {Γ : Ctx} : Ty.Annotation P [] Γ (.reference I) := ⟨trivial,trivial,trivial⟩
def Ψ : StoreTy := StoreTy.empty.put 0 (.ref I)
def μ (n : Integer64Value) : Store := Store.empty.set 0 (.val (.const (.integer n)))

theorem μ_closed (n : Integer64Value) : (μ n).Closed := by
  intro l c hl
  by_cases hi : l = 0
  · subst l
    have he : Cell.val (.const (.integer n)) = c := Option.some.inj hl
    subst c
    trivial
  · simp [μ,Store.set,hi,Store.empty] at hl

theorem store (n : Integer64Value) : StoreOk P B σ Ψ (μ n) :=
  (StoreOk.empty P B σ).allocate_reference assumptions.values rfl i_ann rfl (.V_Const trivial) trivial

theorem loc {Γ : Ctx} {Φ} : HasTypeV P B Ψ [] Γ Φ (.loc 0) (.reference I) :=
  .V_LocRef (by rfl) trivial

def prim (b : String) : Val := .prim b [I] [] []
def num (n : Integer64Value) : Val := .const (.integer n)

theorem primitive {b k names ps r}
    (hs : B.sig b = some (sg k))
    (hns : (sg k).names = names) (hps : (sg k).params = ps)
    (hr : (sg k).ret = r) (hn : NamesWF names ps)
    (hks : (sg k).tparams.map TParamDecl.kind = [.value]) :
    HasTypeV P B StoreTy.empty [] [] [] (prim b)
      (.dependentFn (instantiatedTel (Tel.instR [] (sg k).tel) [I] [])) := by
  apply HasTypeVQ.V_Prim hs
  · exact ⟨by cases k <;> rfl,by simp,by simp,Or.inl (by simp)⟩
  · simpa [hns,hps] using hn
  · refine ⟨by cases k <;> rfl,by cases k <;> trivial,?_,by cases k <;> rfl,by simp,?_,?_,?_⟩
    · intro t ht; cases List.mem_singleton.mp ht; exact ⟨trivial,by simp [Ordinary,Ty.core,Ty.shiftV,I]⟩
    · cases k <;> simp [sg,E,Eff.RowsIn,Eff.single,Ty.RowsInList]
    · intro i hi
      rcases k with _ | _ | _ | _ | _ | _ | _ | _ | _
      all_goals simp [sg,Qsig,QTys,QTy,QEff,E,Eff.single,Eff.empty,Qempty] at hi
    · intro i hi
      rcases k with _ | _ | _ | _ | _ | _ | _ | _ | _
      all_goals simp [sg,Qsig,QTys,QTy,QEff,E,Eff.single,Eff.empty,Qempty] at hi
  · refine ⟨?_,?_,?_,by simp [RowAnnotations],?_⟩
    · rcases k with _ | _ | _ | _ | _ | _ | _ | _ | _
      all_goals simp [sg,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
        Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,E,Eff.single,Eff.empty,
        mapRangesTys,NamesWF,Order.sortUnique,mapRangeAtoms_rangeAt,instAtoms_nil]
    · intro t ht; cases List.mem_singleton.mp ht; exact i_ann
    · rw [hks]
      refine ⟨rfl,[],rfl,?_⟩
      intro i t kind ht hk
      cases i with
      | zero => cases Option.some.inj ht; cases Option.some.inj hk; trivial
      | succ i => cases ht
    · constructor <;> cases k
      all_goals simp [sg,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
        instantiatedTel,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,
        typeEnvAt,SubstEnv.up,upValues,shiftTypes,Ty.shiftV,E,Eff.single,Eff.empty,
        substAtoms_nil,instAtoms_nil,rowFails,mapRangesTys,mapRangeAtoms_rangeAt,
        Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,NamesWF,Order.sortUnique,
        Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
        Ty.Annotation]
theorem update_prim : HasTypeV P B StoreTy.empty [] [] [] (prim "update")
    (.fn ["reference","f"] [.reference I,.fn ["value"] [I] I Eff.empty] U E) := by
  have hv := primitive (b := "update") (k := PrimKind.refUpdate) (names := ["reference","f"])
    (ps := [.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty]) (r := U) rfl rfl rfl rfl ⟨rfl,by decide⟩ rfl
  have ht : instantiatedTel (Tel.instR [] (sg .refUpdate).tel) [I] [] =
      Ty.toTel ["reference","f"] [.reference I,.fn ["value"] [I] I Eff.empty] U E := by
    simp [sg,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,typeEnvAt,SubstEnv.up,upValues,
      shiftTypes,Ty.shiftV,E,Eff.single,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,
      mapRangesTys,mapRangeAtoms_rangeAt,Order.sortUnique,Ty.toTel]
    all_goals simp [Eff.rawBind,Eff.norm,Eff.shiftV,E,Eff.single,rawBindTys,Ty.normTys,Order.sortUnique,substAtoms_nil,instAtoms_nil,rowFails]
  rw [ht] at hv
  have hh := hv.V_Normal
  rw [show (Ty.dependentFn (Ty.toTel ["reference","f"] [.reference I,.fn ["value"] [I] I Eff.empty] U E)).norm =
    .fn ["reference","f"] [.reference I,.fn ["value"] [I] I Eff.empty] U E from by
      rw [Ty.norm,Tel.norm_toTel]
      exact Ty.foldFn_toTel ⟨["reference","f"],[.reference I,.fn ["value"] [I] I Eff.empty],U,E,⟨rfl,by decide⟩⟩] at hh
  exact hh
theorem prim_context {store Γ Φ b a}
    (h : HasTypeV P B StoreTy.empty [] [] [] (prim b) a) (ha : a.WF 0 0 0) :
    HasTypeV P B store [] Γ Φ (prim b) a := by
  have hh := h.shift_values (store' := store) (Δ := Γ) (k := Γ.length) (c := 0)
    assumptions.values StoreTy.WF.empty (StoreTy.Extends.empty store).preservesNormals
    ⟨by simp,by intro i a hi _; cases hi⟩ (Ξ := Φ) (by simp)
  simpa [prim,Val.rename,renameTy_shiftIndex,Ty.shiftV_of_wf_zero ha,Ty.shiftV,I] using hh
theorem ue_ann {Γ : Ctx} : Ty.Annotation P [] Γ (.dependentFn (.done U E)) := by
  constructor <;> simp [Ty.WF,Tel.WF,Eff.WF,E,Eff.single,Ty.WFList,Eff.Canonical,Eff.norm,
    Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys]
theorem sub_refl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩
def identityTel : Tel := .param "value" I (.done I Eff.empty)
def identityBody : Closure := Closure.pure (.ret (.var 0))
def identity : Val := .closure identityTel identityBody

theorem identity_annotation : Ty.Annotation P [] [] (.dependentFn identityTel) := by
  constructor <;> simp [identityTel,Ty.WF,Tel.WF,Eff.WF,Eff.empty,Ty.WFList,Eff.Canonical,Eff.norm,
    Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys]

theorem identity_typed : HasTypeV P B Ψ [] [] [] identity (.fn ["value"] [I] I Eff.empty) := by
  have hc : Capture.empty.closeTel identityTel = identityTel := Capture.empty_closeTel identity_annotation.wf rfl
  have hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] [] [] identityTel (.ret (.var 0)) :=
    .param (.done (.C_Return (.V_Var rfl (by simp [Ordinary,Ty.core,I,Ty.shiftV]))))
  have hdep := DependentClosureTy.mk (CaptureOk.empty P B (hideBuilders Ψ) none) hb identity_annotation
    (by rw [hc]; exact identity_annotation)
  rw [hc] at hdep
  have hh := HasTypeVQ.V_Closure (Ψ := Ψ) (Q := Qempty) (Φ := []) identity_annotation
    (Tel.RuntimeShape.mk identity_annotation.wf identity_annotation.wf ⟨rfl,rfl,trivial⟩) hdep
  have he : (Ty.dependentFn identityTel).norm = .fn ["value"] [I] I Eff.empty :=
    Ty.foldFn_toTel ⟨["value"],[I],I,Eff.empty,⟨rfl,by decide⟩⟩
  simpa only [he,identity,identityBody,Closure.pure] using hh.V_Normal

theorem update_any : HasTypeV P B Ψ [] [] [] (prim "update")
    (.fn ["reference","f"] [.reference I,.fn ["value"] [I] I Eff.empty] U E) :=
  prim_context update_prim (by
    simp [Ty.WF,Ty.WFList,NamesWF,Eff.WF,E,Eff.single,Eff.empty,Eff.Canonical,Eff.norm])

def updateSource : State := .run (Closure.pure (.app (prim "update") [.loc 0,identity])) [] (μ 3)
def updateTarget : State := .run (Closure.pure
  (.letIn (.app (prim "get") [.loc 0]) (.letIn (.app identity [.var 0])
    (.app (prim "set") [.loc 0,.var 0])))) [] (μ 3)

theorem update_start : StateTyE P B σ E updateSource := by
  refine ⟨Ψ,none,U,U,E,E,store 3,
    ClosureTy.pure (.C_App update_any (.cons loc (.cons identity_typed .nil))) ue_ann
      (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) u_ann,?_,?_,?_,μ_closed 3⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,prim,Ty.WF,
      identity,identityBody,identityTel,telBinders,Tel.WF,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]


  · intro f hf; cases hf

/-- 旧 Assumptions の二欄も満たす。 -/
theorem ref_get_field : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet := ⟨sg .refGet,rfl,rfl⟩
theorem ref_set_field : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet := ⟨sg .refSet,rfl,rfl⟩

private theorem no_value_instance {v T ts es rs Φ Γ C Q store}
    (h : HasTypeVQ P B store Q C Γ Φ v T) (hv : v = .prim "get" ts es rs) (hts : ts = [I]) : False := by
  match h with
  | .V_Prim hs _ _ _ hi =>
    cases hv
    cases (show sg .refGet = _ from Option.some.inj hs)
    subst hts
    obtain ⟨_,K,_,hk⟩ := hi.kinds
    have := hk 0 I (.constructor 1) rfl rfl
    cases this
  | .V_Normal hh => exact no_value_instance hh hv hts
  | .V_Sub hh .. => exact no_value_instance hh hv hts
  | .V_Refine hh .. => exact no_value_instance hh hv hts
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

/-- CoreAssumptions と旧二欄を満たす表で ReferencePrimitives は偽である。 -/
theorem primitives_fail : ¬ ReferencePrimitives P B [I] := by
  rintro ⟨a,ha,hg,_⟩
  cases (show I = a from (List.cons.inj ha).1)
  exact no_value_instance hg rfl rfl

private theorem no_get_call {Ψ Q C Γ Φ R code a e L f ws ρ}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .app f ws)
    (hf : f.resolveLocals ρ = .prim "get" [I] [] []) : False := by
  match h with
  | .C_App hv _ =>
    cases hc
    rw [hv.resolve_id ρ] at hf
    subst hf
    exact no_value_instance hv rfl rfl
  | .C_DependentApp hv _ =>
    cases hc
    rw [hv.resolve_id ρ] at hf
    subst hf
    exact no_value_instance hv rfl rfl
  | .C_Sub hh .. | .C_Normal hh | .C_Eff hh _ => exact no_get_call hh hc hf
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private theorem let_first {Ψ Q C Γ Φ R code a e L m n}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .letIn m n) :
    ∃ x f, HasTypeCQ P B Ψ Q C Γ Φ R m x f L := by
  match h with
  | .C_Let hm _ _ => cases hc; exact ⟨_,_,hm⟩
  | .C_Sub hh .. | .C_Normal hh | .C_Eff hh _ => exact let_first hh hc
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_App .. | .C_DependentApp .. |
    .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private def isLet : Comp → Bool | .letIn .. => true | _ => false
private def isApp : Comp → Bool | .app .. => true | _ => false

/-- E_RefUpdate の到達は、どの Ψ でも型付かない。 -/
theorem target_untyped (m : Comp) (k μ') :
    ¬ StateTyE P B σ E (.run (Closure.pure (.letIn (.app (prim "get") [.loc 0]) m)) k μ') := by
  rintro ⟨Ψ',R,a,c,e,e1,_,hq,_⟩
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es0,L,ρ,hqe,_,hbody,_⟩ := hq.open_zero
  have hcode := (Closure.mk.inj hqe).2
  have ht : isLet code0 = true := by
    have hh := congrArg isLet hcode
    cases code0 <;> exact hh.symm
  cases code0 <;> try cases ht
  rename_i m0 n0
  have hm : Comp.app (prim "get") [.loc 0] = m0.resolveLocals ρ := (Comp.letIn.inj hcode).1
  obtain ⟨x,f,hc⟩ := let_first hbody rfl
  have ha : isApp m0 = true := by
    have hh := congrArg isApp hm
    cases m0 <;> exact hh.symm
  cases m0 <;> try cases ha
  rename_i g ws
  exact no_get_call hc rfl (Comp.app.inj hm).1.symm

/-- 到達の元は型付く。 -/
theorem update_source_typed : StateTyE P B σ E updateSource := update_start
theorem update_real_step : Step P B σ updateSource none updateTarget :=
  Step.E_RefUpdate (q := Closure.pure (.app (prim "update") [.loc 0,identity]))
    (b := "update") (ts := [I]) (s := sg .refUpdate) rfl rfl rfl
theorem update_not_preserved : ¬ StateTyE P B σ E updateTarget := target_untyped _ _ _

end
end Benitoite.Release.Refinement.ReferenceBoundary

#print axioms Benitoite.Release.Refinement.ReferenceBoundary.update_not_preserved
#print axioms Benitoite.Release.Refinement.ReferenceBoundary.assumptions
