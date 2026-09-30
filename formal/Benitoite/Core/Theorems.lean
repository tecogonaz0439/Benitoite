import Benitoite.Core.Lemmas.Preservation

/-!
# 段階 A の定理

設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3（エフェクトの健全性）の、
最小実行版の形を言明する。あわせて、遷移を計算する関数 `step` が関係 `Step` と一致することを言明する。

証明に使う補題は `Lemmas/` に置く。性質 2 の保存と性質 3 は、エフェクトの条件を記録する状態の型付け
（`Lemmas/Preservation.lean` の `StateTyQ`）の保存から導く。
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

/-! ## `step` と `Step` の一致 -/

/-- `step` が返す遷移は `Step` の遷移である。IO の応答は、起こりうる応答の中から `oracle` が選ぶ。 -/
theorem step_sound (oracle : Oracle)
    (horacle : ∀ b s ts es ws, B.sig b = some s → s.io = true →
      B.ioResponse b ts es ws (oracle b ts es ws))
    {s : State} {l : Option Event} {s' : State} :
    step P B oracle s = some (l, s') → Step P B s l s' := by
  intro h
  rcases s with ⟨m, k⟩ | r
  · cases m with
    | ret v =>
        cases k with
        | nil => simp [step] at h
        | cons fr k =>
            cases fr
            simp only [step, Option.some.injEq, Prod.mk.injEq] at h
            obtain ⟨rfl, rfl⟩ := h
            exact .E_Return
    | letIn m n =>
        simp only [step, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        exact .E_Let
    | app f ws =>
        cases f with
        | lam ps body =>
            simp only [step] at h
            split at h
            · simp only [Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h
              exact .E_Lam ‹_›
            · cases h
        | fnRef f ts es =>
            simp only [step] at h
            split at h
            · rename_i d hd
              split at h
              · rename_i hc
                simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h
                exact .E_Fun hd hc.1 hc.2.1 hc.2.2
              · cases h
            · cases h
        | prim b ts es =>
            simp only [step] at h
            split at h
            · cases h
            · rename_i sg hsg
              split at h
              · rename_i hio
                split at h
                · rename_i v ho
                  simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_IO hsg hio (ho ▸ horacle _ _ _ _ _ hsg hio)
                · rename_i r ho
                  simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_IOErr hsg hio (ho ▸ horacle _ _ _ _ _ hsg hio)
              · rename_i hio
                have hio' : sg.io = false := by simpa using hio
                split at h
                · rename_i v hd
                  simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_Prim hsg hio' hd
                · rename_i r hd
                  simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_Err hsg hio' hd
                · cases h
        | var _ => simp [step] at h
        | const _ => simp [step] at h
        | con _ _ _ => simp [step] at h
        | list _ => simp [step] at h
    | ite v m n =>
        cases v with
        | const c =>
            cases c with
            | boolean bv =>
                cases bv
                · simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_IfF
                · simp only [step, Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  exact .E_IfT
            | _ => simp [step] at h
        | _ => simp [step] at h
    | «match» v arms =>
        simp only [step] at h
        split at h
        · rename_i m' ws hfm
          simp only [Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          exact .E_Match hfm
        · cases h
  · simp [step] at h

/-- `Step` の遷移は、その IO の応答を返す `oracle` のもとで `step` が返す。 -/
theorem step_complete (oracle : Oracle)
    {s : State} {l : Option Event} {s' : State}
    (horacle : ∀ b ts es ws k ev, s = .run (.app (.prim b ts es) ws) k → l = some ev →
      oracle b ts es ws = ev.outcome) :
    Step P B s l s' → step P B oracle s = some (l, s') := by
  intro h
  cases h with
  | E_Let => rfl
  | E_Return => rfl
  | E_Lam hlen => simp [step, hlen]
  | E_Fun hd hlen hts hes => simp [step, hd, hlen, hts, hes]
  | E_IfT => rfl
  | E_IfF => rfl
  | E_Match hfm => simp [step, hfm]
  | E_Prim hsig hio hd => simp [step, hsig, hio, hd]
  | E_Err hsig hio hd => simp [step, hsig, hio, hd]
  | E_IO hsig hio _ =>
      have ho := horacle _ _ _ _ _ _ rfl rfl
      simp [step, hsig, hio, ho]
  | E_IOErr hsig hio _ =>
      have ho := horacle _ _ _ _ _ _ rfl rfl
      simp [step, hsig, hio, ho]

/-! ## 性質 2: 進行と保存 -/

/-- 進行。型が付いた状態 `⟨M, K⟩` は、`⟨return V, []⟩` であるか、遷移できる。 -/
theorem progress (_hwf : P.WellFormed) (_hwt : P.WellTyped B) (hb : B.Assumptions P)
    {m : Comp} {k : Cont} :
    StateTy P B (.run m k) →
    (∃ v, m = .ret v ∧ k = []) ∨ ∃ l s', Step P B (.run m k) l s' := by
  rintro ⟨a, b, ε, hm, hk⟩
  cases m with
  | ret v =>
      cases k with
      | nil => exact Or.inl ⟨v, rfl, rfl⟩
      | cons fr k => cases fr; exact Or.inr ⟨_, _, .E_Return⟩
  | letIn m n => exact Or.inr ⟨_, _, .E_Let⟩
  | app f args =>
      right
      obtain ⟨as, b₁, ε₁, hf, hargs, _, _⟩ := hm.inv_app rfl
      have hlen := hargs.length_eq
      cases f with
      | var i => obtain ⟨_, hi, _⟩ := hf.inv_var rfl; simp at hi
      | const c =>
          obtain ⟨_, he, _⟩ := (hf.inv_const rfl).fn_right
          cases c <;> simp [Const.type] at he
      | fnRef g ts es =>
          obtain ⟨d, hd, hts, hes, hle⟩ := hf.inv_fnRef rfl
          rw [fnTy_eq] at hle
          obtain ⟨hps, _, _⟩ := hle.fn_fn
          exact ⟨_, _, .E_Fun hd (by rw [hlen, ← hps, List.length_map]) hts hes⟩
      | prim bn ts es =>
          obtain ⟨sg, hsg, hts, hes, had, hle⟩ := hf.inv_prim rfl
          rw [fnTy_eq] at hle
          obtain ⟨hps, _, _⟩ := hle.fn_fn
          have hargs' : HasTypeVs P B [] args (sg.params.map (Ty.subst ts es)) := by
            rw [hps]; exact hargs
          cases hio : sg.io with
          | true =>
              obtain ⟨o, ho⟩ := hb.io_exists _ _ _ _ _ hsg hio hts hes had hargs'
              cases o with
              | val v => exact ⟨_, _, .E_IO hsg hio ho⟩
              | err r => exact ⟨_, _, .E_IOErr hsg hio ho⟩
          | false =>
              obtain ⟨o, ho, _⟩ := hb.delta_typed _ _ _ _ _ hsg hio hts hes had hargs'
              cases o with
              | val v => exact ⟨_, _, .E_Prim hsg hio ho⟩
              | err r => exact ⟨_, _, .E_Err hsg hio ho⟩
      | lam ps body =>
          obtain ⟨_, _, _, hle⟩ := hf.inv_lam rfl
          obtain ⟨hps, _, _⟩ := hle.fn_fn
          exact ⟨_, _, .E_Lam (by rw [hlen, hps])⟩
      | con c ts xs => obtain ⟨_, _, _, _, h⟩ := hf.inv_con rfl; simp at h
      | list xs => obtain ⟨_, _, h⟩ := hf.inv_list rfl; simp at h
  | ite v m n =>
      right
      obtain ⟨_, _, hv, _⟩ := hm.inv_ite rfl
      obtain ⟨bv, rfl⟩ := hv.canonical_boolean
      cases bv
      · exact ⟨_, _, .E_IfF⟩
      · exact ⟨_, _, .E_IfT⟩
  | «match» v arms =>
      right
      obtain ⟨a₁, _, _, hv, _, hex, _⟩ := hm.inv_match rfl
      obtain ⟨m', ws, hfm⟩ := firstMatch_exists (hex v hv.inhabits)
      exact ⟨_, _, .E_Match hfm⟩

/-- 保存。型が付いた状態から遷移した先の状態も型が付くか、`error(r)` である。
IO の応答は、`Builtins.Assumptions.io_typed` により関数の戻り値の型の値である。 -/
theorem preservation (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P)
    {m : Comp} {k : Cont} {l : Option Event} {s' : State} :
    StateTy P B (.run m k) → Step P B (.run m k) l s' →
    StateTy P B s' ∨ ∃ r, s' = .error r := by
  intro hs hstep
  rcases preservationQ hwf hwt hb (Q := fun _ => True) (fun _ _ _ _ => trivial)
    (stateTy_iff.mp hs) hstep with h | h
  · exact Or.inl (stateTy_iff.mpr h)
  · exact Or.inr h

/-! ## 性質 3: エフェクトの健全性 -/

/-- エフェクトの健全性。`· ⊢c M : A ! { }` が成り立ち、M がエフェクト変数を含まないとき、
`⟨M, []⟩` からの実行は IO の事象を伴う遷移をしない。

`StateTy` はエフェクトを存在量化し、`ContTy` は継続の枠のエフェクトを記録しないので、`preservation` だけからは
この定理を導けない。証明では、実行中の計算と継続のすべての枠に許すエフェクトを記録する補助の状態の型付けを
定め、その保存を型付け規則から証明する（新しい仮定は置かない）。 -/
theorem effect_soundness (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P)
    {m : Comp} {a : Ty} :
    HasTypeC P B [] m a Eff.empty → m.NoEffVars →
    ∀ s ev s', Steps P B (.run m []) s → Step P B s (some ev) s' → False := by
  intro hm _ s ev s' hsteps hstep
  -- 実行中の計算と継続の各枠のエフェクトが `IO` を含まないことを、遷移で保たれる性質として追う。
  let Q : Eff → Prop := fun ε => ε .io = false
  have hQ : Eff.DownClosed Q := by
    intro ε ε' hsub h'
    show ε .io = false
    cases hε : ε .io
    · rfl
    · have := hsub _ hε
      simp only [Q] at h'
      rw [h'] at this; cases this
  have hinv : ∀ s₁ s₂, Steps P B s₁ s₂ →
      (StateTyQ P B Q s₁ ∨ ∃ r, s₁ = .error r) → (StateTyQ P B Q s₂ ∨ ∃ r, s₂ = .error r) := by
    intro s₁ s₂ h
    induction h with
    | refl => exact id
    | @step s₀ _ _ _ hst _ ih =>
        intro h₁
        apply ih
        rcases h₁ with hq | ⟨r, rfl⟩
        · cases s₀ with
          | run m₀ k₀ => exact preservationQ hwf hwt hb hQ hq hst
          | error _ => exact hq.elim
        · cases hst
  have h₀ : StateTyQ P B Q (.run m []) := ⟨a, a, Eff.empty, rfl, hm, .K_Empty⟩
  rcases hinv _ _ hsteps (Or.inl h₀) with hq | ⟨r, rfl⟩
  · cases s with
    | error _ => exact hq
    | run m₁ k₁ =>
        obtain ⟨_, _, ε, hqε, hm₁, _⟩ := hq
        -- IO の事象を伴う遷移は、IO を行う組み込みの関数の呼び出しだけである。
        cases hstep with
        | E_IO hsig hio _ | E_IOErr hsig hio _ =>
            obtain ⟨_, _, ε₁, hf, _, _, hsub⟩ := hm₁.inv_app rfl
            obtain ⟨sg, hsg, _, _, _, hle⟩ := hf.inv_prim rfl
            rw [hsig] at hsg; cases hsg
            rw [fnTy_eq] at hle
            obtain ⟨_, _, hsub₂⟩ := hle.fn_fn
            have hio' := hsub _ (hsub₂ _ (Eff.substRho_io (hb.io_effect _ _ hsig hio)))
            simp only [Q] at hqε
            rw [hqε] at hio'; cases hio'
  · cases hstep

end Benitoite.Core
