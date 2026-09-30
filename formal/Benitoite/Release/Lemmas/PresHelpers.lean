import Benitoite.Release.Lemmas.StoreLemmas
import Benitoite.Release.Assumptions

/-!
# 保存の証明の補助（段階 B）
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 継続の末尾の添字を固定した状態の型付け。保存の証明では、継続の末尾で許すエフェクト Eb が変わらない
ことも示すので、Eb を引数に取る。 -/
def StateTyE (P : Program) (B : Builtins) (Eb : Eff) : State → Prop
  | .run m k σ => ∃ Ψ R a b ε ε1,
      StoreOk P B Ψ σ ∧ HasTypeC P B Ψ [] [] R m a ε1 ∧ Eff.Sub ε1 ε ∧
      ContTy P B Ψ R ε k a b Eb none ∧
      Comp.VarsIn 0 (fun _ => True) m ∧ Cont.Closed k ∧ Store.Closed σ
  | .error _ k σ => ∃ Ψ R a b ε,
      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ Cont.Closed k ∧ Store.Closed σ
  | .exit _ _ k σ => ∃ Ψ R a b ε,
      StoreOk P B Ψ σ ∧ ContTy P B Ψ R ε k a b Eb none ∧ Cont.Closed k ∧ Store.Closed σ

theorem stateTy_iff {s : State} : StateTy P B s ↔ ∃ Eb, BuiltinOnly P B Eb ∧ StateTyE P B Eb s := by
  cases s with
  | run m k σ =>
      simp only [StateTy, StateTyE]
      constructor
      · rintro ⟨Ψ, R, a, b, ε, ε1, Eb, h1, h2, h3, h4, h5, h6, h7, h8⟩
        exact ⟨Eb, h5, Ψ, R, a, b, ε, ε1, h1, h2, h3, h4, h6, h7, h8⟩
      · rintro ⟨Eb, h5, Ψ, R, a, b, ε, ε1, h1, h2, h3, h4, h6, h7, h8⟩
        exact ⟨Ψ, R, a, b, ε, ε1, Eb, h1, h2, h3, h4, h5, h6, h7, h8⟩
  | error rs k σ =>
      simp only [StateTy, StateTyE]
      constructor
      · rintro ⟨Ψ, R, a, b, ε, Eb, h1, h2, h3, h4, h5⟩; exact ⟨Eb, h3, Ψ, R, a, b, ε, h1, h2, h4, h5⟩
      · rintro ⟨Eb, h3, Ψ, R, a, b, ε, h1, h2, h4, h5⟩; exact ⟨Ψ, R, a, b, ε, Eb, h1, h2, h3, h4, h5⟩
  | exit n rs k σ =>
      simp only [StateTy, StateTyE]
      constructor
      · rintro ⟨Ψ, R, a, b, ε, Eb, h1, h2, h3, h4, h5⟩; exact ⟨Eb, h3, Ψ, R, a, b, ε, h1, h2, h4, h5⟩
      · rintro ⟨Eb, h3, Ψ, R, a, b, ε, h1, h2, h4, h5⟩; exact ⟨Ψ, R, a, b, ε, Eb, h1, h2, h3, h4, h5⟩

/-! ## 閉じた継続 -/

theorem Cont.Closed.cons {f : Frame} {k : Cont} : Cont.Closed (f :: k) ↔ f.Closed ∧ Cont.Closed k := by
  simp [Cont.Closed]

theorem Cont.Closed.append {k1 k2 : Cont} : Cont.Closed (k1 ++ k2) ↔ Cont.Closed k1 ∧ Cont.Closed k2 := by
  simp only [Cont.Closed, List.mem_append]
  constructor
  · intro h; exact ⟨fun f hf => h f (Or.inl hf), fun f hf => h f (Or.inr hf)⟩
  · rintro ⟨h1, h2⟩ f (hf | hf)
    · exact h1 f hf
    · exact h2 f hf

theorem Cont.Closed.releases {k : Cont} (h : Cont.Closed k) : Cont.Closed (releases k) := by
  intro f hf
  exact h f (releases_sub k f hf).1

theorem Cont.Closed.markPush {k : Cont} (h : Cont.Closed k) :
    Cont.Closed (Benitoite.Release.markPush k) := by
  unfold Benitoite.Release.markPush
  split
  · exact h
  · exact Cont.Closed.cons.mpr ⟨trivial, h⟩

/-! ## 継続の R の正しさ -/

