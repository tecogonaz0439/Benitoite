import Lean
import Benitoite.Release.Model
import Benitoite.Release.ModelTargets
import Benitoite.Release.ModelHttp
import Benitoite.Release.Refinement.LazyPreservation
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.LazyBoundary
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
  | .refGet => ⟨[{}],0,["reference"],[.reference (.tvar 0)],.tvar 0,E,fun _ _ => True,k,none,[],.untargeted⟩
  | .force => ⟨[{}],0,["value"],[.lazy (.tvar 0)],.tvar 0,Eff.empty,fun _ _ => True,k,none,[],.untargeted⟩
  | .refSet => ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,E,fun _ _ => True,k,none,[],.untargeted⟩
  | _ => ⟨[{}],0,["reference","f"],[.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty],
      U,E,fun _ _ => True,k,none,[],.untargeted⟩
def B : Builtins :=
  { sig := fun b => if b = "new" then some (sg .refNew) else
      if b = "get" then some (sg .refGet) else if b = "set" then some (sg .refSet) else
      if b = "update" then some (sg .refUpdate) else if b = "force" then some (sg .force) else none,
    delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False,
    releaseResponse := fun _ _ => True, isResource := fun _ => false,
    effects := fun _ => none, sat := fun _ _ _ => True, refGet := "get",refSet := "set" }

theorem sig_cases {b s} (hs : B.sig b = some s) :
    s = sg .refNew ∨ s = sg .refGet ∨ s = sg .refSet ∨ s = sg .refUpdate ∨ s = sg .force := by
  change (if b = "new" then _ else if b = "get" then _ else if b = "set" then _ else
    if b = "update" then _ else if b = "force" then _ else none) = some s at hs
  split at hs
  · exact Or.inl (Option.some.inj hs).symm
  · split at hs
    · exact Or.inr (Or.inl (Option.some.inj hs).symm)
    · split at hs
      · exact Or.inr (Or.inr (Or.inl (Option.some.inj hs).symm))
      · split at hs
        · exact Or.inr (Or.inr (Or.inr (Or.inl (Option.some.inj hs).symm)))
        · split at hs
          · exact Or.inr (Or.inr (Or.inr (Or.inr (Option.some.inj hs).symm)))
          · cases hs

theorem assumptions : Builtins.CoreAssumptions P B where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  admits_subst := by
    intro b s C0 C1 ts ts' es' hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  external_typed := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  external_exists := by intro Ψ f d ts vs a e hw hs; cases hs
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  delta_typed := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases hk
  io_typed := by intro Ψ b s ts es rs ws a e out obs hs hk ha hi; cases hi
  io_kind := by intro Ψ b s ts es rs ws a e out obs hs ha hi; cases hi
  io_exists := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  pathBases_shape := by
    intro b s hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases hk
  opEff_io := by
    intro b s l hs ho
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases ho
  effect_ops := by intro l bs b hs; cases hs
  ref_get := ⟨sg .refGet,rfl,rfl⟩
  ref_set := ⟨sg .refSet,rfl,rfl⟩
  store_shape := by
    intro b s hs _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> simp [sg,PrimSig.StoreShape,E]
  store_admits := by
    intro b s C ts hs
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> intros <;> trivial

def SavedStep (Eb : Eff) (src dst : State) : Prop :=
  Step P B σ src none dst ∧ StateTyE P B σ Eb dst

abbrev p : Pred := .lt (.var 0) (.integer 8)
abbrev Small : Ty := .refined I p
abbrev three : Val := .const (.integer 3)
abbrev nine : Val := .const (.integer 9)

theorem i_ann {Γ : Ctx} : Ty.Annotation P [] Γ I := ⟨trivial,trivial,trivial⟩
theorem small_ann {Γ : Ctx} : Ty.Annotation P [] Γ Small := by
  constructor <;> simp [Small,p,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.declarationSelf,
    Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.extend,Ty.shiftV,I]

theorem three_small {Ψ : StoreTy} {Γ : Ctx} {Φ} :
    HasTypeV P B Ψ [] Γ Φ three Small := by
  refine .V_Refine (.V_Const trivial) rfl rfl small_ann.sorted.2 small_ann.wf.2.1
    ?_ trivial small_ann.declared.2
  exact (CaptureOk.evaluated_fact (by decide)).weaken (by simp)

private theorem closed_ann {a : Ty} (ha : Ty.Annotation P [] [] a) (Γ : Ctx) :
    Ty.Annotation P [] Γ a := by
  have hm : ShiftMap Γ.length 0 [] Γ := ⟨by simp,by intro i a hi; cases hi⟩
  simpa only [Ty.shiftV_of_wf_zero ha.wf] using hm.annotation ha

private theorem force_tel_instance {a : Ty} (ha : Ty.Annotation P [] [] a) (hn : a.Normal) : instantiatedTel (Tel.instR [] (sg .force).tel) [a] [] =
    Ty.toTel ["value"] [.lazy a] a Eff.empty := by
  change a.norm = a at hn
  simp [sg,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,typeEnvAt,SubstEnv.up,upValues,
    shiftTypes_zero,Ty.shiftV_of_wf_zero ha.wf,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,
    mapRangesTys,mapRangeAtoms_rangeAt,Order.sortUnique,Ty.toTel,hn,Eff.shiftV]
  all_goals simp [Eff.rawBind,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,Eff.shiftV]

