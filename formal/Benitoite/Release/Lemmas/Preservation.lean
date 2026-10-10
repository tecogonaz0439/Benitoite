import Benitoite.Release.Lemmas.PresHelpers

/-!
# 保存（段階 B）

型が付いた状態から遷移した先の状態も型が付き、継続の末尾で許すエフェクト Eb は変わらない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 呼び出しの型付けの取り出し -/

theorem Ty.Le.fn_fn' {ps r ε as b ε'} (h : Ty.Le (.fn ps r ε) (.fn as b ε')) :
    ps = as ∧ r = b ∧ Eff.Sub ε ε' := by
  obtain ⟨ε'', he, hs⟩ := h.fn_left
  simp only [Ty.fn.injEq] at he
  obtain ⟨rfl, rfl, rfl⟩ := he
  exact ⟨rfl, rfl, hs⟩

theorem inv_prim_app {Ψ R b ts es ws a ε1}
    (h : HasTypeC P B Ψ [] [] R (.app (.prim b ts es) ws) a ε1) :
    ∃ s, B.sig b = some s ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧ s.admits [] ts ∧
      HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es)) ∧ Ty.Le (Ty.subst ts es s.ret) a ∧
      Eff.Sub (Eff.substRho es s.eff) ε1 := by
  obtain ⟨as, b', ε', hf, hargs, hle, hsub⟩ := h.inv_app rfl
  obtain ⟨s, hs, hts, hes, had, hle2⟩ := hf.inv_prim rfl
  rw [fnTy_eq] at hle2
  obtain ⟨hps, hr, hsub2⟩ := Ty.Le.fn_fn' hle2
  subst hps hr
  exact ⟨s, hs, hts, hes, had, hargs, hle, hsub2.trans hsub⟩

theorem inv_op_app {Ψ R o ts ws a ε1}
    (h : HasTypeC P B Ψ [] [] R (.app (.op o ts) ws) a ε1) :
    ∃ od, P.ops o = some od ∧ SatAll B [] ts od.tparams ∧
      HasTypeVs P B Ψ [] [] ws (od.params.map (Ty.subst ts [])) ∧ Ty.Le (Ty.subst ts [] od.ret) a ∧
      Eff.Sub (Eff.substRho [] (Eff.single od.eff)) ε1 := by
  obtain ⟨as, b', ε', hf, hargs, hle, hsub⟩ := h.inv_app rfl
  obtain ⟨od, hod, hsat, hle2⟩ := hf.inv_op rfl
  rw [fnTy_eq] at hle2
  obtain ⟨hps, hr, hsub2⟩ := Ty.Le.fn_fn' hle2
  subst hps hr
  exact ⟨od, hod, hsat, hargs, hle, hsub2.trans hsub⟩

theorem Ty.subst_tvar0 (t : Ty) (es : List Eff) : Ty.subst [t] es (.tvar 0) = t := by
  simp [Ty.subst, Ty.substAt, Ty.shift_zero]

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

theorem Ty.subst_wf0 {ts : List Ty} (es : List Eff) (hts : ClosedArgs ts) {a : Ty}
    (ha : Ty.WF ts.length a) : Ty.WF 0 (a.subst ts es) :=
  Ty.subst_wf es (fun t ht => (hts t ht).1) a ha

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

