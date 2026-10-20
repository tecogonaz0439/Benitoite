import Benitoite.Release.Theorems
import Benitoite.Release.LocalScope

/-!
# 有限接頭辞での専用参照の有効性

現在の項・枠・保存継続が使う専用場所にはセルが存在し、同じストア型の通常値は
自由な専用参照を捕捉しない。物理メモリの回収は扱わない。
設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release

/-- 専用場所が指す論理セルが存在する。 -/
def BuilderLive (σ : Store) (l : Nat) : Prop := ∃ c, σ l = some (.builder c)

/-- 枠内の計算も共有番号を使い、let の本体だけ一つ束縛する。 -/
def Frame.LocalRefs (places : Nat → Prop) : Frame → Prop
  | .letF n => Comp.LocalRefs 1 places n
  | .guardF v arms _ body => v.NoFreeBuilders ∧ Arm.LocalRefsList 0 places arms ∧ Comp.LocalRefs 0 places body
  | .handleF cs => Clause.LocalRefsList 0 places cs
  | .release v => v.NoFreeBuilders
  | .mark | .update _ | .drop _ => True

/-- 継続は現在の枠も保存された枠も同じ述語で検査する。 -/
def Cont.LocalRefs (places : Nat → Prop) (k : Cont) : Prop := ∀ f ∈ k, f.LocalRefs places

/-- 通常セルの値と専用 List の要素には自由な専用参照を許さない。 -/
def Cell.LocalRefs (places : Nat → Prop) : Cell → Prop
  | .builder (.list _ vs) => Val.LocalRefsList 0 (fun _ => False) vs
  | .builder (.string _) | .builder (.bytes _) | .used => True
  | .val v | .done v => v.NoFreeBuilders
  | .thunk m => NoFreeBuilders m
  | .cont k => k.LocalRefs places

theorem StoreOk.builder_places {P B Ψ σ} (hσ : StoreOk P B Ψ σ) :
    Ψ.BuilderPlaces (BuilderLive σ) := by
  intro l kind hl
  obtain ⟨c, hc, _⟩ := hσ.builder_cell hl
  exact ⟨c, hc⟩

theorem ContTy.localRefs {P B Ψ R ε k a b ε0 Re places}
    (h : ContTy P B Ψ R ε k a b ε0 Re) (hΨ : Ψ.BuilderPlaces places) : k.LocalRefs places := by
  induction h with
  | K_Empty => intro f hf; simp at hf
  | K_Let hn _ _ _ ih =>
      intro f hf
      rcases List.mem_cons.mp hf with rfl | hf
      · exact hn.localRefs (.nil _) hΨ
      · exact ih f hf
  | K_Mark _ _ ih | K_Update _ _ ih | K_Drop _ _ _ ih =>
      intro f hf
      rcases List.mem_cons.mp hf with rfl | hf
      · trivial
      · exact ih f hf
  | K_Release hv _ _ _ ih =>
      intro f hf
      rcases List.mem_cons.mp hf with rfl | hf
      · exact builder_value_no_free_local hv
      · exact ih f hf
  | K_Handle _ _ hc _ ih =>
      intro f hf
      rcases List.mem_cons.mp hf with rfl | hf
      · exact hc.localRefs (.nil _) (.hidden _ _)
      · exact ih f hf
  | K_Handle_Fail _ _ _ hc _ _ ih =>
      intro f hf
      rcases List.mem_cons.mp hf with rfl | hf
      · exact hc.localRefs (.nil _) (.hidden _ _)
      · exact ih f hf
  | K_Guard hm _ _ hb _ ih =>
      intro f hf
      rcases List.mem_cons.mp hf with rfl | hf
      · obtain ⟨t, c, e, hv, ha, _⟩ := hm.inv_match rfl
        exact ⟨builder_value_no_free_local hv, ha.localRefs (.nil _) hΨ, hb.localRefs (.nil _) hΨ⟩
      · exact ih f hf
  | K_Sub _ _ ih => exact ih

theorem CellOk.localRefs {P B Ψ σ l c} (hσ : StoreOk P B Ψ σ) (h : CellOk P B Ψ l c) :
    c.LocalRefs (BuilderLive σ) := by
  cases c with
  | builder contents =>
      obtain ⟨kind, hl, hok⟩ := h
      cases contents with
      | string _ | bytes _ => trivial
      | list a vs => exact hok.2.2.2.2.localRefs
  | val v | done v => obtain ⟨a, _, hv⟩ := h; exact builder_value_no_free_local hv
  | thunk m =>
      obtain ⟨a, _, hm⟩ := h
      exact hm.localRefs (.nil _) (.hidden _ _)
  | cont k =>
      obtain ⟨b, t, ε, r, _, _, R, ε', hk⟩ := h
      exact hk.localRefs hσ.builder_places
  | used => trivial