theorem force_prim {a : Ty} (ha : Ty.Annotation P [] [] a) (hn : a.Normal)
    (ho : a.Ordinary) (hk : a.HasKind P [] .value) :
    HasTypeV P B StoreTy.empty [] [] [] (.prim "force" [a] [] [])
      (.fn ["value"] [.lazy a] a Eff.empty) := by
  have ht := force_tel_instance ha hn
  have hv : HasTypeV P B StoreTy.empty [] [] [] (.prim "force" [a] [] [])
      (.dependentFn (instantiatedTel (Tel.instR [] (sg .force).tel) [a] [])) := by
    apply HasTypeVQ.V_Prim (s := sg .force) rfl
    · exact ⟨rfl,by simp,by simp,Or.inl (by simp)⟩
    · exact ⟨rfl,by decide⟩
    · refine ⟨rfl,by trivial,?_,rfl,by simp,?_,?_,?_⟩
      · intro t ht; cases List.mem_singleton.mp ht; exact ⟨ha.wf,ho⟩
      · simp [sg,Eff.RowsIn,Eff.empty,Ty.RowsInList]
      · simp [sg,Qsig,QTys,QTy,QEff,Eff.empty,Qempty]
      · simp [sg,Qsig,QTys,QTy,QEff,Eff.empty,Qempty,RowTransport]
    · refine ⟨?_,?_,?_,by simp [RowAnnotations],?_⟩
      · simp [sg,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
          Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
          Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,
          mapRangesTys,NamesWF,Order.sortUnique,mapRangeAtoms_rangeAt,instAtoms_nil]
      · intro t ht; cases List.mem_singleton.mp ht; exact ha
      · refine ⟨rfl,[],rfl,?_⟩
        intro i t k ht hk'
        cases i with
        | zero => cases Option.some.inj ht; cases Option.some.inj hk'; exact hk
        | succ i => cases ht
      · rw [ht]
        have wa (n : Nat) : a.WF 0 0 n := by simpa using (closed_ann ha (List.replicate n none)).wf
        have sa (Γ : Ctx) : a.Sorted Γ := (closed_ann ha Γ).sorted
        have da (Γ : Ctx) : Ty.Declared P [] Γ a := (closed_ann ha Γ).declared
        constructor <;> simp [Ty.toTel,Ty.WF,Tel.WF,Ty.Sorted,Tel.Sorted,Ty.Declared,Tel.Declared,
          wa,sa,da,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList,sortedEff,sortedTys,
          declaredEff,declaredTys,Ty.shiftV_of_wf_zero ha.wf,Eff.shiftV]
  rw [ht] at hv
  have hh := hv.V_Normal
  have ht' : (Ty.dependentFn (Ty.toTel ["value"] [.lazy a] a Eff.empty)).norm =
      .fn ["value"] [.lazy a] a Eff.empty := by
    rw [Ty.norm,Tel.norm_toTel]
    change a.norm = a at hn
    simpa only [Ty.normTys,Ty.norm,hn,show Eff.norm Eff.empty = Eff.empty from rfl,FnView.toTel] using
      (Ty.foldFn_toTel ⟨["value"],[.lazy a],a,Eff.empty,⟨rfl,by decide⟩⟩)
  rwa [ht'] at hh

private theorem sub_refl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩
private theorem empty_ann {a Γ} (ha : Ty.Annotation P [] Γ a) :
    Ty.Annotation P [] Γ (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,trivial,rfl⟩,⟨ha.sorted,trivial⟩,⟨ha.declared,trivial⟩⟩

theorem lazy_covariant {Γ Φ} : Ty.LeQ Γ Φ (.lazy Small) (.lazy I) := .lazy .forget

theorem reference_invariant {Γ Φ} : ¬ Ty.LeQ Γ Φ (.reference Small) (.reference I) := by
  intro h
  obtain ⟨x,hx,he⟩ := h.refCore_right rfl
  cases Option.some.inj hx
  cases he

theorem force_i {Ψ Γ Φ} : HasTypeV P B Ψ [] Γ Φ (.prim "force" [I] [] [])
    (.fn ["value"] [.lazy I] I Eff.empty) := by
  have hv := force_prim i_ann rfl (by simp [Ordinary,Ty.core,I]) (by trivial)
  have ha : (Ty.fn ["value"] [.lazy I] I Eff.empty).WF 0 0 0 := by
    exact ⟨⟨rfl,by decide⟩,⟨trivial,trivial⟩,trivial,trivial,rfl⟩
  have hh := hv.shift_values (store' := Ψ) (k := Γ.length) (c := 0) (Δ := Γ) assumptions.values
    StoreTy.WF.empty (StoreTy.Extends.empty Ψ).preservesNormals
    ⟨by simp,by intro i a hi _; cases hi⟩ (Ξ := Φ) (by simp)
  simpa [Val.rename,renameTy_shiftIndex,Ty.shiftV_of_wf_zero ha,Ty.shiftV,I,Eff.shiftV,Eff.empty] using hh

theorem force_small {Ψ Γ Φ} : HasTypeV P B Ψ [] Γ Φ (.prim "force" [Small] [] [])
    (.fn ["value"] [.lazy Small] Small Eff.empty) := by
  have hv := force_prim small_ann rfl (by simp [Small,Ordinary,Ty.core,I])
    (by simp [Small,I,Ty.HasKind,Ty.NotContCore])
  have ha : (Ty.fn ["value"] [.lazy Small] Small Eff.empty).WF 0 0 0 :=
    ⟨⟨rfl,by decide⟩,⟨(small_ann (Γ := [])).wf,trivial⟩,(small_ann (Γ := [])).wf,trivial,rfl⟩
  have hh := hv.shift_values (store' := Ψ) (k := Γ.length) (c := 0) (Δ := Γ) assumptions.values
    StoreTy.WF.empty (StoreTy.Extends.empty Ψ).preservesNormals
    ⟨by simp,by intro i a hi _; cases hi⟩ (Ξ := Φ) (by simp)
  have hp : renameTy (fun i => i + Γ.length) Small = Small := by
    change renameTy (shiftIndex Γ.length 0) Small = Small
    rw [renameTy_shiftIndex,Ty.shiftV_of_wf_zero (small_ann (Γ := [])).wf]
  simpa only [Val.rename,List.map_cons,List.map_nil,hp,
    Ty.shiftV_of_wf_zero ha,renameTy_shiftIndex,Ty.shiftV_of_wf_zero (small_ann (Γ := [])).wf] using hh

def thunk : Closure := Closure.pure (.ret three)
def Ψ : StoreTy := StoreTy.empty.put 0 (.lazy Small)
def μ : Store := Store.empty.set 0 (.thunk thunk)
def μdone : Store := μ.set 0 (.done three)

theorem thunk_typed : ClosureTy P B (hideBuilders StoreTy.empty) [] none thunk Small Eff.empty :=
  ClosureTy.pure (.C_Return three_small) (empty_ann small_ann)
    (by intros; contradiction) rfl (by intros; contradiction)

theorem store : StoreOk P B σ Ψ μ :=
  (StoreOk.empty P B σ).allocate_lazy assumptions.values rfl small_ann thunk_typed (by trivial)

theorem store_closed : μ.Closed := by
  intro l c hc
  by_cases hl : l = 0
  · subst l; cases Option.some.inj hc; trivial
  · simp [μ,Store.set,Store.empty,hl] at hc

theorem lazy_start : StateTyE P B σ Eff.empty
    (.run (Closure.pure (.lazyC (.ret three))) [] Store.empty) := by
  have hb : HasTypeC P B StoreTy.empty [] [] [] none (.lazyC (.ret three)) (.lazy Small) Eff.empty :=
    .C_Lazy (.C_Return three_small) small_ann
  refine ⟨StoreTy.empty,none,.lazy Small,.lazy Small,Eff.empty,Eff.empty,
    StoreOk.empty _ _ _,ClosureTy.pure hb (empty_ann ⟨small_ann.wf,small_ann.sorted,small_ann.declared⟩)
      (by intros; contradiction) rfl (by intros; contradiction),sub_refl _,
    .K_Empty (sub_refl _) ⟨small_ann.wf,small_ann.sorted,small_ann.declared⟩,?_,?_,?_,?_⟩
  · trivial
  · trivial
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem lazy_pair : SavedStep Eff.empty
    (.run (Closure.pure (.lazyC (.ret three))) [] Store.empty) (.run (Closure.pure (.ret (.loc 0))) [] μ) := lazy_start.lazy_transition assumptions rfl (l := 0) rfl

theorem loc_small {Γ Φ} : HasTypeV P B Ψ [] Γ Φ (.loc 0) (.lazy Small) :=
  .V_LocLazy rfl small_ann.declared

theorem loc_integer {Γ Φ} : HasTypeV P B Ψ [] Γ Φ (.loc 0) (.lazy I) :=
  .V_Sub loc_small lazy_covariant trivial trivial trivial

theorem force_start : StateTyE P B σ Eff.empty
    (.run (Closure.pure (.app (.prim "force" [I] [] []) [.loc 0])) [] μ) := by
  refine ⟨Ψ,none,I,I,Eff.empty,Eff.empty,store,
    ClosureTy.pure (.C_App force_i (.cons loc_integer .nil)) (empty_ann i_ann)
      (by intros; contradiction) rfl (by intros; contradiction),sub_refl _,
    .K_Empty (sub_refl _) i_ann,?_,?_,?_,store_closed⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,Ty.WF,I]
  · intro f hf; cases hf

theorem force_pair : SavedStep Eff.empty
    (.run (Closure.pure (.app (.prim "force" [I] [] []) [.loc 0])) [] μ) (.run thunk [.update 0] μ) := force_start.force_thunk_transition assumptions (s := sg .force) rfl rfl rfl

theorem update_pair : SavedStep Eff.empty
    (.run thunk [.update 0] μ) (.run (Closure.pure (.ret three)) [] μdone) := force_pair.2.lazy_update_any_cell assumptions rfl

theorem done_contract : HasTypeV P B Ψ [] [] [] three Small := by
  have hc := store.write_done (l := 0) rfl (three_small (Ψ := Ψ)) (by trivial)
  have hd := hc.2.2.2.2 0 (.done three) (by rfl)
  obtain ⟨a,ha,hv,_⟩ := hd
  cases Option.some.inj ha
  exact hv

theorem done_store : StoreOk P B σ Ψ μdone := store.write_done rfl three_small (by trivial)
theorem done_closed : μdone.Closed := by
  intro l c hc
  by_cases hl : l = 0
  · subst l; cases Option.some.inj hc; trivial
  · simp [μdone,μ,Store.set,Store.empty,hl] at hc

theorem force_again_start : StateTyE P B σ Eff.empty
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μdone) := by
  refine ⟨Ψ,none,Small,Small,Eff.empty,Eff.empty,done_store,
    ClosureTy.pure (.C_App force_small (.cons loc_small .nil)) (empty_ann small_ann)
      (by intros; contradiction) rfl (by intros; contradiction),sub_refl _,
    .K_Empty (sub_refl _) small_ann,?_,?_,?_,done_closed⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values]
    exact (small_ann (Γ := [])).wf
  · intro f hf; cases hf

theorem force_again_pair : SavedStep Eff.empty
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μdone) (.run (Closure.pure (.ret three)) [] μdone) := force_again_start.force_done_transition assumptions (s := sg .force) rfl rfl rfl

