import Benitoite.Release.Lemmas.PresHelpers
import Benitoite.Release.Lemmas.Canonical

/-!
# 保存（契約名を持つコア）

型が付いた状態から遷移した先の状態も型が付き、継続の末尾で許すエフェクト Eb は変わらない。
契約名を含む型付けから、呼び出しと操作の保存に必要な条件を導く（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 呼び出しの型付けの取り出し -/

theorem Ty.Le.fn_fn' {names ps r ε names' as b ε'} (h : Ty.Le (.fn names ps r ε) (.fn names' as b ε')) :
    names = names' ∧ ps = as ∧ r = b ∧ Eff.Sub ε ε' := by
  obtain ⟨ε'', he, hs⟩ := h.fn_left
  simp only [Ty.fn.injEq] at he
  obtain ⟨rfl, rfl, rfl, rfl⟩ := he
  exact ⟨rfl, rfl, rfl, hs⟩

theorem inv_prim_app {Ψ R b ts es ws a ε1}
    (h : HasTypeC P B Ψ [] [] R (.app (.prim b ts es) ws) a ε1) :
    ∃ s, B.sig b = some s ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧ s.admits [] ts ∧
      HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) ∧ Ty.Le (Ty.subst ts es s.ret) a ∧
      Eff.Sub (Eff.substAt 0 ts es s.eff) ε1 := by
  obtain ⟨names, as, b', ε', hf, hargs, hle, hsub⟩ := h.inv_app rfl
  obtain ⟨s, hs, hts, hes, had, hnames, hle2⟩ := hf.inv_prim rfl
  rw [fnTy_eq] at hle2
  obtain ⟨hnames', hps, hr, hsub2⟩ := Ty.Le.fn_fn' hle2
  subst hnames' hps hr
  exact ⟨s, hs, hts, hes, had, hargs, hle, hsub2.trans hsub⟩

theorem inv_op_app {Ψ R o ts ws a ε1}
    (h : HasTypeC P B Ψ [] [] R (.app (.op o ts) ws) a ε1) :
    ∃ od, P.ops o = some od ∧ SatAll B [] ts od.tparams ∧
      HasTypeVs P B Ψ [] [] ws (od.params.map (Ty.subst ts [])) ∧ Ty.Le (Ty.subst ts [] od.ret) a ∧
      Eff.Sub (Eff.substAt 0 ts [] (Eff.single od.eff)) ε1 := by
  obtain ⟨names, as, b', ε', hf, hargs, hle, hsub⟩ := h.inv_app rfl
  obtain ⟨od, hod, hsat, hnames, hle2⟩ := hf.inv_op rfl
  rw [fnTy_eq] at hle2
  obtain ⟨hnames', hps, hr, hsub2⟩ := Ty.Le.fn_fn' hle2
  subst hnames' hps hr
  exact ⟨od, hod, hsat, hargs, hle, hsub2.trans hsub⟩

theorem Ty.subst_tvar0 (t : Ty) (es : List Eff) (ht : t.Canonical) : Ty.subst [t] es (.tvar 0) = t := by
  simp [Ty.subst, Ty.substAt, Ty.shift_zero 0 t ht]

theorem single_of_length {α} {l : List α} (h : l.length = 1) : ∃ x, l = [x] := by
  match l, h with
  | [x], _ => exact ⟨x, rfl⟩

/-- 閉じた項の型引数は、項の中に書ける閉じた型である。 -/
theorem closedArgs_of {tys : List Ty} (h : Ty.VarsInList 0 (fun _ => True) tys) : ClosedArgs tys := by
  intro t ht
  have := varsInList_mem h ht
  refine ⟨Ty.VarsIn.wf _ this, ?_⟩
  intro b t' ε e; subst e; simp [Ty.VarsIn] at this

theorem envWF_nil (n : Nat) : EnvWF n [] := fun i x h => by simp at h

theorem binds_snoc (as : List Ty) (x : Ty) : binds (as ++ [x]) = some x :: binds as := by
  simp [binds]

theorem Ty.subst_wf0 {ts : List Ty} (es : List Eff) (hts : ClosedArgs ts) (hes : ∀ e ∈ es, Eff.WF 0 e) {a : Ty}
    (ha : Ty.WF ts.length a) : Ty.WF 0 (a.subst ts es) :=
  Ty.subst_wf es (fun t ht => (hts t ht).1) hes a ha

/-! ## E-Op：操作の呼び出しを、その操作の節を持つ最も内側の `handle` の枠で処理する -/

