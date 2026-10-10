import Benitoite.Release.Lemmas.Rename
import Benitoite.Release.Lemmas.TyLemmas
import Benitoite.Release.Assumptions

/-!
# 型の正しさの伝播（段階 B）

環境・ストアの型付け・項の型が正しいとき、型付けの導出の結果の型も正しい。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 環境の型は、番号が `n` より小さい型の変数だけを使う。 -/
def EnvWF (n : Nat) (Γ : List (Option Ty)) : Prop :=
  ∀ (i : Nat) (x : Ty), Γ[i]? = some (some x) → Ty.WF n x

/-- ストアの型付けの型は、型の変数を含まない。 -/
def StoreTy.WF (Ψ : StoreTy) : Prop := ∀ l x, Ψ l = some x → x.WF

theorem Ty.Le.wf {n a b} (h : Ty.Le a b) (w : Ty.WF n a) : Ty.WF n b := by
  rcases h with rfl | ⟨ps, r, ε, ε', rfl, rfl, _⟩
  · exact w
  · simpa [Ty.WF] using w

theorem Ty.Le.wf_rev {n a b} (h : Ty.Le a b) (w : Ty.WF n b) : Ty.WF n a := by
  rcases h with rfl | ⟨ps, r, ε, ε', rfl, rfl, _⟩
  · exact w
  · simpa [Ty.WF] using w

mutual
  /-- 型引数で置き換えた型の正しさ（型引数が閉じているとは限らない、束縛の外側での置き換え）。 -/
  theorem Ty.subst_wf {n : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ t ∈ ts, Ty.WF n t) :
      (a : Ty) → Ty.WF ts.length a → Ty.WF n (a.subst ts es)
    | .base _, _ => by simp [Ty.subst, Ty.substAt, Ty.WF]
    | .opaque _, _ => by simp [Ty.subst, Ty.substAt, Ty.WF]
    | .data _ args, w => by
        simp only [Ty.WF] at w
        have := Ty.substList_wf es hts args w
        simp only [Ty.subst] at this ⊢; simp only [Ty.substAt, Ty.WF]; exact this
    | .list a, w => by
        simp only [Ty.WF] at w
        have := Ty.subst_wf es hts a w
        simp only [Ty.subst] at this ⊢; simp only [Ty.substAt, Ty.WF]; exact this
    | .fn ps r _, w => by
        simp only [Ty.WF] at w
        have h1 := Ty.substList_wf es hts ps w.1
        have h2 := Ty.subst_wf es hts r w.2
        simp only [Ty.subst] at h1 h2 ⊢; simp only [Ty.substAt, Ty.WF]; exact ⟨h1, h2⟩
    | .tvar i, w => by
        simp only [Ty.WF] at w
        simp only [Ty.subst, Ty.substAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, w,
          List.getElem?_eq_getElem w, Option.getD_some, Ty.shift_zero]
        exact hts _ (List.getElem_mem w)
    | .reference a, w => by
        simp only [Ty.WF] at w
        have := Ty.subst_wf es hts a w
        simp only [Ty.subst] at this ⊢; simp only [Ty.substAt, Ty.WF]; exact this
    | .lazy a, w => by
        simp only [Ty.WF] at w
        have := Ty.subst_wf es hts a w
        simp only [Ty.subst] at this ⊢; simp only [Ty.substAt, Ty.WF]; exact this
    | .cont b t _, w => by
        simp only [Ty.WF] at w
        have h1 := Ty.subst_wf es hts b w.1
        have h2 := Ty.subst_wf es hts t w.2
        simp only [Ty.subst] at h1 h2 ⊢; simp only [Ty.substAt, Ty.WF]; exact ⟨h1, h2⟩
    | .map a b, w => by
        simp only [Ty.WF] at w
        have h1 := Ty.subst_wf es hts a w.1
        have h2 := Ty.subst_wf es hts b w.2
        simp only [Ty.subst] at h1 h2 ⊢; simp only [Ty.substAt, Ty.WF]; exact ⟨h1, h2⟩
    | .set a, w => by
        simp only [Ty.WF] at w
        have := Ty.subst_wf es hts a w
        simp only [Ty.subst] at this ⊢; simp only [Ty.substAt, Ty.WF]; exact this
    | .bytes, _ => by simp [Ty.subst, Ty.substAt, Ty.WF]
    | .dict _ τ, w => by
        simp only [Ty.WF] at w
        have := Ty.subst_wf es hts τ w
        simp only [Ty.subst] at this ⊢; simp only [Ty.substAt, Ty.WF]; exact this
    | .tapp i args, w => by
        simp only [Ty.WF] at w
        have hl := Ty.substList_wf es hts args w.2
        simp only [Ty.subst] at hl ⊢
        simp only [Ty.substAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, w.1,
          List.getElem?_eq_getElem w.1, Option.getD_some, Ty.shift_zero]
        exact Ty.applyTo_wf (hts _ (List.getElem_mem w.1)) hl
    | .ctor _, _ => by simp [Ty.subst, Ty.substAt, Ty.WF]

  theorem Ty.substList_wf {n : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ t ∈ ts, Ty.WF n t) :
      (as : List Ty) → Ty.WFList ts.length as → Ty.WFList n (as.map (Ty.subst ts es))
    | [], _ => trivial
    | a :: as, w => by
        simp only [Ty.WFList] at w
        simp only [List.map_cons, Ty.WFList]
        exact ⟨Ty.subst_wf es hts a w.1, Ty.substList_wf es hts as w.2⟩
