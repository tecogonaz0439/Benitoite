import Benitoite.Release.Refinement.TypedFacts

/-!
# 組込みの制約と値注釈の移送の条件

表のsat/admits自体は任意の述語であるため、保存則を証拠として明示する。
モデルは篩の条件と値の番号を読まないcarrierの骨格からこの証拠を作る。
-/
namespace Benitoite.Release.Refinement

def TypedValueImages (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (C : List TParam) (Γ Δ : Ctx) (Ξ : List Pred) (ν : Nat → Val) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.Ordinary →
    HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a)

structure Builtins.ValueAssumptions (P : Program) (B : Builtins) : Prop where
  sat_rename : ∀ C Γ Δ a p (ξ : Nat → Nat), (∀ i j, i < j → ξ i < ξ j) →
    Ty.Annotation P C Γ a → Ty.Annotation P C Δ (renameTy ξ a) →
    B.sat C a p → B.sat C (renameTy ξ a) p
  admits_rename : ∀ b sg C Γ Δ ts (ξ : Nat → Nat), B.sig b = some sg →
    (∀ i j, i < j → ξ i < ξ j) → TypeAnnotations P C Γ ts →
    TypeAnnotations P C Δ (ts.map (renameTy ξ)) →
    sg.admits C ts → sg.admits C (ts.map (renameTy ξ))
  sat_values : ∀ Ψ Q C Γ Δ Ξ ν a p, TypedValueImages P B Ψ Q C Γ Δ Ξ ν →
    Ty.Annotation P C Γ a → B.sat C a p → B.sat C (substTyValues ν a) p
  admits_values : ∀ b sg Ψ Q C Γ Δ Ξ ν ts, B.sig b = some sg →
    TypedValueImages P B Ψ Q C Γ Δ Ξ ν → TypeAnnotations P C Γ ts →
    sg.admits C ts → sg.admits C (ts.map (substTyValues ν))

theorem SatAll.map {B C ts tps} (h : SatAll B C ts tps) (f : Ty → Ty)
    (hf : ∀ a ∈ ts, ∀ p, B.sat C a p → B.sat C (f a) p) : SatAll B C (ts.map f) tps := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a p hi hp
  rw [List.getElem?_map] at hi
  obtain ⟨x, hx, rfl⟩ := Option.map_eq_some_iff.mp hi
  exact hf x (List.mem_of_getElem? hx) p (h.2 i x p hx hp)

/-- 既存の組込み・応答の条件は、それらの判断を追加する群で同じ構造体へ加える。 -/
structure Builtins.CoreAssumptions (P : Program) (B : Builtins) : Prop extends
    Builtins.ValueAssumptions P B

/-- 主定理のCoreAssumptionsから、補助の移送が使う四条件を供給する。 -/
theorem Builtins.CoreAssumptions.values {P B} (h : Builtins.CoreAssumptions P B) :
    Builtins.ValueAssumptions P B := h.toValueAssumptions

end Benitoite.Release.Refinement