/-- 現在の項・継続・全セルの専用参照と、同じ型付けの通常値の捕捉禁止。 -/
def LocalStateInvariant (P : Program) (B : Builtins) (s : State) : Prop :=
  ∃ Ψ, (match s with
    | .run m k σ => StoreOk P B Ψ σ ∧ Comp.LocalRefs 0 (BuilderLive σ) m ∧
        k.LocalRefs (BuilderLive σ) ∧ ∀ l c, σ l = some c → c.LocalRefs (BuilderLive σ)
    | .matchRun v arms _ k σ => StoreOk P B Ψ σ ∧ v.NoFreeBuilders ∧
        Arm.LocalRefsList 0 (BuilderLive σ) arms ∧ k.LocalRefs (BuilderLive σ) ∧
        ∀ l c, σ l = some c → c.LocalRefs (BuilderLive σ)
    | .error _ k σ | .exit _ _ k σ => StoreOk P B Ψ σ ∧ k.LocalRefs (BuilderLive σ) ∧
        ∀ l c, σ l = some c → c.LocalRefs (BuilderLive σ)) ∧
    (∀ Q C Γ v a, HasTypeVQ P B Ψ Q C Γ v a → v.NoFreeBuilders)

theorem StateTy.local_invariant {P B s} (hs : StateTy P B s) : LocalStateInvariant P B s := by
  cases s with
  | run m k σ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, Eb, hσ, hm, _, hk, _⟩ := hs
      exact ⟨Ψ, ⟨hσ, hm.localRefs (.nil _) hσ.builder_places, hk.localRefs hσ.builder_places,
        fun l c hc => (hσ.2.2.2 l c hc).localRefs hσ⟩,
        fun _ _ _ _ _ hv => builder_value_no_free_local hv⟩
  | matchRun v arms next k σ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, Eb, hσ, hm, _, hk, _⟩ := hs
      obtain ⟨t, c, e, hv, ha, _⟩ := hm.inv_match rfl
      exact ⟨Ψ, ⟨hσ, builder_value_no_free_local hv, ha.localRefs (.nil _) hσ.builder_places,
        hk.localRefs hσ.builder_places, fun l c hc => (hσ.2.2.2 l c hc).localRefs hσ⟩,
        fun _ _ _ _ _ hv => builder_value_no_free_local hv⟩
  | error rs k σ | exit n rs k σ =>
      obtain ⟨Ψ, R, a, b, ε, Eb, hσ, hk, _⟩ := hs
      exact ⟨Ψ, ⟨hσ, hk.localRefs hσ.builder_places,
        fun l c hc => (hσ.2.2.2 l c hc).localRefs hσ⟩,
        fun _ _ _ _ _ hv => builder_value_no_free_local hv⟩

/-- 通常 State・Fail・escape・解放を含む任意の有限接頭辞で局所の保証を保つ。 -/
theorem local_steps_invariant {P B s s'} (hwf : P.WellFormed) (hwt : P.WellTyped B)
    (hdecl : P.EffectsOk B) (hb : B.Assumptions P) (hs : StateTy P B s)
    (hsteps : Steps P B s s') : StateTy P B s' ∧ LocalStateInvariant P B s' := by
  have hs' : StateTy P B s' := by
    induction hsteps with
    | refl => exact hs
    | step hst _ ih => exact ih (preservation hwf hwt hdecl hb hs hst)
  exact ⟨hs', hs'.local_invariant⟩

/-- 保存継続を新鮮なセルへ追加する一歩も、既存の専用セルの場所と内容を保つ。 -/
theorem capture_local_valid {P B m n k k' σ κ saved ev}
    (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P)
    (hs : StateTy P B (.run m k σ)) (hf : σ κ = none)
    (hst : Step P B (.run m k σ) ev (.run n k' (σ.set κ (.cont saved)))) :
    StateTy P B (.run n k' (σ.set κ (.cont saved))) ∧
      LocalStateInvariant P B (.run n k' (σ.set κ (.cont saved))) ∧
      ∀ l c, σ l = some (.builder c) → (σ.set κ (.cont saved)) l = some (.builder c) := by
  have hs' := preservation hwf hwt hdecl hb hs hst
  refine ⟨hs', hs'.local_invariant, ?_⟩
  intro l c hc
  have hne : l ≠ κ := by intro he; subst he; rw [hf] at hc; cases hc
  simp [Store.set, hne, hc]

/-- 再開の使用済み更新は保存枠の専用セルを変更せず、型と局所有効性を保つ。 -/
theorem resume_local_valid {P B m n k k' σ κ saved ev}
    (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B) (hb : B.Assumptions P)
    (hs : StateTy P B (.run m k σ)) (hc : σ κ = some (.cont saved))
    (hst : Step P B (.run m k σ) ev (.run n k' (σ.set κ .used))) :
    StateTy P B (.run n k' (σ.set κ .used)) ∧
      LocalStateInvariant P B (.run n k' (σ.set κ .used)) ∧
      ∀ l c, σ l = some (.builder c) → (σ.set κ .used) l = some (.builder c) := by
  have hs' := preservation hwf hwt hdecl hb hs hst
  refine ⟨hs', hs'.local_invariant, ?_⟩
  intro l c hl
  have hne : l ≠ κ := by intro he; subst he; rw [hc] at hl; cases hl
  simp [Store.set, hne, hl]

end Benitoite.Release
