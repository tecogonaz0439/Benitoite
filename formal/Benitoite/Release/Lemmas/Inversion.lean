import Benitoite.Release.Lemmas.Basic

/-!
# 型付けの逆転の補題（契約名を持つコア）

段階 A の逆転の補題を、段階 B の構成に広げる。

名前の整形式と契約名を型付けの導出から取り出す。包含を経由しても同じ名前の並びを保持する
（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Program} {B : Builtins} {Ψ : StoreTy}

theorem fnTy_eq (names : List String) (ps : List Ty) (r : Ty) (ε : Eff) (ts : List Ty) (es : List Eff) :
    fnTy names ps r ε ts es = .fn names (ps.map (Ty.subst ts es)) (Ty.subst ts es r) (Eff.substAt 0 ts es ε) := by
  simp [fnTy, Ty.subst, Ty.substAt]

/-! ## 値 -/

theorem HasTypeVQ.inv_var {C Γ v T i} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .var i) :
    ∃ a, Γ[i]? = some (some a) ∧ (∀ b t ε, a ≠ .cont b t ε) ∧ Ty.Le a T := by
  match h with
  | .V_Var hi hc => cases hv; exact ⟨_, hi, hc, Ty.Le.refl _⟩
  | .V_Sub h hle _ =>
      obtain ⟨a, hi, hc, hle'⟩ := inv_var h hv
      exact ⟨a, hi, hc, hle'.trans hle⟩
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_const {C Γ v T c} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .const c) :
    Ty.Le c.type T := by
  match h with
  | .V_Const => cases hv; exact Ty.Le.refl _
  | .V_Sub h hle _ => exact (inv_const h hv).trans hle
  | .V_Var _ _ => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_fnRef {C Γ v T f ts es} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .fnRef f ts es) :
    ∃ d, P.defs f = some d ∧ SatAll B C ts d.tparams ∧ es.length = d.neffs ∧ NamesWF d.names d.params ∧
      Ty.Le (fnTy d.names d.params d.ret d.eff ts es) T := by
  match h with
  | .V_Fun hd hnames had => cases hv; exact ⟨_, hd, had.types, had.rowCount, hnames, Ty.Le.refl _⟩
  | .V_Sub h hle _ =>
      obtain ⟨d, hd, hts, hes, hnames, hle'⟩ := inv_fnRef h hv
      exact ⟨d, hd, hts, hes, hnames, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.fnRef_admissible {C Γ v T f ts es} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .fnRef f ts es) :
    ∃ d, P.defs f = some d ∧
      Admissible B C d.tparams d.neffs (Qsig d.params d.ret d.eff) Q ts es d.eff := by
  match h with
  | .V_Fun hd _ had => cases hv; exact ⟨_, hd, had⟩
  | .V_Sub h _ _ => exact fnRef_admissible h hv
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_prim {C Γ v T b ts es} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .prim b ts es) :
    ∃ s, B.sig b = some s ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧ s.admits C ts ∧ NamesWF s.names s.params ∧
      Ty.Le (fnTy s.names s.params s.ret s.eff ts es) T := by
  match h with
  | .V_Prim hs hnames had => cases hv; exact ⟨_, hs, had.typeCount, had.rowCount, had.admits, hnames, Ty.Le.refl _⟩
  | .V_Sub h hle _ =>
      obtain ⟨s, hs, hts, hes, had, hnames, hle'⟩ := inv_prim h hv
      exact ⟨s, hs, hts, hes, had, hnames, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_op {C Γ v T o ts} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .op o ts) :
    ∃ od, P.ops o = some od ∧ SatAll B C ts od.tparams ∧ NamesWF od.names od.params ∧
      Ty.Le (fnTy od.names od.params od.ret (Eff.single od.eff) ts []) T := by
  match h with
  | .V_Op hod hnames hts => cases hv; exact ⟨_, hod, hts, hnames, Ty.Le.refl _⟩
  | .V_Sub h hle _ =>
      obtain ⟨od, hod, hts, hnames, hle'⟩ := inv_op h hv
      exact ⟨od, hod, hts, hnames, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_lam_wf {C Γ v T names ps body} (h : HasTypeVQ P B Ψ Q C Γ v T)
    (hv : v = .lam names ps body) :
    ∃ r ε, Ty.WF C.length (.fn names ps r ε) ∧ NamesWF names ps ∧
      HasTypeCQ P B Ψ.hideBuilders Q C (binds ps ++ hideConts Γ) (some r) body r ε ∧ Ty.Le (.fn names ps r ε) T := by
  match h with
  | .V_Lam hnames hw h => cases hv; exact ⟨_, _, hw, hnames, h, Ty.Le.refl _⟩
  | .V_Sub h hle _ =>
      obtain ⟨r, ε, hwf, hnames, hb, hle'⟩ := inv_lam_wf h hv
      exact ⟨r, ε, hwf, hnames, hb, hle'.trans hle⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