def afterForce : Comp := .app (.prim "force" [Small] [] []) [.var 1]
def afterLazy : Comp := .letIn (.app (.prim "force" [I] [] []) [.var 0]) afterForce
def program : Comp := .letIn (.lazyC (.ret three)) afterLazy

theorem program_typed : HasTypeC P B StoreTy.empty [] [] [] none program Small Eff.empty := by
  refine .C_Let (.C_Lazy (.C_Return three_small) small_ann) ?_ small_ann.declared
  have hv : HasTypeV P B StoreTy.empty [] (Ctx.extend [] (.lazy Small)) [] (.var 0) (.lazy I) :=
    .V_Sub (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,Small,I])) lazy_covariant trivial trivial trivial
  refine .C_Let (.C_App force_i (.cons hv .nil)) ?_ (by rw [Ty.shiftV_of_wf_zero (small_ann (Γ := [])).wf]; exact small_ann.declared)
  exact .C_App force_small (.cons (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,Small,I])) .nil)

def capT : Capture := Capture.empty.extend (.loc 0)
def kT : Cont := [.letF (Closure.pure afterLazy)]
def kF : Cont := [.letF (.mk capT afterForce)]
def s0 : State := .run (Closure.pure program) [] Store.empty
def s1 : State := .run (Closure.pure (.lazyC (.ret three))) kT Store.empty
def s2 : State := .run (Closure.pure (.ret (.loc 0))) kT μ
def s3 : State := .run (.mk capT afterLazy) [] μ
def s4 : State := .run (.mk capT (.app (.prim "force" [I] [] []) [.var 0])) kF μ
def s5 : State := .run thunk (.update 0 :: kF) μ
def s6 : State := .run (Closure.pure (.ret three)) kF μdone
def s7 : State := .run (.mk (capT.extend three) afterForce) [] μdone
def s8 : State := .run (Closure.pure (.ret three)) [] μdone