end

theorem fnTy_wf {n ps r ε ts es} (hts : ∀ t ∈ ts, Ty.WF n t) (hps : Ty.WFList ts.length ps)
    (hr : Ty.WF ts.length r) : Ty.WF n (fnTy ps r ε ts es) := by
  rw [fnTy_eq]
  simp only [Ty.WF]
  exact ⟨by simpa [Ty.subst] using Ty.substList_wf es hts ps hps, Ty.subst_wf es hts r hr⟩

theorem EnvWF.binds' {n as Γ} (has : ∀ a ∈ as, Ty.WF n a) (hΓ : EnvWF n Γ) :
    EnvWF n (Release.binds as ++ Γ) := by
  intro i x hi
  by_cases hlt : i < (Release.binds as).length
  · rw [List.getElem?_append_left hlt] at hi
    simp only [binds, List.getElem?_map, Option.map_eq_some_iff, Option.some.injEq] at hi
    obtain ⟨y, hy, rfl⟩ := hi
    exact has _ (List.mem_reverse.mp (List.mem_of_getElem? hy))
  · rw [List.getElem?_append_right (by omega)] at hi
    exact hΓ _ _ hi

theorem EnvWF.hide {n Γ} (h : EnvWF n Γ) : EnvWF n (hideConts Γ) := by
  intro i x hi
  exact h _ _ (hideConts_get.mp hi).1

theorem EnvWF.shift {n Γ} (k : Nat) (h : EnvWF n Γ) : EnvWF (n + k) (shiftEnv k Γ) := by
  intro i x hi
  simp only [shiftEnv, List.getElem?_map, Option.map_eq_some_iff] at hi
  obtain ⟨o, ho, hox⟩ := hi
  cases o with
  | none => simp at hox
  | some y =>
      simp only [Option.some.injEq] at hox
      obtain ⟨a, rfl, rfl⟩ := hox
      exact Ty.shift_wf k _ (h _ _ ho)

theorem Const.type_wf (c : Const) (n : Nat) : Ty.WF n c.type := by
  cases c <;> simp [Const.type, Ty.WF]

theorem varsInList_mem {n pe} : {as : List Ty} → Ty.VarsInList n pe as → ∀ {a}, a ∈ as → Ty.VarsIn n pe a
  | [], _, _, h => by simp at h
  | b :: bs, w, a, h => by
      simp only [Ty.VarsInList] at w
      rcases List.mem_cons.mp h with rfl | h
      · exact w.1
      · exact varsInList_mem w.2 h

-- パターンが束縛する変数の型の正しさ。
mutual
  theorem PatTy.wf {n : Nat} (hwf : P.WellFormed) {p a δ} (hp : PatTy P p a δ) (ha : Ty.WF n a) :
      ∀ x ∈ δ, Ty.WF n x := by
    match hp with
    | .P_Wild => simp
    | .P_Var => simpa using ha
    | .P_Const _ _ _ _ => simp
    | .P_RangeInt => simp
    | .P_RangeChar => simp
    | .P_List (rest := rest) hb ht _ =>
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · rcases List.mem_append.mp hx with hx | hx
          · exact PatTys.wf hwf hb (fun y hy => by
              have he := (List.mem_replicate.mp hy).2; subst y; exact ha) x hx
          · cases rest with
            | none => simp [restTys] at hx
            | some r => cases r with
              | skip => simp [restTys] at hx
              | bind => simp [restTys] at hx; subst x; exact ha
        · exact PatTys.wf hwf ht (fun y hy => by
            have he := (List.mem_replicate.mp hy).2; subst y; exact ha) x hx
    | .P_Con (cd := cd) (ts := ts) hc hts hps =>
        simp only [Ty.WF] at ha
        refine PatTys.wf hwf hps ?_
        intro x hx
        obtain ⟨y, hy, rfl⟩ := List.mem_map.mp hx
        have hs : Ty.WF cd.ntys y := Ty.VarsIn.wf y (varsInList_mem (hwf.2.1 _ _ hc) hy)
        exact Ty.subst_wf [] (Ty.WFList.iff.mp ha) y (by rw [hts]; exact hs)

  theorem PatTys.wf {n : Nat} (hwf : P.WellFormed) {ps as δ} (hps : PatTys P ps as δ)
      (has : ∀ x ∈ as, Ty.WF n x) : ∀ x ∈ δ, Ty.WF n x := by
    match hps with
    | .nil => simp
    | .cons hp hps' =>
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · exact PatTy.wf hwf hp (has _ (by simp)) x hx
        · exact PatTys.wf hwf hps' (fun y hy => has y (by simp [hy])) x hx
