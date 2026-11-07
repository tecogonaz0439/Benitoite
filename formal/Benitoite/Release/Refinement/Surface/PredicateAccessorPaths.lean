import Benitoite.Release.Refinement.Surface.PredicateProjectionCalls
import Benitoite.Release.Refinement.Surface.PredicateProjectionResponse

/-! # 取り出しの宣言から組み立てる判定の経路

受け手の型パラメータを記号のまま具体化し、各欄の宣言の型から次の受け手の型を得る。
元の式の型引数の検査は、検査用に保持した元の取り出しの式で行う。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateAccessorPaths
open PredicateAccessorTargets PredicateProjection PredicateRows MatchFacts
noncomputable section

private theorem AccessPath.normal {P a route b} (h : AccessPath P a route b) :
    AccessPath P a.norm route b.norm := by
  induction h with
  | nil a => exact .nil _
  | @field a b c pattern ref rest hp hex hb tail ih =>
      refine .field ?_ (by simpa only [Exhaustive, Ty.norm_idem] using hex) hb ih
      simpa only [List.map_cons, List.map_nil] using
        (PatTy.P_Convert (b := a.norm) (Ty.norm_idem a).symm hp)

private theorem AccessPath.append {P a left b right c} (h : AccessPath P a left b)
    (tail : AccessPath P b right c) : AccessPath P a (left ++ right) c := by
  induction h with
  | nil a => exact tail
  | field hp hex hb rest ih => exact .field hp hex hb (ih tail)

private theorem AccessPath.convertInput {P a route c b} (h : AccessPath P a route c)
    (nonempty : route ≠ []) (equal : a.norm = b.norm) : AccessPath P b route c.norm := by
  cases h with
  | nil a => exact False.elim (nonempty rfl)
  | field hp hex hb tail =>
      refine .field ?_ (by simpa only [Exhaustive, equal] using hex) hb (AccessPath.normal tail)
      simpa only [List.map_cons, List.map_nil] using (PatTy.P_Convert equal hp)

private theorem AccessPath.refinedInput {P a route b} (h : AccessPath P a route b)
    (nonempty : route ≠ []) (predicate : Pred) : AccessPath P (.refined a predicate) route b.norm := by
  cases h with
  | nil a => exact False.elim (nonempty rfl)
  | field hp hex hb tail =>
      refine .field ?_ ?_ hb (AccessPath.normal tail)
      · simpa only [List.map_cons, List.map_nil] using
          (PatTy.P_Convert (b := .refined a predicate) rfl (.P_Refined hp))
      · intro value hv
        have hi := (Inhabits.norm_all_iff (.refined a predicate) value).mp hv
        exact hex value ((Inhabits.norm_all_iff a value).mpr (hi.refined_inv a predicate rfl).1)

private theorem genericData_subst (owner : DataName) (ntys : Nat) (types : List Ty)
    (count : types.length = ntys) :
    (Ty.data owner ((List.range ntys).map Ty.tvar)).substAt 0 types [] = (Ty.data owner types).norm := by
  subst ntys
  simp only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map]
  congr 1
  apply List.ext_getElem
  · simp
  · intro i hi hj
    simp only [List.getElem_map, List.getElem_range] at hi hj ⊢
    have hil : i < types.length := by simpa using hi
    simp [typeEnvAt, Ty.rawBind, hil]

/-- 宣言の型から記号的に次の受け手へ進む形。各段は型名・型引数の個数・欄の位置だけを照合する。 -/
inductive Chain : Ty → List PredicateAccessorTargets.Step → Ty → Prop where
  | nil (a : Ty) : Chain a [] a
  | data {owner : DataName} {types : List Ty} {step : PredicateAccessorTargets.Step} {rest : List PredicateAccessorTargets.Step} {field leaf : Ty} :
      owner = step.declaration.data → types.length = step.declaration.ntys →
      step.declaration.args[step.position]? = some field →
      Chain (field.norm.substAt 0 types []) rest leaf →
      Chain (.data owner types) (step :: rest) leaf
  | refined {a predicate steps leaf} : steps ≠ [] → Chain a steps leaf →
      Chain (.refined a predicate) steps leaf

/-- 有限の宣言の照合に成功した経路と、その末尾の型。 -/
structure CheckedChain (input : Ty) (steps : List PredicateAccessorTargets.Step) where
  leaf : Ty
  proof : Chain input steps leaf