theorem execution : Step P B σ s0 none s1 ∧ Step P B σ s1 none s2 ∧
    Step P B σ s2 none s3 ∧ Step P B σ s3 none s4 ∧ Step P B σ s4 none s5 ∧
    Step P B σ s5 none s6 ∧ Step P B σ s6 none s7 ∧ Step P B σ s7 none s8 :=
  ⟨.E_Let rfl,.E_Lazy rfl rfl,.E_Return rfl,.E_Let rfl,
    .E_Force (b := "force") (s := sg .force) rfl rfl rfl rfl,
    .E_Update rfl,.E_Return rfl,.E_ForceDone (b := "force") (s := sg .force) rfl rfl rfl rfl⟩

theorem final_view : (Closure.pure (.ret three)).view = .ret three := rfl
theorem final_done : μdone 0 = some (.done three) := rfl

theorem program_start : StateTyE P B σ Eff.empty s0 := by
  refine ⟨StoreTy.empty,none,Small,Small,Eff.empty,Eff.empty,StoreOk.empty _ _ _,
    ClosureTy.pure program_typed (empty_ann small_ann) (by intros; contradiction) rfl
      (by intros; contradiction),sub_refl _,.K_Empty (sub_refl _) small_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [s0,Closure.ClosedAt,Closure.pure,program,afterLazy,afterForce,Comp.ClosedAt,
      Val.ClosedAt,Val.ClosedList,Capture.empty,Capture.Closed,captureSlotsClosed,Capture.values,three]
    exact ⟨trivial,(small_ann (Γ := [none,none])).wf⟩
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem nine_not_small {store} : ¬ HasTypeV P B store [] [] [] nine Small := by
  intro h
  have hf := h.facts rfl p (by simp [Small,p,Ty.assume,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  have hh := hf.sound (fun _ => none) (by intro q hq; cases hq)
  change false = true at hh
  cases hh

theorem done_rejects_nine : ¬ CellOk P B σ Ψ 0 (.done nine) := by
  rintro ⟨a,ha,hv,_⟩
  cases Option.some.inj ha
  exact nine_not_small hv

def Ψwide : StoreTy := StoreTy.empty.put 0 (.lazy I)

theorem contract_removed : ¬ HasTypeV P B Ψwide [] [] [] (.loc 0) (.lazy Small) := by
  intro h
  obtain ⟨l,a,hv,hl,hle⟩ := h.canonical_lazy rfl
  cases Val.loc.inj hv
  cases Option.some.inj hl
  have hv : HasTypeV P B Ψwide [] [] [] nine Small :=
    .V_Sub (.V_Const trivial) hle small_ann.wf small_ann.sorted small_ann.declared
  exact nine_not_small hv

theorem force_without_contract : ¬ HasTypeC P B Ψwide [] [] [] none
    (.app (.prim "force" [Small] [] []) [.loc 0]) Small Eff.empty := by
  intro h
  obtain ⟨r,e,hargs,_,_⟩ := h.primitive_call
    (by intro v hv; cases List.mem_singleton.mp hv; trivial) rfl
    (show B.sig "force" = some (sg .force) from rfl)
  have ht := hargs.arguments
  rw [show Ty.normTys [Small] = [Small] from rfl,
    show ([] : List Eff).map Eff.norm = [] from rfl,force_tel_instance small_ann rfl] at ht
  change HasTypeTelArgsQ P B Ψwide Qempty [] [] [] [.loc 0]
    (.param "value" (.lazy Small) _) r e at ht
  cases ht with
  | param _ hv _ => exact contract_removed hv

theorem lazy_var_no_sort (sort) :
    ¬ Term.HasSort (Ctx.extend [] (.lazy Small)) (.var 0) sort := by
  rintro ⟨_,t,ht,hs⟩
  cases Option.some.inj ht
  cases hs

namespace Snapshot

def Γ : Ctx := Ctx.extend [] I
def cap : Capture := Capture.empty.extend three
def ΨR : StoreTy := StoreTy.empty.put 1 (.ref I)
def μR (n : Integer64Value) : Store := Store.empty.set 1 (.val (.const (.integer n)))
def q : Closure := .mk cap (.lazyC (.ret (.var 0)))
def delayed : Closure := .mk cap (.ret (.var 0))
def ΨC : StoreTy := ΨR.put 0 (.lazy Small)
def μC : Store := (μR 3).set 0 (.thunk delayed)
def μW : Store := μC.set 1 (.val nine)
def μD : Store := μW.set 0 (.done three)

theorem ref_store : StoreOk P B σ ΨR (μR 3) :=
  (StoreOk.empty P B σ).allocate_reference assumptions.values rfl i_ann rfl (.V_Const trivial) (by trivial)

theorem ref_closed : (μR 3).Closed := by
  intro l c hc
  by_cases hl : l = 1
  · subst l; cases Option.some.inj hc; trivial
  · simp [μR,Store.set,Store.empty,hl] at hc

theorem fact_wf : Pred.WellFormed P [] Γ p := by
  constructor <;> simp [p,Γ,Ctx.extend,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.declarationSelf,
    Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Ty.shiftV,I,
    Pred.Declared,Term.Declared]

theorem captured {Ψ : StoreTy} : CaptureOk P B Ψ none Γ [p] cap :=
  ((CaptureOk.empty P B Ψ none).extend (v := three) i_ann (.V_Const trivial) (by trivial)).addEvaluated fact_wf (by decide)

theorem body {Ψ : StoreTy} : HasTypeC P B Ψ [] Γ [p] none (.ret (.var 0)) Small Eff.empty := by
  apply HasTypeCQ.C_Return
  exact .V_Refine (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I])) rfl rfl
    small_ann.sorted.2 small_ann.wf.2.1
    (.hyp (List.mem_append_right _ List.mem_cons_self)) trivial small_ann.declared.2

