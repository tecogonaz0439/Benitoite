import Lean
import Benitoite.Release.Model
import Benitoite.Release.ModelTargets
import Benitoite.Release.ModelHttp
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
  | .refGet => ⟨[{}],0,["reference"],[.reference (.tvar 0)],.tvar 0,E,fun _ _ => True,k,none,[],.untargeted⟩
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
  ref_get := ⟨sg .refGet,rfl,rfl⟩
  ref_set := ⟨sg .refSet,rfl,rfl⟩
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
    (hr : (sg k).ret = r) (hn : NamesWF names ps) :
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
    · have hks : (sg k).tparams.map TParamDecl.kind = [.value] := by cases k <;> rfl
      rw [hks]
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

theorem new_prim : HasTypeV P B StoreTy.empty [] [] [] (prim "new")
    (.fn ["value"] [I] (.reference I) E) := by
  have hv := primitive (b := "new") (k := PrimKind.refNew) (names := ["value"])
    (ps := [.tvar 0]) (r := .reference (.tvar 0)) rfl rfl rfl rfl ⟨rfl,by decide⟩
  have ht : instantiatedTel (Tel.instR [] (sg .refNew).tel) [I] [] =
      Ty.toTel ["value"] [I] (.reference I) E := by
    simp [sg,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,typeEnvAt,SubstEnv.up,upValues,
      shiftTypes,Ty.shiftV,E,Eff.single,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,
      mapRangesTys,mapRangeAtoms_rangeAt,Order.sortUnique,Ty.toTel]
    all_goals simp [Eff.rawBind,Eff.norm,Eff.shiftV,E,Eff.single,rawBindTys,Ty.normTys,Order.sortUnique,substAtoms_nil,instAtoms_nil,rowFails]
  rw [ht] at hv
  have hh := hv.V_Normal
  rw [show (Ty.dependentFn (Ty.toTel ["value"] [I] (.reference I) E)).norm =
    .fn ["value"] [I] (.reference I) E from by
      rw [Ty.norm,Tel.norm_toTel]
      exact Ty.foldFn_toTel ⟨["value"],[I],.reference I,E,⟨rfl,by decide⟩⟩] at hh
  exact hh

theorem get_prim : HasTypeV P B StoreTy.empty [] [] [] (prim "get")
    (.fn ["reference"] [.reference I] I E) := by
  have hv := primitive (b := "get") (k := PrimKind.refGet) (names := ["reference"])
    (ps := [.reference (.tvar 0)]) (r := .tvar 0) rfl rfl rfl rfl ⟨rfl,by decide⟩
  have ht : instantiatedTel (Tel.instR [] (sg .refGet).tel) [I] [] =
      Ty.toTel ["reference"] [.reference I] I E := by
    simp [sg,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,typeEnvAt,SubstEnv.up,upValues,
      shiftTypes,Ty.shiftV,E,Eff.single,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,
      mapRangesTys,mapRangeAtoms_rangeAt,Order.sortUnique,Ty.toTel]
    all_goals simp [Eff.rawBind,Eff.norm,Eff.shiftV,E,Eff.single,rawBindTys,Ty.normTys,Order.sortUnique,substAtoms_nil,instAtoms_nil,rowFails]
  rw [ht] at hv
  have hh := hv.V_Normal
  rw [show (Ty.dependentFn (Ty.toTel ["reference"] [.reference I] I E)).norm =
    .fn ["reference"] [.reference I] I E from by
      rw [Ty.norm,Tel.norm_toTel]
      exact Ty.foldFn_toTel ⟨["reference"],[.reference I],I,E,⟨rfl,by decide⟩⟩] at hh
  exact hh

theorem set_prim : HasTypeV P B StoreTy.empty [] [] [] (prim "set")
    (.fn ["reference","value"] [.reference I,I] U E) := by
  have hv := primitive (b := "set") (k := PrimKind.refSet) (names := ["reference","value"])
    (ps := [.reference (.tvar 0),.tvar 0]) (r := U) rfl rfl rfl rfl ⟨rfl,by decide⟩
  have ht : instantiatedTel (Tel.instR [] (sg .refSet).tel) [I] [] =
      Ty.toTel ["reference","value"] [.reference I,I] U E := by
    simp [sg,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,Tel.norm,Ty.norm,Ty.normTys,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,typeEnvAt,SubstEnv.up,upValues,
      shiftTypes,Ty.shiftV,E,Eff.single,Eff.empty,substAtoms_nil,instAtoms_nil,rowFails,
      mapRangesTys,mapRangeAtoms_rangeAt,Order.sortUnique,Ty.toTel]
    all_goals simp [Eff.rawBind,Eff.norm,Eff.shiftV,E,Eff.single,rawBindTys,Ty.normTys,Order.sortUnique,substAtoms_nil,instAtoms_nil,rowFails]
  rw [ht] at hv
  have hh := hv.V_Normal
  rw [show (Ty.dependentFn (Ty.toTel ["reference","value"] [.reference I,I] U E)).norm =
    .fn ["reference","value"] [.reference I,I] U E from by
      rw [Ty.norm,Tel.norm_toTel]
      exact Ty.foldFn_toTel ⟨["reference","value"],[.reference I,I],U,E,⟨rfl,by decide⟩⟩] at hh
  exact hh

theorem update_prim : HasTypeV P B StoreTy.empty [] [] [] (prim "update")
    (.fn ["reference","f"] [.reference I,.fn ["value"] [I] I Eff.empty] U E) := by
  have hv := primitive (b := "update") (k := PrimKind.refUpdate) (names := ["reference","f"])
    (ps := [.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty]) (r := U) rfl rfl rfl rfl ⟨rfl,by decide⟩
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

theorem new_any {store Γ Φ} : HasTypeV P B store [] Γ Φ (prim "new")
    (.fn ["value"] [I] (.reference I) E) := prim_context new_prim (by
  exact ⟨⟨rfl,by decide⟩,⟨trivial,trivial⟩,trivial,trivial,rfl⟩)
