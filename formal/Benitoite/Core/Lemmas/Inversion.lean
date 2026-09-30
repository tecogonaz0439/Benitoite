import Benitoite.Core.Lemmas.Basic

/-!
# 型付けの逆転の補題

V-Sub と C-Sub は項の形によらずに使えるので、項の形から型付けの前提を取り出すには、
包含の規則を何回か通した後の形を扱う必要がある。ここでは、項の形ごとに、元の規則の前提と、
元の型からの包含を取り出す。
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

theorem fnTy_eq (ps : List Ty) (r : Ty) (ε : Eff) (ts : List Ty) (es : List Eff) :
    fnTy ps r ε ts es = .fn (ps.map (Ty.subst ts es)) (Ty.subst ts es r) (Eff.substRho es ε) := by
  simp [fnTy, Ty.subst]

/-! ## 値 -/

theorem HasTypeV.inv_var {Γ v T i} (h : HasTypeV P B Γ v T) (hv : v = .var i) :
    ∃ a, Γ[i]? = some a ∧ Ty.Le a T := by
  match h with
  | .V_Var hi => cases hv; exact ⟨_, hi, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨a, hi, hle'⟩ := inv_var h hv
      exact ⟨a, hi, hle'.trans hle⟩
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ => cases hv

theorem HasTypeV.inv_const {Γ v T c} (h : HasTypeV P B Γ v T) (hv : v = .const c) :
    Ty.Le c.type T := by
  match h with
  | .V_Const => cases hv; exact Ty.Le.refl _
  | .V_Sub h hle => exact (inv_const h hv).trans hle
  | .V_Var _ => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ => cases hv

theorem HasTypeV.inv_fnRef {Γ v T f ts es} (h : HasTypeV P B Γ v T) (hv : v = .fnRef f ts es) :
    ∃ d, P.defs f = some d ∧ ts.length = d.ntys ∧ es.length = d.neffs ∧
      Ty.Le (fnTy d.params d.ret d.eff ts es) T := by
  match h with
  | .V_Fun hd hts hes => cases hv; exact ⟨_, hd, hts, hes, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨d, hd, hts, hes, hle'⟩ := inv_fnRef h hv
      exact ⟨d, hd, hts, hes, hle'.trans hle⟩
  | .V_Var _ => cases hv
  | .V_Const => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ => cases hv

theorem HasTypeV.inv_prim {Γ v T b ts es} (h : HasTypeV P B Γ v T) (hv : v = .prim b ts es) :
    ∃ s, B.sig b = some s ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧ s.admits ts ∧
      Ty.Le (fnTy s.params s.ret s.eff ts es) T := by
  match h with
  | .V_Prim hs hts hes had => cases hv; exact ⟨_, hs, hts, hes, had, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨s, hs, hts, hes, had, hle'⟩ := inv_prim h hv
      exact ⟨s, hs, hts, hes, had, hle'.trans hle⟩
  | .V_Var _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ => cases hv

theorem HasTypeV.inv_lam {Γ v T ps body} (h : HasTypeV P B Γ v T) (hv : v = .lam ps body) :
    ∃ r ε, HasTypeC P B (ps.reverse ++ Γ) body r ε ∧ Ty.Le (.fn ps r ε) T := by
  match h with
  | .V_Lam h => cases hv; exact ⟨_, _, h, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨r, ε, hb, hle'⟩ := inv_lam h hv
      exact ⟨r, ε, hb, hle'.trans hle⟩
  | .V_Var _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ => cases hv

theorem HasTypeV.inv_con {Γ v T c ts args} (h : HasTypeV P B Γ v T) (hv : v = .con c ts args) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      HasTypeVs P B Γ args (cd.args.map (Ty.subst ts [])) ∧ T = .data cd.data ts := by
  match h with
  | .V_Con hc hts hargs => cases hv; exact ⟨_, hc, hts, hargs, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨cd, hc, hts, hargs, rfl⟩ := inv_con h hv
      exact ⟨cd, hc, hts, hargs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_List _ => cases hv

theorem HasTypeV.inv_list {Γ v T elems} (h : HasTypeV P B Γ v T) (hv : v = .list elems) :
    ∃ a, HasTypeEach P B Γ elems a ∧ T = .list a := by
  match h with
  | .V_List h => cases hv; exact ⟨_, h, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨a, he, rfl⟩ := inv_list h hv
      exact ⟨a, he, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv

/-! ## 計算 -/

theorem HasTypeC.inv_ret {Γ m T ε v} (h : HasTypeC P B Γ m T ε) (hm : m = .ret v) :
    ∃ a, HasTypeV P B Γ v a ∧ Ty.Le a T := by
  match h with
  | .C_Return hv => cases hm; exact ⟨_, hv, Ty.Le.refl _⟩
  | .C_Sub h hle _ =>
      obtain ⟨a, hv, hle'⟩ := inv_ret h hm
      exact ⟨a, hv, hle'.trans hle⟩
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm

theorem HasTypeC.inv_let {Γ m' T ε m n} (h : HasTypeC P B Γ m' T ε) (hm : m' = .letIn m n) :
    ∃ a b ε', HasTypeC P B Γ m a ε' ∧ HasTypeC P B (a :: Γ) n b ε' ∧ Ty.Le b T ∧
      Eff.Sub ε' ε := by
  match h with
  | .C_Let hm' hn => cases hm; exact ⟨_, _, _, hm', hn, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨a, b, ε', h1, h2, hle', hs'⟩ := inv_let h hm
      exact ⟨a, b, ε', h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm

theorem HasTypeC.inv_app {Γ m T ε f args} (h : HasTypeC P B Γ m T ε) (hm : m = .app f args) :
    ∃ as b ε', HasTypeV P B Γ f (.fn as b ε') ∧ HasTypeVs P B Γ args as ∧ Ty.Le b T ∧
      Eff.Sub ε' ε := by
  match h with
  | .C_App hf hargs => cases hm; exact ⟨_, _, _, hf, hargs, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨as, b, ε', h1, h2, hle', hs'⟩ := inv_app h hm
      exact ⟨as, b, ε', h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm

theorem HasTypeC.inv_ite {Γ m' T ε v m n} (h : HasTypeC P B Γ m' T ε) (hm : m' = .ite v m n) :
    ∃ a ε', HasTypeV P B Γ v (.base .boolean) ∧ HasTypeC P B Γ m a ε' ∧ HasTypeC P B Γ n a ε' ∧
      Ty.Le a T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_If hv h1 h2 => cases hm; exact ⟨_, _, hv, h1, h2, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨a, ε', hv, h1, h2, hle', hs'⟩ := inv_ite h hm
      exact ⟨a, ε', hv, h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_Match _ _ _ => cases hm

theorem HasTypeC.inv_match {Γ m T ε v arms} (h : HasTypeC P B Γ m T ε) (hm : m = .match v arms) :
    ∃ a b ε', HasTypeV P B Γ v a ∧ HasTypeArms P B Γ arms a b ε' ∧
      Exhaustive P a (arms.map Prod.fst) ∧ Ty.Le b T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_Match hv harms hex => cases hm; exact ⟨_, _, _, hv, harms, hex, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨a, b, ε', hv, harms, hex, hle', hs'⟩ := inv_match h hm
      exact ⟨a, b, ε', hv, harms, hex, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm

end Benitoite.Core
