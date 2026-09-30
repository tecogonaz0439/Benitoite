import Benitoite.Release.Lemmas.PresMain

/-!
# 進行（段階 B）

型が付いた状態は、実行を終えた状態であるか、遷移できる。継続の末尾で許すエフェクト Eb が組み込みの
エフェクトの名前だけであることから、どの `handle` の枠も処理しない利用者の操作の呼び出しは起きない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 閉じた値の形 -/

/-- 関数の型の閉じた値は、`λ`、関数の名前、組み込みの関数、操作のいずれかである。 -/
theorem HasTypeV.canonical_fn {Ψ C v ps r ε} (h : HasTypeV P B Ψ C [] v (.fn ps r ε)) :
    (∃ qs body, v = .lam qs body) ∨ (∃ f ts es, v = .fnRef f ts es) ∨ (∃ b ts es, v = .prim b ts es) ∨
      (∃ o ts, v = .op o ts) := by
  cases v with
  | var i => obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | const c =>
      obtain ⟨_, e, _⟩ := (h.inv_const rfl).fn_right
      cases c <;> simp [Const.type] at e
  | fnRef f ts es => exact Or.inr (Or.inl ⟨_, _, _, rfl⟩)
  | prim b ts es => exact Or.inr (Or.inr (Or.inl ⟨_, _, _, rfl⟩))
  | op o ts => exact Or.inr (Or.inr (Or.inr ⟨_, _, rfl⟩))
  | lam qs body => exact Or.inl ⟨_, _, rfl⟩
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | loc l => rcases h.inv_loc rfl with ⟨_, _, h'⟩ | ⟨_, _, h'⟩ <;> simp at h'
  | mapV ks vs => obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | setV _ => obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | bytesV _ => have h' := h.inv_bytesV rfl; simp at h'
  | dict _ _ _ => obtain ⟨_, _, _, _, h'⟩ := h.inv_dict rfl; simp at h'
  | super _ _ => obtain ⟨_, _, _, _, _, _, h'⟩ := h.inv_super rfl; simp at h'