theorem Clause.VarsInList.mem {n pe} {hs : List Clause} (h : Clause.VarsInList n pe hs) {c : Clause}
    (hc : c ∈ hs) : Comp.VarsIn (n + c.ntys) pe c.body := by
  induction hs with
  | nil => simp at hc
  | cons c' cs ih =>
      obtain ⟨o, a, k, m⟩ := c'
      simp only [Clause.VarsInList] at h
      rcases List.mem_cons.mp hc with rfl | hc
      · exact h.1
      · exact ih h.2 hc

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
  obtain ⟨rfl, _, _⟩ := hsplit
  have hΨwf := hσ.wf
  have hts : ClosedArgs ts := closedArgs_of htsc
  obtain ⟨t, εb, εc, Rh, hk1, hk2, hsub, hcl, htw⟩ := hk.split
  have hRh : ∀ x, Rh = some x → Ty.WF 0 x := hk2.R_wf (fun x hx => by cases hx)
  obtain ⟨sg', hsg', harity, hntys, hbody⟩ := hcl.find hc
  rw [hsg] at hsg'; cases hsg'
  -- 節の本体の型：Γ = [] なので環境のずらしは消え、T と Rh は閉じているのでずらしで変わらない。
  have hshT : t.shift c.ntys 0 = t := Ty.shift_of_wf _ _ htw
  have hshR : Rh.map (Ty.shift c.ntys 0) = Rh := by
    cases hR : Rh with
    | none => rfl
    | some x => simp only [Option.map_some]; rw [Ty.shift_of_wf _ _ (hRh x hR)]
  rw [hshT, hshR] at hbody
  simp only [shiftEnv, List.map_nil, List.append_nil] at hbody
  -- 型引数の置き換え（01-12 の E-Op の θ = [T̄/ᾱ]。01-12「型パラメータの組み込みの制約」）。
  have hsc := opSig_scoped hwf hb hsg
  have hθ := HasTypeC.substTy (c := 0) hwf hb hbody (Nat.zero_le _) hts
    (by simpa using hsat) (StoreFix.of_wf hΨwf ts)
  simp only [List.take_zero, envSubst, List.map_cons, Option.map_some, Ty.substAt] at hθ
  have htθ : t.substAt 0 ts [] = t := Ty.substAt_nil_of_wf ts t htw
  have hRθ : Rh.map (Ty.substAt 0 ts []) = Rh := by
    cases hR : Rh with
    | none => rfl
    | some x => simp only [Option.map_some]; rw [Ty.substAt_nil_of_wf ts x (hRh x hR)]
  rw [htθ, hRθ, Eff.substRho_nil] at hθ
  rw [← binds_map] at hθ
  -- 新しい継続の場所 κ。
  have hΨκ : Ψ κ = none := by
    cases h' : Ψ κ with
    | none => rfl
    | some x => exact absurd hκ (hσ.2.2.1 _ _ h')
  have hlen : ts.length = sg.tparams.length := hsat.1
  have hretw : Ty.WF 0 (Ty.subst ts [] sg.ret) :=
    Ty.subst_wf0 [] hts (by rw [hlen]; exact Ty.VarsIn.wf _ hsc.2)
  have hparw : ∀ y ∈ sg.params.map (Ty.subst ts []), Ty.WF 0 y := by
    intro y hy
    obtain ⟨z, hz, rfl⟩ := List.mem_map.mp hy
    exact Ty.subst_wf0 [] hts (by rw [hlen]; exact Ty.VarsIn.wf _ (varsInList_mem hsc.1 hz))
  let x : LocTy := .cont (Ty.subst ts [] sg.ret) t εc Rh
  have hxwf : x.WF := ⟨hretw, htw, hRh⟩
  have hsub' : StoreTy.Sub Ψ (Ψ.set κ x) := StoreTy.set_sub (Or.inl hΨκ)
  have hΨ'κ : (Ψ.set κ x) κ = some x := by simp [StoreTy.set]
  have hck' := Cont.Closed.append.mp hck
  have hck2 := Cont.Closed.cons.mp hck'.2
  refine ⟨Ψ.set κ x, Rh, t, b, εb, εc, ?_, ?_, hsub, ?_, ?_, ?_, ?_⟩
  · -- ストア
    refine hσ.set hxwf (Or.inl hΨκ) ?_
    exact ⟨_, _, _, _, hΨ'κ, ⟨k1, h, rfl⟩, R, ε, (ContTy.K_Sub hk1 hle).store hsub'⟩
  · -- 計算
    have hθ' := hθ.store hsub'
    simp only [Comp.substTy]
    rw [show some (Ty.cont (Ty.substAt 0 ts [] sg.ret) t εc) ::
          binds (sg.params.map (Ty.substAt 0 ts [])) =
        binds (sg.params.map (Ty.substAt 0 ts []) ++ [.cont (Ty.substAt 0 ts [] sg.ret) t εc]) by
        rw [binds_snoc]] at hθ'
    refine hθ'.instantiate (InstOk.snoc ?_ ⟨_, _, _, κ, rfl, ⟨hretw, htw⟩, rfl, hΨ'κ, hRh⟩)
    exact InstOk.of_values hb (hargs.store hsub') hparw hwsc
  · exact .K_Drop hΨ'κ (fun h' => hsub _ h') (hk2.store hsub')
  · -- 計算が閉じていること
    have hmem : c ∈ h := List.mem_of_find?_eq_some hc
    have hb' := Clause.VarsInList.mem hck2.1 hmem
    rw [Nat.zero_add, hntys, ← hlen] at hb'
    refine Comp.VarsIn.instantiate ?_ ?_
    · exact Val.VarsInList.append hwsc ⟨trivial, trivial⟩
    · have := Comp.VarsIn.substTyAt (c := 0) [] (fun u hu => varsInList_mem htsc hu) c.body
        (by simpa using hb')
      exact this
  · exact Cont.Closed.cons.mpr ⟨trivial, hck2.2⟩
  · exact hcσ.set (Cont.Closed.append.mpr ⟨hck'.1, Cont.Closed.cons.mpr ⟨hck2.1, fun f hf => by simp at hf⟩⟩)

end Benitoite.Release