theorem get_any {store Γ Φ} : HasTypeV P B store [] Γ Φ (prim "get")
    (.fn ["reference"] [.reference I] I E) := prim_context get_prim (by
  exact ⟨⟨rfl,by decide⟩,⟨trivial,trivial⟩,trivial,trivial,rfl⟩)
theorem set_any {store Γ Φ} : HasTypeV P B store [] Γ Φ (prim "set")
    (.fn ["reference","value"] [.reference I,I] U E) := prim_context set_prim (by
  exact ⟨⟨rfl,by decide⟩,⟨trivial,trivial,trivial⟩,trivial,trivial,rfl⟩)

theorem ie_ann {Γ : Ctx} : Ty.Annotation P [] Γ (.dependentFn (.done I E)) := by
  constructor <;> simp [Ty.WF,Tel.WF,Eff.WF,E,Eff.single,Ty.WFList,Eff.Canonical,Eff.norm,
    Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys]
theorem ue_ann {Γ : Ctx} : Ty.Annotation P [] Γ (.dependentFn (.done U E)) := by
  constructor <;> simp [Ty.WF,Tel.WF,Eff.WF,E,Eff.single,Ty.WFList,Eff.Canonical,Eff.norm,
    Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys]
theorem re_ann {Γ : Ctx} : Ty.Annotation P [] Γ (.dependentFn (.done (.reference I) E)) := by
  constructor <;> simp [Ty.WF,Tel.WF,Eff.WF,E,Eff.single,Ty.WFList,Eff.Canonical,Eff.norm,
    Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys]

theorem empty_cover (Γ : Ctx) (Φ : List Pred) : Eff.Covers Γ Φ E Eff.empty :=
  ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
theorem sub_refl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩

def afterSet : Comp := .ret (.var 1)
def afterGet : Comp := .letIn (.app (prim "set") [.var 1,num 9]) afterSet
def afterNew : Comp := .letIn (.app (prim "get") [.var 0]) afterGet
def program : Comp := .letIn (.app (prim "new") [num 3]) afterNew

theorem program_typed : HasTypeC P B StoreTy.empty [] [] [] none program I E := by
  refine .C_Let (.C_App new_any (.cons (.V_Const trivial) .nil)) ?_ trivial
  refine .C_Let (.C_App get_any (.cons (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I])) .nil)) ?_ trivial
  refine .C_Let (.C_App set_any (.cons (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I]))
    (.cons (.V_Const trivial) .nil))) ?_ trivial
  exact .C_Eff (.C_Return (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I]))) (empty_cover _ _)

def capR : Capture := Capture.empty.extend (.loc 0)
def capX : Capture := capR.extend (num 3)
def kR : Cont := [.letF (Closure.pure afterNew)]
def kX : Cont := [.letF (.mk capR afterGet)]
def kU : Cont := [.letF (.mk capX afterSet)]
def s0 : State := .run (Closure.pure program) [] Store.empty
def s1 : State := .run (Closure.pure (.app (prim "new") [num 3])) kR Store.empty
def s2 : State := .run (Closure.pure (.ret (.loc 0))) kR (μ 3)
def s3 : State := .run (.mk capR afterNew) [] (μ 3)
def s4 : State := .run (.mk capR (.app (prim "get") [.var 0])) kX (μ 3)
def s5 : State := .run (Closure.pure (.ret (num 3))) kX (μ 3)
def s6 : State := .run (.mk capX afterGet) [] (μ 3)
def s7 : State := .run (.mk capX (.app (prim "set") [.var 1,num 9])) kU (μ 3)
def s8 : State := .run (Closure.pure (.ret (.const .unit))) kU (μ 9)
def s9 : State := .run (.mk (capX.extend (.const .unit)) afterSet) [] (μ 9)

theorem execution : Step P B σ s0 none s1 ∧ Step P B σ s1 none s2 ∧
    Step P B σ s2 none s3 ∧ Step P B σ s3 none s4 ∧ Step P B σ s4 none s5 ∧
    Step P B σ s5 none s6 ∧ Step P B σ s6 none s7 ∧ Step P B σ s7 none s8 ∧
    Step P B σ s8 none s9 := by
  refine ⟨.E_Let rfl,.E_RefNew (b := "new") (s := sg .refNew) rfl rfl rfl rfl,
    .E_Return rfl,.E_Let rfl,.E_RefGet (b := "get") (s := sg .refGet) rfl rfl rfl rfl,
    .E_Return rfl,.E_Let rfl,?_,.E_Return rfl⟩
  have hm : (μ 3).set 0 (.val (num 9)) = μ 9 := by
    funext i; simp [μ,Store.set]; split <;> rfl
  rw [s7,s8,←hm]
  exact .E_RefSet (b := "set") (s := sg .refSet) rfl rfl rfl

theorem final_snapshot : (Closure.mk (capX.extend (.const .unit)) afterSet).view = .ret (num 3) := rfl
theorem final_current : (μ 9) 0 = some (.val (num 9)) := rfl

-- 三つの開始の StateTyE を具体に構成し、代表の保存へ渡す。
theorem pure_new_start : StateTyE P B σ E
    (.run (Closure.pure (.app (prim "new") [num 3])) [] Store.empty) := by
  refine ⟨StoreTy.empty,none,.reference I,.reference I,E,E,StoreOk.empty _ _ _,
    ClosureTy.pure (.C_App new_any (.cons (.V_Const trivial) .nil)) re_ann
      (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) ref_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,prim,Ty.WF,num]
  · intro f hf; cases hf
  · intro l c hl; cases hl

theorem pure_new_saved : StateTyE P B σ E
    (.run (Closure.pure (.ret (.loc 0))) [] (μ 3)) :=
  pure_new_start.reference_new assumptions rfl rfl rfl

theorem pure_get_start : StateTyE P B σ E
    (.run (Closure.pure (.app (prim "get") [.loc 0])) [] (μ 3)) := by
  refine ⟨Ψ,none,I,I,E,E,store 3,
    ClosureTy.pure (.C_App get_any (.cons loc .nil)) ie_ann
      (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) i_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,prim,Ty.WF]
  · intro f hf; cases hf
  · exact μ_closed 3