/-- 辞書の型の閉じた値は、実装の辞書であるか、E-Super で `↑` を一段取り出せる。 -/
theorem HasTypeV.canonical_dict (hwt : P.WellTyped B) {Ψ C} :
    (v : Val) → ∀ {cl τ}, HasTypeV P B Ψ C [] v (.dict cl τ) →
      (∃ i ts vs, v = .dict i ts vs) ∨ (∃ v', v.superStep P = some v')
  | .dict i ts vs, _, _, _ => Or.inl ⟨i, ts, vs, rfl⟩
  | .super w s, cl, τ, h => by
      obtain ⟨cl0, τ0, cd0, hw, hcl0, hs, _⟩ := h.inv_super rfl
      right
      rcases HasTypeV.canonical_dict hwt w hw with ⟨i, ts, vs, rfl⟩ | ⟨w', hw'⟩
      · obtain ⟨id, hi, _, _, he⟩ := hw.inv_dict rfl
        simp only [Ty.dict.injEq] at he
        obtain ⟨rfl, rfl⟩ := he
        obtain ⟨cd, hcd, _, _, _, hsup⟩ := hwt.impl hi
        rw [hcl0] at hcd; cases hcd
        obtain ⟨u, hu, _⟩ := hsup s hs
        exact ⟨(u.substTy ts []).instantiate vs, by simp only [Val.superStep, hi, hu, Option.map_some]⟩
      · have hnd : ∀ i ts vs, w ≠ .dict i ts vs := by
          rintro i ts vs rfl; simp [Val.superStep] at hw'
        exact ⟨_, by rw [Val.superStep_super_of_not_dict hnd, hw']; rfl⟩
  | .var _, _, _, h => by obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | .const c, _, _, h => by
      have := (h.inv_const rfl).eq_of_not_fn (by intros; simp)
      cases c <;> simp [Const.type] at this
  | .fnRef _ _ _, _, _, h => by
      obtain ⟨_, _, _, _, hle⟩ := h.inv_fnRef rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn (by intros; simp); simp at this
  | .prim _ _ _, _, _, h => by
      obtain ⟨_, _, _, _, _, hle⟩ := h.inv_prim rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn (by intros; simp); simp at this
  | .op _ _, _, _, h => by
      obtain ⟨_, _, _, hle⟩ := h.inv_op rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn (by intros; simp); simp at this
  | .lam _ _, _, _, h => by
      obtain ⟨_, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn (by intros; simp); simp at this
  | .con _ _ _, _, _, h => by obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | .list _, _, _, h => by obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | .loc _, _, _, h => by rcases h.inv_loc rfl with ⟨_, _, h'⟩ | ⟨_, _, h'⟩ <;> simp at h'
  | .mapV _ _, _, _, h => by obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | .setV _, _, _, h => by obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | .bytesV _, _, _, h => by have h' := h.inv_bytesV rfl; simp at h'

/-- メソッドの呼び出しは、E-Meth か E-Super で遷移できる。 -/
theorem progress_meth (hwt : P.WellTyped B) {Ψ σ R a ε v m ss es ws k}
    (hm : HasTypeC P B Ψ [] [] R (.meth v m ss es ws) a ε) :
    ∃ l s', Step P B (.run (.meth v m ss es ws) k σ) l s' := by
  obtain ⟨cl, τ, cd, ms, hv, hcl, hms, hsat, hesl, hws, _, _⟩ := hm.inv_meth rfl
  rcases HasTypeV.canonical_dict hwt v hv with ⟨i, ts, vs, rfl⟩ | ⟨v', hv'⟩
  · obtain ⟨id, hi, hsatI, hvs, he⟩ := hv.inv_dict rfl
    simp only [Ty.dict.injEq] at he
    obtain ⟨rfl, rfl⟩ := he
    obtain ⟨cd', hcd, _, _, hmeths, _⟩ := hwt.impl hi
    rw [hcl] at hcd; cases hcd
    obtain ⟨body, hbody, _⟩ := hmeths m ms hms
    exact ⟨_, _, .E_Meth hi hbody hcl hms (by rw [hws.length_eq, List.length_map])
      (by rw [hvs.length_eq, List.length_map]) hsatI.1 hsat.1 hesl⟩
  · exact ⟨_, _, .E_Super hv'⟩

/-- `resume` の第一引数は、変数か場所である。 -/
theorem HasTypeC.resume_form {Ψ C Γ R m T ε w v} (h : HasTypeC P B Ψ C Γ R m T ε)
    (hm : m = .resume w v) : (∃ i, w = .var i) ∨ (∃ l, w = .loc l) := by
  match h with
  | .C_Resume _ _ => cases hm; exact Or.inl ⟨_, rfl⟩
  | .C_ResumeL _ _ => cases hm; exact Or.inr ⟨_, rfl⟩
  | .C_Sub h _ _ => exact resume_form h hm
  | .C_Return _ => cases hm
  | .C_Let _ _ => cases hm
  | .C_App _ _ => cases hm
  | .C_If _ _ _ => cases hm
  | .C_Match _ _ _ => cases hm
  | .C_Lazy _ => cases hm
  | .C_Escape _ _ => cases hm
  | .C_Use _ _ _ _ => cases hm
  | .C_Handle _ _ _ => cases hm

/-! ## ストアの中身の形 -/

theorem StoreOk.cont_cell {Ψ σ κ b t e r} (hσ : StoreOk P B Ψ σ) (hΨ : Ψ κ = some (.cont b t e r)) :
    σ κ = some .used ∨ ∃ k', σ κ = some (.cont k') := by
  obtain ⟨c, hc, hok⟩ := hσ.cell hΨ
  cases c with
  | val v => obtain ⟨a, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | thunk m => obtain ⟨a, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | done v => obtain ⟨a, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | cont k' => exact Or.inr ⟨k', hc⟩
  | used => exact Or.inl hc

theorem StoreOk.ref_cell {Ψ σ l a} (hσ : StoreOk P B Ψ σ) (hΨ : Ψ l = some (.ref a)) :
    ∃ v, σ l = some (.val v) := by
  obtain ⟨c, hc, hok⟩ := hσ.cell hΨ
  cases c with
  | val v => exact ⟨v, hc⟩
  | thunk m => obtain ⟨a, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | done v => obtain ⟨a, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | cont k' => obtain ⟨_, _, _, _, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | used => obtain ⟨_, _, _, _, ha⟩ := hok; rw [hΨ] at ha; cases ha