theorem body_needs_fact {Ψ : StoreTy} :
    ¬ HasTypeC P B Ψ [] Γ [] none (.ret (.var 0)) Small Eff.empty := by
  intro h
  have hf := h.ret_value rfl |>.facts rfl p (by simp [Small,p,Ty.assume,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  have hh := hf.sound (fun _ => some (.integer 9)) (by intro q hq; cases hq)
  change false = true at hh
  cases hh

theorem delayed_typed {Ψ : StoreTy} : ClosureTy P B Ψ [] none delayed Small Eff.empty := by
  have hh := ClosureTy.capture (captured (Ψ := Ψ)) (body (Ψ := Ψ)) (empty_ann small_ann)
    rfl (by intros; contradiction)
  simpa only [delayed,show cap.closeTy Small = Small from rfl,Capture.closeEff,Eff.subst_values_empty] using hh

theorem lazy_typed : ClosureTy P B ΨR [] none q (.lazy Small) Eff.empty := by
  have hb : HasTypeC P B ΨR [] Γ [p] none (.lazyC (.ret (.var 0))) (.lazy Small) Eff.empty := by
    apply HasTypeCQ.C_Lazy (a := Small) _ small_ann
    simpa [Γ,hideConts,Ctx.extend,I,Ty.shiftV,Ty.Ordinary,Ordinary,Ty.core] using
      (body (Ψ := hideBuilders ΨR))
  have hh := ClosureTy.capture (captured (Ψ := ΨR)) hb
    (empty_ann ⟨small_ann.wf,small_ann.sorted,small_ann.declared⟩) rfl (by intros; contradiction)
  simpa only [q,show cap.closeTy (.lazy Small) = .lazy Small from rfl,
    Capture.closeEff,Eff.subst_values_empty] using hh

theorem start : StateTyE P B σ E (.run q [] (μR 3)) := by
  refine ⟨ΨR,none,.lazy Small,.lazy Small,E,Eff.empty,ref_store,lazy_typed,?_,
    .K_Empty (sub_refl _) ⟨small_ann.wf,small_ann.sorted,small_ann.declared⟩,?_,?_,?_,ref_closed⟩
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
  · trivial
  · simp [q,cap,Closure.ClosedAt,Capture.extend,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Capture.values,three]
  · intro f hf; cases hf

theorem allocated : SavedStep E
    (.run q [] (μR 3)) (.run (Closure.pure (.ret (.loc 0))) [] μC) := start.lazy_transition assumptions (m := .ret (.var 0)) rfl (l := 0) rfl

theorem pending_store : StoreOk P B σ ΨC μC :=
  ref_store.allocate_lazy assumptions.values rfl small_ann delayed_typed (by trivial)

theorem pending_closed : μC.Closed := by
  intro l c hc
  by_cases hl : l = 0
  · subst l; cases Option.some.inj hc
    simp [Cell.Closed,delayed,cap,Closure.ClosedAt,Capture.extend,Capture.empty,Capture.Closed,
      captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Capture.values,three]
  · simp only [μC,Store.set,hl,↓reduceIte] at hc
    exact ref_closed l c hc

theorem set_head : HasTypeV P B ΨC [] [] [] (.prim B.refSet [I] [] [])
    (.fn ["reference","value"] [.reference I,I] U E) := by
  obtain ⟨a,he,_,hs⟩ := assumptions.reference_primitives (ts := [I]) rfl i_ann rfl
    (by simp [Ordinary,Ty.core,Ty.norm,I]) (by trivial)
  cases List.cons.inj he |>.1
  exact hs.weaken_empty assumptions.values

theorem set_start : StateTyE P B σ E
    (.run (Closure.pure (.app (.prim B.refSet [I] [] []) [.loc 1,nine])) [] μC) := by
  have hu : Ty.Annotation P [] [] U := ⟨trivial,trivial,trivial⟩
  have ha : Ty.Annotation P [] [] (.dependentFn (.done U E)) :=
    ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  refine ⟨ΨC,none,U,U,E,E,pending_store,ClosureTy.pure
    (.C_App set_head (.cons (.V_LocRef rfl trivial) (.cons (.V_Const trivial) .nil))) ha
    (by intros; contradiction) rfl (by intros; contradiction),sub_refl _,.K_Empty (sub_refl _) hu,?_,?_,?_,pending_closed⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,I,Ty.WF,nine]
  · intro f hf; cases hf

theorem set_pair : SavedStep E
    (.run (Closure.pure (.app (.prim B.refSet [I] [] []) [.loc 1,nine])) [] μC) (.run (Closure.pure (.ret (.const .unit))) [] μW) := set_start.reference_set_transition assumptions (s := sg .refSet) rfl rfl rfl

theorem written_store : StoreOk P B σ ΨC μW :=
  pending_store.write_reference (l := 1) rfl rfl rfl (.V_Const trivial) (by trivial)

theorem written_closed : μW.Closed := by
  intro l c hc
  by_cases hl : l = 1
  · subst l; cases Option.some.inj hc; trivial
  · simp only [μW,Store.set,hl,↓reduceIte] at hc
    exact pending_closed l c hc

theorem captured_after_set : CaptureOk P B ΨC none Γ [p] cap ∧
    Entails [] (predBind (valEnv cap.env).values p) :=
  ⟨(captured (Ψ := ΨR)).store assumptions.values ref_store.wf
      (StoreTy.extends_put (Ψ := ΨR) (l := 0) (x := LocTy.lazy Small) rfl).preservesNormals,
    (captured (Ψ := ΨC)).close_entails (.hyp (List.mem_append_right _ List.mem_cons_self))⟩

theorem force_start : StateTyE P B σ E
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μW) := by
  refine ⟨ΨC,none,Small,Small,E,Eff.empty,written_store,ClosureTy.pure
    (.C_App force_small (.cons (.V_LocLazy rfl small_ann.declared) .nil)) (empty_ann small_ann)
    (by intros; contradiction) rfl (by intros; contradiction),?_,.K_Empty (sub_refl _) small_ann,?_,?_,?_,written_closed⟩
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values]
    exact (small_ann (Γ := [])).wf
  · intro f hf; cases hf

