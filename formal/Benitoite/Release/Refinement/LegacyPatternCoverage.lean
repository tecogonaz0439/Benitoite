import Benitoite.Release.Refinement.LegacyPatternMatch
import Benitoite.Release.TypeBounds

namespace Benitoite.Release.Refinement
noncomputable section

private theorem legacy_tys_injective : Function.Injective embedTys := by
  intro as bs h
  have he : embedTy (.data "" as) = embedTy (.data "" bs) := by
    change Ty.data "" (embedTys as) = Ty.data "" (embedTys bs)
    rw [h]
  have := embedTy_injective he
  cases this
  rfl

private theorem old_decl {K P0 c d n args} (h : (embedProgramWithKinds K P0).cons c = some ⟨d, n, args⟩) :
    ∃ old : Benitoite.Release.ConDecl, P0.cons c = some old ∧ old.data = d ∧ old.ntys = n ∧
      embedTys old.args = args := by
  obtain ⟨old, ho, he⟩ := Option.map_eq_some_iff.mp h
  simp only [embedConDecl, ConDecl.mk.injEq] at he
  exact ⟨old, ho, he.1, he.2.1, he.2.2⟩

private theorem old_public_args {old : Benitoite.Release.ConDecl} {as : List ScopePublic.PublicTy}
    (h : embedTys old.args = as.map ScopePublic.PublicTy.ty) :
    old.args.map (Benitoite.Release.Ty.subst [] []) = as.map ScopePublic.PublicTy.oldTy := by
  apply legacy_tys_injective
  simp only [embedTys_eq_map, List.map_map, Function.comp_def, legacy_subst, List.map_nil] at h ⊢
  have e : old.args.map (fun x => Ty.subst [] [] (embedTy x)) = (old.args.map embedTy).map (Ty.subst [] []) := by
    simp [List.map_map, Function.comp_def]
  rw [e, h]
  simp [List.map_map, Function.comp_def, ScopePublic.PublicTy.subst_ty, ScopePublic.PublicTy.embed_oldTy]