theorem StoreOk.lazy_cell {Ψ σ l a} (hσ : StoreOk P B Ψ σ) (hΨ : Ψ l = some (.lazy a)) :
    (∃ m, σ l = some (.thunk m)) ∨ ∃ v, σ l = some (.done v) := by
  obtain ⟨c, hc, hok⟩ := hσ.cell hΨ
  cases c with
  | val v => obtain ⟨a, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | thunk m => exact Or.inl ⟨m, hc⟩
  | done v => exact Or.inr ⟨v, hc⟩
  | cont k' => obtain ⟨_, _, _, _, ha, _⟩ := hok; rw [hΨ] at ha; cases ha
  | used => obtain ⟨_, _, _, _, ha⟩ := hok; rw [hΨ] at ha; cases ha

/-! ## ハンドラの探索 -/

theorem split_of_not_noHandler {o : OpRef} : ∀ {k : Cont}, ¬ NoHandler k o →
    ∃ k1 h k2, SplitAt o k k1 h k2
  | [], hno => absurd (fun h hin => by simp at hin) hno
  | f :: k, hno => by
      by_cases hf : ∃ h, f = .handleF h ∧ handles h o = true
      · obtain ⟨h, rfl, hh⟩ := hf
        exact ⟨[], h, k, rfl, hh, fun h' hin => by simp at hin⟩
      · have hno' : ¬ NoHandler k o := by
          intro hk; apply hno; intro h hin
          rcases List.mem_cons.mp hin with e | hin
          · cases hh : handles h o
            · rfl
            · exact absurd ⟨h, e.symm, hh⟩ hf
          · exact hk h hin
        obtain ⟨k1, h, k2, e, hh, hn⟩ := split_of_not_noHandler hno'
        refine ⟨f :: k1, h, k2, by rw [e]; rfl, hh, fun h' hin => ?_⟩
        rcases List.mem_cons.mp hin with e' | hin
        · cases hh' : handles h' o
          · rfl
          · exact absurd ⟨h', e'.symm, hh'⟩ hf
        · exact hn h' hin

theorem findClause_of_handles {h : List Clause} {o : OpRef} (hh : handles h o = true) :
    ∃ c, findClause h o = some c := by
  unfold handles at hh
  unfold findClause
  obtain ⟨c, hc, hco⟩ := List.any_eq_true.mp hh
  cases e : h.find? (fun c => c.op == o) with
  | none => rw [List.find?_eq_none] at e; exact (e c hc hco).elim
  | some c' => exact ⟨c', rfl⟩

/-- 継続のどの `handle` の枠も処理しない利用者の操作は、型の付いた状態では呼ばれない。 -/
theorem no_unhandled_user (hdecl : P.EffectsOk B) {Ψ R ε k a b Eb o od}
    (hk : ContTy P B Ψ R ε k a b Eb none) (hEb : BuiltinOnly P B Eb) (hod : P.ops o = some od)
    (hε : ε (.name od.eff) = true) (hno : NoHandler k (.user o)) : False := by
  obtain ⟨os, hos, hmem⟩ := hdecl.2.1 o od hod
  have hend := hk.name_end hε (fun hs hin => by
    have hh := hno hs hin
    have hall : (os.map OpRef.user).all (handles hs) = false := by
      rw [Bool.eq_false_iff]; intro h
      rw [List.all_eq_true] at h
      have := h (.user o) (List.mem_map.mpr ⟨o, hmem, rfl⟩)
      rw [hh] at this; cases this
    simp only [handled, effOps, hos]
    revert hall
    cases os.map OpRef.user <;> simp)
  obtain ⟨l, hl, hnone, _⟩ := hEb _ hend
  cases hl
  rw [hos] at hnone; cases hnone

/-! ## 各形の状態の進行 -/