theorem pure_get_saved : StateTyE P B σ E
    (.run (Closure.pure (.ret (num 3))) [] (μ 3)) :=
  pure_get_start.reference_get assumptions rfl rfl rfl

theorem pure_set_start : StateTyE P B σ E
    (.run (Closure.pure (.app (prim "set") [.loc 0,num 9])) [] (μ 3)) := by
  refine ⟨Ψ,none,U,U,E,E,store 3,
    ClosureTy.pure (.C_App set_any (.cons loc (.cons (.V_Const trivial) .nil))) ue_ann
      (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) u_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,prim,Ty.WF,num]
  · intro f hf; cases hf
  · exact μ_closed 3

theorem pure_set_saved : StateTyE P B σ E
    (.run (Closure.pure (.ret (.const .unit))) [] (μ 9)) := by
  have hh := pure_set_start.reference_set assumptions rfl rfl
  have hm : (μ 3).set 0 (.val (num 9)) = μ 9 := by funext i; simp [μ,Store.set]; split <;> rfl
  simpa only [hm,prim] using hh


def ΓR : Ctx := Ctx.extend [] (.reference I)
def ΓX : Ctx := ΓR.extend I
def ΓU : Ctx := ΓX.extend U
def p : Pred := .lt (.var 0) (.integer 8)
def small : Ty := .refined I (.lt (.var 0) (.integer 8))

theorem capturedR : CaptureOk P B Ψ none ΓR [] capR :=
  (CaptureOk.empty P B Ψ none).extend ref_ann loc trivial

theorem capturedX : CaptureOk P B Ψ none ΓX [] capX :=
  capturedR.extend i_ann (.V_Const trivial) trivial

theorem p_wf : Pred.WellFormed P [] ΓX p := by
  constructor <;> simp [p,ΓX,ΓR,Ctx.extend,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.declarationSelf,
    Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Ty.shiftV,I,
    Pred.Declared,Term.Declared]

theorem snapshot_capture : CaptureOk P B Ψ none ΓX [p] capX :=
  capturedX.addEvaluated p_wf (by decide)

theorem snapshot_write : StoreOk P B σ Ψ ((μ 3).set 0 (.val (num 9))) ∧
    CaptureOk P B Ψ none ΓX [p] capX ∧
    Entails [] (predBind (valEnv capX.env).values p) :=
  snapshot_capture.reference_write_snapshot assumptions.values (store 3)
    (.hyp (List.mem_append_right _ List.mem_cons_self)) rfl rfl rfl (.V_Const trivial) trivial

theorem small_annotation {Γ : Ctx} : Ty.Annotation P [] Γ small := by
  constructor <;> simp [small,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.declarationSelf,
    Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.extend,Ty.shiftV,I]

theorem body_reads_snapshot : HasTypeC P B Ψ [] ΓU [p.lift] none afterSet small Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I])) rfl rfl
    small_annotation.sorted.2 small_annotation.wf.2.1 ?_ trivial small_annotation.declared.2
  exact .hyp (List.mem_append_right _ List.mem_cons_self)

