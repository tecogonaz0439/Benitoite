import Benitoite.Release.Refinement.TypeShiftExchange

namespace Benitoite.Release.Refinement
open Order

theorem Ty.shiftV_fixed_before {nr nt nv a} (hw : Ty.WF nr nt nv a) (k c : Nat) (hc : nv≤c) :
    a.shiftV k c=a := by
  rw [Ty.shiftV_eq_renameTy,renameTy_eq_rawSubstV]
  apply Ty.rawSubstV_fixed hw
  intro i hi
  simp [shiftIndex,show i<c by omega]

theorem Ty.subst_up_fixed {nr nt nv a} (hw : Ty.WF nr nt nv a) (ν : Nat → Val) :
    substTyValues (upSubst nv ν) a=a.norm := by
  simp only [substTyValues,Ty.bind,valEnv,←Ty.rawSubstV_eq_rawBind]
  rw [Ty.rawSubstV_fixed hw _ (by intro i hi; simp [upSubst,hi,Val.toTerm?])]

def binderRenames (k c : Nat) : List Ty → List Ty
  | [] => []
  | a::as => a.shiftV k c::binderRenames k (c+1) as

@[simp] theorem binderRenames_length (ps : List Ty) (k c : Nat) :
    (binderRenames k c ps).length=ps.length := by
  induction ps generalizing c <;> simp_all [binderRenames]

theorem binderRenames_fixed {nt n ps} (hw : BinderTypes.LocalWF nt n ps) (k c : Nat) :
    binderRenames k (c+n) ps=ps := by
  induction ps generalizing n c with
  | nil => rfl
  | cons a as ih =>
    simp only [binderRenames]
    rw [Ty.shiftV_fixed_before hw.1 k _ (by omega)]
    congr 1
    simpa only [Nat.add_assoc] using ih hw.2 c

theorem binderImages_fixed {nt n ps} (hw : BinderTypes.LocalWF nt n ps) (ν : Nat → Val) :
    binderImages (upSubst n ν) ps=ps.map Ty.norm := by
  induction ps generalizing n ν with
  | nil => rfl
  | cons a as ih =>
    simp only [binderImages, List.map_cons, Ty.subst_up_fixed hw.1,upSubst_add]
    exact congrArg (List.cons a.norm) (ih hw.2 ν)

theorem Ty.shiftTypes_fixed_before {nr nt nv a} (hw : Ty.WF nr nt nv a) (k c : Nat) (hc : nt≤c) :
    shiftTypes k c a=a := by
  have hh := Ty.rawBind_agrees (θ := .shiftTypes k c) (τ := renEnv id) hw
    ⟨by intro i hi; simp [SubstEnv.shiftTypes,renEnv,shiftIndex,show i<c by omega],rfl,rfl,rfl⟩
  simpa only [Ty.rawBind_shiftTypes,Ty.rawBind_id] using hh

theorem BinderTypes.LocalWF.shiftTypes_fixed {nt n ps} (hw : BinderTypes.LocalWF nt n ps) (k c : Nat) (hc : nt≤c) :
    ps.map (shiftTypes k c)=ps := by
  induction ps generalizing n with
  | nil => rfl
  | cons a as ih => simp only [List.map_cons,Ty.shiftTypes_fixed_before hw.1 k c hc,ih hw.2]

mutual
  theorem Ty.rawRenameTypes_comp (a : Ty) (ρ τ : Nat → Nat) :
      (a.rawRenameTypes ρ).rawRenameTypes τ=a.rawRenameTypes (fun i => τ (ρ i)) := by
    cases a <;> simp only [Ty.rawRenameTypes,Ty.rawRenameTypes_comp,rawRenameTypesList_comp,
      rawRenameRowsTypes_comp,rawRenameTelTypes_comp]
  theorem rawRenameTypesList_comp (as : List Ty) (ρ τ : Nat → Nat) :
      rawRenameTypesList τ (rawRenameTypesList ρ as)=rawRenameTypesList (fun i => τ (ρ i)) as := by
    cases as <;> simp only [rawRenameTypesList,Ty.rawRenameTypes_comp,rawRenameTypesList_comp]
  theorem rawRenameRowsTypes_comp (e : Eff) (ρ τ : Nat → Nat) :
      rawRenameRowsTypes τ (rawRenameRowsTypes ρ e)=rawRenameRowsTypes (fun i => τ (ρ i)) e := by
    cases e; simp only [rawRenameRowsTypes,rawRenameTypesList_comp]
  theorem rawRenameTelTypes_comp (t : Tel) (ρ τ : Nat → Nat) :
      rawRenameTelTypes τ (rawRenameTelTypes ρ t)=rawRenameTelTypes (fun i => τ (ρ i)) t := by
    cases t <;> simp only [rawRenameTelTypes,Ty.rawRenameTypes_comp,rawRenameRowsTypes_comp,rawRenameTelTypes_comp]
