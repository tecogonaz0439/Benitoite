import Benitoite.Release.Lemmas.StoreLemmas

/-!
# 専用セルの保持と通常セルの不変

Reference の値セルだけを比較し、継続の使用済みへの更新と通常リソースの解放を区別する。
設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release

/-- 比較するのは Reference の .val セルだけである。 -/
def OrdinaryStoreEq (σ σ' : Store) : Prop :=
  ∀ l v, σ l = some (.val v) ↔ σ' l = some (.val v)

theorem OrdinaryStoreEq.refl (σ : Store) : OrdinaryStoreEq σ σ := fun _ _ => Iff.rfl

theorem OrdinaryStoreEq.symm {σ σ' : Store} (h : OrdinaryStoreEq σ σ') : OrdinaryStoreEq σ' σ :=
  fun l v => (h l v).symm

theorem OrdinaryStoreEq.trans {σ σ' σ'' : Store}
    (h : OrdinaryStoreEq σ σ') (h' : OrdinaryStoreEq σ' σ'') : OrdinaryStoreEq σ σ'' :=
  fun l v => (h l v).trans (h' l v)

/-- 値セルではない場所を値セル以外で更新しても、Reference のセルは変わらない。 -/
theorem OrdinaryStoreEq.set_nonval {σ : Store} {l c}
    (hl : ∀ v, σ l ≠ some (.val v)) (hc : ∀ v, c ≠ .val v) :
    OrdinaryStoreEq σ (σ.set l c) := by
  intro i v
  by_cases hi : i = l
  · subst hi
    simp [Store.set, hl v, hc v]
  · simp [Store.set, hi]

/-- 専用セルの新鮮な追加は通常セルを変更しない。 -/
theorem builder_new_frame {σ : Store} {l c} (hl : σ l = none) :
    OrdinaryStoreEq σ (σ.set l (.builder c)) := by
  apply OrdinaryStoreEq.set_nonval
  · intro v; simp [hl]
  · intro v h; cases h

/-- 専用セルの更新は、その同じ場所の通常値セルを作らない。 -/
theorem builder_update_frame {σ : Store} {l old c} (hl : σ l = some (.builder old)) :
    OrdinaryStoreEq σ (σ.set l (.builder c)) := by
  apply OrdinaryStoreEq.set_nonval
  · intro v; simp [hl]
  · intro v h; cases h

/-- 通常引数の評価を含めず、専用項そのものだけを識別する。 -/
def Comp.IsBuilder : Comp → Prop
  | .builderLet .. | .builderOp .. => True
  | _ => False

/-- 上限超過と抽象 Byte の失敗も、事象を伴わない。 -/
theorem builder_step_no_event {P B m k σ ev s'}
    (hm : m.IsBuilder) (hs : Step P B (.run m k σ) ev s') : ev = none := by
  cases hs <;> simp_all [Comp.IsBuilder]

/-- 専用項の一歩は通常の Reference の値セルを変えない。 -/
theorem builder_step_frame {P B m k σ ev s'}
    (hm : m.IsBuilder) (hs : Step P B (.run m k σ) ev s') :
    match s' with
    | .run _ _ σ' | .error _ _ σ' | .exit _ _ _ σ' | .matchRun _ _ _ _ σ' => OrdinaryStoreEq σ σ' := by
  cases hs with
  | E_BuilderNew hl => exact builder_new_frame hl
  | E_BuilderOp hl _ => exact builder_update_frame hl
  | E_BuilderErr => exact .refl _
  | _ => exact (show False from hm).elim

/-- 捕捉の新しい場所に保存継続を置いても、既存の専用セルは同じ場所に残る。 -/
theorem capture_builder_cell {P B Ψ σ κ l kind saved ct}
    (hσ : StoreOk P B Ψ σ) (hf : Ψ κ = none) (hl : Ψ l = some (.builder kind)) :
    ∃ c, σ l = some (.builder c) ∧
      (σ.set κ (.cont saved)) l = some (.builder c) ∧
      BuilderCellOk P B (Ψ.set κ ct) kind c := by
  obtain ⟨c, hc, ht⟩ := hσ.builder_cell hl
  have hne : l ≠ κ := by intro he; subst he; rw [hf] at hl; cases hl
  exact ⟨c, hc, by simp [Store.set, hne, hc], ht.store (StoreTy.set_sub (Or.inl hf))⟩

/-- 再開は継続セルだけを使用済みにし、専用セルの内容・場所をそのまま保つ。 -/
theorem resume_builder_cell {P B Ψ σ κ l kind saved}
    (hσ : StoreOk P B Ψ σ) (hk : σ κ = some (.cont saved))
    (hl : Ψ l = some (.builder kind)) :
    ∃ c, σ l = some (.builder c) ∧ (σ.set κ .used) l = some (.builder c) ∧
      BuilderCellOk P B Ψ kind c := by
  obtain ⟨c, hc, ht⟩ := hσ.builder_cell hl
  have hne : l ≠ κ := by intro he; subst he; rw [hk] at hc; cases hc
  exact ⟨c, hc, by simp [Store.set, hne, hc], ht⟩

/-- 通常リソースの release と、解放を伝播する drop を持たない枠列。 -/
def BuilderOnlyFrames (k : Cont) : Prop := ∀ f ∈ k,
  match f with
  | .release _ | .drop _ => False
  | _ => True

/-- 構築器を保持する実行項だけでは、解放枠は追加されない。 -/
theorem builder_frames_releases_nil {k : Cont} (h : BuilderOnlyFrames k) : releases k = [] := by
  induction k with
  | nil => rfl
  | cons f k ih =>
      have hf := h f (by simp)
      have ht : BuilderOnlyFrames k := fun f hf => h f (by simp [hf])
      cases f <;> simp_all [releases]

/-- E_DropRel の後続そのものが、追加の解放枠なしの状態になる。 -/
theorem drop_local_silent {P B σ κ saved v k ev s'}
    (hl : σ κ = some (.cont saved)) (hr : releases saved = [])
    (hs : Step P B (.run (.ret v) (.drop κ :: k) σ) ev s') :
    ev = none ∧ s' = .run (.ret v) k (σ.set κ .used) := by
  cases hs with
  | E_Drop hu => rw [hl] at hu; cases hu
  | E_DropRel hc =>
      rw [hl] at hc
      cases hc
      simp [hr]

/-- 未再開の保存継続を使用済みにする更新も、通常の値セルを変えない。 -/
theorem drop_local_frame {σ : Store} {κ saved} (hl : σ κ = some (.cont saved)) :
    OrdinaryStoreEq σ (σ.set κ .used) := by
  apply OrdinaryStoreEq.set_nonval
  · intro v; simp [hl]
  · intro v h; cases h

/-- escape で継続を破棄しても、構築器だけの保持から解放枠は生じない。 -/
theorem escape_drop_local_silent {P B σ κ saved v k ev s'}
    (hl : σ κ = some (.cont saved)) (hr : releases saved = [])
    (hs : Step P B (.run (.escape v) (.drop κ :: k) σ) ev s') :
    ev = none ∧ s' = .run (.escape v) k (σ.set κ .used) := by
  cases hs with
  | E_EscDrop hu => rw [hl] at hu; cases hu
  | E_EscDropRel hc =>
      rw [hl] at hc
      cases hc
      simp [hr]

/-- error で継続を破棄する場合。通常リソースの解放を持つ保存枠には適用しない。 -/
theorem error_drop_local_silent {P B σ κ saved rs k ev s'}
    (hl : σ κ = some (.cont saved)) (hr : releases saved = [])
    (hs : Step P B (.error rs (.drop κ :: k) σ) ev s') :
    ev = none ∧ s' = .error rs k (σ.set κ .used) := by
  cases hs with
  | E_ErrDrop hu => rw [hl] at hu; cases hu
  | E_ErrDropRel hc =>
      rw [hl] at hc
      cases hc
      simp [hr]

/-- exit で継続を破棄する場合も、同じ保存枠の条件を使う。 -/
theorem exit_drop_local_silent {P B σ κ saved n rs k ev s'}
    (hl : σ κ = some (.cont saved)) (hr : releases saved = [])
    (hs : Step P B (.exit n rs (.drop κ :: k) σ) ev s') :
    ev = none ∧ s' = .exit n rs k (σ.set κ .used) := by
  cases hs with
  | E_ExitDrop hu => rw [hl] at hu; cases hu
  | E_ExitDropRel hc =>
      rw [hl] at hc
      cases hc
      simp [hr]

/-- 再開と現在の継続は、専用セルの型を保つ同じストア拡張で型を保つ。 -/
theorem cont_local_store_weaken {P B Ψ Ψ' R ε k a b ε0 Re}
    (h : ContTy P B Ψ R ε k a b ε0 Re) (hΨ : StoreTy.Sub Ψ Ψ') :
    ContTy P B Ψ' R ε k a b ε0 Re := h.store hΨ

end Benitoite.Release