theorem body_needs_snapshot_fact :
    ¬ HasTypeC P B Ψ [] ΓU [] none afterSet small Eff.empty := by
  intro h
  have hf := (h.ret_value rfl).facts rfl (.lt (.var 0) (.integer 8)) (by simp [small,Ty.assume,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  have hh := hf.sound (fun _ => some (.integer 9)) (by
    intro q hq
    change q ∈ [] at hq
    cases hq)
  change false = true at hh
  cases hh

theorem final_refined : HasTypeV P B Ψ [] [] [] (num 3) small := by
  refine .V_Refine (.V_Const trivial) rfl rfl small_annotation.sorted.2 small_annotation.wf.2.1
    ?_ trivial small_annotation.declared.2
  exact CaptureOk.evaluated_fact (by decide)

theorem final_typed : StateTyE P B σ E s9 := by
  have hc := snapshot_capture.extend (v := Val.const Const.unit) u_ann (.V_Const trivial) trivial
  have ha : Ty.Annotation P [] ΓU (.dependentFn (.done small Eff.empty)) := by
    refine ⟨⟨small_annotation.wf,trivial,rfl⟩,⟨small_annotation.sorted,trivial⟩,
      ⟨small_annotation.declared,trivial⟩⟩
  have hh := ClosureTy.capture hc body_reads_snapshot ha rfl (by intro r hr; cases hr)
  have hclose : (capX.extend (.const .unit)).closeTy small = small := rfl
  rw [hclose] at hh
  refine ⟨Ψ,none,small,small,E,Eff.empty,store 9,?_,?_,.K_Empty (sub_refl E) small_annotation,?_,?_,?_,μ_closed 9⟩
  · simpa only [Capture.closeEff,Eff.subst_values_empty] using hh
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
  · trivial
  · simp [Closure.ClosedAt,capX,capR,Capture.extend,Capture.empty,Capture.Closed,
      captureSlotsClosed,Val.ClosedAt,Capture.values,afterSet,Comp.ClosedAt,num]
  · intro f hf; cases hf

theorem reference_not_integer_observation : ¬ Term.HasSort ΓR (.var 0) .integer := by
  rintro ⟨_,t,ht,hs⟩
  cases Option.some.inj ht
  cases hs

theorem no_live_predicate : ¬ Pred.WellFormed P [] ΓR (.lt (.var 0) (.integer 8)) := by
  intro h
  exact reference_not_integer_observation h.sorted.1

theorem guard_cannot_set : ¬ HasTypeC P B Ψ [] [] [] none
    (.app (prim "set") [.loc 0,num 9]) U Eff.empty := by
  intro h
  obtain ⟨r,e,ha,_,hc⟩ := h.primitive_call
    (by intro v hv; rcases List.mem_cons.mp hv with rfl | hv; trivial
        rcases List.mem_cons.mp hv with rfl | hv; trivial; cases hv) rfl (show B.sig "set" = some (sg .refSet) from rfl)
  obtain ⟨_,_,_,_,_,_,hef⟩ := ha.reference_set (by simp [sg,PrimSig.StoreShape,E]) rfl
  subst e
  obtain ⟨atom,hm,_⟩ := hc.1 (.name stateEff (.fixed .top)) (by rfl)
  cases hm


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

theorem update_step : Step P B σ updateSource none updateTarget :=
  Step.E_RefUpdate (q := Closure.pure (.app (prim "update") [.loc 0,identity]))
    (b := "update") (ts := [I]) (s := sg .refUpdate) rfl rfl rfl

theorem update_saved : StateTyE P B σ E updateTarget := by
  have hh := update_start.reference_update assumptions rfl rfl
  exact hh

namespace RefField

def declaration : ConDecl := ⟨"Box",0,[.reference I,I]⟩
def PM : Program := { P with cons := fun c => if c = "Box" ∨ c = "Other" then some declaration else none }
def value : Val := .con "Box" [] [.loc 0,num 3]
def ty : Ty := .data "Box" []
def field0 : FieldRef := ⟨"Box","Box",0,.integer⟩
def field1 : FieldRef := ⟨"Box","Box",1,.integer⟩
def observation : Term := .dataValue "Box" [none,some (.integer 3)]

theorem value_typed : HasTypeV PM B Ψ [] [] [] value ty := by
  refine .V_Con (cd := declaration) rfl rfl ⟨rfl,[],rfl,by intro i a k ht hk; cases ht⟩ ?_ ?_ ?_
  · simp [declaration,Ty.WF,Ty.WFList]
  · exact .cons (.V_LocRef rfl trivial) (.cons (.V_Const trivial) .nil)
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
    Val.toTerm?,Val.toTermSlots,num] at hp
  rcases hp with rfl
  exact ⟨by decide,by trivial⟩


theorem live_field_undeclared : ¬ field0.Declared PM [] [] observation := by
  rintro ⟨ts,cd,a,_,hc,_,_,harg,_,hs⟩
  have he : declaration = cd := Option.some.inj hc
  subst cd
  have he : Ty.reference I = a := Option.some.inj harg
  subst a
  cases hs

def otherAlts : List Alt := [⟨.con "Other" [.wild,.wild],[]⟩]
theorem other_typed : AltsTy PM otherAlts ty [] := by
  refine ⟨by decide,rfl,?_,?_⟩
  · intro alt hh
    cases Option.some.inj hh
    rfl
  · intro alt hm
    cases List.mem_singleton.mp hm
    refine ⟨[],.P_Con (cd := declaration) rfl rfl ?_ (.cons .P_Wild (.cons .P_Wild .nil)),.refl _,rfl⟩
    intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · trivial
    · rcases List.mem_cons.mp ht with rfl | ht; trivial; cases ht

theorem root_exclusion : PathsEvaluated value (excludedTests otherAlts) := by
  apply MatchFacts.excluded_paths_true_of_typing other_typed value_typed rfl
  intro p hp
  change p ∈ [Pred.not (.constructorIs observation "Other")] at hp
  cases List.mem_singleton.mp hp
  exact ⟨by decide,by trivial⟩

end RefField


theorem program_start : StateTyE P B σ E s0 := by
  refine ⟨StoreTy.empty,none,I,I,E,E,StoreOk.empty _ _ _,
    ClosureTy.pure program_typed ie_ann (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) i_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,program,afterNew,afterGet,afterSet,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.empty,Capture.Closed,
      captureSlotsClosed,Capture.values,prim,Ty.WF,num]
  · intro f hf; cases hf
  · intro l c hl; cases hl

theorem snapshot_closure : ClosureTy P B Ψ [] none (.mk capX (.ret (.var 0))) small Eff.empty := by
  have hb : HasTypeC P B Ψ [] ΓX [p] none (.ret (.var 0)) small Eff.empty := by
    apply HasTypeCQ.C_Return
    exact .V_Refine (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I])) rfl rfl
      small_annotation.sorted.2 small_annotation.wf.2.1
      (.hyp (List.mem_append_right _ List.mem_cons_self)) trivial small_annotation.declared.2
  have ha : Ty.Annotation P [] ΓX (.dependentFn (.done small Eff.empty)) :=
    ⟨⟨small_annotation.wf,trivial,rfl⟩,⟨small_annotation.sorted,trivial⟩,⟨small_annotation.declared,trivial⟩⟩
  simpa only [show capX.closeTy small = small from rfl,Capture.closeEff,Eff.subst_values_empty]
    using ClosureTy.capture snapshot_capture hb ha rfl (by intro r hr; cases hr)

theorem pending_guard : GuardBodyTy P B Ψ none (.mk capX (.ret (.var 0))) (.base .boolean) small Eff.empty := by
  have hg : Ty.Annotation P [] ΓX (.refined (.base .boolean) .truth) := by
    constructor <;> simp [Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,
      Ty.Sorted,Pred.Sorted,Ty.Declared,Pred.Declared]
  have hb : HasTypeCQ P B Ψ Qempty [] ΓX [.truth,p] none (.ret (.var 0)) small Eff.empty [] := by
    apply HasTypeCQ.C_Return
    exact .V_Refine (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I])) rfl rfl
      small_annotation.sorted.2 small_annotation.wf.2.1
      (.hyp (List.mem_append_right _ (List.mem_cons_of_mem _ List.mem_cons_self)))
      trivial small_annotation.declared.2
  have hh := GuardBodyTy.mk (p := .truth) (a := small) (e := Eff.empty) snapshot_capture hg hb
    (CaptureLocals.empty _ _ LocalRef.bound) rfl
    ⟨⟨small_annotation.wf,trivial,rfl⟩,⟨small_annotation.sorted,trivial⟩,⟨small_annotation.declared,trivial⟩⟩
    rfl (by intro r hr; cases hr)
  have hgclose : capX.closeTy (.refined (.base .boolean) .truth) = .base .boolean :=
    (Ty.subst_values_of_wf_zero (nr := 0) (nt := 0) (a := .refined (.base .boolean) .truth)
      (by simp [Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn]) _).trans
      (Ty.norm_refined_truth _)
  simpa only [hgclose,Comp.resolveLocals_id,show capX.closeTy small = small from rfl,
    Capture.closeEff,Eff.subst_values_empty] using hh