mutual
  /-- 公開の値の旧 Release の照合の値は、旧の宣言で同じ型に属する。 -/
  private theorem legacy_public {K P0} (hp : (embedProgramWithKinds K P0).HasScopePublic)
      {t : ScopePublic.PublicTree} {a : ScopePublic.PublicTy} (h : t.Typed a) :
      Benitoite.Release.Inhabits P0 a.oldTy t.legacy := by
    match h with
    | .text s => exact .const (c := .string s)
    | .integer n => exact .const (c := .integer n)
    | .bytes _ => exact .bytes
    | .list _ hs => exact .list (legacy_public_each hp hs)
    | .none (a := a) _ =>
      obtain ⟨old, ho, hd, hn, hargs⟩ := old_decl hp.optionNone
      have hz : old.args = [] := legacy_tys_injective hargs
      have hi := Benitoite.Release.Inhabits.con (ts := [a.oldTy]) (tys' := []) (args := []) ho
        (by rw [hn]; rfl) (by rw [hz]; exact .nil)
      rwa [hd] at hi
    | .some (a := a) _ hx =>
      obtain ⟨old, ho, hd, hn, hargs⟩ := old_decl hp.optionSome
      have hz : old.args = [.tvar 0] := legacy_tys_injective hargs
      have hs : (Benitoite.Release.Ty.tvar 0).subst [a.oldTy] [] = a.oldTy := by
        apply embedTy_injective
        rw [legacy_subst]
        simp [embedTy, embedTys, ScopePublic.PublicTy.embed_oldTy, Ty.subst, Ty.substAt, substTypeAt,
          Ty.bind, Ty.rawBind, typeEnvAt, ScopePublic.PublicTy.norm_ty]
      have hi := Benitoite.Release.Inhabits.con (ts := [a.oldTy]) (tys' := []) ho
        (by rw [hn]; rfl) (by rw [hz]; simpa [hs] using Benitoite.Release.InhabitsAll.cons (legacy_public hp hx) .nil)
      rwa [hd] at hi
    | .con (c := c) (d := d) (as := as) hl hs =>
      obtain ⟨old, ho, hd, hn, hargs⟩ := old_decl (ScopePublic.lookup_cons hp hl)
      have hi := Benitoite.Release.Inhabits.con (ts := []) (tys' := []) ho (by rw [hn]; rfl)
        (by rw [old_public_args hargs]; exact legacy_public_all hp hs)
      rwa [hd] at hi
  private theorem legacy_public_all {K P0} (hp : (embedProgramWithKinds K P0).HasScopePublic)
      {ts : List ScopePublic.PublicTree} {as : List ScopePublic.PublicTy} (h : ScopePublic.PublicTree.TypedAll ts as) :
      Benitoite.Release.InhabitsAll P0 (as.map ScopePublic.PublicTy.oldTy) (ScopePublic.PublicTree.legacyList ts) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs => exact .cons (legacy_public hp hx) (legacy_public_all hp hs)
  private theorem legacy_public_each {K P0} (hp : (embedProgramWithKinds K P0).HasScopePublic)
      {ts : List ScopePublic.PublicTree} {a : ScopePublic.PublicTy} (h : ScopePublic.PublicTree.TypedEach ts a) :
      Benitoite.Release.InhabitsEach P0 a.oldTy (ScopePublic.PublicTree.legacyList ts) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs => exact .cons (legacy_public hp hx) (legacy_public_each hp hs)
end

mutual
  theorem legacy_inhabits {K P0 B0 B nt t v} (tables : LegacyTables K P0 B0 B)
      (h : Inhabits (embedProgramWithKinds K P0) t v)
      (a : Benitoite.Release.Ty) (he : embedTy a = t) (hw : a.WF 0 nt) :
      Benitoite.Release.Inhabits P0 a (legacyPatternVal v) := by
    match h with
    | .const (c := c) =>
      have eq := embedTy_injective ((legacyPatternConst_type c).trans he.symm)
      cases eq
      exact .const (c := legacyPatternConst c)
    | .fn =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.fn.injEq] at he
      exact .fn
    | .tvar =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.tvar.injEq] at he
      exact .tvar
    | .reference =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.reference.injEq] at he
      exact .reference
    | .lazy =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.lazy.injEq] at he
      exact .lazy
    | .cont =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.cont.injEq] at he
      exact .cont
    | .map =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.map.injEq] at he
      exact .map
    | .set =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.set.injEq] at he
      exact .set
    | .bytes =>
      cases a <;> simp only [embedTy,reduceCtorEq] at he
      exact .bytes
    | .dict =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.dict.injEq] at he
      exact .dict
    | .tapp =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.tapp.injEq] at he
      exact .tapp
    | .ctor =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.ctor.injEq] at he
      exact .ctor
    | .dependentFn | .external | .scoped | .pathBases | .scopePattern | .refined _ _ =>
      cases a <;> simp only [embedTy,reduceCtorEq] at he
    | .checked | .checkedRequest | .checkedAtOpaque =>
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.opaque.injEq] at he
      rename_i o ix
      cases ix with
      | rvar i => exact (Nat.not_lt_zero i hw).elim
      | fixed r => exact .checked
    | .list hs =>
      have ih := legacy_inhabitsEach (nt := nt) tables hs
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.list.injEq] at he
      rename_i a
      exact .list (ih a he hw)
    | .con (c := c) (cd := cd) lookup arity fields hs =>
      have ih := legacy_inhabitsAll (nt := nt) tables hs
      cases a <;> simp only [embedTy,reduceCtorEq,Ty.data.injEq] at he
      rename_i d as
      obtain ⟨rfl,rfl⟩ := he
      obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp lookup
      have count : old.ntys = as.length := by
        simpa only [embedConDecl,embedTys_eq_map,List.length_map] using arity
      apply Benitoite.Release.Inhabits.con ho count
      apply ih (old.args.map (Benitoite.Release.Ty.subst as []))
      · simp only [embedConDecl,embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst]
      · apply Benitoite.Release.Ty.WFList.iff.mpr
        intro a ha
        obtain ⟨b,hb,rfl⟩ := List.mem_map.mp ha
        apply Benitoite.Release.Ty.subst_wf [] (Benitoite.Release.Ty.WFList.iff.mp hw) (by simp)
        rw [←count]
        apply legacy_wf (nv := 0)
        simpa only [List.length_replicate,List.length_nil] using (tables.constructorFields c old ho b hb).1.wf
    | .atError (detail := detail) standard =>
      cases a <;> simp only [embedTy,atErrorType,reduceCtorEq,Ty.data.injEq] at he
      rename_i d as
      obtain ⟨rfl,hzero⟩ := he
      have hz := legacy_tys_injective (show embedTys as = embedTys [] from hzero)
      subst as
      obtain ⟨cd,lookup,data,arity,fields⟩ := standard.2.2.1
      obtain ⟨old,ho,rfl⟩ := Option.map_eq_some_iff.mp lookup
      have hfields : embedTys old.args = [ScopePublic.PublicTy.ty (.data "Scope.AtDetail")] := fields
      have hz : old.ntys = 0 := arity
      have hd : old.data = "Scope.ScopeError" := data
      rw [←hd]
      apply Benitoite.Release.Inhabits.con (ts := []) ho hz
      rw [old_public_args (as := [.data "Scope.AtDetail"]) hfields]
      exact .cons (legacy_public standard.2.2.2 detail.publicTree_typed) .nil
  termination_by structural h

  theorem legacy_inhabitsAll {K P0 B0 B nt ts vs} (tables : LegacyTables K P0 B0 B)
      (h : InhabitsAll (embedProgramWithKinds K P0) ts vs)
      (as : List Benitoite.Release.Ty) (he : embedTys as = ts)
      (hw : Benitoite.Release.Ty.WFList 0 nt as) :
      Benitoite.Release.InhabitsAll P0 as (legacyPatternVals vs) := by
    match h with
    | .nil =>
      cases as <;> simp only [embedTys,reduceCtorEq] at he
      exact .nil
    | .cons hv hs =>
      have ihv := legacy_inhabits (nt := nt) tables hv
      have ihs := legacy_inhabitsAll (nt := nt) tables hs
      cases as <;> simp only [embedTys,reduceCtorEq,List.cons.injEq] at he
      rename_i a as
      exact .cons (ihv a he.1 hw.1) (ihs as he.2 hw.2)
  termination_by structural h

  theorem legacy_inhabitsEach {K P0 B0 B nt t vs} (tables : LegacyTables K P0 B0 B)
      (h : InhabitsEach (embedProgramWithKinds K P0) t vs)
      (a : Benitoite.Release.Ty) (he : embedTy a = t) (hw : a.WF 0 nt) :
      Benitoite.Release.InhabitsEach P0 a (legacyPatternVals vs) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs =>
      exact .cons (legacy_inhabits tables hv a he hw)
        (legacy_inhabitsEach tables hs a he hw)
  termination_by structural h
end

theorem embedExhaustive {K P0 B0 B nt a ps}
    (tables : LegacyTables K P0 B0 B)
    (wf : Benitoite.Release.Ty.WF 0 nt a)
    (h : Benitoite.Release.Exhaustive P0 a ps) :
    Exhaustive (embedProgramWithKinds K P0) (embedTy a) ps := by
  intro v hv
  have hi := (Inhabits.norm_all_iff _ _).mp hv
  obtain ⟨p,hp,hm⟩ := h (legacyPatternVal v) (legacy_inhabits tables hi a rfl wf)
  refine ⟨p,hp,?_⟩
  have he := congrArg Option.isSome (legacy_matchVal p v)
  simp only [Option.isSome_map] at he
  exact he ▸ hm

end
end Benitoite.Release.Refinement
