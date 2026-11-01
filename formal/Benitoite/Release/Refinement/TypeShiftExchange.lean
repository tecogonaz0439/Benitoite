import Benitoite.Release.Refinement.MethodArguments
import Benitoite.Release.Refinement.TypeShiftContracts
import Benitoite.Release.Refinement.ValueRenameAlgebra

namespace Benitoite.Release.Refinement

mutual
  theorem Val.toTerm_shiftEAt (v : Val) (k c : Nat) : (v.shiftEAt k c).toTerm?=v.toTerm? := by
    cases v
    case const con => cases con <;> rfl
    all_goals simp only [Val.shiftEAt,Val.toTerm?,Val.toTermSlots_shiftEAt]
  theorem Val.toTermSlots_shiftEAt (vs : List Val) (k c : Nat) :
      Val.toTermSlots (Val.shiftEListAt k c vs)=Val.toTermSlots vs := by
    cases vs <;> simp only [Val.shiftEListAt,Val.toTermSlots,Val.toTerm_shiftEAt,Val.toTermSlots_shiftEAt]
end

theorem shiftTypes_renameTy (a : Ty) (k c : Nat) (ξ : Nat → Nat) :
    shiftTypes k c (renameTy ξ a)=renameTy ξ (shiftTypes k c a) := by
  simp only [renameTy_eq_rawSubstV,shiftTypes_substV]

theorem shiftRowsTypes_renameEff (e : Eff) (k c : Nat) (ξ : Nat → Nat) :
    shiftRowsTypes k c (renameEff ξ e)=renameEff ξ (shiftRowsTypes k c e) := by
  simp only [renameEff_eq_rawSubstV,shiftRowsTypes_substV]

theorem shiftTelTypes_rename (t : Tel) (k c : Nat) (ξ : Nat → Nat) :
    shiftTelTypes k c (Tel.rawBind (renEnv ξ) t)=Tel.rawBind (renEnv ξ) (shiftTelTypes k c t) := by
  simp only [←Tel.rawSubstV_eq_rawBind,renEnv,shiftTelTypes_substV]

theorem telBinders_shiftTypes (t : Tel) (k c : Nat) : telBinders (shiftTelTypes k c t)=telBinders t := by
  cases t <;> simp [shiftTelTypes,telBinders,telBinders_shiftTypes]

theorem shiftKindE_rename (b : BuilderKind) (k c : Nat) (ξ : Nat → Nat) :
    shiftKindE k c (renameKind ξ b)=renameKind ξ (shiftKindE k c b) := by
  cases b <;> simp [shiftKindE,renameKind,shiftTypes_renameTy]

mutual
  theorem Val.shiftEAt_rename (v : Val) (k c : Nat) (ξ : Nat → Nat) :
      (v.rename ξ).shiftEAt k c=(v.shiftEAt k c).rename ξ := by
    cases v <;> simp only [Val.rename,Val.shiftEAt,Val.shiftEAt_rename,Val.shiftEListAt_rename,
      Comp.shiftEAt_rename,List.map_map,Function.comp_def,shiftTypes_renameTy,shiftRowsTypes_renameEff,
      shiftTelTypes_rename,telBinders_shiftTypes,List.length_map]
  theorem Val.shiftEListAt_rename (vs : List Val) (k c : Nat) (ξ : Nat → Nat) :
      Val.shiftEListAt k c (Val.renameList ξ vs)=Val.renameList ξ (Val.shiftEListAt k c vs) := by
    cases vs <;> simp only [Val.renameList,Val.shiftEListAt,Val.shiftEAt_rename,Val.shiftEListAt_rename]
  theorem Comp.shiftEAt_rename (m : Comp) (k c : Nat) (ξ : Nat → Nat) :
      (m.rename ξ).shiftEAt k c=(m.shiftEAt k c).rename ξ := by
    cases m
    case checkAt _ _ _ bs _ _ _ =>
      cases bs <;> simp only [Comp.rename,Comp.shiftEAt,Val.shiftEAt_rename,shiftTypes_renameTy]
    all_goals simp only [Comp.rename,Comp.shiftEAt,Val.shiftEAt_rename,Val.shiftEListAt_rename,
      Comp.shiftEAt_rename,Arm.shiftEListAt_rename,Clause.shiftEListAt_rename,List.map_map,Function.comp_def,
      shiftTypes_renameTy,shiftRowsTypes_renameEff,shiftKindE_rename]
  theorem Arm.shiftEListAt_rename (arms : List Arm) (k c : Nat) (ξ : Nat → Nat) :
      Arm.shiftEListAt k c (Arm.renameList ξ arms)=Arm.renameList ξ (Arm.shiftEListAt k c arms) := by
    cases arms with
    | nil => rfl
    | cons arm arms => cases arm with
      | mk alts guard body => cases guard <;> simp only [Arm.renameList,Arm.shiftEListAt,
        Comp.shiftEAt_rename,Arm.shiftEListAt_rename]
  theorem Clause.shiftEListAt_rename (cs : List Clause) (k c : Nat) (ξ : Nat → Nat) :
      Clause.shiftEListAt k c (Clause.renameList ξ cs)=Clause.renameList ξ (Clause.shiftEListAt k c cs) := by
    cases cs with
    | nil => rfl
    | cons cl cs => cases cl <;> simp only [Clause.renameList,Clause.shiftEListAt,Comp.shiftEAt_rename,
      Clause.shiftEListAt_rename,shiftTypes_renameTy]
