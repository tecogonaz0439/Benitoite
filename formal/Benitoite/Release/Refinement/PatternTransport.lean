import Benitoite.Release.Refinement.Patterns
import Benitoite.Release.Refinement.ValueBinding

namespace Benitoite.Release.Refinement

theorem restTys_map (f : Ty → Ty) (rest : Option ListRest) (a : Ty)
    (hl : f (.list a) = .list (f a)) : (restTys rest a).map f = restTys rest (f a) := by
  cases rest with
  | none => rfl
  | some r => cases r <;> simp [restTys, hl]

mutual
  theorem PatTy.shift_values {P p a δ} (h : PatTy P p a δ) (k c : Nat) :
      PatTy P p (a.shiftV k c) (δ.map (Ty.shiftV k c)) := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const (c := con) hc =>
      have he : ((embedConst con).type).shiftV k c = (embedConst con).type := by
        cases con <;> rfl
      rw [he]; exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List (rest := rest) (a := a) hb ha hn =>
      simp only [List.map_append]
      rw [restTys_map (Ty.shiftV k c) rest a rfl]
      exact .P_List (by simpa only [List.map_replicate] using hb.shift_values k c)
        (by simpa only [List.map_replicate] using ha.shift_values k c) hn
    | .P_Con (cd := cd) (ts := ts) hc hn hw hp =>
      have hh := hp.shift_values k c
      have he : (cd.args.map (Ty.subst ts [])).map (Ty.shiftV k c) =
          cd.args.map (Ty.subst (ts.map (Ty.shiftV k c)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a hm => Ty.subst_shiftV_closed (hw a hm) ts k c)
      rw [he] at hh
      simpa only [Ty.shiftV, shiftVTys_eq_map] using
        PatTy.P_Con hc (by simpa using hn) hw hh
  theorem PatTys.shift_values {P ps as δ} (h : PatTys P ps as δ) (k c : Nat) :
      PatTys P ps (as.map (Ty.shiftV k c)) (δ.map (Ty.shiftV k c)) := by
    match h with
    | .nil => exact .nil
    | .cons hp hs =>
      simpa only [List.map_append, List.map_cons] using PatTys.cons (hp.shift_values k c) (hs.shift_values k c)
end

mutual
  theorem PatTy.subst_values {P p a δ} (h : PatTy P p a δ) (ν : Nat → Val) :
      PatTy P p (substTyValues ν a) (δ.map (substTyValues ν)) := by
    match h with
    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const (c := con) hc =>
      have he : substTyValues ν (embedConst con).type = (embedConst con).type := by
        cases con <;> rfl
      rw [he]; exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List (rest := rest) (a := a) hb ha hn =>
      simp only [List.map_append]
      rw [restTys_map (substTyValues ν) rest a rfl]
      exact .P_List (by simpa only [List.map_replicate, substTyValues, Ty.bind] using hb.subst_values ν)
        (by simpa only [List.map_replicate, substTyValues, Ty.bind] using ha.subst_values ν) hn
    | .P_Con (cd := cd) (ts := ts) hc hn hw hp =>
      have hh := hp.subst_values ν
      have he : (cd.args.map (Ty.subst ts [])).map (substTyValues ν) =
          cd.args.map (Ty.subst (ts.map (substTyValues ν)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a hm => Ty.substV_subst_closed (hw a hm) ts (valEnv ν).values)
      rw [he] at hh
      simpa only [substTyValues_eq_bind, Ty.bind_data] using
        PatTy.P_Con hc (by simpa using hn) hw hh
  theorem PatTys.subst_values {P ps as δ} (h : PatTys P ps as δ) (ν : Nat → Val) :
      PatTys P ps (as.map (substTyValues ν)) (δ.map (substTyValues ν)) := by
    match h with
    | .nil => exact .nil
    | .cons hp hs =>
      simpa only [List.map_append, List.map_cons] using PatTys.cons (hp.subst_values ν) (hs.subst_values ν)
end

theorem AltsTy.map {P alts a δ} (h : AltsTy P alts a δ) (f : Ty → Ty)
    (hf : ∀ p a δ, PatTy P p a δ → PatTy P p (f a) (δ.map f)) :
    AltsTy P alts (f a) (δ.map f) := by
  refine ⟨h.1, by simpa using h.2.1, h.2.2.1, ?_⟩
  intro alt hm
  obtain ⟨γ,hp,hs,he⟩ := h.2.2.2 alt hm
  exact ⟨γ.map f, hf _ _ _ hp, by simpa using hs, by rw [selectSlots_map, he]; rfl⟩

theorem AltsTy.shift_values {P alts a δ} (h : AltsTy P alts a δ) (k c : Nat) :
    AltsTy P alts (a.shiftV k c) (δ.map (Ty.shiftV k c)) :=
  h.map _ (fun _ _ _ hp => hp.shift_values k c)

theorem AltsTy.subst_values {P alts a δ} (h : AltsTy P alts a δ) (ν : Nat → Val) :
    AltsTy P alts (substTyValues ν a) (δ.map (substTyValues ν)) :=
  h.map _ (fun _ _ _ hp => hp.subst_values ν)

end Benitoite.Release.Refinement
