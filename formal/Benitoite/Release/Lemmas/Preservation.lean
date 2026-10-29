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
    names = names' ∧ ps = as ∧ r = b ∧ Eff.Covers ε' ε := by
  obtain ⟨ε'', he, hs⟩ := h.fn_left
  simp only [Ty.fn.injEq] at he
  obtain ⟨rfl, rfl, rfl, rfl⟩ := he
  exact ⟨rfl, rfl, rfl, hs⟩

theorem inv_prim_app {Ψ R b ts es rs ws a ε1}
    (h : HasTypeC P B Ψ [] [] R (.app (.prim b ts es rs) ws) a ε1) :
    ∃ s, B.sig b = some s ∧ ts.length = s.ntys ∧ es.length = s.neffs ∧ s.admits [] ts ∧
      HasTypeVs P B Ψ [] [] ws ((s.inst rs).params.map (Ty.subst ts es)) ∧ Ty.Le (Ty.subst ts es (s.inst rs).ret) a ∧
      Eff.Covers ε1 (Eff.substAt 0 ts es (s.inst rs).eff) ∧ B.RangeAdmissible b s rs := by
  obtain ⟨names, as, b', ε', hf, hargs, hle, hsub⟩ := h.inv_app rfl
  obtain ⟨s, hs, hrs, hts, hes, had, hnames, hle2⟩ := hf.inv_prim rfl
  rw [fnTy_eq] at hle2
  obtain ⟨hnames', hps, hr, hsub2⟩ := Ty.Le.fn_fn' hle2
  subst hnames' hps hr
  exact ⟨s, hs, hts, hes, had, hargs, hle, hsub.trans hsub2, hrs⟩

theorem inv_op_app {Ψ R o ts ws a ε1}
    (h : HasTypeC P B Ψ [] [] R (.app (.op o ts) ws) a ε1) :
    ∃ od, P.ops o = some od ∧ SatAll B [] ts od.tparams ∧
      HasTypeVs P B Ψ [] [] ws (od.params.map (Ty.subst ts [])) ∧ Ty.Le (Ty.subst ts [] od.ret) a ∧
      Eff.Covers ε1 (Eff.substAt 0 ts [] (Eff.single od.eff)) := by
  obtain ⟨names, as, b', ε', hf, hargs, hle, hsub⟩ := h.inv_app rfl
  obtain ⟨od, hod, hsat, hnames, hle2⟩ := hf.inv_op rfl
  rw [fnTy_eq] at hle2
  obtain ⟨hnames', hps, hr, hsub2⟩ := Ty.Le.fn_fn' hle2
  subst hnames' hps hr
  exact ⟨od, hod, hsat, hargs, hle, hsub.trans hsub2⟩

theorem Ty.subst_tvar0 (t : Ty) (es : List Eff) (ht : t.Canonical) : Ty.subst [t] es (.tvar 0) = t := by
  simp [Ty.subst, Ty.substAt, Ty.shift_zero 0 t ht]

theorem single_of_length {α} {l : List α} (h : l.length = 1) : ∃ x, l = [x] := by
  match l, h with
  | [x], _ => exact ⟨x, rfl⟩

/-- 閉じた項の型引数は、項の中に書ける閉じた型である。 -/
theorem closedArgs_of {tys : List Ty} (h : Ty.VarsInList 0 0 (fun _ => True) tys) : ClosedArgs tys := by
  intro t ht
  have := varsInList_mem h ht
  refine ⟨Ty.VarsIn.wf _ this, ?_⟩
  intro b t' ε e; subst e; simp [Ty.VarsIn] at this

theorem envWF_nil (n : Nat) : EnvWF n [] := fun i x h => by simp at h

theorem binds_snoc (as : List Ty) (x : Ty) : binds (as ++ [x]) = some x :: binds as := by
  simp [binds]

theorem Ty.subst_wf0 {ts : List Ty} (es : List Eff) (hts : ClosedArgs ts) (hes : ∀ e ∈ es, Eff.WF 0 0 e) {a : Ty}
    (ha : Ty.WF 0 ts.length a) : Ty.WF 0 0 (a.subst ts es) :=
  Ty.subst_wf es (fun t ht => (hts t ht).1) hes a ha