theorem progress_ret (hb : B.Assumptions P) {Ψ σ R ε v a b Eb k} (hσ : StoreOk P B Ψ σ)
    (hk : ContTy P B Ψ R ε k a b Eb none) :
    State.Final (.run (.ret v) k σ) ∨ ∃ l s', Step P B (.run (.ret v) k σ) l s' := by
  cases k with
  | nil => exact Or.inl trivial
  | cons f k =>
      right
      cases f with
      | letF n => exact ⟨_, _, .E_Return⟩
      | mark => exact ⟨_, _, .E_Mark⟩
      | update l => exact ⟨_, _, .E_Update⟩
      | release w =>
          obtain ⟨o, hw, hres, _, _⟩ := hk.inv_release
          obtain ⟨r, hr⟩ := hb.release_exists Ψ w o hw hres
          cases r with
          | none => exact ⟨_, _, .E_Release hr⟩
          | some r => exact ⟨_, _, .E_RelErr hr⟩
      | handleF h => exact ⟨_, _, .E_HRet⟩
      | drop κ =>
          obtain ⟨_, _, _, _, hΨκ, _, _⟩ := hk.inv_drop
          rcases hσ.cont_cell hΨκ with h | ⟨k', h⟩
          · exact ⟨_, _, .E_Drop h⟩
          · exact ⟨_, _, .E_DropRel h⟩

theorem progress_escape (hb : B.Assumptions P) {Ψ σ R ε v a b Eb k r} (hσ : StoreOk P B Ψ σ)
    (hk : ContTy P B Ψ R ε k a b Eb none) (hR : R = some r) :
    ∃ l s', Step P B (.run (.escape v) k σ) l s' := by
  cases k with
  | nil => obtain ⟨_, _, e, _⟩ := hk.inv_nil; rw [hR] at e; cases e
  | cons f k =>
      cases f with
      | letF n => exact ⟨_, _, .E_EscLet⟩
      | mark => exact ⟨_, _, .E_EscMark⟩
      | update l => obtain ⟨_, _, _, e, _⟩ := hk.inv_update; rw [hR] at e; cases e
      | release w =>
          obtain ⟨o, hw, hres, _, _⟩ := hk.inv_release
          obtain ⟨r, hr⟩ := hb.release_exists Ψ w o hw hres
          cases r with
          | none => exact ⟨_, _, .E_EscRel hr⟩
          | some r => exact ⟨_, _, .E_EscRelErr hr⟩
      | handleF h => exact ⟨_, _, .E_EscHandle⟩
      | drop κ =>
          obtain ⟨_, _, _, _, hΨκ, _, _⟩ := hk.inv_drop
          rcases hσ.cont_cell hΨκ with h | ⟨k', h⟩
          · exact ⟨_, _, .E_EscDrop h⟩
          · exact ⟨_, _, .E_EscDropRel h⟩

theorem progress_error (hb : B.Assumptions P) {Ψ σ R ε a b Eb k rs} (hσ : StoreOk P B Ψ σ)
    (hk : ContTy P B Ψ R ε k a b Eb none) :
    State.Final (.error rs k σ) ∨ ∃ l s', Step P B (.error rs k σ) l s' := by
  cases k with
  | nil => exact Or.inl trivial
  | cons f k =>
      right
      cases f with
      | letF n => exact ⟨_, _, .E_ErrPopLet⟩
      | mark => exact ⟨_, _, .E_ErrPopMark⟩
      | update l => exact ⟨_, _, .E_ErrPopUpdate⟩
      | release w =>
          obtain ⟨o, hw, hres, _, _⟩ := hk.inv_release
          obtain ⟨r, hr⟩ := hb.release_exists Ψ w o hw hres
          cases r with
          | none => exact ⟨_, _, .E_ErrRel hr⟩
          | some r => exact ⟨_, _, .E_ErrRelErr hr⟩
      | handleF h => exact ⟨_, _, .E_ErrPopHandle⟩
      | drop κ =>
          obtain ⟨_, _, _, _, hΨκ, _, _⟩ := hk.inv_drop
          rcases hσ.cont_cell hΨκ with h | ⟨k', h⟩
          · exact ⟨_, _, .E_ErrDrop h⟩
          · exact ⟨_, _, .E_ErrDropRel h⟩

