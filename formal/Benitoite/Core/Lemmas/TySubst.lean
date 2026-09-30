import Benitoite.Core.Lemmas.SubstTyping
import Benitoite.Core.Lemmas.Compose
import Benitoite.Core.Assumptions

/-!
# 型とエフェクトの置き換えで型付けが保たれること

E-Fun は、関数の本体に呼び出しの型引数とエフェクト引数の置き換え θ を施す（01-12 の `Mθ`）。
定義の本体は、型パラメータを「ほかの何とも等しくない型」として型が付いている（01-12「定義」）ので、
θ を施した本体には、θ を施した型が付く。
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

theorem Const.type_subst (c : Const) (ts : List Ty) (es : List Eff) :
    c.type.subst ts es = c.type := by
  cases c <;> simp [Const.type, Ty.subst]

/-- 構成子の引数の型に、データ型の型引数の置き換えと θ を続けて施したもの。 -/
theorem ConDecl.args_subst {cd : ConDecl} (hcd : cd.Scoped) {ts : List Ty} (hts : ts.length = cd.ntys)
    (ts' : List Ty) (es' : List Eff) :
    (cd.args.map (Ty.subst ts [])).map (Ty.subst ts' es') =
      cd.args.map (Ty.subst (ts.map (Ty.subst ts' es')) []) := by
  have h : Ty.VarsInList (· < ts.length) (· < ([] : List Eff).length) cd.args :=
    Ty.VarsInList.mono (fun i (hi : i < cd.ntys) => (by omega : i < ts.length)) (fun i hi => hi.elim)
      cd.args hcd
  rw [Ty.subst_comp_list ts' es' cd.args h]
  rfl

