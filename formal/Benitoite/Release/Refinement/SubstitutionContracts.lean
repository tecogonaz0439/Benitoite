import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.TypeRenaming

/-! 値の置換の入力契約。正規化の実装と主定理の証明から定義を分離する。 -/
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

/-- 型パラメータの制約を保つ改名と、閉じた型による具体化の条件。 -/
structure Builtins.TypeAssumptions (P : Program) (B : Builtins) : Prop where
  sat_renameTypes : ∀ C C' Γ Δ a p ρ, TypeParamRenaming C C' ρ →
    Ty.Annotation P C Γ a → Ty.Annotation P C' Δ (a.renameTypes ρ) →
    B.sat C a p → B.sat C' (a.renameTypes ρ) p
  admits_renameTypes : ∀ b sg C C' Γ Δ ts ρ, B.sig b = some sg → TypeParamRenaming C C' ρ →
    TypeAnnotations P C Γ ts → TypeAnnotations P C' Δ (ts.map (fun a => a.renameTypes ρ)) →
    sg.admits C ts → sg.admits C' (ts.map (fun a => a.renameTypes ρ))
  sat_subst : ∀ C0 C1 a p ts es,
    B.sat (C1 ++ C0) a p →
    (∀ t ∈ ts, t.WF 0 0 0) → SatAll B C1 ts C0 → ts.length = C0.length →
    B.sat C1 (a.substAt C1.length ts es) p
  admits_subst : ∀ b sg C0 C1 ts ts' es', B.sig b = some sg → sg.admits (C1 ++ C0) ts →
    (∀ t ∈ ts', t.WF 0 0 0) → SatAll B C1 ts' C0 → ts'.length = C0.length →
    sg.admits C1 (ts.map (Ty.substAt C1.length ts' es'))

/-- 値の置換が多相節の下へ入るときに使う二種類の保存則。 -/
structure Builtins.SubstitutionAssumptions (P : Program) (B : Builtins) : Prop extends
    Builtins.ValueAssumptions P B, Builtins.TypeAssumptions P B


/-- 通常値は置換後の型で検査し、継続場所の閉じた契約と R0 は保つ。 -/
def SubstOk (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx) (C : List TParam)
    (Γ : Ctx) (_Φ : List Pred) (Δ : Ctx) (Ξ : List Pred) (R0 : Option Ty) (σ : Nat → Val) : Prop :=
  ∀ i a, Γ[i]? = some (some a) →
    ImageOk P B store Q C Δ Ξ R0 σ i a


end Benitoite.Release.Refinement