/-- 従来の逆転の結論を保つ入口。整形式の証拠が要る保存の証明はinv_lam_wfを使う。 -/
theorem HasTypeVQ.inv_lam {C Γ v T names ps body} (h : HasTypeVQ P B Ψ Q C Γ v T)
    (hv : v = .lam names ps body) :
    ∃ r ε, NamesWF names ps ∧ HasTypeCQ P B Ψ.hideBuilders Q C (binds ps ++ hideConts Γ) (some r) body r ε ∧
      Ty.Le (.fn names ps r ε) T := by
  obtain ⟨r, ε, _, hn, hb, hl⟩ := h.inv_lam_wf hv
  exact ⟨r, ε, hn, hb, hl⟩

theorem HasTypeVQ.inv_con {C Γ v T c ts args} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .con c ts args) :
    ∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      HasTypeVsQ P B Ψ Q C Γ args (cd.args.map (Ty.subst ts [])) ∧ T = .data cd.data ts := by
  match h with
  | .V_Con hc hts hargs => cases hv; exact ⟨_, hc, hts, hargs, rfl⟩
  | .V_Sub h hle _ =>
      obtain ⟨cd, hc, hts, hargs, rfl⟩ := inv_con h hv
      exact ⟨cd, hc, hts, hargs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_List _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_list {C Γ v T elems} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .list elems) :
    ∃ a, HasTypeEachQ P B Ψ Q C Γ elems a ∧ T = .list a := by
  match h with
  | .V_List h _ => cases hv; exact ⟨_, h, rfl⟩
  | .V_Sub h hle _ =>
      obtain ⟨a, he, rfl⟩ := inv_list h hv
      exact ⟨a, he, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

theorem HasTypeVQ.inv_loc {C Γ v T l} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .loc l) :
    (∃ a, Ψ l = some (.ref a) ∧ T = .reference a) ∨ (∃ a, Ψ l = some (.lazy a) ∧ T = .lazy a) := by
  match h with
  | .V_LocRef hl => cases hv; exact Or.inl ⟨_, hl, rfl⟩
  | .V_LocLazy hl => cases hv; exact Or.inr ⟨_, hl, rfl⟩
  | .V_Sub h hle _ =>
      rcases inv_loc h hv with ⟨a, hl, rfl⟩ | ⟨a, hl, rfl⟩
      · exact Or.inl ⟨a, hl, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
      · exact Or.inr ⟨a, hl, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun .. => cases hv
  | .V_Prim .. => cases hv
  | .V_Op _ _ _ => cases hv
  | .V_Lam _ _ _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_List _ _ => cases hv

/-! ## 計算 -/