/-- 関数の型の置き換えの合成（V-Fun・V-Prim の型に θ を施したもの）。 -/
theorem fnTy_subst {ps : List Ty} {r : Ty} {ε : Eff} {nt ne : Nat}
    (hs : Ty.VarsInList (· < nt) (· < ne) ps ∧ Ty.VarsIn (· < nt) (· < ne) r ∧
      Eff.RhosIn (· < ne) ε)
    {ts : List Ty} {es : List Eff} (hts : ts.length = nt) (hes : es.length = ne)
    (ts' : List Ty) (es' : List Eff) :
    (fnTy ps r ε ts es).subst ts' es' =
      fnTy ps r ε (ts.map (Ty.subst ts' es')) (es.map (Eff.substRho es')) := by
  unfold fnTy
  subst hts hes
  exact Ty.subst_comp ts' es' (.fn ps r ε) hs

/-! ## パターン -/

mutual
  theorem PatTy.substTy (hwf : P.WellFormed) (ts' : List Ty) (es' : List Eff) {p a δ} :
      PatTy P p a δ → PatTy P p (a.subst ts' es') (δ.map (Ty.subst ts' es'))
    | .P_Wild => .P_Wild
    | .P_Var => by simpa using PatTy.P_Var
    | .P_Const h1 h2 => by rw [Const.type_subst]; exact .P_Const h1 h2
    | .P_Con (cd := cd) (ts := ts) hc hts hps => by
        simp only [Ty.subst]
        refine .P_Con hc (by simpa using hts) ?_
        rw [← ConDecl.args_subst (hwf.2 _ _ hc) hts]
        exact PatTys.substTy hwf ts' es' hps

  theorem PatTys.substTy (hwf : P.WellFormed) (ts' : List Ty) (es' : List Eff) {ps as δ} :
      PatTys P ps as δ → PatTys P ps (as.map (Ty.subst ts' es')) (δ.map (Ty.subst ts' es'))
    | .nil => .nil
    | .cons hp hps => by
        simp only [List.map_cons, List.map_append]
        exact .cons (PatTy.substTy hwf ts' es' hp) (PatTys.substTy hwf ts' es' hps)
end

/-! ## 網羅性 -/

mutual
  /-- θ を施した型の値の形をした値は、施す前の型の値の形をしている。 -/
  theorem Inhabits.of_subst (hwf : P.WellFormed) (ts' : List Ty) (es' : List Eff) {u v} :
      Inhabits P u v → ∀ t, u = t.subst ts' es' → Inhabits P t v
    | .const (c := c), t, hu => by
        cases t with
        | tvar i => exact .tvar
        | base ι => simp [Ty.subst] at hu; rw [← hu]; exact .const
        | «opaque» o => simp [Ty.subst] at hu; rw [← hu]; exact .const
        | data d args => cases c <;> simp [Const.type, Ty.subst] at hu
        | list a => cases c <;> simp [Const.type, Ty.subst] at hu
        | fn ps r ε => exact .fn
    | .con (cd := cd) (ts := ts) hc hn hargs, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | data d ts0 =>
            simp only [Ty.subst, Ty.data.injEq] at hu
            obtain ⟨rfl, rfl⟩ := hu
            have hlen : ts0.length = cd.ntys := by simpa using hn.symm
            refine .con hc hlen.symm ?_
            rw [← ConDecl.args_subst (hwf.2 _ _ hc) hlen] at hargs
            exact InhabitsAll.of_subst hwf ts' es' hargs _ rfl
        | fn ps r ε => exact .fn
        | base _x => simp [Ty.subst] at hu
        | «opaque» _x => simp [Ty.subst] at hu
        | list _x => simp [Ty.subst] at hu
    | .list he, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | list a0 =>
            simp only [Ty.subst, Ty.list.injEq] at hu
            subst hu
            exact .list (InhabitsEach.of_subst hwf ts' es' he a0 rfl)
        | fn ps r ε => exact .fn
        | base _x => simp [Ty.subst] at hu
        | «opaque» _x => simp [Ty.subst] at hu
        | data _x _y => simp [Ty.subst] at hu
    | .fn, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | base _x => simp [Ty.subst] at hu
        | «opaque» _x => simp [Ty.subst] at hu
        | data _x _y => simp [Ty.subst] at hu
        | list _x => simp [Ty.subst] at hu
    | .tvar, t, hu => by
        cases t with
        | tvar i => exact .tvar
        | fn ps r ε => exact .fn
        | base _x => simp [Ty.subst] at hu
        | «opaque» _x => simp [Ty.subst] at hu
        | data _x _y => simp [Ty.subst] at hu
        | list _x => simp [Ty.subst] at hu

  theorem InhabitsAll.of_subst (hwf : P.WellFormed) (ts' : List Ty) (es' : List Eff) {us vs} :
      InhabitsAll P us vs → ∀ tsx : List Ty, us = tsx.map (Ty.subst ts' es') → InhabitsAll P tsx vs
    | .nil, tsx, hu => by
        cases tsx with
        | nil => exact .nil
        | cons _ _ => simp at hu
    | .cons h hs, tsx, hu => by
        cases tsx with
        | nil => simp at hu
        | cons t tsx =>
            simp only [List.map_cons, List.cons.injEq] at hu
            exact .cons (Inhabits.of_subst hwf ts' es' h t hu.1)
              (InhabitsAll.of_subst hwf ts' es' hs tsx hu.2)

  theorem InhabitsEach.of_subst (hwf : P.WellFormed) (ts' : List Ty) (es' : List Eff) {u vs} :
      InhabitsEach P u vs → ∀ t, u = t.subst ts' es' → InhabitsEach P t vs
    | .nil, _, _ => .nil
    | .cons h hs, t, hu =>
        .cons (Inhabits.of_subst hwf ts' es' h t hu) (InhabitsEach.of_subst hwf ts' es' hs t hu)
end

theorem Exhaustive.substTy (hwf : P.WellFormed) (ts' : List Ty) (es' : List Eff) {a ps}
    (h : Exhaustive P a ps) : Exhaustive P (a.subst ts' es') ps :=
  fun v hv => h v (Inhabits.of_subst hwf ts' es' hv a rfl)

/-! ## 値と計算 -/

theorem Comp.substTyArms_fst (ts : List Ty) (es : List Eff) (arms : List (Pat × Comp)) :
    (Comp.substTyArms ts es arms).map Prod.fst = arms.map Prod.fst := by
  induction arms with
  | nil => simp [Comp.substTyArms]
  | cons x xs ih => obtain ⟨p, m⟩ := x; simp [Comp.substTyArms, ih]

mutual
  theorem HasTypeV.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) (ts' : List Ty)
      (es' : List Eff) {Γ v a} (h : HasTypeV P B Γ v a) :
      HasTypeV P B (Γ.map (Ty.subst ts' es')) (v.substTy ts' es') (a.subst ts' es') := by
    match h with
    | .V_Var hi =>
        simp only [Val.substTy]; exact .V_Var (by simp [hi])
    | .V_Const => simp only [Val.substTy]; rw [Const.type_subst]; exact .V_Const
    | .V_Fun hd hts hes =>
        simp only [Val.substTy]
        have hsc := hwf.1 _ _ hd
        unfold Def.Scoped at hsc
        rw [fnTy_subst ⟨hsc.1, hsc.2.1, hsc.2.2.1⟩ hts hes]
        exact .V_Fun hd (by simpa using hts) (by simpa using hes)
    | .V_Prim hs hts hes had =>
        simp only [Val.substTy]
        have hsc := hb.sig_scoped _ _ hs
        unfold PrimSig.Scoped at hsc
        rw [fnTy_subst hsc hts hes]
        exact .V_Prim hs (by simpa using hts) (by simpa using hes) (hb.admits_subst _ _ _ _ _ hs had)
    | .V_Lam hb' =>
        simp only [Val.substTy, Ty.subst]
        refine .V_Lam ?_
        have := HasTypeC.substTy hwf hb ts' es' hb'
        simpa [List.map_append, List.map_reverse] using this
    | .V_Con (cd := cd) hc hts hargs =>
        simp only [Val.substTy, Ty.subst]
        refine .V_Con hc (by simpa using hts) ?_
        rw [← ConDecl.args_subst (hwf.2 _ _ hc) hts]
        exact HasTypeVs.substTy hwf hb ts' es' hargs
    | .V_List he =>
        simp only [Val.substTy, Ty.subst]; exact .V_List (HasTypeEach.substTy hwf hb ts' es' he)
    | .V_Sub h hle => exact .V_Sub (HasTypeV.substTy hwf hb ts' es' h) (hle.subst ts' es')

  theorem HasTypeVs.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) (ts' : List Ty)
      (es' : List Eff) {Γ vs as} (h : HasTypeVs P B Γ vs as) :
      HasTypeVs P B (Γ.map (Ty.subst ts' es')) (Val.substTyList ts' es' vs)
        (as.map (Ty.subst ts' es')) := by
    match h with
    | .nil => simp only [Val.substTyList, List.map_nil]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substTyList, List.map_cons]
        exact .cons (HasTypeV.substTy hwf hb ts' es' hv) (HasTypeVs.substTy hwf hb ts' es' hvs)

  theorem HasTypeEach.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) (ts' : List Ty)
      (es' : List Eff) {Γ vs a} (h : HasTypeEach P B Γ vs a) :
      HasTypeEach P B (Γ.map (Ty.subst ts' es')) (Val.substTyList ts' es' vs)
        (a.subst ts' es') := by
    match h with
    | .nil => simp only [Val.substTyList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substTyList]
        exact .cons (HasTypeV.substTy hwf hb ts' es' hv) (HasTypeEach.substTy hwf hb ts' es' hvs)

  theorem HasTypeC.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) (ts' : List Ty)
      (es' : List Eff) {Γ m a ε} (h : HasTypeC P B Γ m a ε) :
      HasTypeC P B (Γ.map (Ty.subst ts' es')) (m.substTy ts' es') (a.subst ts' es')
        (Eff.substRho es' ε) := by
    match h with
    | .C_Return hv =>
        simp only [Comp.substTy]; rw [Eff.substRho_empty]
        exact .C_Return (HasTypeV.substTy hwf hb ts' es' hv)
    | .C_Sub h hle hs =>
        exact .C_Sub (HasTypeC.substTy hwf hb ts' es' h) (hle.subst ts' es')
          (Eff.substRho_mono es' hs)
    | .C_Let hm hn =>
        simp only [Comp.substTy]
        exact .C_Let (HasTypeC.substTy hwf hb ts' es' hm) (HasTypeC.substTy hwf hb ts' es' hn)
    | .C_App hf hargs =>
        simp only [Comp.substTy]
        have := HasTypeV.substTy hwf hb ts' es' hf
        simp only [Ty.subst] at this
        exact .C_App this (HasTypeVs.substTy hwf hb ts' es' hargs)
    | .C_If hv hm hn =>
        simp only [Comp.substTy]
        have := HasTypeV.substTy hwf hb ts' es' hv
        simp only [Ty.subst] at this
        exact .C_If this (HasTypeC.substTy hwf hb ts' es' hm) (HasTypeC.substTy hwf hb ts' es' hn)
    | .C_Match hv harms hex =>
        simp only [Comp.substTy]
        refine .C_Match (HasTypeV.substTy hwf hb ts' es' hv)
          (HasTypeArms.substTy hwf hb ts' es' harms) ?_
        rw [Comp.substTyArms_fst]
        exact hex.substTy hwf ts' es'

  theorem HasTypeArms.substTy (hwf : P.WellFormed) (hb : B.Assumptions P) (ts' : List Ty)
      (es' : List Eff) {Γ arms a b ε} (h : HasTypeArms P B Γ arms a b ε) :
      HasTypeArms P B (Γ.map (Ty.subst ts' es')) (Comp.substTyArms ts' es' arms)
        (a.subst ts' es') (b.subst ts' es') (Eff.substRho es' ε) := by
    match h with
    | .nil => simp only [Comp.substTyArms]; exact .nil
    | .cons hp hm harms =>
        simp only [Comp.substTyArms]
        refine .cons (PatTy.substTy hwf ts' es' hp) ?_ (HasTypeArms.substTy hwf hb ts' es' harms)
        have := HasTypeC.substTy hwf hb ts' es' hm
        simpa [List.map_append, List.map_reverse] using this
end

end Benitoite.Core