theorem pending_after_write : StoreOk P B σ Ψ ((μ 3).set 0 (.val (num 9))) ∧
    GuardBodyTy P B Ψ none (.mk capX (.ret (.var 0))) (.base .boolean) small Eff.empty :=
  ⟨snapshot_write.1,pending_guard.store assumptions.values (store 3).wf (.refl _)⟩

def Ψplus : StoreTy := Ψ.put 1 (.ref U)
def μplus : Store := (μ 9).set 1 (.val (.const .unit))
theorem extension_store : StoreOk P B σ Ψplus μplus :=
  (store 9).allocate_reference assumptions.values rfl u_ann rfl (.V_Const trivial) trivial

theorem extension_capture : CaptureOk P B Ψplus none ΓX [p] capX :=
  snapshot_capture.store assumptions.values (store 9).wf (StoreTy.extends_put (by rfl)).preservesNormals

theorem extension_guard : GuardBodyTy P B Ψplus none (.mk capX (.ret (.var 0))) (.base .boolean) small Eff.empty :=
  pending_guard.store assumptions.values (store 9).wf (StoreTy.extends_put (by rfl))

theorem extension_closure : ClosureTy P B Ψplus [] none (.mk capX (.ret (.var 0))) small Eff.empty :=
  snapshot_closure.store assumptions.values (store 9).wf (StoreTy.extends_put (by rfl))

theorem extension_value : HasTypeV P B Ψplus [] [] [] (num 3) small :=
  final_refined.store_extend assumptions.values (store 9).wf (StoreTy.extends_put (by rfl))

-- 非正規形の格納型を StoreOk から排除しない。
def rawUnit : Ty := .refined U .truth
def Ψraw : StoreTy := StoreTy.empty.put 0 (.ref rawUnit)
theorem raw_cell_write : CellOk P B σ Ψraw 0 (.val (.const .unit)) :=
  CellOk.val_write (a := U) rfl rfl rfl (.V_Const trivial) trivial
theorem raw_cell_read : HasTypeV P B Ψraw [] [] [] (.const .unit) U :=
  raw_cell_write.val_read rfl rfl rfl

def snapshotAlts : List Alt := [⟨.const (.integer 3),[]⟩]
def snapshotMatch : Comp := .match (.var 0) [.mk snapshotAlts none (.ret (.var 0))]
theorem snapshot_match_step : Step P B σ (.run (.mk capX snapshotMatch) [] (μ 9)) none
    (.matchRun (num 3) capX [.mk snapshotAlts none (.ret (.var 0))] 0 [] (μ 9)) := .E_Match rfl

theorem snapshot_match_body : Step P B σ
    (.matchRun (num 3) capX [.mk snapshotAlts none (.ret (.var 0))] 0 [] (μ 9)) none
    (.run (.mk capX (.ret (.var 0))) [] (μ 9)) :=
  Step.E_MatchBody (v := num 3) (arms := [.mk snapshotAlts none (.ret (.var 0))])
    (next := 0) (ws := []) rfl rfl

theorem snapshot_matched_fact : PathsEvaluated (num 3) (matchedTests snapshotAlts) := by
  apply MatchFacts.matched_paths_true (show firstAlt (num 3) snapshotAlts = some [] from rfl)
  intro p hp
  change p ∈ [Pred.eq (.integer 3) (.integer 3)] at hp
  cases List.mem_singleton.mp hp
  exact ⟨by decide,by trivial⟩

namespace BoolSnapshot
abbrev T : Ty := .base .boolean
def SB : StoreTy := StoreTy.empty.put 0 (.ref T)
def mb (b : Bool) : Store := Store.empty.set 0 (.val (.const (.boolean b)))
def ctx : Ctx := Ctx.extend [] T
def captured : Capture := Capture.empty.extend (.const (.boolean true))
def cond : Pred := boolCond (.var 0) true
def result : Ty := .refined T cond
def code : Comp := .ite (.var 0) (.ret (.var 0)) (.ret (.const (.boolean true)))

theorem st (b : Bool) : StoreOk P B σ SB (mb b) :=
  (StoreOk.empty _ _ _).allocate_reference assumptions.values rfl ⟨trivial,trivial,trivial⟩ rfl
    (.V_Const trivial) trivial

theorem get_step : Step P B σ
    (.run (Closure.pure (.app (.prim "get" [T] [] []) [.loc 0])) [] (mb true)) none
    (.run (Closure.pure (.ret (.const (.boolean true)))) [] (mb true)) :=
  .E_RefGet (b := "get") (s := sg .refGet) rfl rfl rfl rfl

theorem capture_ok : CaptureOk P B SB none ctx [] captured :=
  (CaptureOk.empty _ _ _ _).extend ⟨trivial,trivial,trivial⟩
    ((st true).reference_read (l := 0) (b := T) (a := T) rfl rfl rfl rfl) trivial

theorem ann {Γ : Ctx} : Ty.Annotation P [] Γ result := by
  constructor <;> simp [result,cond,boolCond,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,
    Term.VarsIn,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.Readable,Ctx.extend,
    Ctx.declarationSelf,Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Comparison.Allowed,Ty.shiftV,T]

theorem branches : HasTypeC P B SB [] ctx [] none code result Eff.empty := by
  refine .C_If (.V_Var rfl (by simp [Ordinary,Ty.core])) rfl (.C_Return ?_) (.C_Return ?_)
  · exact .V_Refine (.V_Var rfl (by simp [Ordinary,Ty.core])) rfl rfl ann.sorted.2 ann.wf.2.1
      (.hyp (List.mem_append_right _ List.mem_cons_self)) trivial ann.declared.2
  · refine .V_Refine (.V_Const trivial) rfl rfl ann.sorted.2 ann.wf.2.1 ?_ trivial ann.declared.2
    exact (CaptureOk.evaluated_fact (p := boolCond (.boolean true) true) (by decide)).weaken (by simp)