/-- 計算の型付けを、C-Sub を通した後の形から取り出すための共通の形。`Q m a ε` が項の形ごとの前提で、
結果の型と効果は包含で広がる。 -/
theorem HasTypeCQ.inv_ret {Δl : LocalCtx} {C Γ R m T ε v} (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl) (hm : m = .ret v) :
    ∃ a, HasTypeVQ P B Ψ Q C Γ v a ∧ Ty.Le a T := by
  match h with
  | .C_Return hv => cases hm; exact ⟨_, hv, Ty.Le.refl _⟩
  | .C_Sub h hle _ _ =>
      obtain ⟨a, hv, hle'⟩ := inv_ret h hm
      exact ⟨a, hv, hle'.trans hle⟩
  | .C_Eff h _ => exact inv_ret h hm
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_let {Δl : LocalCtx} {C Γ R m' T ε m n} (h : HasTypeCQ P B Ψ Q C Γ R m' T ε Δl) (hm : m' = .letIn m n) :
    ∃ a b ε', HasTypeCQ P B Ψ Q C Γ R m a ε' Δl ∧ HasTypeCQ P B Ψ Q C (some a :: Γ) R n b ε' (LocalCtx.extend 1 Δl) ∧
      Ty.Le b T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_Let hm' hn => cases hm; exact ⟨_, _, _, hm', hn, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨a, b, ε', h1, h2, hle', hs'⟩ := inv_let h hm
      exact ⟨a, b, ε', h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨a, b, ε', h1, h2, hle', hs'⟩ := inv_let h hm
      exact ⟨a, b, ε', h1, h2, hle', hs'.trans hs⟩
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_app {Δl : LocalCtx} {C Γ R m T ε f args} (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl) (hm : m = .app f args) :
    ∃ names as b ε', HasTypeVQ P B Ψ Q C Γ f (.fn names as b ε') ∧ HasTypeVsQ P B Ψ Q C Γ args as ∧ Ty.Le b T ∧
      Eff.Sub ε' ε := by
  match h with
  | .C_App hf hargs => cases hm; exact ⟨_, _, _, _, hf, hargs, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨names, as, b, ε', h1, h2, hle', hs'⟩ := inv_app h hm
      exact ⟨names, as, b, ε', h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨names, as, b, ε', h1, h2, hle', hs'⟩ := inv_app h hm
      exact ⟨names, as, b, ε', h1, h2, hle', hs'.trans hs⟩
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_ite {Δl : LocalCtx} {C Γ R m' T ε v m n} (h : HasTypeCQ P B Ψ Q C Γ R m' T ε Δl) (hm : m' = .ite v m n) :
    ∃ a ε', HasTypeVQ P B Ψ Q C Γ v (.base .boolean) ∧ HasTypeCQ P B Ψ Q C Γ R m a ε' Δl ∧
      HasTypeCQ P B Ψ Q C Γ R n a ε' Δl ∧ Ty.Le a T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_If hv h1 h2 => cases hm; exact ⟨_, _, hv, h1, h2, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨a, ε', hv, h1, h2, hle', hs'⟩ := inv_ite h hm
      exact ⟨a, ε', hv, h1, h2, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨a, ε', hv, h1, h2, hle', hs'⟩ := inv_ite h hm
      exact ⟨a, ε', hv, h1, h2, hle', hs'.trans hs⟩
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_match {Δl : LocalCtx} {C Γ R m T ε v arms} (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl)
    (hm : m = .match v arms) :
    ∃ a b ε', HasTypeVQ P B Ψ Q C Γ v a ∧ HasTypeArmsQ P B Ψ Q C Γ R arms a b ε' Δl ∧
      Exhaustive P a (unguardedPats arms) ∧ Ty.Le b T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_Match hv harms hex => cases hm; exact ⟨_, _, _, hv, harms, hex, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨a, b, ε', hv, harms, hex, hle', hs'⟩ := inv_match h hm
      exact ⟨a, b, ε', hv, harms, hex, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨a, b, ε', hv, harms, hex, hle', hs'⟩ := inv_match h hm
      exact ⟨a, b, ε', hv, harms, hex, hle', hs'.trans hs⟩
  | .C_Return _ | .C_Let _ _ | .C_App _ _ | .C_If _ _ _ | .C_Lazy _
  | .C_Escape _ _ | .C_Use _ _ _ _ | .C_Handle _ _ _ | .C_Resume _ _ | .C_ResumeL _ _
  | .C_Meth .. | .C_BuilderLet .. | .C_BuilderOp .. => cases hm

theorem HasTypeCQ.inv_lazy {Δl : LocalCtx} {C Γ R m' T ε m} (h : HasTypeCQ P B Ψ Q C Γ R m' T ε Δl) (hm : m' = .lazyC m) :
    ∃ a, HasTypeCQ P B Ψ.hideBuilders Q C (hideConts Γ) none m a Eff.empty ∧ T = .lazy a := by
  match h with
  | .C_Lazy h => cases hm; exact ⟨_, h, rfl⟩
  | .C_Sub h hle _ _ =>
      obtain ⟨a, h1, rfl⟩ := inv_lazy h hm
      exact ⟨a, h1, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .C_Eff h _ => exact inv_lazy h hm
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_escape {Δl : LocalCtx} {C Γ R m T ε v} (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl) (hm : m = .escape v) :
    ∃ r, R = some r ∧ HasTypeVQ P B Ψ Q C Γ v r := by
  match h with
  | .C_Escape hv _ => cases hm; exact ⟨_, rfl, hv⟩
  | .C_Sub h _ _ hw => exact inv_escape h hm
  | .C_Eff h _ => exact inv_escape h hm
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_use {Δl : LocalCtx} {C Γ R m' T ε v m} (h : HasTypeCQ P B Ψ Q C Γ R m' T ε Δl) (hm : m' = .use v m) :
    ∃ o b ε', HasTypeVQ P B Ψ Q C Γ v (.opaque o) ∧ B.isResource o = true ∧
      HasTypeCQ P B Ψ Q C Γ R m b ε' Δl ∧ Eff.mem ε' (.name stateEff) ∧ Ty.Le b T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_Use hv hr hm' hs => cases hm; exact ⟨_, _, _, hv, hr, hm', hs, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨o, b, ε', hv, hr, h1, hst, hle', hs'⟩ := inv_use h hm
      exact ⟨o, b, ε', hv, hr, h1, hst, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨o, b, ε', hv, hr, h1, hst, hle', hs'⟩ := inv_use h hm
      exact ⟨o, b, ε', hv, hr, h1, hst, hle', hs'.trans hs⟩
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_handle {Δl : LocalCtx} {C Γ R m' T ε m h} (hh : HasTypeCQ P B Ψ Q C Γ R m' T ε Δl)
    (hm : m' = .handle m h) (ho : handles h .fail = false) :
    ∃ t εm ε', HasTypeCQ P B Ψ Q C Γ R m t εm Δl ∧ Eff.Sub εm (Eff.union ε' (handled P B h)) ∧
      HasTypeClausesQ P B Ψ Q C Γ R h t ε' Δl ∧ Ty.Le t T ∧ Eff.Sub ε' ε := by
  match hh with
  | .C_Handle h1 hs hc => cases hm; exact ⟨_, _, _, h1, hs, hc, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Handle_Fail _ _ _ hc =>
      cases hm
      cases hc
      simp [handles, Clause.op] at ho
  | .C_Sub h' hle hs _ =>
      obtain ⟨t, εm, ε', h1, hs1, hc, hle', hs'⟩ := inv_handle h' hm ho
      exact ⟨t, εm, ε', h1, hs1, hc, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h' hs =>
      obtain ⟨t, εm, ε', h1, hs1, hc, hle', hs'⟩ := inv_handle h' hm ho
      exact ⟨t, εm, ε', h1, hs1, hc, hle', hs'.trans hs⟩
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeCQ.inv_resumeL {Δl : LocalCtx} {C Γ R m T ε l v} (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl)
    (hm : m = .resume (.loc l) v) :
    ∃ b t ε', Ψ l = some (.cont b t ε' R) ∧ HasTypeVQ P B Ψ Q C Γ v b ∧ Ty.Le t T ∧ Eff.Sub ε' ε := by
  match h with
  | .C_ResumeL hl hv => cases hm; exact ⟨_, _, _, hl, hv, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨b, t, ε', hl, hv, hle', hs'⟩ := inv_resumeL h hm
      exact ⟨b, t, ε', hl, hv, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨b, t, ε', hl, hv, hle', hs'⟩ := inv_resumeL h hm
      exact ⟨b, t, ε', hl, hv, hle', hs'.trans hs⟩
  | .C_Resume _ _ => cases hm
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm

theorem HasTypeCQ.inv_resumeVar {Δl : LocalCtx} {C Γ R m T ε i v} (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl)
    (hm : m = .resume (.var i) v) :
    ∃ b t ε', Γ[i]? = some (some (.cont b t ε')) ∧ HasTypeVQ P B Ψ Q C Γ v b ∧ Ty.Le t T ∧
      Eff.Sub ε' ε := by
  match h with
  | .C_Resume hi hv => cases hm; exact ⟨_, _, _, hi, hv, Ty.Le.refl _, Eff.Sub.refl _⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨b, t, ε', hi, hv, hle', hs'⟩ := inv_resumeVar h hm
      exact ⟨b, t, ε', hi, hv, hle'.trans hle, hs'.trans hs⟩
  | .C_Eff h hs =>
      obtain ⟨b, t, ε', hi, hv, hle', hs'⟩ := inv_resumeVar h hm
      exact ⟨b, t, ε', hi, hv, hle', hs'.trans hs⟩
  | .C_ResumeL _ _ => cases hm
  | .C_BuilderLet .. | .C_BuilderOp .. => cases hm
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