/-- 宣言の型を各段で具体化し、受け手の型名・型引数の個数・欄の位置を照合する。 -/
def checkChain (input : Ty) (steps : List PredicateAccessorTargets.Step) : Option (CheckedChain input steps) :=
  match steps with
  | [] => some ⟨input, .nil input⟩
  | step :: rest => match input with
      | .refined inner _predicate => do
          let result ← checkChain inner (step :: rest)
          pure ⟨result.leaf, .refined (by simp) result.proof⟩
      | .data owner types =>
          if ownerEq : owner = step.declaration.data then
            if count : types.length = step.declaration.ntys then
              match selected : step.declaration.args[step.position]? with
              | none => none
              | some field => do
                  let result ← checkChain (field.norm.substAt 0 types []) rest
                  pure ⟨result.leaf, .data ownerEq count selected result.proof⟩
            else none
          else none
      | _ => none
termination_by (steps.length, sizeOf input)
decreasing_by all_goals simp_wf <;> omega

/-- 構文上の型の連続と既存の取り出しの条件から、全入力に使う経路の型付けを得る。 -/
theorem Chain.path {p : Program} {a : Ty} {steps : List PredicateAccessorTargets.Step} {leaf : Ty} (chain : Chain a steps leaf) (formed : p.WellFormed)
    (accessors : ∀ s ∈ steps, AccessorOk p.declarations s.constructor s.declaration s.position) :
    AccessPath p.declarations.core a.norm (steps.map PredicateAccessorTargets.Step.reference) leaf.norm := by
  induction chain with
  | nil a => exact .nil _
  | @data owner types step rest field leaf ownerEq count selected tail ih =>
      have first := AccessPath.accessor (P := p.declarations.core)
        (show p.declarations.core.SameTypes p.declarations.core from ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩)
        (accessors step (by simp)) selected (ref := step.reference) rfl rfl
      have concrete := first.substAt formed.types 0 types []
      rw [genericData_subst _ _ _ count] at concrete
      subst owner
      have remaining := ih (fun s hs => accessors s (by simp [hs]))
      have result := AccessPath.append (AccessPath.normal concrete) remaining
      simpa only [Ty.norm_idem, List.map_cons, List.singleton_append] using result
  | @refined a predicate steps leaf nonempty tail ih =>
      have path := ih accessors
      have nonempty' : steps.map PredicateAccessorTargets.Step.reference ≠ [] := by simpa using nonempty
      have lifted := AccessPath.refinedInput path nonempty' predicate
      have result := AccessPath.convertInput lifted nonempty' (b := (Ty.refined a predicate).norm)
        (by simp only [Ty.norm, Ty.norm_refineNorm, Ty.norm_idem])
      simpa only [Ty.norm_idem] using result

/-- 解析した元の取り出しの宣言を使い、同じ経路の内部行の条件を組み立てる。 -/
theorem Parsed.valid_projection {p source} (target : Parsed p source) {projection : Projection} {types entry leaf}
    (formed : p.WellFormed) (candidate : PredicateProjectionCalls.candidate target entry = some (projection, types))
    (chain : Chain projection.input target.steps leaf) (scalar : leaf.norm.core = .base entry.input)
    (entryValid : entry.Valid) (sorted : RouteSorted projection.route entry.sort)
    (signature : PrimSig.Scoped p.declarations.core projection.signature) :
    Valid p.declarations.core projection := by
  have route : projection.route = target.steps.map PredicateAccessorTargets.Step.reference := by
    unfold PredicateProjectionCalls.candidate at candidate
    split at candidate
    · cases candidate
    · split at candidate
      · cases candidate; rfl
      · cases candidate
  have entryEq : projection.entry = entry := by
    unfold PredicateProjectionCalls.candidate at candidate
    split at candidate
    · cases candidate
    · split at candidate
      · cases candidate; rfl
      · cases candidate
  have nonempty : projection.route ≠ [] := by
    unfold PredicateProjectionCalls.candidate at candidate
    split at candidate
    · cases candidate
    · split at candidate
      · cases candidate; simp_all
      · cases candidate
  have inputNormal : projection.input.norm = projection.input := by
    simp [Projection.input, Ty.norm, Ty.normTys_eq_map, List.map_map, Function.comp_def]
  have path := chain.path formed (target.accessor_conditions formed)
  rw [inputNormal, ← route] at path
  exact ⟨entryEq ▸ entryValid, ⟨leaf.norm, path, by simpa only [Ty.norm_idem, entryEq] using scalar⟩,
    nonempty, by simpa only [entryEq] using sorted, signature⟩

end
end Benitoite.Release.Refinement.Surface.PredicateAccessorPaths
