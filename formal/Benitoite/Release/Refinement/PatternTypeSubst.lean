import Benitoite.Release.Refinement.PatternSemantics
import Benitoite.Release.Refinement.TypeSubstFormation

/-! # パターンと型・行の置換（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem data_image (d : DataName) (xs : List Ty) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    (Ty.data d xs).substAt c ts es = .data d (xs.map (Ty.substAt c ts es)) := by
  simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,
    Ty.normTys_eq_map,rawBindTys_eq_map,List.map_map]
  rfl


mutual
  theorem PatTy.substAt {P p a δ} (h : PatTy P p a δ) (hp : P.WellFormed)
      (c : Nat) (ts : List Ty) (es : List Eff) :
      PatTy P p (a.substAt c ts es) (δ.map (Ty.substAt c ts es)) := by
    match h with
    | .P_Convert he hpat =>
      have hh := PatTy.P_Convert (b := a.substAt c ts es)
        (by simpa only [Ty.substAt_norm_source,Ty.substAt,substTypeAt,Ty.bind,Ty.norm_idem]
          using Ty.rawBind_norm_congr (typeEnvAt c ts es) he) (hpat.substAt hp c ts es)
      simpa only [List.map_map,Function.comp_def,Ty.substAt_norm_source,
        Ty.substAt,substTypeAt,Ty.bind,Ty.norm_rawBind,Ty.norm_idem] using hh
    | .P_Refined (a := base) (φ := φ) hpat =>
      have hh := PatTy.P_Refined (φ := φ) (hpat.substAt hp c ts es)
      have out := PatTy.P_Convert (b := (Ty.refined base φ).substAt c ts es) (by
        simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,
          typeEnvAt,upValues_id,predBind_id,Ty.norm_refineNorm,Ty.norm_idem]) hh
      have hn : (δ.map (Ty.substAt c ts es)).map Ty.norm = δ.map (Ty.substAt c ts es) := by
        rw [List.map_map]
        apply List.map_congr_left
        intro a _
        exact Ty.norm_idem _
      rw [hn] at out
      exact out

    | .P_Wild => exact .P_Wild
    | .P_Var => exact .P_Var
    | .P_Const (c := con) hc =>
      have he : (embedConst con).type.substAt c ts es = (embedConst con).type := by
        cases con <;> rfl
      rw [he]; exact .P_Const hc
    | .P_RangeInt => exact .P_RangeInt
    | .P_RangeChar => exact .P_RangeChar
    | .P_List (rest := rest) (a := a) hb ha hn =>
      simp only [List.map_append]
      rw [restTys_map (Ty.substAt c ts es) rest a rfl]
      exact .P_List (by simpa only [List.map_replicate,Ty.substAt,substTypeAt,Ty.bind] using hb.substAt hp c ts es)
        (by simpa only [List.map_replicate,Ty.substAt,substTypeAt,Ty.bind] using ha.substAt hp c ts es) hn
    | .P_Con (c := con) (cd := cd) (ts := xs) hc hn hw hpat =>
      have hh := hpat.substAt hp c ts es
      have he : (cd.args.map (Ty.subst xs [])).map (Ty.substAt c ts es) =
          cd.args.map (Ty.subst (xs.map (Ty.substAt c ts es)) []) := by
        rw [List.map_map]
        apply List.map_congr_left
        intro a hm
        exact Ty.subst_substAt (hw a hm) xs [] (by omega)
          ((hp.cons con cd hc).2 a hm).1.2.1 c ts es
      rw [he] at hh
      rw [data_image]
      exact PatTy.P_Con hc (by simpa using hn) hw hh

  theorem PatTys.substAt {P ps as δ} (h : PatTys P ps as δ) (hp : P.WellFormed)
      (c : Nat) (ts : List Ty) (es : List Eff) :
      PatTys P ps (as.map (Ty.substAt c ts es)) (δ.map (Ty.substAt c ts es)) := by
    match h with
    | .nil => exact .nil
    | .cons hpatt hs =>
      simpa only [List.map_append,List.map_cons] using
        PatTys.cons (hpatt.substAt hp c ts es) (hs.substAt hp c ts es)
end

theorem AltsTy.substAt {P alts a δ} (h : AltsTy P alts a δ) (hp : P.WellFormed)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    AltsTy P alts (a.substAt c ts es) (δ.map (Ty.substAt c ts es)) :=
  h.map _ (fun _ _ _ hpat => hpat.substAt hp c ts es)


private theorem all_reflect {P as vs} (f : Ty → Ty)
    (h : InhabitsAll P (as.map f) vs)
    (ih : ∀ a v, v ∈ vs → Inhabits P (f a) v → Inhabits P a v) :
    InhabitsAll P as vs := by
  induction as generalizing vs with
  | nil => cases h; exact .nil
  | cons a as ind =>
    cases h with
    | cons hv hs =>
      exact .cons (ih a _ (by simp) hv)
        (ind hs (fun a v hm => ih a v (List.mem_cons_of_mem _ hm)))

private theorem each_reflect {P a vs} (f : Ty → Ty)
    (h : InhabitsEach P (f a) vs)
    (ih : ∀ v, v ∈ vs → Inhabits P (f a) v → Inhabits P a v) :
    InhabitsEach P a vs := by
  induction vs with
  | nil => exact .nil
  | cons v vs ind =>
    cases h with
    | cons hv hs =>
      exact .cons (ih _ (by simp) hv)
        (ind hs (fun v hm => ih v (List.mem_cons_of_mem _ hm)))