theorem if_after_set : StateTyE P B σ E (.run (.mk captured code) [] (mb false)) := by
  have hc := capture_ok.store assumptions.values (st true).wf (.refl _)
  have ha : Ty.Annotation P [] ctx (.dependentFn (.done result Eff.empty)) :=
    ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩
  have hq := ClosureTy.capture hc branches ha rfl (by intro r hr; cases hr)
  have hr := hc.substOk.annotation ann
  have he : captured.closeEff Eff.empty = Eff.empty := Eff.subst_values_empty _
  rw [he] at hq
  refine ⟨SB,none,_,_,E,Eff.empty,st false,hq,?_,.K_Empty (sub_refl E) hr,?_,?_,?_,?_⟩
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu)⟩
  · trivial
  · simp [Closure.ClosedAt,code,captured,Capture.extend,Capture.empty,Capture.Closed,captureSlotsClosed,
      Capture.values,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · intro i c hi
    by_cases hi0 : i = 0
    · subst i; have he := Option.some.inj hi; subst c; trivial
    · simp [mb,Store.set,hi0,Store.empty] at hi

theorem select_old_true : Step P B σ (.run (.mk captured code) [] (mb false)) none
    (.run (.mk captured (.ret (.var 0))) [] (mb false)) ∧
    StateTyE P B σ E (.run (.mk captured (.ret (.var 0))) [] (mb false)) :=
  ⟨.E_IfT rfl,if_after_set.if_true rfl⟩

end BoolSnapshot


theorem new_pair : Step P B σ
    (.run (Closure.pure (.app (prim "new") [num 3])) [] Store.empty) none
    (.run (Closure.pure (.ret (.loc 0))) [] (μ 3)) ∧
    StateTyE P B σ E (.run (Closure.pure (.ret (.loc 0))) [] (μ 3)) :=
  pure_new_start.reference_new_transition assumptions rfl rfl rfl rfl

theorem get_pair : Step P B σ
    (.run (Closure.pure (.app (prim "get") [.loc 0])) [] (μ 3)) none
    (.run (Closure.pure (.ret (num 3))) [] (μ 3)) ∧
    StateTyE P B σ E (.run (Closure.pure (.ret (num 3))) [] (μ 3)) :=
  pure_get_start.reference_get_transition assumptions rfl rfl rfl

theorem update_pair : Step P B σ updateSource none updateTarget ∧ StateTyE P B σ E updateTarget :=
  update_start.reference_update_transition assumptions rfl rfl


private theorem let_effect {P B Ψ Q C Γ Φ R code a e L m n}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .letIn m n) :
    ∃ x f, HasTypeCQ P B Ψ Q C Γ Φ R m x f L ∧ Eff.Covers Γ Φ e f := by
  match h with
  | .C_Let hm _ _ => cases hc; exact ⟨_,_,hm,.refl _ _ _⟩
  | .C_Sub hh _ he _ _ _ | .C_Eff hh he =>
    obtain ⟨x,f,hm,hf⟩ := let_effect hh hc
    exact ⟨x,f,hm,he.trans hf⟩
  | .C_Normal hh => exact let_effect hh hc
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_App .. | .C_DependentApp .. |
    .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

theorem guard_with_set_untyped : ¬ HasTypeC P B Ψ [] [] [] none
    (.letIn (.app (prim "set") [.loc 0,num 9]) (.ret (.const (.boolean true))))
    (.base .boolean) Eff.empty := by
  intro h
  obtain ⟨x,e,hs,hcov⟩ := let_effect h rfl
  obtain ⟨r,f,ha,_,hc⟩ := hs.primitive_call
    (by intro v hv; rcases List.mem_cons.mp hv with rfl | hv; trivial
        rcases List.mem_cons.mp hv with rfl | hv; trivial; cases hv) rfl
    (show B.sig "set" = some (sg .refSet) from rfl)
  obtain ⟨_,_,_,_,_,_,he⟩ := ha.reference_set (by simp [sg,PrimSig.StoreShape,E]) rfl
  subst f
  obtain ⟨atom,hm,_⟩ := (hcov.trans hc).1 (.name stateEff (.fixed .top)) (by rfl)
  cases hm

def matchEq : Pred := .eq (.var 0) (.integer 3)
def exactly3 : Ty := .refined I matchEq

theorem match_snapshot_capture : CaptureOk P B Ψ none ΓX [matchEq] capX := by
  have hp : Pred.WellFormed P [] ΓX matchEq := by
    constructor <;> simp [matchEq,ΓX,ΓR,Ctx.extend,Pred.WF,Pred.VarsIn,Term.VarsIn,
      Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.declarationSelf,
      Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Ty.shiftV,I,Pred.Declared,Term.Declared]
  apply capturedX.addEvaluated hp
  exact snapshot_matched_fact (.eq (.integer 3) (.integer 3)) List.mem_cons_self

theorem match_body_reads_snapshot : HasTypeC P B Ψ [] ΓX [matchEq] none
    (.ret (.var 0)) exactly3 Eff.empty := by
  have ha : Ty.Annotation P [] ΓX exactly3 := by
    constructor <;> simp [exactly3,matchEq,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,
      Term.VarsIn,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.Readable,
      Ctx.declarationSelf,Ctx.extend,Ty.shiftV,I,Ty.HasSort,Ty.sort?,Ordinary,
      Ty.Declared,Pred.Declared,Term.Declared]
  exact .C_Return (.V_Refine (.V_Var rfl (by simp [Ordinary,Ty.core,Ty.shiftV,I])) rfl rfl
    ha.sorted.2 ha.wf.2.1 (.hyp (List.mem_append_right _ List.mem_cons_self)) trivial ha.declared.2)

theorem set_pair : Step P B σ
    (.run (Closure.pure (.app (prim "set") [.loc 0,num 9])) [] (μ 3)) none
    (.run (Closure.pure (.ret (.const .unit))) [] (μ 9)) ∧
    StateTyE P B σ E (.run (Closure.pure (.ret (.const .unit))) [] (μ 9)) := by
  have hh := pure_set_start.reference_set_transition assumptions rfl rfl rfl
  have hm : (μ 3).set 0 (.val (num 9)) = μ 9 := by funext i; simp [μ,Store.set]; split <;> rfl
  simpa only [hm,prim] using hh