end

private theorem typeIndices_comm (n k c : Nat) :
    (fun i => shiftIndex k (c+n) (shiftIndex n 0 i))=(fun i => shiftIndex n 0 (shiftIndex k c i)) := by
  funext i
  simp only [shiftIndex,Nat.not_lt_zero,↓reduceIte]
  split <;> split <;> omega

theorem shiftTypes_comm (a : Ty) (n k c : Nat) :
    shiftTypes k (c+n) (shiftTypes n 0 a)=shiftTypes n 0 (shiftTypes k c a) := by
  simp only [←Ty.rawRenameTypes_shift,Ty.rawRenameTypes_comp,typeIndices_comm]

theorem shiftRowsTypes_comm (e : Eff) (n k c : Nat) :
    shiftRowsTypes k (c+n) (shiftRowsTypes n 0 e)=shiftRowsTypes n 0 (shiftRowsTypes k c e) := by
  simp only [←rawRenameRowsTypes_shift,rawRenameRowsTypes_comp,typeIndices_comm]

theorem Eff.shiftV_union (e f : Eff) (k c : Nat) :
    (Eff.union e f).shiftV k c=Eff.union (e.shiftV k c) (f.shiftV k c) := by
  cases e; cases f
  simp only [Eff.union,←Eff.norm_shiftV,Eff.shiftV,Eff.test,Eff.atoms,Eff.fails,shiftVTys_eq_map,List.map_append]

theorem Eff.shiftTypes_union (e f : Eff) (k c : Nat) :
    shiftRowsTypes k c (Eff.union e f)=Eff.union (shiftRowsTypes k c e) (shiftRowsTypes k c f) := by
  cases e; cases f
  simp only [Eff.union,←Eff.norm_shiftTypes,shiftRowsTypes,Eff.test,Eff.atoms,Eff.fails,shiftTypesList_eq_map,List.map_append]

theorem ClauseSig.same_atoms {P B e f o sg} (h : ClauseSig P B e o sg) (he : f.atoms=e.atoms) :
    ClauseSig P B f o sg := by
  obtain ⟨S,hS,hs,hr⟩ := h
  refine ⟨S,?_,hs,hr⟩
  rcases hS with hS|⟨b,s,l,ho,hb,hl,hr⟩
  · exact Or.inl hS
  · exact Or.inr ⟨b,s,l,ho,hb,hl,by simpa only [Eff.ClauseRangeIs,Eff.mem,Eff.test,he] using hr⟩

theorem ClauseSig.shift_values {P B e o sg} (h : ClauseSig P B e o sg) (k c : Nat) :
    ClauseSig P B (e.shiftV k c) o sg := h.same_atoms (by cases e; rfl)

theorem ClauseSig.shift_types {P B e o sg} (h : ClauseSig P B e o sg) (k c : Nat) :
    ClauseSig P B (shiftRowsTypes k c e) o sg := h.same_atoms (by cases e; rfl)

theorem substEffValues_atoms (e : Eff) (ν : Nat → Val) : (substEffValues ν e).atoms=e.atoms := by
  cases e
  simp only [substEffValues,Eff.bind,Eff.rawBind,valEnv,instAtoms_nil,substAtoms_nil,Eff.norm,Eff.atoms]

theorem ClauseSig.subst_values {P B e o sg} (h : ClauseSig P B e o sg) (ν : Nat → Val) :
    ClauseSig P B (substEffValues ν e) o sg := h.same_atoms (substEffValues_atoms e ν)

theorem handles_rename (cs : List Clause) (ξ : Nat → Nat) (o : OpRef) :
    handles (Clause.renameList ξ cs) o=handles cs o := by
  induction cs with
  | nil => rfl
  | cons cl cs ih => simp only [handles,Clause.op] at ih; cases cl <;> simp [Clause.renameList,handles,Clause.op,ih]

theorem handles_subst (cs : List Clause) (ν : Nat → Val) (ρ : Nat → LocalRef) (o : OpRef) :
    handles (Clause.substList ν cs ρ) o=handles cs o := by
  induction cs with
  | nil => rfl
  | cons cl cs ih => simp only [handles,Clause.op] at ih; cases cl <;> simp [Clause.substList,handles,Clause.op,ih]