theorem force_pair : SavedStep E
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μW) (.run delayed [.update 0] μW) := force_start.force_thunk_transition assumptions (s := sg .force) rfl rfl rfl

theorem update_pair : SavedStep E
    (.run delayed [.update 0] μW) (.run (Closure.pure (.ret three)) [] μD) := force_pair.2.lazy_update_const_transition assumptions (c := .integer 3) rfl

theorem later_value : μD 0 = some (.done three) ∧ μD 1 = some (.val nine) := ⟨rfl,rfl⟩

theorem later_force : Step P B σ
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μD) none
    (.run (Closure.pure (.ret three)) [] μD) :=
  .E_ForceDone (b := "force") (s := sg .force) rfl rfl rfl rfl

theorem done_store : StoreOk P B σ ΨC μD :=
  written_store.write_done rfl three_small (by trivial)

theorem done_closed : μD.Closed := by
  intro l c hc
  by_cases hl : l = 0
  · subst l; cases Option.some.inj hc; trivial
  · simp only [μD,Store.set,hl,↓reduceIte] at hc
    exact written_closed l c hc

theorem later_start : StateTyE P B σ E
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μD) := by
  refine ⟨ΨC,none,Small,Small,E,Eff.empty,done_store,ClosureTy.pure
    (.C_App force_small (.cons (.V_LocLazy rfl small_ann.declared) .nil)) (empty_ann small_ann)
    (by intros; contradiction) rfl (by intros; contradiction),?_,.K_Empty (sub_refl _) small_ann,?_,?_,?_,done_closed⟩
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values]
    exact (small_ann (Γ := [])).wf
  · intro f hf; cases hf