theorem ContTy.R_wf {Ψ R ε k a b ε0 Re} (h : ContTy P B Ψ R ε k a b ε0 Re)
    (hRe : ∀ x, Re = some x → Ty.WF 0 x) : ∀ x, R = some x → Ty.WF 0 x := by
  induction h with
  | K_Empty _ _ => exact hRe
  | K_Let _ _ _ ih => exact ih hRe
  | K_Mark _ hw _ => intro x hx; cases hx; exact hw
  | K_Update _ _ _ => intro x hx; cases hx
  | K_Release _ _ _ _ ih => exact ih hRe
  | K_Handle _ _ _ _ ih => exact ih hRe
  | K_Drop _ _ _ ih => exact ih hRe
  | K_Sub _ _ ih => exact ih hRe

/-! ## `markPush` -/

/-- 関数の呼び出しの遷移が `mark` を積んだ継続に、呼び出した関数の本体の R で型を付ける。 -/
theorem ContTy.markPush {Ψ R ε k a b E r} (hk : ContTy P B Ψ R ε k a b E none) (hle : Ty.Le r a)
    (hw : Ty.WF 0 r) : ContTy P B Ψ (some r) ε (Benitoite.Release.markPush k) r b E none := by
  unfold Benitoite.Release.markPush
  split
  · rename_i k0
    obtain ⟨a', R', hle', hR, hrest, _⟩ := hk.inv_mark
    exact .K_Mark (.K_Sub hrest (hle.trans hle')) hw
  · exact .K_Mark (.K_Sub hk hle) hw

/-! ## 節の探索 -/

theorem HasTypeClauses.find {Ψ C Γ R hs t ε o c} (h : HasTypeClauses P B Ψ C Γ R hs t ε)
    (hc : findClause hs o = some c) :
    ∃ sg, opSig P B o = some sg ∧ c.arity = sg.params.length ∧ c.ntys = sg.tparams.length ∧
      HasTypeC P B Ψ (sg.tparams ++ C)
        (some (.cont sg.ret (t.shift c.ntys 0) ε) :: (binds sg.params ++ shiftEnv c.ntys Γ))
        (R.map (Ty.shift c.ntys 0)) c.body (t.shift c.ntys 0) ε := by
  match h with
  | .nil => simp [findClause] at hc
  | .cons (o := o') (n := n) (k := k) (body := body) hsg hn hk hbody hrest =>
      simp only [findClause, List.find?_cons] at hc
      split at hc
      · rename_i heq
        simp only [Option.some.injEq] at hc
        subst hc
        have : o' = o := by simpa [Clause.op] using heq
        subst this
        exact ⟨_, hsg, hn, hk, hbody⟩
      · exact HasTypeClauses.find hrest hc

theorem findClause_op {hs : List Clause} {o c} (h : findClause hs o = some c) : c.op = o := by
  simp only [findClause] at h
  have := List.find?_some h
  simpa using this

/-! ## 閉じた値の並び -/

theorem HasTypeVs.get {Ψ C Γ vs as} :
    HasTypeVs P B Ψ C Γ vs as → ∀ (i : Nat) (a : Ty), as[i]? = some a →
      ∃ v, vs[i]? = some v ∧ HasTypeV P B Ψ C Γ v a
  | .nil, i, a, h => by simp at h
  | .cons hv _, 0, a, h => by simp at h; subst h; exact ⟨_, rfl, hv⟩
  | .cons _ hvs, i + 1, a, h => by simpa using HasTypeVs.get hvs i a (by simpa using h)

theorem Val.VarsInList.get {n pe} : {ws : List Val} → Val.VarsInList n pe ws → ∀ {i : Nat} {w},
    ws[i]? = some w → Val.VarsIn n pe w
  | [], _, _, _, h => by simp at h
  | v :: vs, hcl, 0, w, h => by simp at h; subst h; exact hcl.1
  | v :: vs, hcl, i + 1, w, h => Val.VarsInList.get hcl.2 (by simpa using h)

theorem InstOk.of_values (hb : B.Assumptions P) {Ψ R0 ws as} (hws : HasTypeVs P B Ψ [] [] ws as)
    (hwf : ∀ x ∈ as, Ty.WF 0 x) (hcl : Val.VarsInList 0 (fun _ => True) ws) :
    InstOk P B Ψ R0 as ws := by
  refine ⟨hws.length_eq, fun i x w hx hw => Or.inl ?_⟩
  obtain ⟨w', hw', hwt⟩ := hws.get i x hx
  rw [hw] at hw'; cases hw'
  exact ⟨hwt.notCont, hwf x (List.mem_of_getElem? hx), ClosedTy.of hb hwt (Val.VarsInList.get hcl hw)⟩

end Benitoite.Release