/-! 不変性の負例 -/
theorem small_ne : I.norm ≠ small.norm := by
  intro h
  have hp := congrArg Ty.refinementPredicates h
  simp only [Ty.predicates_norm] at hp
  simp [small,I,Ty.refinementPredicates,Pred.conjuncts] at hp

theorem le_strengthen_fails {Γ Φ} : ¬ Ty.LeQ Γ Φ (.reference I) (.reference small) := by
  intro h
  obtain ⟨x,hx,he⟩ := h.refCore_right rfl
  cases Option.some.inj hx
  exact small_ne he

theorem le_weaken_fails {Γ Φ} : ¬ Ty.LeQ Γ Φ (.reference small) (.reference I) := by
  intro h
  obtain ⟨x,hx,he⟩ := h.refCore_right rfl
  cases Option.some.inj hx
  exact small_ne he.symm

-- 矛盾した Φ の下でも内容型を変えられない。
theorem le_under_false : ¬ Ty.LeQ [] [.falsity] (.reference I) (.reference small) :=
  le_strengthen_fails

theorem loc_not_small : ¬ HasTypeV P B Ψ [] [] [] (.loc 0) (.reference small) := by
  intro h
  obtain ⟨l,b,hv,hl,he⟩ := h.canonical_ref rfl
  cases Val.loc.inj hv
  have hb : LocTy.ref I = LocTy.ref b := Option.some.inj hl
  cases LocTy.ref.inj hb
  exact small_ne he

theorem small_normal : small.Normal := rfl

def Ψs : StoreTy := StoreTy.empty.put 0 (.ref small)

theorem nine_not_small {store} : ¬ HasTypeV P B store [] [] [] (num 9) small := by
  intro h
  have hf := h.facts rfl (.lt (.var 0) (.integer 8)) (by simp [small,Ty.assume,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  have hh := hf.sound (fun _ => none) (by intro q hq; cases hq)
  change false = true at hh
  cases hh

/-- 篩の内容型のセルへ違反する値を置いた CellOk は作れない。 -/
theorem cell_rejects_nine : ¬ CellOk P B σ Ψs 0 (.val (num 9)) := by
  intro h
  exact nine_not_small (h.val_read (a := small) (b := small) rfl rfl
    small_normal)

/-- Reference の変数はどの sort でも読めない（別名を含む）。 -/
theorem reference_var_no_sort (s) : ¬ Term.HasSort ΓX (.var 1) s := by
  rintro ⟨_,t,ht,hs⟩
  cases Option.some.inj ht
  cases hs

/-- 篩の内容型のセルは StoreOk に載り、読み出しは small を返し、適合する書込みは通る。 -/
def μs : Store := Store.empty.set 0 (.val (num 3))
theorem store_small : StoreOk P B σ Ψs μs :=
  (StoreOk.empty P B σ).allocate_reference assumptions.values rfl small_annotation small_normal
    (by
      refine .V_Refine (.V_Const trivial) rfl rfl small_annotation.sorted.2 small_annotation.wf.2.1
        ?_ trivial small_annotation.declared.2
      exact CaptureOk.evaluated_fact (by decide)) trivial
theorem read_small : HasTypeV P B Ψs [] [] [] (num 3) small :=
  store_small.reference_read (l := 0) (a := small) (b := small) rfl rfl rfl small_normal

/-- 非正規形の型引数でも、遷移が読む正規化像に対して補助入力を作れる。 -/
theorem raw_primitives : ReferencePrimitives P B [.refined I .truth] :=
  assumptions.reference_primitives rfl i_ann rfl (by simp [Ordinary,Ty.core,Ty.norm,I]) trivial


-- RV-L00b.14c t3 と同じ表。get の kind だけを constructor 1 にする。
def t3_sg (k : PrimKind) : PrimSig :=
  match k with
  | .refNew => ⟨[{}],0,["value"],[.tvar 0],.reference (.tvar 0),E,fun _ _ => True,k,none,[],.untargeted⟩
  | .refGet => ⟨[{kind := .constructor 1}],0,["reference"],[.reference (.tvar 0)],.tvar 0,E,fun _ _ => True,k,none,[],.untargeted⟩
  | .refSet => ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,E,fun _ _ => True,k,none,[],.untargeted⟩
  | _ => ⟨[{}],0,["reference","f"],[.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty],
      U,E,fun _ _ => True,k,none,[],.untargeted⟩
def t3_B : Builtins :=
  { sig := fun b => if b = "new" then some (t3_sg .refNew) else
      if b = "get" then some (t3_sg .refGet) else if b = "set" then some (t3_sg .refSet) else
      if b = "update" then some (t3_sg .refUpdate) else none,
    delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False,
    releaseResponse := fun _ _ => True, isResource := fun _ => false,
    effects := fun _ => none, sat := fun _ _ _ => True, refGet := "get",refSet := "set" }

theorem t3_not_core : ¬ Builtins.CoreAssumptions P t3_B := by
  intro h
  have hs := h.store_shape "get" (t3_sg .refGet) rfl (by decide)
  simp [PrimSig.StoreShape,t3_sg,E] at hs


theorem small_primitives : ReferencePrimitives P B [small] :=
  assumptions.reference_primitives (a := small) rfl small_annotation small_normal
    (by simp [small,I,Ordinary,Ty.core,Ty.norm]) (by simp [small,I,Ty.HasKind,Ty.NotContCore])

theorem get_small_head : HasTypeV P B Ψs [] [] [] (.prim B.refGet [small] [] [])
    (.fn ["reference"] [.reference small] small E) := by
  obtain ⟨a,he,hg,_⟩ := small_primitives
  have he' : a = small := (List.cons.inj he).1.symm
  subst a
  exact hg.weaken_empty assumptions.values

theorem set_small_head : HasTypeV P B Ψs [] [] [] (.prim B.refSet [small] [] [])
    (.fn ["reference","value"] [.reference small,small] U E) := by
  obtain ⟨a,he,_,hs⟩ := small_primitives
  have he' : a = small := (List.cons.inj he).1.symm
  subst a
  exact hs.weaken_empty assumptions.values

theorem small_state_annotation : Ty.Annotation P [] [] (.dependentFn (.done small E)) :=
  ⟨⟨small_annotation.wf,trivial,rfl⟩,⟨small_annotation.sorted,trivial⟩,
    ⟨small_annotation.declared,trivial⟩⟩

theorem small_loc : HasTypeV P B Ψs [] [] [] (.loc 0) (.reference small) :=
  .V_LocRef rfl small_annotation.declared

theorem small_get_start : StateTyE P B σ E
    (.run (Closure.pure (.app (.prim B.refGet [small] [] []) [.loc 0])) [] μs) := by
  refine ⟨Ψs,none,small,small,E,E,store_small,
    ClosureTy.pure (.C_App get_small_head (.cons small_loc .nil)) small_state_annotation
      (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) small_annotation,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values]
    exact (small_annotation (Γ := [])).wf
  · intro f hf; cases hf
  · exact μ_closed 3

theorem small_get_pair : Step P B σ
    (.run (Closure.pure (.app (.prim B.refGet [small] [] []) [.loc 0])) [] μs) none
    (.run (Closure.pure (.ret (num 3))) [] μs) ∧
    StateTyE P B σ E (.run (Closure.pure (.ret (num 3))) [] μs) :=
  small_get_start.reference_get_transition assumptions rfl rfl rfl

theorem small_set_start : StateTyE P B σ E
    (.run (Closure.pure (.app (.prim B.refSet [small] [] []) [.loc 0,num 3])) [] μs) := by
  refine ⟨Ψs,none,U,U,E,E,store_small,
    ClosureTy.pure (.C_App set_small_head (.cons small_loc (.cons read_small .nil))) ue_ann
      (by intro r hr; cases hr) rfl (by intro r hr; cases hr),
    sub_refl E,.K_Empty (sub_refl E) u_ann,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,Closure.pure,Capture.empty,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Capture.values,num]
    exact (small_annotation (Γ := [])).wf
  · intro f hf; cases hf
  · exact μ_closed 3

