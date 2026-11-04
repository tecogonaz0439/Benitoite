import Benitoite.Release.Refinement.ScopeSignatureFormation

/-! # 同じ範囲付き表の八つの置換条件と制約の供給 -/
namespace Benitoite.Release.Refinement.ScopeSignatures
noncomputable section

/-- 共通表の型引数の許容は、宣言した個数で決まる。 -/
theorem admits_iff_count {delta io b sg C ts}
    (hs : (builtins delta io).sig b = some sg) :
    sg.admits C ts ↔ ts.length = sg.tparams.length := by
  have hm := lookup_mem hs
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp [refGet,refSet,pathBases,readTextIn,readBytesIn,writeTextIn,writeBytesIn,
    appendTextIn,appendBytesIn,sendIn,checkPathIn,checkRequestIn,pathInValue,requestInValue,
    widenPathIn,widenRequestIn,pureIn,ioIn,List.length_eq_zero_iff]

/-- 任意の P と応答表について、値と型の八つの保存条件を構成する。 -/
theorem substitutionAssumptions (P : Program) (delta io) :
    (builtins delta io).SubstitutionAssumptions P where
  sat_rename := by
    intro C Γ Δ a p ξ _ _ _ h
    exact (ModelConstraints.sat_rename _ _ a p ξ).mpr h
  admits_rename := by
    intro b sg C Γ Δ ts ξ hs _ _ _ h
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ h
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)
  sat_renameTypes := by
    intro C D Γ Δ a p ρ ren _ _ h
    exact ModelConstraints.sat_renameTypes ren h
  admits_renameTypes := by
    intro b sg C D Γ Δ ts ρ hs _ _ _ h
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)
  sat_subst := by
    intro C0 C1 a p ts es h wf images count
    exact ModelConstraints.sat_subst h wf images count
  admits_subst := by
    intro b sg C0 C1 ts ts' es' hs h _ _ _
    exact (admits_iff_count hs).mpr (by simpa using (admits_iff_count hs).mp h)

/-- 同じ sat は、任意の型に無制約を供給する。 -/
theorem sat_unconstrained {delta io} (a : Ty) :
    (builtins delta io).sat [] a.norm ({} : TParam) :=
  ModelConstraints.sat_unconstrained _ _ _

/-- 表が許容した型引数は、同じ表の各型パラメータの制約を満たす。 -/
theorem admits_sat {delta io b sg C ts}
    (hs : (builtins delta io).sig b = some sg)
    (h : sg.admits (TypeCtx.constraints C) (Ty.normTys ts)) :
    SatAll (builtins delta io) C ts (sg.tparams.map TParamDecl.constraints) := by
  have count : ts.length = sg.tparams.length := by
    simpa [Ty.normTys_eq_map] using (admits_iff_count hs).mp h
  refine ⟨by simpa using count,?_⟩
  intro i a p ha hp
  have hm := lookup_mem hs
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals simp only [refGet,refSet,pathBases,readTextIn,readBytesIn,writeTextIn,writeBytesIn,
    appendTextIn,appendBytesIn,sendIn,checkPathIn,checkRequestIn,pathInValue,requestInValue,
    widenPathIn,widenRequestIn,pureIn,ioIn,List.map_nil,List.map_cons,List.getElem?_cons,
    List.getElem?_nil,TypeCtx.valueParam] at hp
  all_goals first
    | cases hp
    | (split at hp <;> first | cases hp; exact ModelConstraints.sat_unconstrained _ _ _ | cases hp)

/-- P の宣言の arity と kind は、置換条件と独立に同じ lookup から得る。 -/
example {P delta io b sg} (hp : ScopeDeclarations.HasHttp P)
    (hs : (builtins delta io).sig b = some sg) :
    (builtins delta io).SubstitutionAssumptions P ∧ PrimSig.Scoped P sg :=
  ⟨substitutionAssumptions P delta io,sig_scoped hp hs⟩

/-- 非空制約の開いた型と型像にも、同じ一般の保存則を適用する。 -/
example {S ps C D ρ as a p C0 C1 ts es}
    (ren : TypeParamRenaming C D ρ) (ha : ModelConstraints.sat S C.constraints a p)
    (hs : ModelConstraints.admits S ps C.constraints as)
    (hsub : ModelConstraints.sat S (TypeCtx.constraints (C1 ++ C0)) a p)
    (has : ModelConstraints.admits S ps (TypeCtx.constraints (C1 ++ C0)) as)
    (wf : ∀ t ∈ ts, Ty.WF 0 0 0 t)
    (images : ts.length = (TypeCtx.constraints C0).length ∧
      ∀ (i : Nat) (t : Ty) (q : TParam), ts[i]? = some t → (TypeCtx.constraints C0)[i]? = some q →
        ModelConstraints.sat S C1.constraints t.norm q)
    (count : ts.length = C0.length) :
    ModelConstraints.sat S D.constraints (a.renameTypes ρ) p ∧
    ModelConstraints.admits S ps D.constraints (as.map (fun t => t.renameTypes ρ)) ∧
    ModelConstraints.sat S C1.constraints (a.substAt C1.length ts es) p ∧
    ModelConstraints.admits S ps C1.constraints (as.map (Ty.substAt C1.length ts es)) :=
  ⟨ModelConstraints.sat_renameTypes ren ha,ModelConstraints.admits_renameTypes ren hs,
    ModelConstraints.sat_subst hsub wf images count,ModelConstraints.admits_subst has wf images count⟩

example {delta io a} : (builtins delta io).sat [] (Ty.norm a) ({} : TParam) := sat_unconstrained a
example {delta io b sg C ts} (hs : (builtins delta io).sig b = some sg)
    (ha : sg.admits C.constraints (Ty.normTys ts)) :
    SatAll (builtins delta io) C ts (sg.tparams.map TParamDecl.constraints) := admits_sat hs ha
end
end Benitoite.Release.Refinement.ScopeSignatures