theorem later_pair : SavedStep E
    (.run (Closure.pure (.app (.prim "force" [Small] [] []) [.loc 0])) [] μD) (.run (Closure.pure (.ret three)) [] μD) := later_start.force_done_transition assumptions (s := sg .force) rfl rfl rfl

end Snapshot

namespace Reentry

def ΨR : StoreTy := StoreTy.empty.put 0 (.lazy I)
def q : Closure := Closure.pure (.app (.prim "force" [I] [] []) [.loc 0])
def μR : Store := Store.empty.set 0 (.thunk q)

theorem q_typed : ClosureTy P B (hideBuilders ΨR) [] none q I Eff.empty :=
  ClosureTy.pure (.C_App force_i (.cons (.V_LocLazy rfl trivial) .nil)) (empty_ann i_ann)
    (by intros; contradiction) rfl (by intros; contradiction)

theorem store : StoreOk P B σ ΨR μR := by
  refine ⟨⟨1,?_⟩,?_,?_,?_,?_⟩
  · intro l hl; have hn : l ≠ 0 := by omega
    simp [μR,Store.set,Store.empty,hn]
  · intro l x hx
    by_cases hl : l = 0
    · subst l; cases Option.some.inj hx; trivial
    · simp [ΨR,StoreTy.put,StoreTy.empty,hl] at hx
  · intro l x hx
    by_cases hl : l = 0
    · subst l; cases Option.some.inj hx; trivial
    · simp [ΨR,StoreTy.put,StoreTy.empty,hl] at hx
  · intro l x hx
    by_cases hl : l = 0
    · subst l; simp [μR,Store.set]
    · simp [ΨR,StoreTy.put,StoreTy.empty,hl] at hx
  · intro l c hc
    by_cases hl : l = 0
    · subst l; cases Option.some.inj hc; exact ⟨I,rfl,q_typed,by trivial⟩
    · simp [μR,Store.set,Store.empty,hl] at hc

theorem start : StateTyE P B σ Eff.empty (.run q [] μR) := by
  have hq := q_typed.store assumptions.values store.wf.hide (StoreTy.hide_extends ΨR)
  refine ⟨ΨR,none,I,I,Eff.empty,Eff.empty,store,hq,sub_refl _,.K_Empty (sub_refl _) i_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [q,Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,I,Ty.WF]
  · intro f hf; cases hf
  · intro l c hc
    by_cases hl : l = 0
    · subst l; cases Option.some.inj hc
      simp [q,Cell.Closed,Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
        Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,I,Ty.WF]
    · simp [μR,Store.set,Store.empty,hl] at hc

theorem first : SavedStep Eff.empty
    (.run q [] μR) (.run q [.update 0] μR) := start.force_thunk_transition assumptions (s := sg .force) rfl rfl rfl
theorem second : SavedStep Eff.empty
    (.run q [.update 0] μR) (.run q [.update 0,.update 0] μR) := first.2.force_thunk_transition assumptions (s := sg .force) rfl rfl rfl

theorem same_thunk : μR 0 = some (.thunk q) := rfl

end Reentry
namespace LazyField

def declaration : ConDecl := ⟨"Box",0,[.lazy Small,I]⟩
def PM : Program := { P with cons := fun c => if c = "Box" ∨ c = "Other" then some declaration else none }
def value : Val := .con "Box" [] [.loc 0,three]
def ty : Ty := .data "Box" []
def field0 : FieldRef := ⟨"Box","Box",0,.integer⟩
def field1 : FieldRef := ⟨"Box","Box",1,.integer⟩
def observation : Term := .dataValue "Box" [none,some (.integer 3)]