theorem HasTypeVQ.inv_mapV {C Γ v T ks vs} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .mapV ks vs) :
    ∃ a b, T = .map a b := by
  match h with
  | .V_Const => cases hv
  | .V_Map _ _ _ _ _ _ => cases hv; exact ⟨_, _, rfl⟩
  | .V_Sub h hle _ =>
      obtain ⟨a, b, rfl⟩ := inv_mapV h hv
      exact ⟨a, b, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeVQ.inv_setV {C Γ v T elems} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .setV elems) :
    ∃ a, T = .set a := by
  match h with
  | .V_Const => cases hv
  | .V_Set _ _ _ => cases hv; exact ⟨_, rfl⟩
  | .V_Sub h hle _ =>
      obtain ⟨a, rfl⟩ := inv_setV h hv
      exact ⟨a, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeVQ.inv_bytesV {C Γ v T bs} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .bytesV bs) :
    T = .bytes := by
  match h with
  | .V_Const => cases hv
  | .V_Bytes => rfl
  | .V_Sub h hle _ =>
      have := inv_bytesV h hv
      subst this
      exact (hle.eq_of_not_fn_left (by intros; simp)).symm

theorem HasTypeVQ.inv_dict {C Γ v T i ts vs} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .dict i ts vs) :
    ∃ id, P.impls i = some id ∧ SatAll B C ts id.tparams ∧
      HasTypeVsQ P B Ψ Q C Γ vs (id.dictTys.map (Ty.subst ts [])) ∧ T = .dict id.cls (id.target.subst ts []) := by
  match h with
  | .V_Const => cases hv
  | .V_Dict hi hts hvs => cases hv; exact ⟨_, hi, hts, hvs, rfl⟩
  | .V_Sub h hle _ =>
      obtain ⟨id, hi, hts, hvs, rfl⟩ := inv_dict h hv
      exact ⟨id, hi, hts, hvs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeVQ.inv_super {C Γ v T w s} (h : HasTypeVQ P B Ψ Q C Γ v T) (hv : v = .super w s) :
    ∃ cl τ cd, HasTypeVQ P B Ψ Q C Γ w (.dict cl τ) ∧ P.classes cl = some cd ∧ s ∈ cd.supers ∧
      T = .dict s τ := by
  match h with
  | .V_Const => cases hv
  | .V_Super hw hc hs => cases hv; exact ⟨_, _, _, hw, hc, hs, rfl⟩
  | .V_Sub h hle _ =>
      obtain ⟨cl, τ, cd, hw, hc, hs, rfl⟩ := inv_super h hv
      exact ⟨cl, τ, cd, hw, hc, hs, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩

theorem HasTypeCQ.inv_meth {Δl : LocalCtx} {C Γ R m' T ε v m ss es ws} (h : HasTypeCQ P B Ψ Q C Γ R m' T ε Δl)
    (hm : m' = .meth v m ss es ws) :
    ∃ cl τ cd ms, HasTypeVQ P B Ψ Q C Γ v (.dict cl τ) ∧ P.classes cl = some cd ∧ cd.methods m = some ms ∧
      SatAll B C ss ms.tparams ∧ es.length = ms.neffs ∧ NamesWF ms.names ms.params ∧
      HasTypeVsQ P B Ψ Q C Γ ws (ms.params.map (Ty.subst (ss ++ [τ]) es)) ∧
      Ty.Le (ms.ret.subst (ss ++ [τ]) es) T ∧ Eff.Sub (Eff.substAt 0 (ss ++ [τ]) es ms.eff) ε ∧ MethodRowsAdmissible C Q ms es ∧
      (∀ t ∈ ss ++ [τ], Ty.WF C.length t ∧ ∀ b r e, t ≠ .cont b r e) := by
  match h with
  | .C_Meth hv hc hms hnames hsat hscope hes hws =>
      cases hm; exact ⟨_, _, _, _, hv, hc, hms, hsat, hes.1, hnames, hws, Ty.Le.refl _, Eff.Sub.refl _, hes, hscope⟩
  | .C_Sub h hle hs _ =>
      obtain ⟨cl, τ, cd, ms, hv, hc, hms, hsat, hes, hnames, hws, hle', hs', hrows, hscope⟩ := inv_meth h hm
      exact ⟨cl, τ, cd, ms, hv, hc, hms, hsat, hes, hnames, hws, hle'.trans hle, hs'.trans hs, hrows, hscope⟩
  | .C_Eff h hs =>
      obtain ⟨cl, τ, cd, ms, hv, hc, hms, hsat, hes, hnames, hws, hle', hs', hrows, hscope⟩ := inv_meth h hm
      exact ⟨cl, τ, cd, ms, hv, hc, hms, hsat, hes, hnames, hws, hle', hs'.trans hs, hrows, hscope⟩
  | .C_Return .. | .C_Let .. | .C_App .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_BuilderLet .. | .C_BuilderOp .. => cases hm

/-- returnの型付けから、その値自身の型付けを得る。型の包含で得た整形式の証拠を保つ。 -/
theorem HasTypeCQ.ret_value {Δl : LocalCtx} {P B Ψ C Γ R m a ε v}
    (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl) (hm : m = .ret v) : HasTypeVQ P B Ψ Q C Γ v a := by
  match h with
  | .C_Return hv => cases hm; exact hv
  | .C_Sub h hl _ hw => exact .V_Sub (HasTypeCQ.ret_value h hm) hl hw
  | .C_Eff h _ => exact HasTypeCQ.ret_value h hm
  | .C_Let _ _ | .C_App _ _ | .C_If _ _ _ | .C_Match _ _ _ | .C_Lazy _
  | .C_Escape _ _ | .C_Use _ _ _ _ | .C_Handle _ _ _ | .C_Resume _ _ | .C_ResumeL _ _
  | .C_Meth .. | .C_BuilderLet .. | .C_BuilderOp .. => cases hm

/-- 専用宣言の逆転。包含で広がる前の本体と種類の整形式を取り出す。 -/
theorem HasTypeCQ.inv_builderLet {P B Ψ Q C Δl Γ R m T ε kind body}
    (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl) (hm : m = .builderLet kind body) :
    ∃ a e, Ty.WF C.length kind.contents ∧
      HasTypeCQ P B Ψ Q C (none :: Γ) R body a e (some kind :: Δl) ∧
      Ty.Le a T ∧ Eff.Sub e ε := by
  match h with
  | .C_BuilderLet hw hb => cases hm; exact ⟨_, _, hw, hb, .refl _, .refl _⟩
  | .C_Sub h hl he _ =>
      obtain ⟨a, e, hw, hb, hl', he'⟩ := h.inv_builderLet hm
      exact ⟨a, e, hw, hb, hl'.trans hl, he'.trans he⟩
  | .C_Eff h he =>
      obtain ⟨a, e, hw, hb, hl, he'⟩ := h.inv_builderLet hm
      exact ⟨a, e, hw, hb, hl, he'.trans he⟩
  | .C_Return .. | .C_Let .. | .C_App .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_Meth .. | .C_BuilderOp .. => cases hm

/-- 専用操作の逆転。局所参照は通常値に変換せず分類を保つ。 -/
theorem HasTypeCQ.inv_builderOp {P B Ψ Q C Δl Γ R m T ε kind op r args}
    (h : HasTypeCQ P B Ψ Q C Γ R m T ε Δl) (hm : m = .builderOp kind op r args) :
    Ty.WF C.length kind.contents ∧ LocalRef.HasKind Ψ Δl r kind ∧
      HasTypeVsQ P B Ψ Q C Γ args (op.params kind) ∧ Ty.Le (op.result kind) T := by
  match h with
  | .C_BuilderOp hw hr ha => cases hm; exact ⟨hw, hr, ha, .refl _⟩
  | .C_Sub h hl _ _ =>
      obtain ⟨hw, hr, ha, hl'⟩ := h.inv_builderOp hm
      exact ⟨hw, hr, ha, hl'.trans hl⟩
  | .C_Eff h _ => exact h.inv_builderOp hm
  | .C_Return .. | .C_Let .. | .C_App .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_Meth .. | .C_BuilderLet .. => cases hm

end Benitoite.Release
