import Benitoite.Release.Refinement.CanonicalCells
import Benitoite.Release.Refinement.ReferenceStore

/-!
# 専用セルの保持と通常セルの不変

専用項の一歩は事象を伴わず、Reference の値セルを変えない。捕捉と再開の一歩は既存の専用セルを
同じ場所と内容のまま保ち、構築器だけを保持する保存継続の破棄は解放枠を足さない。
比べるのは Reference の値セルだけであり、継続の使用済みへの更新と通常リソースの解放とを区別する。
設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 比較するのは Reference の値セル（`Cell.val`）だけである。 -/
def OrdinaryStoreEq (μ μ' : Store) : Prop :=
  ∀ l v, μ l = some (.val v) ↔ μ' l = some (.val v)

theorem OrdinaryStoreEq.refl (μ : Store) : OrdinaryStoreEq μ μ := fun _ _ => Iff.rfl

theorem OrdinaryStoreEq.symm {μ μ' : Store} (h : OrdinaryStoreEq μ μ') : OrdinaryStoreEq μ' μ :=
  fun l v => (h l v).symm

theorem OrdinaryStoreEq.trans {μ μ' μ'' : Store}
    (h : OrdinaryStoreEq μ μ') (h' : OrdinaryStoreEq μ' μ'') : OrdinaryStoreEq μ μ'' :=
  fun l v => (h l v).trans (h' l v)

/-- 値セルではない場所を値セル以外で更新しても、Reference のセルは変わらない。 -/
theorem OrdinaryStoreEq.set_nonval {μ : Store} {l c}
    (hl : ∀ v, μ l ≠ some (.val v)) (hc : ∀ v, c ≠ .val v) :
    OrdinaryStoreEq μ (μ.set l c) := by
  intro i v
  by_cases hi : i = l
  · subst hi
    simp [Store.set, hl v, hc v]
  · simp [Store.set, hi]

/-- 専用セルの新鮮な追加は通常セルを変更しない。 -/
theorem builder_new_frame {μ : Store} {l c} (hl : μ l = none) :
    OrdinaryStoreEq μ (μ.set l (.builder c)) := by
  apply OrdinaryStoreEq.set_nonval
  · intro v; simp [hl]
  · intro v h; cases h

/-- 専用セルの更新は、その同じ場所の通常値セルを作らない。 -/
theorem builder_update_frame {μ : Store} {l old c} (hl : μ l = some (.builder old)) :
    OrdinaryStoreEq μ (μ.set l (.builder c)) := by
  apply OrdinaryStoreEq.set_nonval
  · intro v; simp [hl]
  · intro v h; cases h

/-- 通常引数の評価を含めず、専用項そのものだけを識別する。 -/
def Comp.IsBuilder : Comp → Prop
  | .builderLet .. | .builderOp .. => True
  | _ => False

/-- 実行の一歩が読む形（`Closure.view`）が専用項なら、閉包の本体も専用項である。 -/
private theorem view_isBuilder {q : Closure} (hm : q.view.IsBuilder) : q.code.IsBuilder := by
  cases q with
  | mk cap code => cases code <;> simp_all [Closure.view, Closure.code, Comp.IsBuilder]

/-- 専用項の一歩は事象を伴わない。上限超過と抽象 Byte の失敗も同じである。 -/
theorem builder_step_no_event {P B σ q k μ ev s'}
    (hm : q.view.IsBuilder) (hs : Step P B σ (.run q k μ) ev s') : ev = none := by
  have hc := view_isBuilder hm
  cases hs <;> simp_all [Comp.IsBuilder, Closure.view]

/-- 専用項の一歩は通常の Reference の値セルを変えない。 -/
theorem builder_step_frame {P B σ q k μ ev s'}
    (hm : q.view.IsBuilder) (hs : Step P B σ (.run q k μ) ev s') :
    match s' with
    | .run _ _ μ' | .error _ _ μ' | .exit _ _ _ μ' | .matchRun _ _ _ _ _ μ' => OrdinaryStoreEq μ μ' := by
  have hc := view_isBuilder hm
  cases hs with
  | E_BuilderNew _ hl => exact builder_new_frame hl
  | E_BuilderOp _ hl _ => exact builder_update_frame hl
  | E_BuilderErr => exact .refl _
  | _ => exfalso; simp_all [Comp.IsBuilder, Closure.view]

/-- 捕捉で新しい場所に保存継続を置いても、既存の専用セルは同じ場所に同じ内容で残り、
広げたストア型の下でも内容の型付けを保つ。 -/
theorem capture_builder_cell {P B σ Ψ μ κ l kind saved ct}
    (hA : B.ValueAssumptions P) (hμ : StoreOk P B σ Ψ μ) (hf : Ψ κ = none)
    (hl : Ψ l = some (.builder kind)) :
    ∃ c, μ l = some (.builder c) ∧
      (μ.set κ (.cont saved)) l = some (.builder c) ∧
      BuilderCellOk P B (Ψ.put κ ct) kind c := by
  obtain ⟨c, hc, ht, had⟩ := hμ.builder_cell hl
  have hne : l ≠ κ := by intro he; subst he; rw [hf] at hl; cases hl
  have hcell : CellOk P B σ Ψ l (.builder c) := ⟨kind, hl, ht, had⟩
  obtain ⟨kind', hl', ht', _⟩ := hcell.store hA hμ.wf (StoreTy.extends_put (x := ct) hf)
  have hk : kind' = kind := by
    simp only [StoreTy.put, hne, ↓reduceIte, hl, Option.some.injEq, LocTy.builder.injEq] at hl'
    exact hl'.symm
  subst hk
  exact ⟨c, hc, by simp [Store.set, hne, hc], ht'⟩

/-- 再開は継続セルだけを使用済みにし、専用セルの内容と場所をそのまま保つ。 -/
theorem resume_builder_cell {P B σ Ψ μ κ l kind saved}
    (hμ : StoreOk P B σ Ψ μ) (hk : μ κ = some (.cont saved))
    (hl : Ψ l = some (.builder kind)) :
    ∃ c, μ l = some (.builder c) ∧ (μ.set κ .used) l = some (.builder c) ∧
      BuilderCellOk P B Ψ kind c := by
  obtain ⟨c, hc, ht, _⟩ := hμ.builder_cell hl
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

/-- 値を返して未再開の保存継続を破棄する一歩（E_DropRel）は、解放枠を持たない保存継続なら
事象を伴わず、追加の解放枠なしの状態になる。構築器だけの枠列は `builder_frames_releases_nil` で
この前提を満たす。 -/
theorem drop_local_silent {P B σ q κ saved v k μ ev s'}
    (hq : q.view = .ret v) (hl : μ κ = some (.cont saved)) (hrel : releases saved = [])
    (hs : Step P B σ (.run q (.drop κ :: k) μ) ev s') :
    ev = none ∧ s' = .run (Closure.pure (.ret v)) k (μ.set κ .used) := by
  cases hs with
  | E_Drop _ hu => rw [hl] at hu; cases hu
  | E_DropRel hv hc =>
      rw [hq] at hv; cases hv
      rw [hl] at hc; cases hc
      simp [hrel]
  | E_AtOk hc => simp [Closure.view, hc] at hq
  | E_AtError hc => simp [Closure.view, hc] at hq
  | E_AtPrepareError hc => simp [Closure.view, hc] at hq
  | _ => simp_all

/-- 未再開の保存継続を使用済みにする更新も、通常の値セルを変えない。 -/
theorem drop_local_frame {μ : Store} {κ saved} (hl : μ κ = some (.cont saved)) :
    OrdinaryStoreEq μ (μ.set κ .used) := by
  apply OrdinaryStoreEq.set_nonval
  · intro v; simp [hl]
  · intro v h; cases h

end
end Benitoite.Release.Refinement