theorem value_typed : HasTypeV PM B Ψ [] [] [] value ty := by
  refine .V_Con (cd := declaration) rfl rfl ⟨rfl,[],rfl,by intro i a k ht hk; cases ht⟩ ?_ ?_ ?_
  · simp [declaration,Ty.WF,Ty.WFList,Small,p,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,I]
  · exact .cons (.V_LocLazy rfl small_ann.declared) (.cons (.V_Const trivial) .nil)
  · refine ⟨trivial,trivial,⟨⟨0,?_,rfl⟩,trivial⟩⟩
    refine ⟨⟨"Box",declaration,rfl,rfl⟩,?_⟩
    intro c d hc _
    change (if c = "Box" ∨ c = "Other" then some declaration else none) = some d at hc
    split at hc
    · cases Option.some.inj hc; rfl
    · cases hc

theorem partial_observation : value.toTerm? = some observation := rfl
theorem missing_field : (Term.field field0 observation).observe (fun _ => none) = none := rfl
theorem immutable_field : (Term.field field1 observation).observe (fun _ => none) = some (.integer 3) := rfl
theorem live_fact_fails : (Pred.lt (.field field0 observation) (.integer 8)).evalClosed = none := by decide

theorem root_shape : MatchFacts.RootShape PM ty value := MatchFacts.rootShape_of_typing value_typed

def alts : List Alt := [⟨.con "Box" [.wild,.wild],[]⟩]
theorem actual_match : firstAlt value alts = some [] := rfl
theorem root_fact : PathsEvaluated value (matchedTests alts) := by
  apply MatchFacts.matched_paths_true actual_match
  intro p hp
  simp [value,alts,matchedTests,alternativesTest,patternTest?,pathFacts,PathTest.predicate,
    Val.toTerm?,Val.toTermSlots,three] at hp
  rcases hp with rfl
  exact ⟨by decide,by trivial⟩


theorem live_field_undeclared : ¬ field0.Declared PM [] [] observation := by
  rintro ⟨ts,cd,a,_,hc,_,_,harg,_,hs⟩
  have he : declaration = cd := Option.some.inj hc
  subst cd
  have he : Ty.lazy Small = a := Option.some.inj harg
  subst a
  cases hs

end LazyField


end
end Benitoite.Release.Refinement.LazyBoundary

namespace Benitoite.Release.Refinement.LazyBoundary
noncomputable section

namespace UpdateCases

def four : Val := .const (.integer ⟨4,by decide⟩)
def μfour : Store := μdone.set 0 (.done four)

theorem four_small : HasTypeV P B Ψ [] [] [] four Small := by
  refine .V_Refine (.V_Const trivial) rfl rfl small_ann.sorted.2 small_ann.wf.2.1
    ?_ trivial small_ann.declared.2
  exact CaptureOk.evaluated_fact (by decide)

theorem done_start : StateTyE P B σ Eff.empty
    (.run (Closure.pure (.ret four)) [.update 0] μdone) := by
  refine ⟨Ψ,none,Small,Small,Eff.empty,Eff.empty,done_store,
    ClosureTy.pure (.C_Return four_small) (empty_ann small_ann)
      (by intros; contradiction) rfl (by intros; contradiction),sub_refl _,
    .K_Update rfl small_ann (.K_Empty (sub_refl _) small_ann),?_,?_,?_,done_closed⟩
  · trivial
  · trivial
  · intro f hf; cases List.mem_singleton.mp hf; trivial

theorem overwrite_done : SavedStep Eff.empty
    (.run (Closure.pure (.ret four)) [.update 0] μdone)
    (.run (Closure.pure (.ret four)) [] μfour) :=
  done_start.lazy_update_any_cell assumptions rfl

theorem old_and_new_contracts : StoreOk P B σ Ψ μfour ∧
    HasTypeV P B Ψ [] [] [] three Small ∧
    Entails [] (p.open (.integer 3)) ∧ μfour 0 = some (.done four) :=
  ⟨done_store.write_done rfl four_small (by trivial),three_small,
    CaptureOk.evaluated_fact (by decide),rfl⟩

theorem error_start : StateTyE P B σ Eff.empty (.error [] [.update 0] μ) :=
  ⟨Ψ,none,Small,Small,Eff.empty,store,
    .K_Update rfl small_ann (.K_Empty (sub_refl _) small_ann),
    (by intro f hf; cases List.mem_singleton.mp hf; trivial),store_closed⟩

theorem error_pop : SavedStep Eff.empty (.error [] [.update 0] μ) (.error [] [] μ) :=
  error_start.lazy_update_pop_error

theorem exit_start : StateTyE P B σ Eff.empty (.exit 0 [] [.update 0] μ) :=
  error_start

theorem exit_pop : SavedStep Eff.empty (.exit 0 [] [.update 0] μ) (.exit 0 [] [] μ) :=
  exit_start.lazy_update_pop_exit

theorem pops_keep_thunk : μ 0 = some (.thunk thunk) := rfl

end UpdateCases
end
end Benitoite.Release.Refinement.LazyBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "Benitoite.Release.Refinement.LazyBoundary").length > 1
    then some name else none).mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
