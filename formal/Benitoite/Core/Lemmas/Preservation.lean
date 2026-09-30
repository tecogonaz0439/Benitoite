import Benitoite.Core.Lemmas.Canonical
import Benitoite.Core.Semantics

/-!
# エフェクトの条件を記録する状態の型付けと、その保存

01-12 の状態の型付け（`StateTy`）は、実行中の計算のエフェクトを存在量化し、継続の枠のエフェクトを
記録しない。エフェクトの健全性を示すには、遷移の後もエフェクトが条件を満たすことを追う必要がある
（Codex の GPT-6-Astra のレビューの指摘）。そこで、エフェクトの集合の条件 `Q` を引数に取る状態の型付け
`StateTyQ Q` を定め、`Q` が部分集合について閉じていれば遷移で保たれることを示す。

`Q` をどの集合でも成り立つ条件にすると `StateTy` と同じになり（`stateTy_iff`）、保存が得られる。
`Q` を「`IO` を含まない」にすると、エフェクトの健全性が得られる。
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

/-- `⊢k K : A ⇒ B` に、各枠の計算のエフェクトが `Q` を満たすことを加えたもの。 -/
inductive ContTyQ (P : Program) (B : Builtins) (Q : Eff → Prop) : Cont → Ty → Ty → Prop
  | K_Empty {a} : ContTyQ P B Q [] a a
  | K_Let {n k a c b ε} :
      HasTypeC P B [a] n c ε → Q ε → ContTyQ P B Q k c b →
      ContTyQ P B Q (.letF n :: k) a b

/-- 状態 `⟨M, K⟩` に型が付き、実行中の計算と継続の各枠のエフェクトが `Q` を満たす。 -/
def StateTyQ (P : Program) (B : Builtins) (Q : Eff → Prop) : State → Prop
  | .run m k => ∃ a b ε, Q ε ∧ HasTypeC P B [] m a ε ∧ ContTyQ P B Q k a b
  | .error _ => False

/-- 部分集合について閉じた条件。 -/
def Eff.DownClosed (Q : Eff → Prop) : Prop := ∀ ε ε', Eff.Sub ε ε' → Q ε' → Q ε

theorem contTy_iff {k a b} : ContTy P B k a b ↔ ContTyQ P B (fun _ => True) k a b := by
  constructor
  · intro h
    induction h with
    | K_Empty => exact .K_Empty
    | K_Let hn _ ih => exact .K_Let hn trivial ih
  · intro h
    induction h with
    | K_Empty => exact .K_Empty
    | K_Let hn _ _ ih => exact .K_Let hn ih

theorem stateTy_iff {s} : StateTy P B s ↔ StateTyQ P B (fun _ => True) s := by
  cases s with
  | run m k =>
      simp only [StateTy, StateTyQ, true_and]
      constructor
      · rintro ⟨a, b, ε, hm, hk⟩; exact ⟨a, b, ε, hm, contTy_iff.mp hk⟩
      · rintro ⟨a, b, ε, hm, hk⟩; exact ⟨a, b, ε, hm, contTy_iff.mpr hk⟩
  | error r => simp [StateTy, StateTyQ]

/-- 関数の型の包含から、引数の型と結果の型の等しさと、エフェクトの包含を取り出す。 -/
theorem Ty.Le.fn_fn {ps r ε as b ε'} (h : Ty.Le (.fn ps r ε) (.fn as b ε')) :
    ps = as ∧ r = b ∧ Eff.Sub ε ε' := by
  obtain ⟨ε'', he, hs⟩ := h.fn_left
  simp only [Ty.fn.injEq] at he
  obtain ⟨rfl, rfl, rfl⟩ := he
  exact ⟨rfl, rfl, hs⟩

