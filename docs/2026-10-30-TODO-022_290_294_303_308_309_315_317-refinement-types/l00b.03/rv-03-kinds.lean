import Benitoite.Release.Refinement.Context.Capture
namespace Benitoite.Release.Refinement.RV03
noncomputable section
def constructorD : List TParamDecl := [⟨{}, .constructor 1⟩]

/-- 既存の入口は同じ呼出し元の C で value と constructor の両方の K を選べる。 -/
theorem exist_value (P : Program) :
    TypeArgsKinded P (constructorD.map TParamDecl.constraints) [.tvar 0] [.value] :=
  ⟨rfl, [.value], rfl, by
    intro i a k ha hk
    cases i with
    | zero => cases ha; cases hk; rfl
    | succ i => simp at ha⟩

/-- 一つの前提の K は、必ず何らかの宣言 D の kind 列として書ける。 -/
theorem exists_decl {P C ts ks} (h : TypeArgsKinded P C ts ks) :
    ∃ D : List TParamDecl, D.map TParamDecl.constraints = C ∧ TypeArgsKindedAt P D ts ks := by
  obtain ⟨hn, K, hK, hk⟩ := h
  let D := List.zipWith (fun c k => (⟨c, k⟩ : TParamDecl)) C K
  have hc : D.map TParamDecl.constraints = C := by
    apply List.ext_getElem
    · simp [D, hK]
    · intro i h1 h2; simp [D, List.getElem_zipWith]
  have hk' : D.map TParamDecl.kind = K := by
    apply List.ext_getElem
    · simp [D, hK]
    · intro i h1 h2; simp [D, List.getElem_zipWith]
  exact ⟨D, hc, hn, by rw [hk']; exact hk⟩
#print axioms exists_decl
end
end Benitoite.Release.Refinement.RV03