/-! ## E-Op：操作の呼び出しを、その操作の節を持つ最も内側の `handle` の枠で処理する -/

theorem InstOk.snoc {Ψ R0 as ws x w} (h : InstOk P B Ψ R0 as ws)
    (hx : ∃ b t ε l, x = .cont b t ε ∧ Ty.WF 0 0 x ∧ w = .loc l ∧ Ψ l = some (.cont b t ε R0) ∧
      ∀ r, R0 = some r → Ty.WF 0 0 r) :
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

/-- 組み込みのエフェクト L の操作 op を処理しない継続の枠は、L の名前の原子を `handled` に含めない（L の全ての操作の
節がそろわない）。 -/
theorem NoHandler.handled_false (hdecl : P.EffectsOk B) {k : Cont} {l : EffName} {bs : List PrimName} {b0 : PrimName}
    (hbs : B.effects l = some bs) (hb0 : b0 ∈ bs) (hno : NoHandler k (.prim b0)) :
    ∀ hs, Frame.handleF hs ∈ k → Eff.test (handled P B hs) (.nameTop l) = false := by
  have hPl : P.effects l = none := by
    cases e : P.effects l with
    | none => rfl
    | some os => rw [hdecl.2.2 l os e] at hbs; cases hbs
  intro hs hin
  have hh := hno hs hin
  have hall : (bs.map OpRef.prim).all (handles hs) = false := by
    rw [Bool.eq_false_iff]; intro h
    rw [List.all_eq_true] at h
    have := h (.prim b0) (List.mem_map.mpr ⟨b0, hb0, rfl⟩)
    rw [hh] at this; cases this
  simp only [Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps, hPl, hbs, Option.map_some]
  revert hall
  cases bs.map OpRef.prim <;> simp