/-- 保存（エフェクトの条件つき）。 -/
theorem preservationQ (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P)
    {Q : Eff → Prop} (hQ : Eff.DownClosed Q) {m k l s'}
    (hs : StateTyQ P B Q (.run m k)) (hstep : Step P B (.run m k) l s') :
    StateTyQ P B Q s' ∨ ∃ r, s' = .error r := by
  obtain ⟨a, b, ε, hq, hm, hk⟩ := hs
  cases hstep with
  | E_Let =>
      obtain ⟨a₁, b₁, ε₁, hm₁, hn₁, hle, hsub⟩ := hm.inv_let rfl
      have hq₁ := hQ _ _ hsub hq
      exact Or.inl ⟨a₁, b, ε₁, hq₁, hm₁, .K_Let (.C_Sub hn₁ hle (Eff.Sub.refl _)) hq₁ hk⟩
  | E_Return =>
      cases hk with
      | K_Let hn hq' hk' =>
          obtain ⟨a', hv, hle⟩ := hm.inv_ret rfl
          have hn' : HasTypeC P B ([_] : List Ty).reverse _ _ _ := hn
          exact Or.inl ⟨_, _, _, hq', hn'.instantiate (.cons (.V_Sub hv hle) .nil), hk'⟩
  | E_Lam hlen =>
      obtain ⟨as, b₁, ε₁, hf, hargs, hle, hsub⟩ := hm.inv_app rfl
      obtain ⟨r, ε₀, hbody, hle₂⟩ := hf.inv_lam rfl
      obtain ⟨rfl, rfl, hsub₂⟩ := hle₂.fn_fn
      rw [List.append_nil] at hbody
      have hsub₀ := hsub₂.trans hsub
      exact Or.inl ⟨a, b, _, hQ _ _ hsub₀ hq,
        .C_Sub (hbody.instantiate hargs) hle (Eff.Sub.refl _), hk⟩
  | @E_Fun _ ts es _ _ d hd hlen hts hes =>
      obtain ⟨as, b₁, ε₁, hf, hargs, hle, hsub⟩ := hm.inv_app rfl
      obtain ⟨d', hd', _, _, hle₂⟩ := hf.inv_fnRef rfl
      rw [hd] at hd'; cases hd'
      rw [fnTy_eq] at hle₂
      obtain ⟨hps, hr, hsub₂⟩ := hle₂.fn_fn
      -- 定義の本体に、呼び出しの型引数とエフェクト引数の置き換えを施す（01-12 の E-Fun の `Mθ`）。
      have h₀ : HasTypeC P B d.params.reverse d.body d.ret d.eff := hwt _ _ hd
      have hbody := h₀.substTy hwf hb ts es
      rw [List.map_reverse, hps] at hbody
      have hinst := hbody.instantiate hargs
      rw [hr] at hinst
      exact Or.inl ⟨a, b, _, hQ _ _ (hsub₂.trans hsub) hq, .C_Sub hinst hle (Eff.Sub.refl _), hk⟩
  | E_IfT =>
      obtain ⟨a₁, ε₁, _, hm₁, _, hle, hsub⟩ := hm.inv_ite rfl
      exact Or.inl ⟨a, b, ε₁, hQ _ _ hsub hq, .C_Sub hm₁ hle (Eff.Sub.refl _), hk⟩
  | E_IfF =>
      obtain ⟨a₁, ε₁, _, _, hn₁, hle, hsub⟩ := hm.inv_ite rfl
      exact Or.inl ⟨a, b, ε₁, hQ _ _ hsub hq, .C_Sub hn₁ hle (Eff.Sub.refl _), hk⟩
  | E_Match hfm =>
      obtain ⟨a₁, b₁, ε₁, hv, harms, _, hle, hsub⟩ := hm.inv_match rfl
      obtain ⟨p, hmem, hmatch⟩ := firstMatch_mem hfm
      obtain ⟨δ, hp, hbody⟩ := harms.mem hmem
      rw [List.append_nil] at hbody
      exact Or.inl ⟨a, b, ε₁, hQ _ _ hsub hq,
        .C_Sub (hbody.instantiate (hp.match_typed hv hmatch)) hle (Eff.Sub.refl _), hk⟩
  | E_Prim hsig hio hδ =>
      obtain ⟨as, b₁, ε₁, hf, hargs, hle, hsub⟩ := hm.inv_app rfl
      obtain ⟨s₀, hs₀, hts, hes, had, hle₂⟩ := hf.inv_prim rfl
      rw [hsig] at hs₀; cases hs₀
      rw [fnTy_eq] at hle₂
      obtain ⟨hps, hr, _⟩ := hle₂.fn_fn
      obtain ⟨o, ho, hoty⟩ := hb.delta_typed _ _ _ _ _ hsig hio hts hes had (by rw [hps]; exact hargs)
      rw [hδ] at ho; cases ho
      rw [hr] at hoty
      exact Or.inl ⟨a, b, Eff.empty, hQ _ _ (Eff.empty_sub _) hq,
        .C_Sub (.C_Return hoty) hle (Eff.Sub.refl _), hk⟩
  | E_Err => exact Or.inr ⟨_, rfl⟩
  | E_IO hsig hio hresp =>
      obtain ⟨as, b₁, ε₁, hf, hargs, hle, hsub⟩ := hm.inv_app rfl
      obtain ⟨s₀, hs₀, hts, hes, had, hle₂⟩ := hf.inv_prim rfl
      rw [hsig] at hs₀; cases hs₀
      rw [fnTy_eq] at hle₂
      obtain ⟨hps, hr, _⟩ := hle₂.fn_fn
      have hoty := hb.io_typed _ _ _ _ _ _ hsig hio hts hes had (by rw [hps]; exact hargs) hresp
      rw [hr] at hoty
      exact Or.inl ⟨a, b, Eff.empty, hQ _ _ (Eff.empty_sub _) hq,
        .C_Sub (.C_Return hoty) hle (Eff.Sub.refl _), hk⟩
  | E_IOErr => exact Or.inr ⟨_, rfl⟩

end Benitoite.Core
