import Benitoite.Release.Lemmas.Basic

/-!
# 型付けの逆転の補題（段階 B）

段階 A の逆転の補題を、段階 B の構成に広げる。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins} {Ψ : StoreTy}

theorem fnTy_eq (ps : List Ty) (r : Ty) (ε : Eff) (ts : List Ty) (es : List Eff) :
    fnTy ps r ε ts es = .fn (ps.map (Ty.subst ts es)) (Ty.subst ts es r) (Eff.substRho es ε) := by
  simp [fnTy, Ty.subst, Ty.substAt]

/-! ## 値 -/

theorem HasTypeV.inv_var {C Γ v T i} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .var i) :
    ∃ a, Γ[i]? = some (some a) ∧ (∀ b t ε, a ≠ .cont b t ε) ∧ Ty.Le a T := by
  match h with
  | .V_Var hi hc => cases hv; exact ⟨_, hi, hc, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨a, hi, hc, hle'⟩ := inv_var h hv
      exact ⟨a, hi, hc, hle'.trans hle⟩
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_const {C Γ v T c} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .const c) :
    Ty.Le c.type T := by
  match h with
  | .V_Const => cases hv; exact Ty.Le.refl _
  | .V_Sub h hle => exact (inv_const h hv).trans hle
  | .V_Var _ _ => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_fnRef {C Γ v T f ts es} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .fnRef f ts es) :
    ∃ d, P.defs f = some d ∧ SatAll B C ts d.tparams ∧ es.length = d.neffs ∧
      Ty.Le (fnTy d.params d.ret d.eff ts es) T := by
  match h with
  | .V_Fun hd hts hes => cases hv; exact ⟨_, hd, hts, hes, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨d, hd, hts, hes, hle'⟩ := inv_fnRef h hv
      exact ⟨d, hd, hts, hes, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_prim {C Γ v T b ts es} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .prim b ts es) :
    ∃ s, B.sig b = some s ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧ s.admits C ts ∧
      Ty.Le (fnTy s.params s.ret s.eff ts es) T := by
  match h with
  | .V_Prim hs hts hes had => cases hv; exact ⟨_, hs, hts, hes, had, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨s, hs, hts, hes, had, hle'⟩ := inv_prim h hv
      exact ⟨s, hs, hts, hes, had, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_op {C Γ v T o ts} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .op o ts) :
    ∃ od, P.ops o = some od ∧ SatAll B C ts od.tparams ∧
      Ty.Le (fnTy od.params od.ret (Eff.single od.eff) ts []) T := by
  match h with
  | .V_Op hod hts => cases hv; exact ⟨_, hod, hts, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨od, hod, hts, hle'⟩ := inv_op h hv
      exact ⟨od, hod, hts, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_lam {C Γ v T ps body} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .lam ps body) :
    ∃ r ε, HasTypeC P B Ψ C (binds ps ++ hideConts Γ) (some r) body r ε ∧ Ty.Le (.fn ps r ε) T := by
  match h with
  | .V_Lam h => cases hv; exact ⟨_, _, h, Ty.Le.refl _⟩
  | .V_Sub h hle =>
      obtain ⟨r, ε, hb, hle'⟩ := inv_lam h hv
      exact ⟨r, ε, hb, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_con {C Γ v T c ts args} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .con c ts args) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      HasTypeVs P B Ψ C Γ args (cd.args.map (Ty.subst ts [])) ∧ T = .data cd.data ts := by
  match h with
  | .V_Con hc hts hargs => cases hv; exact ⟨_, hc, hts, hargs, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨cd, hc, hts, hargs, rfl⟩ := inv_con h hv
      exact ⟨cd, hc, hts, hargs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_list {C Γ v T elems} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .list elems) :
    ∃ a, HasTypeEach P B Ψ C Γ elems a ∧ T = .list a := by
  match h with
  | .V_List h _ => cases hv; exact ⟨_, h, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨a, he, rfl⟩ := inv_list h hv
      exact ⟨a, he, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeV.inv_loc {C Γ v T l} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .loc l) :
    (∃ a, Ψ l = some (.ref a) ∧ T = .reference a) ∨ (∃ a, Ψ l = some (.lazy a) ∧ T = .lazy a) := by
  match h with
  | .V_LocRef hl => cases hv; exact Or.inl ⟨_, hl, rfl⟩
  | .V_LocLazy hl => cases hv; exact Or.inr ⟨_, hl, rfl⟩
  | .V_Sub h hle =>
      rcases inv_loc h hv with ⟨a, hl, rfl⟩ | ⟨a, hl, rfl⟩
      · exact Or.inl ⟨a, hl, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
      · exact Or.inr ⟨a, hl, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv

/-! ## 計算 -/