end

theorem upSubst_shiftEAt (ν : Nat → Val) (n k c : Nat) :
    (fun i => (upSubst n ν i).shiftEAt k c)=upSubst n (fun i => (ν i).shiftEAt k c) := by
  funext i
  unfold upSubst
  split <;> simp only [Val.shiftEAt,Val.shiftEAt_rename]

theorem substTyValues_shiftEAt (a : Ty) (ν : Nat → Val) (k c : Nat) :
    substTyValues (fun i => (ν i).shiftEAt k c) (shiftTypes k c a)=shiftTypes k c (substTyValues ν a) := by
  simp only [substTyValues,Ty.bind,valEnv,Val.toTerm_shiftEAt,←Ty.rawSubstV_eq_rawBind,
    shiftTypes_substV,Ty.norm_shiftTypes]

theorem substEffValues_shiftEAt (e : Eff) (ν : Nat → Val) (k c : Nat) :
    substEffValues (fun i => (ν i).shiftEAt k c) (shiftRowsTypes k c e)=shiftRowsTypes k c (substEffValues ν e) := by
  simp only [substEffValues,Eff.bind,valEnv,Val.toTerm_shiftEAt,←Eff.rawSubstV_eq_rawBind,
    shiftRowsTypes_substV,Eff.norm_shiftTypes]

theorem shiftKindE_contents (b : BuilderKind) (k c : Nat) :
    (shiftKindE k c b).contents=shiftTypes k c b.contents := by cases b <;> rfl

theorem shiftKindE_result (op : BuilderOp) (b : BuilderKind) (k c : Nat) :
    op.resultType (shiftKindE k c b)=shiftTypes k c (op.resultType b) := by
  cases op <;> simp [BuilderOp.resultType,shiftTypes,shiftKindE_contents]

theorem shiftKindE_parameters (op : BuilderOp) (b : BuilderKind) (k c : Nat) :
    op.parameters (shiftKindE k c b)=(op.parameters b).map (shiftTypes k c) := by
  cases op <;> cases b <;> rfl

theorem TypeCtxMap.methodRows {P C C' Γ Δ ms Q es k c} (hm : TypeCtxMap k c Γ Δ)
    (hn : C'.length=C.length+k) (he : RowAnnotations P C Γ es)
    (ha : MethodRowsAdmissible C Γ.length Q ms es) :
    MethodRowsAdmissible C' Δ.length Q ms (es.map (shiftRowsTypes k c)) := by
  refine ⟨by simpa using ha.1,?_,by simpa using ha.2.2.1,by simpa using ha.2.2.2.1,?_⟩
  · intro f hf
    obtain ⟨e,he',rfl⟩ := List.mem_map.mp hf
    simpa only [hn, hm.length] using Eff.wf_shiftTypes (ha.2.1 e he') k c
  · exact ha.2.2.2.2.map _ (fun _ h => h.shiftTypes k c) (fun _ => rfl)

theorem unguardedPats_shiftEAt (arms : List Arm) (k c : Nat) :
    unguardedPats (Arm.shiftEListAt k c arms)=unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih => cases arm with
    | mk alts guard body => cases guard <;> simp [Arm.shiftEListAt,unguardedPats,ih]

theorem Tel.open_shiftTypes (t : Tel) (v : Val) (k c : Nat) :
    Tel.bind (Tel.argumentsEnv (v.shiftEAt k c)) (shiftTelTypes k c t)=
      shiftTelTypes k c (Tel.bind (Tel.argumentsEnv v) t) := by
  simp only [argumentsEnv_eq,Val.toTerm_shiftEAt,Tel.bind,SubstEnv.valuesOnly,
    ←Tel.rawSubstV_eq_rawBind,shiftTelTypes_substV,Tel.norm_shiftTypes]

theorem Tel.arguments_typeShift (t : Tel) (vs : List Val) (k c : Nat) :
    Tel.arguments (shiftTelTypes k c t) (Val.shiftEListAt k c vs)=
      (Tel.arguments t vs).map (fun (as,r,e) => (as.map (shiftTypes k c),shiftTypes k c r,shiftRowsTypes k c e)) := by
  induction vs generalizing t with
  | nil => cases t <;> simp only [Tel.arguments,shiftTelTypes,Val.shiftEListAt,Ty.norm_shiftTypes,
      Eff.norm_shiftTypes,List.map_nil,Option.map_none,Option.map_some]
  | cons v vs ih => cases t with
    | done r e => simp only [Tel.arguments,shiftTelTypes,Val.shiftEListAt,Option.map_none]
    | param n a t =>
      simp only [shiftTelTypes,Val.shiftEListAt,Tel.arguments]
      rw [Tel.open_shiftTypes,ih]
      simp only [Option.map_map]
      congr 1
      funext x
      obtain ⟨as,r,e⟩ := x
      simp only [Function.comp_def,List.map_cons,Ty.norm_shiftTypes]

theorem Tel.arguments_shiftTypes {t vs as r e} (h : Tel.arguments t vs=some (as,r,e)) (k c : Nat) :
    Tel.arguments (shiftTelTypes k c t) (Val.shiftEListAt k c vs)=
      some (as.map (shiftTypes k c),shiftTypes k c r,shiftRowsTypes k c e) := by
  rw [Tel.arguments_typeShift,h]; rfl

end Benitoite.Release.Refinement