theorem InstOk.snoc {Ψ R0 as ws x w} (h : InstOk P B Ψ R0 as ws)
    (hx : ∃ b t ε l, x = .cont b t ε ∧ Ty.WF 0 x ∧ w = .loc l ∧ Ψ l = some (.cont b t ε R0) ∧
      ∀ r, R0 = some r → Ty.WF 0 r) :
    InstOk P B Ψ R0 (as ++ [x]) (ws ++ [w]) := by
  obtain ⟨hlen, hpt⟩ := h
  refine ⟨by simp [hlen], fun i y v hy hv => ?_⟩
  by_cases hi : i < as.length
  · rw [List.getElem?_append_left hi] at hy
    rw [List.getElem?_append_left (by omega)] at hv
    exact hpt i y v hy hv
  · have hi' : i = as.length := by
      have := (List.getElem?_eq_some_iff.mp hy).1; simp at this; omega
    subst hi'
    rw [List.getElem?_append_right (Nat.le_refl _)] at hy
    rw [List.getElem?_append_right (by omega)] at hv
    simp at hy hv
    subst hy; rw [hlen] at hv; simp at hv; subst hv
    exact Or.inr hx

theorem Clause.VarsInList.mem {depth n pe} {hs : List Clause} (h : Clause.VarsInList n pe hs depth) {c : Clause}
    (hc : c ∈ hs) : Comp.VarsIn (n + c.ntys) pe c.body (depth + c.arity + 1) := by
  induction hs with
  | nil => simp at hc
  | cons c' cs ih =>
      cases c' with
      | mk o a k m =>
        simp only [Clause.VarsInList] at h
        rcases List.mem_cons.mp hc with rfl | hc
        · exact h.1
        · exact ih h.2 hc
      | fail E body =>
        simp only [Clause.VarsInList] at h
        rcases List.mem_cons.mp hc with rfl | hc
        · exact h.2.1
        · exact ih h.2.2 hc