theorem small_set_pair : Step P B σ
    (.run (Closure.pure (.app (.prim B.refSet [small] [] []) [.loc 0,num 3])) [] μs) none
    (.run (Closure.pure (.ret (.const .unit))) [] (μs.set 0 (.val (num 3)))) ∧
    StateTyE P B σ E (.run (Closure.pure (.ret (.const .unit))) [] (μs.set 0 (.val (num 3)))) :=
  small_set_start.reference_set_transition assumptions rfl rfl rfl


-- 旧3モデルの実表の存在と、型パラメータを移したときの kind を照合する。
theorem model_get_contract :
    ∃ s, (Benitoite.Release.Model.builtins).sig (Benitoite.Release.Model.builtins).refGet = some s ∧
      s.kind = .refGet ∧ (s.tparams.map embedTParam).map TParamDecl.kind = [.value] :=
  ⟨Benitoite.Release.Model.refGetSig,rfl,rfl,rfl⟩

theorem model_set_contract :
    ∃ s, (Benitoite.Release.Model.builtins).sig (Benitoite.Release.Model.builtins).refSet = some s ∧
      s.kind = .refSet ∧ (s.tparams.map embedTParam).map TParamDecl.kind = [.value] :=
  ⟨Benitoite.Release.Model.refSetSig,rfl,rfl,rfl⟩

theorem modeltargets_get_contract (pat : String → Option Benitoite.Scope.Domain.Range) (tgt : String → Option Benitoite.Scope.Domain.Target) :
    ∃ s, (Benitoite.Release.ModelTargets.builtins pat tgt).sig (Benitoite.Release.ModelTargets.builtins pat tgt).refGet = some s ∧
      s.kind = .refGet ∧ (s.tparams.map embedTParam).map TParamDecl.kind = [.value] :=
  ⟨Benitoite.Release.Model.refGetSig,rfl,rfl,rfl⟩

theorem modeltargets_set_contract (pat : String → Option Benitoite.Scope.Domain.Range) (tgt : String → Option Benitoite.Scope.Domain.Target) :
    ∃ s, (Benitoite.Release.ModelTargets.builtins pat tgt).sig (Benitoite.Release.ModelTargets.builtins pat tgt).refSet = some s ∧
      s.kind = .refSet ∧ (s.tparams.map embedTParam).map TParamDecl.kind = [.value] :=
  ⟨Benitoite.Release.Model.refSetSig,rfl,rfl,rfl⟩

theorem modelhttp_get_contract (hostPat : String → Int → Int → Option Benitoite.Scope.Domain.Range) (reqTarget : Benitoite.Release.Val → Option Benitoite.Scope.Domain.Target) :
    ∃ s, (Benitoite.Release.ModelHttp.builtins hostPat reqTarget).sig (Benitoite.Release.ModelHttp.builtins hostPat reqTarget).refGet = some s ∧
      s.kind = .refGet ∧ (s.tparams.map embedTParam).map TParamDecl.kind = [.value] :=
  ⟨Benitoite.Release.Model.refGetSig,rfl,rfl,rfl⟩

theorem modelhttp_set_contract (hostPat : String → Int → Int → Option Benitoite.Scope.Domain.Range) (reqTarget : Benitoite.Release.Val → Option Benitoite.Scope.Domain.Target) :
    ∃ s, (Benitoite.Release.ModelHttp.builtins hostPat reqTarget).sig (Benitoite.Release.ModelHttp.builtins hostPat reqTarget).refSet = some s ∧
      s.kind = .refSet ∧ (s.tparams.map embedTParam).map TParamDecl.kind = [.value] :=
  ⟨Benitoite.Release.Model.refSetSig,rfl,rfl,rfl⟩


end
end Benitoite.Release.Refinement.ReferenceBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "Benitoite.Release.Refinement.ReferenceBoundary").length > 1
    then some name else none).mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