theorem handles_shiftEAt (cs : List Clause) (k c : Nat) (o : OpRef) :
    handles (Clause.shiftEListAt k c cs) o=handles cs o := by
  induction cs with
  | nil => rfl
  | cons cl cs ih => simp only [handles,Clause.op] at ih; cases cl <;> simp [Clause.shiftEListAt,handles,Clause.op,ih]

theorem handled_rename (P B cs ξ) : handled P B (Clause.renameList ξ cs)=handled P B cs := by
  simp only [handled,funext (handles_rename cs ξ)]

theorem handled_subst (P B cs ν ρ) : handled P B (Clause.substList ν cs ρ)=handled P B cs := by
  simp only [handled,funext (handles_subst cs ν ρ)]

theorem handled_shiftEAt (P B cs k c) : handled P B (Clause.shiftEListAt k c cs)=handled P B cs := by
  simp only [handled,funext (handles_shiftEAt cs k c)]

theorem handled_shift_values (P B cs k c) : (handled P B cs).shiftV k c=handled P B cs := rfl

theorem handled_shift_types (P B cs k c) : shiftRowsTypes k c (handled P B cs)=handled P B cs := rfl

private theorem shift_var_aux {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) {Ψ' C' Δ k c} (hn : C'.length=C.length+k)
    (hm : TypeCtxMap k c Γ Δ) (hC : TypeParamRenaming C C' (shiftIndex k c)) : ∀ i,v=.var i → HasTypeVQ P B Ψ' Q C' Δ Φ (.var i) (shiftTypes k c a) := by
  match h with
  | .V_Var hi ho => intro i he; cases he; exact .V_Var (hm.lookup _ _ hi) ((Ty.ordinary_shiftTypes _ _ _).mpr ho)
  | .V_Normal hv =>
    intro i he
    simpa only [Ty.norm_shiftTypes] using (shift_var_aux hv hn hm hC i he).V_Normal
  | .V_Sub hv hl hw hs hd =>
    intro i he
    exact .V_Sub (shift_var_aux hv hn hm hC i he) (hl.shiftTypes hm)
      (by simpa only [hn,hm.length] using Ty.wf_shiftTypes hw k c) (Ty.sorted_shiftTypes hs hm) (hd.shiftTypes hm hC)
  | .V_Refine hv hi ht hs hw he hda hdp =>
    intro i hvEq
    have hh := shift_var_aux (Ψ' := Ψ') hv hn hm hC i hvEq
    cases hvEq
    exact .V_Refine hh ((Ty.hasSort_shiftTypes _ _ _ _).mpr hi) ht (Pred.sorted_shiftTypes hs hm)
      (by simpa only [hm.length] using hw) (hm.entails he) (hda.shiftTypes hm hC) (hdp.shiftTypes hm)
  | .V_Const _ | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ | .V_Fun _ _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _
  | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ | .V_PathBases _
  | .V_ScopePattern _ _ _ | .V_Checked _ _ _ | .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ | .V_AtError _
  | .V_Map _ _ _ _ _ _ | .V_Set _ _ _ | .V_Dict _ _ _ _ _ _ _ _ | .V_Raise .. | .V_LocRef _ _
  | .V_LocLazy _ _ | .V_Bytes _ | .V_Con _ _ _ _ _ _ | .V_Super _ _ _ _ | .V_List _ _ _ _ =>
    intro i he; cases he
termination_by structural h

theorem HasTypeVQ.shift_types_var {P B Ψ Q C Γ Φ i a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.var i) a) {Ψ' C' Δ k c} (hn : C'.length=C.length+k)
    (hm : TypeCtxMap k c Γ Δ) (hC : TypeParamRenaming C C' (shiftIndex k c)) : HasTypeVQ P B Ψ' Q C' Δ Φ (.var i) (shiftTypes k c a) :=
  shift_var_aux h hn hm hC i rfl

 theorem substEffValues_union (e f : Eff) (ν : Nat → Val) :
    substEffValues ν (Eff.union e f)=Eff.union (substEffValues ν e) (substEffValues ν f) := by
  cases e with
  | mk a fs => cases f with
    | mk b gs =>
      simp only [substEffValues,Eff.bind,Eff.union]
      rw [Eff.norm_rawBind]
      simp only [Eff.rawBind,valEnv,instAtoms_nil,substAtoms_nil,rowFails,List.length_nil,List.range_zero,
        List.filter_nil,List.flatMap_nil,List.append_nil,Eff.norm,Eff.atoms,Eff.test,Eff.fails,
        rawBindTys_eq_map,Ty.normTys_eq_map,List.map_append,List.map_map]
      congr 1
      apply sortUnique_eq_iff_mem.mpr
      intro t
      simp only [mem_sortUnique,List.mem_append,List.mem_map]
      simp only [Function.comp_def]
      apply or_congr <;> constructor
      all_goals first
        | (rintro ⟨x,hx,he⟩; exact ⟨_,⟨x,hx,rfl⟩,by simpa only [Ty.norm_idem] using he⟩)
        | (rintro ⟨_,⟨x,hx,rfl⟩,he⟩; exact ⟨x,hx,by simpa only [Ty.norm_idem] using he⟩)

theorem TypeCtxMap.prefix {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (n : Nat) :
    TypeCtxMap k (c+n) (Γ.shiftE n) (Δ.shiftE n) := by
  constructor
  · simpa only [Ctx.shiftE,Ctx.shiftEAt,List.length_map] using h.length
  · intro i a hi
    simp only [Ctx.shiftE,Ctx.shiftEAt,List.getElem?_map] at hi ⊢
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u => cases u with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg,Option.map_some,Option.some.injEq] at hi
        cases hi
        rw [h.lookup _ _ hg]
        simp only [Option.map_some,shiftTypes_comm]

theorem OpSig.continuation_shift_types {sg : OpSig} (hw : sg.WF) (t : Ty) (e : Eff) (k c : Nat) :
    shiftTypes k (c+sg.tparams.length) (sg.continuation t e)=
      sg.continuation (shiftTypes k c t) (shiftRowsTypes k c e) := by
  simp only [OpSig.continuation,shiftTypes,
    Ty.shiftTypes_fixed_before hw.2 k (c+sg.tparams.length) (by omega),
    shiftTypes_shiftV,shiftRowsTypes_shiftV,shiftTypes_comm,shiftRowsTypes_comm]

theorem TypeCtxMap.clause {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (sg : OpSig) (hw : sg.WF) (t : Ty) (e : Eff) :
    TypeCtxMap k (c+sg.tparams.length) (sg.context Γ t e)
      (sg.context Δ (shiftTypes k c t) (shiftRowsTypes k c e)) := by
  have hh := (h.prefix sg.tparams.length).many sg.params
  rw [BinderTypes.LocalWF.shiftTypes_fixed hw.1 k (c+sg.tparams.length) (by omega)] at hh
  have hx := hh.extend (sg.continuation t e)
  simpa only [OpSig.context,OpSig.continuation_shift_types hw] using hx

theorem TypeCtxMap.failure {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (E : Ty) :
    TypeCtxMap k (c+1) (failureContext Γ E) (failureContext Δ (shiftTypes k c E)) := by
  have hh := ((h.prefix 1).extend (shiftTypes 1 0 E)).none
  simpa only [failureContext,shiftTypes_comm] using hh

theorem OpSig.continuation_subst_values {sg : OpSig} (hw : sg.WF) (t : Ty) (e : Eff) (ν : Nat → Val) :
    substTyValues (upSubst sg.params.length (fun i => (ν i).shiftEAt sg.tparams.length 0))
      (sg.continuation t e)=(sg.continuation (substTyValues ν t) (substEffValues ν e)).norm := by
  simp only [OpSig.continuation]
  change Ty.cont (substTyValues _ sg.ret) (substTyValues _ _) (substEffValues _ _)=_
  rw [Ty.subst_up_fixed hw.2,Ty.bind_shiftV_values,Eff.bind_shiftV_values,
    substTyValues_shiftEAt,substEffValues_shiftEAt]
  simp only [Ty.norm, ← Ty.norm_shiftV, Ty.norm_shiftTypes, ← Eff.norm_shiftV, Eff.norm_shiftTypes]
  simp only [substTyValues, substEffValues, Ty.bind, Eff.bind, Ty.norm_shiftV, Ty.norm_shiftTypes, Eff.norm_shiftV, Eff.norm_shiftTypes, Ty.norm_idem, Eff.norm_idem]

 theorem handled_subst_values (P : Program) (B : Builtins) (cs : List Clause) (ν : Nat → Val) :
    substEffValues ν (handled P B cs)=handled P B cs := by
  change substEffValues ν (.mk _ [])=_
  simp only [substEffValues,Eff.bind,Eff.rawBind,valEnv,instAtoms_nil,substAtoms_nil,
    rawBindTys,rowFails,List.length_nil,List.range_zero,List.nil_append,
    Eff.norm,Eff.fails]
  rfl

end Benitoite.Release.Refinement