theorem progress_exit (hb : B.Assumptions P) {Ψ σ R ε a b Eb k n rs} (hσ : StoreOk P B Ψ σ)
    (hk : ContTy P B Ψ R ε k a b Eb none) :
    State.Final (.exit n rs k σ) ∨ ∃ l s', Step P B (.exit n rs k σ) l s' := by
  cases k with
  | nil => exact Or.inl trivial
  | cons f k =>
      right
      cases f with
      | letF n => exact ⟨_, _, .E_ExitPopLet⟩
      | mark => exact ⟨_, _, .E_ExitPopMark⟩
      | update l => exact ⟨_, _, .E_ExitPopUpdate⟩
      | release w =>
          obtain ⟨o, hw, hres, _, _⟩ := hk.inv_release
          obtain ⟨r, hr⟩ := hb.release_exists Ψ w o hw hres
          cases r with
          | none => exact ⟨_, _, .E_ExitRel hr⟩
          | some r => exact ⟨_, _, .E_ExitRelErr hr⟩
      | handleF h => exact ⟨_, _, .E_ExitPopHandle⟩
      | drop κ =>
          obtain ⟨_, _, _, _, hΨκ, _, _⟩ := hk.inv_drop
          rcases hσ.cont_cell hΨκ with h | ⟨k', h⟩
          · exact ⟨_, _, .E_ExitDrop h⟩
          · exact ⟨_, _, .E_ExitDropRel h⟩

/-- IO を行う組み込みの関数とプロセスの終了の関数の呼び出し。 -/
theorem progress_io (hb : B.Assumptions P) {Ψ σ b0 s ts es ws k} (hσ : StoreOk P B Ψ σ)
    (hsig : B.sig b0 = some s) (hkd : s.kind = .io ∨ s.kind = .exit) (htl : ts.length = s.ntys)
    (hel : es.length = s.neffs) (had : s.admits [] ts)
    (hargs : HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst ts es))) :
    ∃ l s', Step P B (.run (.app (.prim b0 ts es) ws) k σ) l s' := by
  by_cases hno : NoHandler k (.prim b0)
  · obtain ⟨o, ho⟩ := hb.io_exists Ψ b0 s ts es ws hsig hkd htl hel had hargs
    rcases hb.io_kind b0 s ts es ws o hsig ho with ⟨hk, hne⟩ | ⟨hk, hne⟩
    · cases o with
      | val v => exact ⟨_, _, .E_IO hsig hk hno ho⟩
      | err r => exact ⟨_, _, .E_IOErr hsig (Or.inl hk) hno ho⟩
      | exit n => exact absurd rfl (hne n)
    · cases o with
      | val v => exact absurd rfl (hne v)
      | err r => exact ⟨_, _, .E_IOErr hsig (Or.inr hk) hno ho⟩
      | exit n => exact ⟨_, _, .E_Exit hsig hk hno ho⟩
  · obtain ⟨k1, h, k2, hsplit⟩ := split_of_not_noHandler hno
    obtain ⟨c, hc⟩ := findClause_of_handles hsplit.2.1
    obtain ⟨κ, hκ, _⟩ := hσ.fresh
    exact ⟨_, _, .E_OpPrim hsig hkd hsplit hc hκ⟩

