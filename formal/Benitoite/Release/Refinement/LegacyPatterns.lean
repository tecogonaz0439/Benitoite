import Benitoite.Release.Refinement.LegacyTypeAlgebra

namespace Benitoite.Release.Refinement
noncomputable section

theorem LegacyTypeInput.at_values {K P0 Δ a k} (h : LegacyTypeInput K P0 Δ a k) (nv : Nat) :
    LegacyTypeInput K P0 {Δ with nv := nv} a k :=
  ⟨h.1,(embedTy_wf_values a Δ.nr Δ.kinds.length Δ.nv nv).mp h.2.1,embedTy_sorted a _,
    (embedTy_declared_context a _ _ _ _ _ rfl).mp h.2.2.2.1,h.2.2.2.2⟩

theorem LegacyNodeContext.bindings {K P0 κ Ψ C Γ δ}
    (child : LegacyNodeContext K P0 κ Ψ C (Benitoite.Release.binds δ ++ Γ)) (nv : Nat) :
    LegacyNodeTypes K P0 κ C nv δ := by
  intro a ha
  have hm : some a ∈ Benitoite.Release.binds δ ++ Γ :=
    List.mem_append_left _ (List.mem_map.mpr ⟨a,List.mem_reverse.mpr ha,rfl⟩)
  obtain ⟨i,hi⟩ := List.mem_iff_getElem?.mp hm
  exact ((child.2.2.2.2 i a hi).1).at_values nv

private theorem legacy_restTys (rest : Option ListRest) (a : Benitoite.Release.Ty) :
    embedTys (Benitoite.Release.restTys rest a) = restTys rest (embedTy a) := by
  cases rest with
  | none => rfl
  | some r => cases r <;> rfl

mutual
  theorem embedPatTy {K P0 B0 B p a δ} (tables : LegacyTables K P0 B0 B)
      (h : Benitoite.Release.PatTy P0 p a δ) :
      PatTy (embedProgramWithKinds K P0) p (embedTy a) (embedTys δ) := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const (c := c) hc =>
      have he : embedTy c.type = (embedConst c).type := (Const.type_embed c).symm
      rw [he]; exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List (rest := rest) (a := a) hb ha hn =>
      have hb' := embedPatTys tables hb
      have ha' := embedPatTys tables ha
      change PatTy _ _ (.list (embedTy a)) (embedTys _)
      rw [embedTys_eq_map,List.map_append,List.map_append,
        ←embedTys_eq_map (Benitoite.Release.restTys rest a),legacy_restTys]
      exact PatTy.P_List (by simpa only [embedTys_eq_map,List.map_replicate] using hb')
        (by simpa only [embedTys_eq_map,List.map_replicate] using ha') hn
    | .P_Con (c := c) (cd := cd) (ts := ts) hc hn hs =>
      apply PatTy.P_Con (cd := embedConDecl cd)
        (by simp only [embedProgramWithKinds_cons,hc,Option.map_some]) (by simpa only [embedTys_eq_map,List.length_map,embedConDecl] using hn)
      · intro a ha
        obtain ⟨old,hm,rfl⟩ := List.mem_map.mp (by simpa only [embedConDecl,embedTys_eq_map] using ha)
        simpa only [embedConDecl,List.length_replicate,List.length_nil] using (tables.constructorFields c cd hc old hm).1.wf
      · have hh := embedPatTys tables hs
        simpa only [embedConDecl,embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst] using hh
  theorem embedPatTys {K P0 B0 B ps as δ} (tables : LegacyTables K P0 B0 B)
      (h : Benitoite.Release.PatTys P0 ps as δ) :
      PatTys (embedProgramWithKinds K P0) ps (embedTys as) (embedTys δ) := by
    match h with
    | .nil => exact .nil
    | .cons hp hs =>
      simpa only [embedTys_eq_map,List.map_append,List.map_cons] using
        PatTys.cons (embedPatTy tables hp) (embedPatTys tables hs)
end

theorem legacy_selectSlots {α : Type} (xs : List α) (slots : List Nat) :
    selectSlots xs slots = Benitoite.Release.selectSlots xs slots := by
  induction slots with
  | nil => rfl
  | cons i is ih => simp only [selectSlots,Benitoite.Release.selectSlots,ih]

theorem embedAltsTy {K P0 B0 B alts a δ} (tables : LegacyTables K P0 B0 B)
    (h : Benitoite.Release.AltsTy P0 alts a δ) :
    AltsTy (embedProgramWithKinds K P0) alts (embedTy a) (embedTys δ) := by
  refine ⟨h.1,by simpa only [embedTys_eq_map,List.length_map] using h.2.1,h.2.2.1,?_⟩
  intro alt hm
  obtain ⟨γ,hpat,hperm,hslots⟩ := h.2.2.2 alt hm
  refine ⟨embedTys γ,embedPatTy tables hpat,by simpa only [embedTys_eq_map,List.length_map] using hperm,?_⟩
  rw [embedTys_eq_map,selectSlots_map]
  rw [legacy_selectSlots,hslots]
  simp only [Option.map_some,embedTys_eq_map]

end
end Benitoite.Release.Refinement