end

theorem AltsTy.wf {n alts a δ} (hwf : P.WellFormed) (h : AltsTy P alts a δ)
    (ha : Ty.WF n a) : ∀ x ∈ δ, Ty.WF n x := by
  obtain ⟨p, γ, slots, hp, hs⟩ := h.witness
  intro x hx
  exact PatTy.wf hwf hp ha x (selectSlots_mem hs x hx)

theorem LocTy.WF.ref {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) {l a} (h : Ψ l = some (.ref a)) (n : Nat) :
    Ty.WF n a := Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h)

theorem LocTy.WF.lazy {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) {l a} (h : Ψ l = some (.lazy a)) (n : Nat) :
    Ty.WF n a := Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h)

theorem LocTy.WF.contT {Ψ : StoreTy} (hΨ : StoreTy.WF Ψ) {l b t ε r} (h : Ψ l = some (.cont b t ε r))
    (n : Nat) : Ty.WF n t := Ty.WF.mono (Nat.zero_le _) _ (hΨ _ _ h).2.1

mutual
  /-- 型付けの結果の型の正しさ（値）。 -/
  theorem HasTypeV.wf (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ v a}
      (h : HasTypeV P B Ψ C Γ v a) (hΓ : EnvWF C.length Γ) (hΨ : StoreTy.WF Ψ)
      (hv : Val.VarsIn C.length (fun _ => True) v) : Ty.WF C.length a := by
    match h with
    | .V_Var hi _ => exact hΓ _ _ hi
    | .V_Const => exact Const.type_wf _ _
    | .V_Fun hd hts _ =>
        simp only [Val.VarsIn] at hv
        have hsc := hwf.1 _ _ hd
        unfold Def.Scoped at hsc
        have hl : _ = _ := hts.1
        refine fnTy_wf (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1)) ?_ ?_
        · rw [hl]; exact Ty.VarsInList.wf _ hsc.1
        · rw [hl]; exact Ty.VarsIn.wf _ hsc.2.1
    | .V_Prim hs hts _ _ =>
        simp only [Val.VarsIn] at hv
        have hsc := hb.sig_scoped _ _ hs
        unfold PrimSig.Scoped at hsc
        refine fnTy_wf (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1)) ?_ ?_
        · rw [hts]; exact Ty.VarsInList.wf _ hsc.1
        · rw [hts]; exact Ty.VarsIn.wf _ hsc.2.1
    | .V_Op hod hts =>
        simp only [Val.VarsIn] at hv
        have hsc := hwf.2.2.1 _ _ hod
        unfold OpDecl.Scoped at hsc
        have hl : _ = _ := hts.1
        refine fnTy_wf (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv)) ?_ ?_
        · rw [hl]; exact Ty.VarsInList.wf _ hsc.1
        · rw [hl]; exact Ty.VarsIn.wf _ hsc.2
    | .V_Lam (ps := ps) hbody =>
        simp only [Val.VarsIn] at hv
        have hps := Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1)
        have := HasTypeC.wf hwf hb hbody (EnvWF.binds' hps hΓ.hide) hΨ hv.2
        simp only [Ty.WF]
        exact ⟨Ty.WFList.iff.mpr hps, this⟩
    | .V_Con hc hts _ =>
        simp only [Val.VarsIn] at hv
        simp only [Ty.WF]; exact Ty.VarsInList.wf _ hv.1
    | .V_List _ hw => simpa [Ty.WF] using hw
    | .V_LocRef hl => simpa [Ty.WF] using LocTy.WF.ref hΨ hl C.length
    | .V_LocLazy hl => simpa [Ty.WF] using LocTy.WF.lazy hΨ hl C.length
    | .V_Map _ _ _ _ hwa hwb => simp only [Ty.WF]; exact ⟨hwa, hwb⟩
    | .V_Set _ _ hw => simpa [Ty.WF] using hw
    | .V_Bytes => simp [Ty.WF]
    | .V_Dict (id := id) hi hts _ =>
        simp only [Val.VarsIn] at hv
        have hsc := (hwf.2.2.2.2 _ _ hi).2.1
        have hl : _ = _ := hts.1
        simp only [Ty.WF]
        exact Ty.subst_wf [] (Ty.WFList.iff.mp (Ty.VarsInList.wf _ hv.1)) _
          (by rw [hl]; exact Ty.VarsIn.wf _ hsc)
    | .V_Super hv' _ _ =>
        simp only [Val.VarsIn] at hv
        have := HasTypeV.wf hwf hb hv' hΓ hΨ hv
        simpa [Ty.WF] using this
    | .V_Sub h hle => exact hle.wf (HasTypeV.wf hwf hb h hΓ hΨ hv)

  /-- 型付けの結果の型の正しさ（計算）。 -/
  theorem HasTypeC.wf (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ R m a ε}
      (h : HasTypeC P B Ψ C Γ R m a ε) (hΓ : EnvWF C.length Γ) (hΨ : StoreTy.WF Ψ)
      (hm : Comp.VarsIn C.length (fun _ => True) m) : Ty.WF C.length a := by
    match h with
    | .C_Return hv => simp only [Comp.VarsIn] at hm; exact HasTypeV.wf hwf hb hv hΓ hΨ hm
    | .C_Sub h hle _ => exact hle.wf (HasTypeC.wf hwf hb h hΓ hΨ hm)
    | .C_Let hm' hn =>
        simp only [Comp.VarsIn] at hm
        have ha := HasTypeC.wf hwf hb hm' hΓ hΨ hm.1
        refine HasTypeC.wf hwf hb hn ?_ hΨ hm.2
        have := EnvWF.binds' (as := [_]) (by simpa using ha) hΓ
        simpa [Release.binds] using this
    | .C_App hf _ =>
        simp only [Comp.VarsIn] at hm
        have := HasTypeV.wf hwf hb hf hΓ hΨ hm.1
        simp only [Ty.WF] at this; exact this.2
    | .C_If _ hm' _ => simp only [Comp.VarsIn] at hm; exact HasTypeC.wf hwf hb hm' hΓ hΨ hm.2.1
    | .C_Match hv harms _ =>
        simp only [Comp.VarsIn] at hm
        exact HasTypeArms.wf hwf hb harms (HasTypeV.wf hwf hb hv hΓ hΨ hm.1) hΓ hΨ hm.2
    | .C_Lazy hm' =>
        simp only [Comp.VarsIn] at hm
        simpa [Ty.WF] using HasTypeC.wf hwf hb hm' hΓ.hide hΨ hm
    | .C_Escape _ hw => exact hw
    | .C_Use _ _ hm' _ => simp only [Comp.VarsIn] at hm; exact HasTypeC.wf hwf hb hm' hΓ hΨ hm.2
    | .C_Handle hm' _ _ => simp only [Comp.VarsIn] at hm; exact HasTypeC.wf hwf hb hm' hΓ hΨ hm.1
    | .C_Resume hi _ =>
        have := hΓ _ _ hi
        simp only [Ty.WF] at this; exact this.2
    | .C_ResumeL hl _ => exact LocTy.WF.contT hΨ hl C.length
    | .C_Meth (τ := τ) (ms := ms) hv hc hmeth hts _ _ =>
        simp only [Comp.VarsIn] at hm
        have hτ : Ty.WF C.length τ := by
          have := HasTypeV.wf hwf hb hv hΓ hΨ hm.1
          simpa [Ty.WF] using this
        have hsc := hwf.2.2.2.1 _ _ hc _ _ hmeth
        have hl : _ = _ := hts.1
        refine Ty.subst_wf _ ?_ _ ?_
        · intro t ht
          rcases List.mem_append.mp ht with ht | ht
          · exact Ty.WFList.iff.mp (Ty.VarsInList.wf _ hm.2.1) t ht
          · simp at ht; rw [ht]; exact hτ
        · simp only [List.length_append, List.length_singleton, hl]
          exact Ty.VarsIn.wf _ hsc.2.1

  theorem HasTypeArms.wf (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ C Γ R arms a b ε}
      (h : HasTypeArms P B Ψ C Γ R arms a b ε) (ha : Ty.WF C.length a) (hΓ : EnvWF C.length Γ)
      (hΨ : StoreTy.WF Ψ) (harms : Arm.VarsInList C.length (fun _ => True) arms) :
      Ty.WF C.length b := by
    match h with
    | .nil hw => exact hw
    | .plain hp hbody _ =>
        simp only [Arm.VarsInList] at harms
        exact HasTypeC.wf hwf hb hbody (EnvWF.binds' (AltsTy.wf hwf hp ha) hΓ) hΨ harms.1
    | .guarded hp _ hbody _ =>
        simp only [Arm.VarsInList] at harms
        exact HasTypeC.wf hwf hb hbody (EnvWF.binds' (AltsTy.wf hwf hp ha) hΓ) hΨ harms.2.1

end

end Benitoite.Release