/-- E-Op と E-OpPrim の共通の部分。操作 o の型 `sg` と、型引数 `ts` と引数 `ws` の型付けから、遷移した先の状態の
型付けを作る。 -/
theorem pres_op_common (hwf : P.WellFormed) (hb : B.Assumptions P)
    {Ψ σ R a b ε Eb o sg ts ws k k1 h k2 c κ}
    (hσ : StoreOk P B Ψ σ) (hk : ContTy P B Ψ R ε k a b Eb none)
    (htsc : Ty.VarsInList 0 (fun _ => True) ts) (hwsc : Val.VarsInList 0 (fun _ => True) ws)
    (hck : Cont.Closed k) (hcσ : Store.Closed σ)
    (hsg : opSig P B o = some sg) (hsat : SatAll B [] ts sg.tparams)
    (hargs : HasTypeVs P B Ψ [] [] ws (sg.params.map (Ty.subst ts [])))
    (hle : Ty.Le (Ty.subst ts [] sg.ret) a)
    (hsplit : SplitAt o k k1 h k2) (hc : findClause h o = some c) (hκ : σ κ = none) :
    StateTyE P B Eb (.run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
      (σ.set κ (.cont (k1 ++ [.handleF h])))) := by
  obtain ⟨rfl, hhandles, hno⟩ := hsplit
  have hΨwf := hσ.wf
  have hts : ClosedArgs ts := closedArgs_of htsc
  obtain ⟨t, εb, εc, Rh, hk1, hk2, hsub, hcl, htw⟩ := hk.split (by
    have hn := opSig_ne_fail hsg
    exact ContTy.selected_ordinary hk hn ⟨rfl, hhandles, hno⟩)
  have hRh : ∀ x, Rh = some x → Ty.WF 0 x := hk2.R_wf (fun x hx => by cases hx)
  obtain ⟨sg', hsg', harity, hntys, hew, hbody⟩ := hcl.find hc
  rw [hsg] at hsg'; cases hsg'
  -- 節の本体の型：Γ = [] なので環境のずらしは消え、T と Rh は閉じているのでずらしで変わらない。
  have hshT : t.shift c.ntys 0 = t := Ty.shift_of_wf _ _ htw
  have hshR : Rh.map (Ty.shift c.ntys 0) = Rh := by
    cases hR : Rh with
    | none => rfl
    | some x => simp only [Option.map_some]; rw [Ty.shift_of_wf _ _ (hRh x hR)]
  have hshE : Eff.shift c.ntys 0 εc = Eff.norm εc := by
    rw [Eff.shift, Eff.rawShift_of_wf (c := 0) _ _ hew]
  rw [hshT, hshR, hshE] at hbody
  simp only [shiftEnv, List.map_nil, List.append_nil] at hbody
  -- 型引数の置き換え（01-12 の E-Op の θ = [T̄/ᾱ]。01-12「型パラメータの組み込みの制約」）。
  have hsc := opSig_scoped hwf hb hsg
  have hθ := HasTypeCQ.substTy (c := 0) hwf hb hbody (Nat.zero_le _) hts (by simp)
    (by simpa using hsat) (StoreFix.of_wf hΨwf ts) (RowTransport.refl Qempty)
  simp only [List.take_zero, envSubst, List.map_cons, Option.map_some, Ty.substAt] at hθ
  have htθ : t.substAt 0 ts [] = t := Ty.substAt_nil_of_wf ts t htw
  have hRθ : Rh.map (Ty.substAt 0 ts []) = Rh := by
    cases hR : Rh with
    | none => rfl
    | some x => simp only [Option.map_some]; rw [Ty.substAt_nil_of_wf ts x (hRh x hR)]
  rw [htθ, hRθ, Eff.substAt_nil_of_wf (c := 0) ts (Eff.norm εc) (Eff.norm_WF εc hew) (Eff.norm_idem εc)] at hθ
  rw [← binds_map] at hθ
  -- 新しい継続の場所 κ。
  have hΨκ : Ψ κ = none := by
    cases h' : Ψ κ with
    | none => rfl
    | some x => exact absurd hκ (hσ.2.2.1 _ _ h')
  have hlen : ts.length = sg.tparams.length := hsat.1
  have hretw : Ty.WF 0 (Ty.subst ts [] sg.ret) :=
    Ty.subst_wf0 [] hts (by simp) (by rw [hlen]; exact Ty.VarsIn.wf _ hsc.2.2)
  have hparw : ∀ y ∈ sg.params.map (Ty.subst ts []), Ty.WF 0 y := by
    intro y hy
    obtain ⟨z, hz, rfl⟩ := List.mem_map.mp hy
    exact Ty.subst_wf0 [] hts (by simp) (by rw [hlen]; exact Ty.VarsIn.wf _ (varsInList_mem hsc.2.1 hz))
  let x : LocTy := .cont (Ty.subst ts [] sg.ret) t (Eff.norm εc) Rh
  have hxwf : x.WF := ⟨hretw, htw, hRh, Eff.norm_WF εc hew, Eff.norm_idem εc⟩
  have hsub' : StoreTy.Sub Ψ (Ψ.set κ x) := StoreTy.set_sub (Or.inl hΨκ)
  have hΨ'κ : (Ψ.set κ x) κ = some x := by simp [StoreTy.set]
  have hck' := Cont.Closed.append.mp hck
  have hck2 := Cont.Closed.cons.mp hck'.2
  refine ⟨Ψ.set κ x, Rh, t, b, εb, Eff.norm εc, ?_, ?_, (Eff.norm_sub_self εc).trans hsub, ?_, ?_, ?_, ?_⟩
  · -- ストア
    refine hσ.set hxwf (Or.inl hΨκ) ?_
    refine ⟨_, _, _, _, hΨ'κ, ⟨k1, h, rfl⟩, R, ε, ?_⟩
    have hcell := (ContTy.K_Sub hk1 hle).resume_append ⟨k1, h, rfl⟩ (Ty.Le.refl t)
      (ContTy.K_Empty (Eff.Sub.refl (Eff.norm εc)) htw) (Eff.sub_norm_self εc)
    simpa only [List.append_nil] using hcell.store hsub'
  · -- 計算
    have hθ' := hθ.store hsub'
    simp only [Comp.substTy]
    rw [show some (Ty.cont (Ty.substAt 0 ts [] sg.ret) t (Eff.norm εc)) ::
          binds (sg.params.map (Ty.substAt 0 ts [])) =
        binds (sg.params.map (Ty.substAt 0 ts []) ++ [.cont (Ty.substAt 0 ts [] sg.ret) t (Eff.norm εc)]) by
        rw [binds_snoc]] at hθ'
    refine hθ'.instantiate (InstOk.snoc ?_ ⟨_, _, _, κ, rfl, ⟨hretw, htw, Eff.norm_WF εc hew, Eff.norm_idem εc⟩, rfl, hΨ'κ, hRh⟩)
    exact InstOk.of_values hb (hargs.store hsub') hparw hwsc
  · exact .K_Drop hΨ'κ (fun h' => hsub.1 _ ((Eff.mem_norm εc _).mp h')) (hk2.store hsub')
  · -- 計算が閉じていること
    have hmem : c ∈ h := List.mem_of_find?_eq_some hc
    have hb' := Clause.VarsInList.mem hck2.1 hmem
    rw [Nat.zero_add, hntys, ← hlen] at hb'
    refine Comp.VarsIn.instantiate (depth := c.arity + 1) ?_ ?_ ?_
    · exact Val.VarsInList.append hwsc ⟨trivial, trivial⟩
    · have := Comp.VarsIn.substTyAt (c := 0) [] (fun u hu => varsInList_mem htsc hu) (by simp) c.body
        (by simpa using hb')
      exact this
    · have hwlen := hargs.length_eq
      simp only [List.length_map] at hwlen
      simp only [List.length_append, List.length_cons, List.length_nil]
      omega
  · exact Cont.Closed.cons.mpr ⟨trivial, hck2.2⟩
  · exact hcσ.set (Cont.Closed.append.mpr ⟨hck'.1, Cont.Closed.cons.mpr ⟨hck2.1, fun f hf => by simp at hf⟩⟩)

end Benitoite.Release