/-- 組み込みの関数の呼び出し。 -/
theorem progress_prim (hb : B.Assumptions P) {Ψ σ R a ε1 b0 ts es ws k} (hσ : StoreOk P B Ψ σ)
    (hm : HasTypeC P B Ψ [] [] R (.app (.prim b0 ts es) ws) a ε1) :
    ∃ l s', Step P B (.run (.app (.prim b0 ts es) ws) k σ) l s' := by
  obtain ⟨s, hsig, htl, hel, had, hargs, _, _⟩ := inv_prim_app hm
  cases hkd : s.kind with
  | pure =>
      obtain ⟨o, hδ, hne, _⟩ := hb.delta_typed Ψ b0 s ts es ws hsig hkd htl hel had hargs
      cases o with
      | val v => exact ⟨_, _, .E_Prim hsig hkd hδ⟩
      | err r => exact ⟨_, _, .E_Err hsig hkd hδ⟩
      | exit n => exact absurd rfl (hne n)
  | io => exact progress_io hb hσ hsig (Or.inl hkd) htl hel had hargs
  | exit => exact progress_io hb hσ hsig (Or.inr hkd) htl hel had hargs
  | refNew =>
      obtain ⟨t, rfl, rfl, hargs', _, _⟩ := store_prim_inv hb hsig (by simp [hkd]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkd] at hsh
      obtain ⟨_, _, hps, _, _⟩ := hsh
      have hl := hargs'.length_eq
      rw [hps] at hl; simp at hl
      obtain ⟨v, rfl⟩ := single_of_length hl
      obtain ⟨l, hl, _⟩ := hσ.fresh
      exact ⟨_, _, .E_RefNew hsig hkd hl⟩
  | refGet =>
      obtain ⟨t, rfl, rfl, hargs', _, _⟩ := store_prim_inv hb hsig (by simp [hkd]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkd] at hsh
      obtain ⟨_, _, hps, _, _⟩ := hsh
      rw [hps] at hargs'
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs'
      rcases hargs' with _ | ⟨hw, _ | _⟩
      obtain ⟨l, rfl, hΨl⟩ := hw.canonical_ref
      obtain ⟨v, hv⟩ := hσ.ref_cell hΨl
      exact ⟨_, _, .E_RefGet hsig hkd hv⟩
  | refSet =>
      obtain ⟨t, rfl, rfl, hargs', _, _⟩ := store_prim_inv hb hsig (by simp [hkd]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkd] at hsh
      obtain ⟨_, _, hps, _, _⟩ := hsh
      rw [hps] at hargs'
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs'
      rcases hargs' with _ | ⟨hw, _ | ⟨_, _ | _⟩⟩
      obtain ⟨l, rfl, _⟩ := hw.canonical_ref
      exact ⟨_, _, .E_RefSet hsig hkd⟩
  | refUpdate =>
      obtain ⟨t, rfl, rfl, hargs', _, _⟩ := store_prim_inv hb hsig (by simp [hkd]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkd] at hsh
      obtain ⟨_, _, hps, _, _⟩ := hsh
      rw [hps] at hargs'
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs'
      rcases hargs' with _ | ⟨hw, _ | ⟨_, _ | _⟩⟩
      obtain ⟨l, rfl, _⟩ := hw.canonical_ref
      exact ⟨_, _, .E_RefUpdate hsig hkd⟩
  | force =>
      obtain ⟨t, rfl, rfl, hargs', _, _⟩ := store_prim_inv hb hsig (by simp [hkd]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkd] at hsh
      obtain ⟨_, _, hps, _, _⟩ := hsh
      rw [hps] at hargs'
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs'
      rcases hargs' with _ | ⟨hw, _ | _⟩
      obtain ⟨l, rfl, hΨl⟩ := hw.canonical_lazy
      rcases hσ.lazy_cell hΨl with ⟨m, hm'⟩ | ⟨v, hv⟩
      · exact ⟨_, _, .E_Force hsig hkd hm'⟩
      · exact ⟨_, _, .E_ForceDone hsig hkd hv⟩