/-- E-Op と E-OpPrim の共通の部分。型引数 `ts` と引数 `ws` の型付けから、遷移した先の状態の型付けを作る。節の操作の
型は、処理する `handle` の枠の穴の効果 εh（保護本体の効果）から選んだ節の添字で決まるので（L30.1。`ClauseSig`）、
呼び出し側は、εh が呼び出しの効果の名前の原子を受け取ること（枠より内側の継続が処理しない名前の原子は、継続の
先頭の効果 ε から εh へ届く。`ContTy.split`）を使って、引数と結果の型付けを節の操作の型について示す。 -/
theorem pres_op_common (hwf : P.WellFormed) (hb : B.CoreAssumptions P)
    {Ψ σ R a b ε Eb o ts ws k k1 h k2 c κ}
    (hσ : StoreOk P B Ψ σ) (hk : ContTy P B Ψ R ε k a b Eb none)
    (htsc : Ty.VarsInList 0 0 (fun _ => True) ts) (hwsc : Val.VarsInList 0 (fun _ => True) ws)
    (hck : Cont.Closed k) (hcσ : Store.Closed σ) (hne : o ≠ .fail)
    (hsel : ∀ εh sg, ClauseSig P B εh o sg →
      (∀ l r, Eff.mem ε (.name l r) →
        (∀ hs', Frame.handleF hs' ∈ k1 → Eff.test (handled P B hs') (.nameTop l) = false) →
        ∃ r', Eff.mem εh (.name l r') ∧ (Atom.name l r').Covers (.name l r)) →
      SatAll B [] ts sg.tparams ∧ HasTypeVs P B Ψ [] [] ws (sg.params.map (Ty.subst ts [])) ∧
        Ty.Le (Ty.subst ts [] sg.ret) a)
    (hsplit : SplitAt o k k1 h k2) (hc : findClause h o = some c) (hκ : σ κ = none) :
    StateTyE P B Eb (.run ((c.body.substTy ts []).instantiate (ws ++ [.loc κ])) (.drop κ :: k2)
      (σ.set κ (.cont (k1 ++ [.handleF h])))) := by
  obtain ⟨rfl, hhandles, hno⟩ := hsplit
  have hΨwf := hσ.wf
  have hts : ClosedArgs ts := closedArgs_of htsc
  obtain ⟨t, εh, εb, εc, Rh, hk1, hk2, hsub, hcl, htw, hprop⟩ := hk.split
    (ContTy.selected_ordinary hk hne ⟨rfl, hhandles, hno⟩)
  have hRh : ∀ x, Rh = some x → Ty.WF 0 0 x := hk2.R_wf (fun x hx => by cases hx)
  obtain ⟨sg, hsg, harity, hntys, hew, hbody⟩ := hcl.find hc
  obtain ⟨hsat, hargs, hle⟩ := hsel εh sg hsg hprop
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
  have hsc := hsg.scoped hwf hb
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
  have hretw : Ty.WF 0 0 (Ty.subst ts [] sg.ret) :=
    Ty.subst_wf0 [] hts (by simp) (by rw [hlen]; exact Ty.VarsIn.wf _ hsc.2.2)
  have hparw : ∀ y ∈ sg.params.map (Ty.subst ts []), Ty.WF 0 0 y := by
    intro y hy
    obtain ⟨z, hz, rfl⟩ := List.mem_map.mp hy
    exact Ty.subst_wf0 [] hts (by simp) (by rw [hlen]; exact Ty.VarsIn.wf _ (varsInList_mem hsc.2.1 hz))
  let x : LocTy := .cont (Ty.subst ts [] sg.ret) t (Eff.norm εc) Rh
  have hxwf : x.WF := ⟨hretw, htw, hRh, Eff.norm_WF εc hew, Eff.norm_idem εc⟩
  have hsub' : StoreTy.Sub Ψ (Ψ.set κ x) := StoreTy.set_sub (Or.inl hΨκ)
  have hΨ'κ : (Ψ.set κ x) κ = some x := by simp [StoreTy.set]
  have hck' := Cont.Closed.append.mp hck
  have hck2 := Cont.Closed.cons.mp hck'.2
  -- 節の本体は節の効果 εc で型付き、枠の下の継続の効果 εb は εc を覆う（K-Handle）。本体の効果を C-Eff で εb へ
  -- 広げる（L40.6c）。
  refine ⟨Ψ.set κ x, Rh, t, b, εb, εb, ?_, ?_, Eff.Sub.refl _, ?_, ?_, ?_, ?_⟩
  · -- ストア
    refine hσ.set hxwf (Or.inl hΨκ) ?_
    refine ⟨_, _, _, _, hΨ'κ, ⟨k1, h, rfl⟩, R, ε, ?_⟩
    have hcell := (ContTy.K_Sub hk1 hle).resume_append ⟨k1, h, rfl⟩ (Ty.Le.refl t)
      (ContTy.K_Empty (Eff.Sub.refl (Eff.norm εc)) htw) (Eff.sub_norm_self εc).covers
    simpa only [List.append_nil] using hcell.store hsub'
  · -- 計算
    have hθ' := hθ.store hsub'
    simp only [Comp.substTy]
    rw [show some (Ty.cont (Ty.substAt 0 ts [] sg.ret) t (Eff.norm εc)) ::
          binds (sg.params.map (Ty.substAt 0 ts [])) =
        binds (sg.params.map (Ty.substAt 0 ts []) ++ [.cont (Ty.substAt 0 ts [] sg.ret) t (Eff.norm εc)]) by
        rw [binds_snoc]] at hθ'
    refine .C_Eff (hθ'.instantiate (InstOk.snoc ?_ ⟨_, _, _, κ, rfl, ⟨hretw, htw, Eff.norm_WF εc hew, Eff.norm_idem εc⟩, rfl, hΨ'κ, hRh⟩))
      (Eff.covers_norm_right.mpr hsub)
    exact InstOk.of_values hb (hargs.store hsub') hparw hwsc
  · exact .K_Drop hΨ'κ (fun h' => hsub.nameTop ((Eff.mem_norm εc _).mp h')) (hk2.store hsub')
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