/-- 計算の型付けを、C-Sub を通した後の形から取り出すための共通の形。`Q m a ε` が項の形ごとの前提で、
結果の型と効果は包含で広がる。 -/
theorem HasTypeC.inv_ret {C Γ R m T ε v} (h : HasTypeC P B Ψ C Γ R m T ε) (hm : m = .ret v) :
    ∃ a, HasTypeV P B Ψ C Γ v a ∧ Ty.Le a T := by
  match h with
  | .C_Return hv => cases hm; exact ⟨_, hv, Ty.Le.refl _⟩
  | .C_Sub h hle _ =>
      obtain ⟨a, hv, hle'⟩ := inv_ret h hm
      exact ⟨a, hv, hle'.trans hle⟩
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_let {C Γ R m' T ε m n} (h : HasTypeC P B Ψ C Γ R m' T ε) (hm : m' = .letIn m n) :
    ∃ a b ε', HasTypeC P B Ψ C Γ R m a ε' ∧ HasTypeC P B Ψ C (some a :: Γ) R n b ε' ∧
      Ty.Le b T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_Let hm' hn => cases hm; exact ⟨_, _, _, hm', hn, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨a, b, ε', h1, h2, hle', hs'⟩ := inv_let h hm
      exact ⟨a, b, ε', h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_app {C Γ R m T ε f args} (h : HasTypeC P B Ψ C Γ R m T ε) (hm : m = .app f args) :
    ∃ as b ε', HasTypeV P B Ψ C Γ f (.fn as b ε') ∧ HasTypeVs P B Ψ C Γ args as ∧ Ty.Le b T ∧
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
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_ite {C Γ R m' T ε v m n} (h : HasTypeC P B Ψ C Γ R m' T ε) (hm : m' = .ite v m n) :
    ∃ a ε', HasTypeV P B Ψ C Γ v (.base .boolean) ∧ HasTypeC P B Ψ C Γ R m a ε' ∧
      HasTypeC P B Ψ C Γ R n a ε' ∧ Ty.Le a T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_If hv h1 h2 => cases hm; exact ⟨_, _, hv, h1, h2, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨a, ε', hv, h1, h2, hle', hs'⟩ := inv_ite h hm
      exact ⟨a, ε', hv, h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_match {C Γ R m T ε v arms} (h : HasTypeC P B Ψ C Γ R m T ε)
    (hm : m = .match v arms) :
    ∃ a b ε', HasTypeV P B Ψ C Γ v a ∧ HasTypeArms P B Ψ C Γ R arms a b ε' ∧
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
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_lazy {C Γ R m' T ε m} (h : HasTypeC P B Ψ C Γ R m' T ε) (hm : m' = .lazyC m) :
    ∃ a, HasTypeC P B Ψ C (hideConts Γ) none m a Eff.empty ∧ T = .lazy a := by
  match h with
  | .C_Lazy h => cases hm; exact ⟨_, h, rfl⟩
  | .C_Sub h hle _ =>
      obtain ⟨a, h1, rfl⟩ := inv_lazy h hm
      exact ⟨a, h1, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_escape {C Γ R m T ε v} (h : HasTypeC P B Ψ C Γ R m T ε) (hm : m = .escape v) :
    ∃ r, R = some r ∧ HasTypeV P B Ψ C Γ v r := by
  match h with
  | .C_Escape hv _ => cases hm; exact ⟨_, rfl, hv⟩
  | .C_Sub h _ _ => exact inv_escape h hm
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_use {C Γ R m' T ε v m} (h : HasTypeC P B Ψ C Γ R m' T ε) (hm : m' = .use v m) :
    ∃ o b ε', HasTypeV P B Ψ C Γ v (.opaque o) ∧ B.isResource o = true ∧
      HasTypeC P B Ψ C Γ R m b ε' ∧ ε' (.name stateEff) = true ∧ Ty.Le b T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_Use hv hr hm' hs => cases hm; exact ⟨_, _, _, hv, hr, hm', hs, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨o, b, ε', hv, hr, h1, hst, hle', hs'⟩ := inv_use h hm
      exact ⟨o, b, ε', hv, hr, h1, hst, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Handle _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_handle {C Γ R m' T ε m h} (hh : HasTypeC P B Ψ C Γ R m' T ε)
    (hm : m' = .handle m h) :
    ∃ t εm ε', HasTypeC P B Ψ C Γ R m t εm ∧ Eff.Sub εm (Eff.union ε' (handled P B h)) ∧
      HasTypeClauses P B Ψ C Γ R h t ε' ∧ Ty.Le t T ∧ Eff.Sub ε' ε := by
  match hh with
  | .C_Handle h1 hs hc => cases hm; exact ⟨_, _, _, h1, hs, hc, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h' hle hs =>
      obtain ⟨t, εm, ε', h1, hs1, hc, hle', hs'⟩ := inv_handle h' hm
      exact ⟨t, εm, ε', h1, hs1, hc, hle'.trans hle, hs'.trans hs⟩
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Resume _ _ => cases hm
  | .C_ResumeL _ _ => cases hm

theorem HasTypeC.inv_resumeL {C Γ R m T ε l v} (h : HasTypeC P B Ψ C Γ R m T ε)
    (hm : m = .resume (.loc l) v) :
    ∃ b t ε', Ψ l = some (.cont b t ε' R) ∧ HasTypeV P B Ψ C Γ v b ∧ Ty.Le t T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_ResumeL hl hv => cases hm; exact ⟨_, _, _, hl, hv, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨b, t, ε', hl, hv, hle', hs'⟩ := inv_resumeL h hm
      exact ⟨b, t, ε', hl, hv, hle'.trans hle, hs'.trans hs⟩
  | .C_Resume _ _ => cases hm
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm

theorem HasTypeC.inv_resumeVar {C Γ R m T ε i v} (h : HasTypeC P B Ψ C Γ R m T ε)
    (hm : m = .resume (.var i) v) :
    ∃ b t ε', Γ[i]? = some (some (.cont b t ε')) ∧ HasTypeV P B Ψ C Γ v b ∧ Ty.Le t T ∧
      Eff.Sub ε' ε := by
  match h with
  | .C_Resume hi hv => cases hm; exact ⟨_, _, _, hi, hv, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨b, t, ε', hi, hv, hle', hs'⟩ := inv_resumeVar h hm
      exact ⟨b, t, ε', hi, hv, hle'.trans hle, hs'.trans hs⟩
  | .C_ResumeL _ _ => cases hm
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm

/-! ## 段階 B2 の値と計算 -/

theorem HasTypeV.inv_mapV {C Γ v T ks vs} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .mapV ks vs) :
    ∃ a b, T = .map a b := by
  match h with
  | .V_Map _ _ _ _ _ _ => cases hv; exact ⟨_, _, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨a, b, rfl⟩ := inv_mapV h hv
      exact ⟨a, b, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeV.inv_setV {C Γ v T elems} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .setV elems) :
    ∃ a, T = .set a := by
  match h with
  | .V_Set _ _ _ => cases hv; exact ⟨_, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨a, rfl⟩ := inv_setV h hv
      exact ⟨a, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeV.inv_bytesV {C Γ v T bs} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .bytesV bs) :
    T = .bytes := by
  match h with
  | .V_Bytes => rfl
  | .V_Sub h hle =>
      have := inv_bytesV h hv
      subst this
      exact (hle.eq_of_not_fn_left (by intros; simp)).symm

theorem HasTypeV.inv_dict {C Γ v T i ts vs} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .dict i ts vs) :
    ∃ id, P.impls i = some id ∧ SatAll B C ts id.tparams ∧
      HasTypeVs P B Ψ C Γ vs (id.dictTys.map (Ty.subst ts [])) ∧ T = .dict id.cls (id.target.subst ts []) := by
  match h with
  | .V_Dict hi hts hvs => cases hv; exact ⟨_, hi, hts, hvs, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨id, hi, hts, hvs, rfl⟩ := inv_dict h hv
      exact ⟨id, hi, hts, hvs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeV.inv_super {C Γ v T w s} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .super w s) :
    ∃ cl τ cd, HasTypeV P B Ψ C Γ w (.dict cl τ) ∧ P.classes cl = some cd ∧ s ∈ cd.supers ∧
      T = .dict s τ := by
  match h with
  | .V_Super hw hc hs => cases hv; exact ⟨_, _, _, hw, hc, hs, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨cl, τ, cd, hw, hc, hs, rfl⟩ := inv_super h hv
      exact ⟨cl, τ, cd, hw, hc, hs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeC.inv_meth {C Γ R m' T ε v m ss es ws} (h : HasTypeC P B Ψ C Γ R m' T ε)
    (hm : m' = .meth v m ss es ws) :
    ∃ cl τ cd ms, HasTypeV P B Ψ C Γ v (.dict cl τ) ∧ P.classes cl = some cd ∧ cd.methods m = some ms ∧
      SatAll B C ss ms.tparams ∧ es.length = ms.neffs ∧
      HasTypeVs P B Ψ C Γ ws (ms.params.map (Ty.subst (ss ++ [τ]) es)) ∧
      Ty.Le (ms.ret.subst (ss ++ [τ]) es) T ∧ Eff.Sub (Eff.substRho es ms.eff) ε := by
  match h with
  | .C_Meth hv hc hms hsat hes hws =>
      cases hm; exact ⟨_, _, _, _, hv, hc, hms, hsat, hes, hws, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs =>
      obtain ⟨cl, τ, cd, ms, hv, hc, hms, hsat, hes, hws, hle', hs'⟩ := inv_meth h hm
      exact ⟨cl, τ, cd, ms, hv, hc, hms, hsat, hes, hws, hle'.trans hle, hs'.trans hs⟩

end Benitoite.Release