/-- 関数の適用。 -/
theorem progress_app (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {Ψ σ R a b ε ε1 Eb f ws k}
    (hσ : StoreOk P B Ψ σ) (hm : HasTypeC P B Ψ [] [] R (.app f ws) a ε1) (hε : Eff.Sub ε1 ε)
    (hk : ContTy P B Ψ R ε k a b Eb none) (hEb : BuiltinOnly P B Eb) :
    ∃ l s', Step P B (.run (.app f ws) k σ) l s' := by
  obtain ⟨as, b', ε', hf, hargs, _, _⟩ := hm.inv_app rfl
  rcases hf.canonical_fn with ⟨ps, body, rfl⟩ | ⟨g, ts, es, rfl⟩ | ⟨b0, ts, es, rfl⟩ | ⟨o, ts, rfl⟩
  · obtain ⟨r, ε'', _, hle⟩ := hf.inv_lam rfl
    obtain ⟨hps, _, _⟩ := Ty.Le.fn_fn' hle
    exact ⟨_, _, .E_Lam (by rw [hargs.length_eq, hps])⟩
  · obtain ⟨d, hd, hsat, hes, hle⟩ := hf.inv_fnRef rfl
    rw [fnTy_eq] at hle
    obtain ⟨hps, _, _⟩ := Ty.Le.fn_fn' hle
    have hwl : ws.length = d.params.length := by rw [hargs.length_eq, ← hps, List.length_map]
    exact ⟨_, _, .E_Fun hd hwl hsat.1 hes⟩
  · exact progress_prim hb hσ hm
  · by_cases hno : NoHandler k (.user o)
    · obtain ⟨od, hod, _, _, _, hsub⟩ := inv_op_app hm
      refine (no_unhandled_user hdecl hk hEb hod ?_ hno).elim
      apply hε; apply hsub
      rw [Eff.substRho_nil]
      simp [Eff.single]
    · obtain ⟨k1, h, k2, hsplit⟩ := split_of_not_noHandler hno
      obtain ⟨c, hc⟩ := findClause_of_handles hsplit.2.1
      obtain ⟨κ, hκ, _⟩ := hσ.fresh
      exact ⟨_, _, .E_Op hsplit hc hκ⟩

theorem progress_run (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {Ψ σ R a b ε ε1 Eb m k}
    (hσ : StoreOk P B Ψ σ) (hm : HasTypeC P B Ψ [] [] R m a ε1) (hε : Eff.Sub ε1 ε)
    (hk : ContTy P B Ψ R ε k a b Eb none) (hEb : BuiltinOnly P B Eb) :
    State.Final (.run m k σ) ∨ ∃ l s', Step P B (.run m k σ) l s' := by
  cases m with
  | ret v => exact progress_ret hb hσ hk
  | letIn m n => exact Or.inr ⟨_, _, .E_Let⟩
  | app f ws => exact Or.inr (progress_app hdecl hb hσ hm hε hk hEb)
  | ite v m n =>
      obtain ⟨_, _, hv, _⟩ := hm.inv_ite rfl
      obtain ⟨c, rfl⟩ := hv.canonical_boolean
      cases c
      · exact Or.inr ⟨_, _, .E_IfF⟩
      · exact Or.inr ⟨_, _, .E_IfT⟩
  | «match» v arms =>
      obtain ⟨_, _, _, hv, _, hex, _⟩ := hm.inv_match rfl
      obtain ⟨m', ws, hfm⟩ := firstMatch_exists (hex v hv.inhabits)
      exact Or.inr ⟨_, _, .E_Match hfm⟩
  | lazyC m =>
      obtain ⟨l, hl, _⟩ := hσ.fresh
      exact Or.inr ⟨_, _, .E_Lazy hl⟩
  | escape v =>
      obtain ⟨r, hR, _⟩ := hm.inv_escape rfl
      exact Or.inr (progress_escape hb hσ hk hR)
  | use v m => exact Or.inr ⟨_, _, .E_Use⟩
  | handle m h => exact Or.inr ⟨_, _, .E_Handle⟩
  | resume w v =>
      rcases hm.resume_form rfl with ⟨i, rfl⟩ | ⟨κ, rfl⟩
      · obtain ⟨_, _, _, hi, _⟩ := hm.inv_resumeVar rfl
        simp at hi
      · obtain ⟨_, _, _, hΨκ, _⟩ := hm.inv_resumeL rfl
        rcases hσ.cont_cell hΨκ with h | ⟨k', h⟩
        · exact Or.inr ⟨_, _, .E_ResumeErr h⟩
        · exact Or.inr ⟨_, _, .E_Resume h⟩
  | meth v m ss es ws => exact Or.inr (progress_meth hwt hm)

theorem progressE (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {Eb : Eff} {s : State}
    (hs : StateTyE P B Eb s) (hEb : BuiltinOnly P B Eb) : s.Final ∨ ∃ l s', Step P B s l s' := by
  cases s with
  | run m k σ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, _, _, _⟩ := hs
      exact progress_run hwt hdecl hb hσ hm hε hk hEb
  | error rs k σ =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, _, _⟩ := hs
      exact progress_error hb hσ hk
  | exit n rs k σ =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, _, _⟩ := hs
      exact progress_exit hb hσ hk

end Benitoite.Release