private theorem reflect_type {P} (hp : P.WellFormed) (c : Nat)
    (ts : List Ty) (es : List Eff) (v : Val)
    (ih : ∀ w, sizeOf w < sizeOf v → ∀ a, Inhabits P (a.substAt c ts es) w → Inhabits P a w)
    (a : Ty) (h : Inhabits P (a.substAt c ts es) v) : Inhabits P a v := by
  cases a with
  | tvar i => exact .tvar
  | tapp i xs => exact .tapp
  | ctor k => exact .ctor
  | fn ns ps r e => exact .fn
  | dependentFn t => exact .dependentFn
  | reference a => exact .reference
  | lazy a => exact .lazy
  | cont b t e => exact .cont
  | map a b => exact .map
  | set a => exact .set
  | bytes => exact .bytes
  | dict cl a => exact .dict
  | external id xs => exact .external
  | «scoped» o k ix => exact .scoped
  | pathBases => exact .pathBases
  | scopePattern k => exact .scopePattern
  | base b => exact h
  | «opaque» o ix => simpa only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,
      typeEnvAt,RangeIx.inst_nil,Ty.norm] using h
  | refined a p =>
    have he : (Ty.refined a p).substAt c ts es = (a.substAt c ts es).refineNorm p := by
      simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,
        typeEnvAt,upValues_id,predBind_id]
    rw [he] at h
    obtain ⟨ha,hp'⟩ := Inhabits.refineNorm_iff.mp h
    exact .refined (reflect_type hp c ts es v ih a ha) hp'
  | list a =>
    obtain ⟨vs,rfl,hs⟩ := Inhabits.list_inv h _ rfl
    exact .list (each_reflect (Ty.substAt c ts es) hs (fun w hm hw => ih w (by
      have := List.sizeOf_lt_of_mem hm
      simp only [Val.list.sizeOf_spec]
      omega) a hw))
  | data d xs =>
    rw [data_image] at h
    rcases Inhabits.data_inv h d (xs.map (Ty.substAt c ts es)) rfl with
      ⟨con,tys,vs,cd,rfl,hc,rfl,hn,hw,hs⟩ | ⟨rfl,he,detail,rfl,hs⟩
    · have hn' : cd.ntys = xs.length := by simpa using hn
      have he : (cd.args.map (Ty.subst xs [])).map (Ty.substAt c ts es) =
          cd.args.map (Ty.subst (xs.map (Ty.substAt c ts es)) []) := by
        rw [List.map_map]
        apply List.map_congr_left
        intro a hm
        exact Ty.subst_substAt (hw a hm) xs [] (by omega)
          ((hp.cons con cd hc).2 a hm).1.2.1 c ts es
      rw [←he] at hs
      exact .con hc hn' hw (all_reflect (Ty.substAt c ts es) hs (fun a w hm hw' => ih w (by
        have := List.sizeOf_lt_of_mem hm
        simp only [Val.con.sizeOf_spec]
        omega) a hw'))
    · have hx : xs = [] := List.map_eq_nil_iff.mp he
      subst xs
      exact .atError hs
termination_by sizeOf a

private theorem reflect_value {P} (hp : P.WellFormed) (c : Nat)
    (ts : List Ty) (es : List Eff) (v : Val) :
    ∀ a, Inhabits P (a.substAt c ts es) v → Inhabits P a v := by
  have main : ∀ n, ∀ v : Val, sizeOf v = n →
      ∀ a, Inhabits P (a.substAt c ts es) v → Inhabits P a v := by
    intro n
    induction n using Nat.strongRecOn with
    | ind n ind =>
      intro v hv a ha
      exact reflect_type hp c ts es v (fun w hw a h => ind (sizeOf w) (by omega) w rfl a h) a ha
  exact main (sizeOf v) v rfl

theorem Inhabits.of_substAt {P : Program} {a : Ty} {v : Val} (c : Nat) (ts : List Ty) (es : List Eff)
    (hp : P.WellFormed) (h : Inhabits P (a.substAt c ts es) v) :
    Inhabits P a.norm v :=
  (Inhabits.norm_all_iff a v).mpr (reflect_value hp c ts es v a h)

theorem InhabitsAll.of_substAt {P as vs} (c : Nat) (ts : List Ty) (es : List Eff)
    (hp : P.WellFormed) (h : InhabitsAll P (as.map (Ty.substAt c ts es)) vs) :
    InhabitsAll P as vs :=
  all_reflect (Ty.substAt c ts es) h (fun a v _ => reflect_value hp c ts es v a)

theorem InhabitsEach.of_substAt {P : Program} {a : Ty} {vs : List Val} (c : Nat) (ts : List Ty) (es : List Eff)
    (hp : P.WellFormed) (h : InhabitsEach P (a.substAt c ts es) vs) :
    InhabitsEach P a vs :=
  each_reflect (Ty.substAt c ts es) h (fun v _ => reflect_value hp c ts es v a)

theorem unguardedPats_substTy (arms : List Arm) (c : Nat) (ts : List Ty) (es : List Eff) :
    unguardedPats (Arm.substTyAtList c ts es arms) = unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih =>
    cases arm with
    | mk alts guard body => cases guard <;> simp [Arm.substTyAtList, unguardedPats, ih]

theorem Exhaustive.substAt {P a ps} (h : Exhaustive P a ps) (hp : P.WellFormed)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    Exhaustive P (a.substAt c ts es) ps := by
  intro v hv
  exact h v (Inhabits.of_substAt c ts es hp ((Inhabits.norm_all_iff _ v).mp hv))

end
end Benitoite.Release.Refinement
