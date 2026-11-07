import Benitoite.Release.Refinement.Surface.PredicateSimulationMapProviders

/-! # Setの実δと、代表値の縮約・集合演算の対応 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardCollections
noncomputable section

local macro "providerSetCombineImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardMapSet
    `Benitoite.Release.Refinement.StandardCollections.setCombine))

local macro "providerEntryLEImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardMapSet
    `Benitoite.Release.Refinement.StandardCollections.entryLE))

local macro "unfoldSetCombine" : tactic => do
  let implementation := Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardMapSet
    `Benitoite.Release.Refinement.StandardCollections.setCombine)
  `(tactic| unfold $implementation:ident)

private abbrev providerSetCombine : PrimName → List MapEntry → List MapEntry → List MapEntry := providerSetCombineImpl
private abbrev providerEntryLE : List ConName → MapEntry → MapEntry → Bool := providerEntryLEImpl

private theorem entry_order_same {source rows a b c d} (constructors : List ConName)
    (left : MapEntryRel source rows a b) (right : MapEntryRel source rows c d) :
    providerEntryLE constructors a c = providerEntryLE constructors b d := by
  change
    (compare (a.key.toTerm?.bind (fun t => t.observe (fun _ => none)) |>.bind (Observation.orderKey constructors))
      (c.key.toTerm?.bind (fun t => t.observe (fun _ => none)) |>.bind (Observation.orderKey constructors)) != .gt) =
    (compare (b.key.toTerm?.bind (fun t => t.observe (fun _ => none)) |>.bind (Observation.orderKey constructors))
      (d.key.toTerm?.bind (fun t => t.observe (fun _ => none)) |>.bind (Observation.orderKey constructors)) != .gt)
  rw [left.2.1.toTerm,right.2.1.toTerm]

private theorem combine_related {source rows xs ys us vs} (left : MapEntriesRel source rows xs ys)
    (right : MapEntriesRel source rows us vs) (name : PrimName) :
    MapEntriesRel source rows (providerSetCombine name xs us) (providerSetCombine name ys vs) := by
  unfold providerSetCombine
  unfoldSetCombine
  by_cases union : name = "Set.union"
  · simp only [union,ite_true]
    exact right.foldInsertUnit left
  · simp only [union,ite_false]
    apply left.filter
    intro a b entry
    simp only [entry.1,right.hasCode]

private theorem combine_noMint {keys xs ys} (left : MapEntriesAvoid keys xs) (right : MapEntriesAvoid keys ys)
    (name : PrimName) : MapEntriesAvoid keys (providerSetCombine name xs ys) := by
  unfold providerSetCombine
  unfoldSetCombine
  by_cases union : name = "Set.union"
  · simp only [union,ite_true]
    exact right.foldInsertUnit left
  · simp only [union,ite_false]
    exact left.filter _

theorem set_fromList_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (type : Ty) :
    OptionalOutcomeRel source rows (setDelta constructors "Set.fromList" [type] [] [] [.list xs])
      (setDelta constructors "Set.fromList" [type] [] [] [.list ys]) := by
  change OptionalOutcomeRel source rows ((normalizedSet constructors xs).bind _) ((normalizedSet constructors ys).bind _)
  apply OptionalMapEntriesRel.bind_out (normalized_set_related constructors related)
  intro originals targets entries
  exact .some (.value entries.setValue)

theorem set_fromList_noMint {keys xs} (avoid : ValuesAvoid keys xs) (constructors : List ConName) (type : Ty) :
    OptionalOutcomeAvoid keys (setDelta constructors "Set.fromList" [type] [] [] [.list xs]) := by
  change OptionalOutcomeAvoid keys ((normalizedSet constructors xs).bind _)
  apply normalized_set_bind_noMint avoid
  intro entries normal
  exact normal.setValue

theorem set_unary_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (name : PrimName) (type : Ty) :
    OptionalOutcomeRel source rows (setDelta constructors name [type] [] [] [.setV xs])
      (setDelta constructors name [type] [] [] [.setV ys]) := by
  change OptionalOutcomeRel source rows ((normalizedSet constructors xs).bind _) ((normalizedSet constructors ys).bind _)
  apply OptionalMapEntriesRel.bind_out (normalized_set_related constructors related)
  intro originals targets entries
  by_cases size : name = "Set.size"
  · simp only [size,ite_true]
    rw [entries.length]
    exact .refl _
  · simp only [size,ite_false]
    by_cases list : name = "Set.toList"
    · simp only [list,ite_true]
      exact .some (.value (.list entries.keys))
    · simp only [list,ite_false]
      exact .none

theorem set_unary_noMint {keys xs} (avoid : ValuesAvoid keys xs)
    (constructors : List ConName) (name : PrimName) (type : Ty) :
    OptionalOutcomeAvoid keys (setDelta constructors name [type] [] [] [.setV xs]) := by
  change OptionalOutcomeAvoid keys ((normalizedSet constructors xs).bind _)
  apply normalized_set_bind_noMint avoid
  intro entries normal
  by_cases size : name = "Set.size"
  · simp only [size,ite_true]
    exact count_noMint _
  · simp only [size,ite_false]
    by_cases list : name = "Set.toList"
    · simp only [list,ite_true]
      exact ValueAvoid.list normal.keys
    · simp only [list,ite_false]
      trivial

private def member_response (constructors : List ConName) (name : PrimName) (xs : List Val) (x : Val) : Option Outcome := do
  let entries ← normalizedSet constructors xs
  let code ← valKeyCode x
  if name = "Set.contains" then return .val (.const (.boolean (hasCode code entries)))
  else if name = "Set.add" then return .val (setValue ((mapInsert code x (.const .unit) entries).mergeSort (providerEntryLE constructors)))
  else if name = "Set.remove" then return .val (setValue (removeCode code entries)) else none

private theorem member_related {source rows xs ys x y} (related : Values source rows xs ys) (element : Value source rows x y)
    (constructors : List ConName) (name : PrimName) :
    OptionalOutcomeRel source rows (member_response constructors name xs x) (member_response constructors name ys y) := by
  unfold member_response
  apply OptionalMapEntriesRel.bind_out (normalized_set_related constructors related)
  intro originals targets entries
  simp only [element.keyCode]
  generalize found : valKeyCode y = code
  cases code with
  | none => exact .none
  | some code =>
    by_cases contains : name = "Set.contains"
    · simp only [contains,ite_true]
      change OptionalOutcomeRel source rows (some (.val (.const (.boolean (hasCode code originals)))))
        (some (.val (.const (.boolean (hasCode code targets)))))
      rw [entries.hasCode code]
      exact .refl _
    · simp only [contains,ite_false]
      by_cases add : name = "Set.add"
      · simp only [add,ite_true]
        exact .some (.value (((entries.insert element (.constant .unit)).mergeSort _ (entry_order_same constructors)).setValue))
      · simp only [add,ite_false]
        by_cases remove : name = "Set.remove"
        · simp only [remove,ite_true]
          exact .some (.value ((entries.removeCode code).setValue))
        · simp only [remove,ite_false]
          exact .none

private theorem member_noMint {keys xs x} (avoid : ValuesAvoid keys xs) (elementAvoid : ValueAvoid keys x)
    (constructors : List ConName) (name : PrimName) :
    OptionalOutcomeAvoid keys (member_response constructors name xs x) := by
  unfold member_response
  apply normalized_set_bind_noMint avoid
  intro entries normal
  cases found : valKeyCode x with
  | none => trivial
  | some code =>
    by_cases contains : name = "Set.contains"
    · simp only [contains,ite_true]
      exact ValueAvoid.constant _ _
    · simp only [contains,ite_false]
      by_cases add : name = "Set.add"
      · simp only [add,ite_true]
        exact ((normal.insert elementAvoid (ValueAvoid.constant _ _)).mergeSort (providerEntryLE constructors)).setValue
      · simp only [add,ite_false]
        by_cases remove : name = "Set.remove"
        · simp only [remove,ite_true]
          exact (normal.removeCode code).setValue
        · simp only [remove,ite_false]
          trivial

theorem set_combine_delta {source rows xs ys us vs} (left : Values source rows xs ys) (right : Values source rows us vs)
    (constructors : List ConName) (name : PrimName) (type : Ty)
    (allowed : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference") :
    OptionalOutcomeRel source rows (setDelta constructors name [type] [] [] [.setV xs,.setV us])
      (setDelta constructors name [type] [] [] [.setV ys,.setV vs]) := by
  simp only [setDelta,ite_eq_left allowed]
  apply OptionalMapEntriesRel.bind_out (normalized_set_related constructors left)
  intro originals targets entries
  apply OptionalMapEntriesRel.bind_out (normalized_set_related constructors right)
  intro originalRight targetRight rightEntries
  exact .some (.value (((combine_related entries rightEntries name).mergeSort _ (entry_order_same constructors)).setValue))

theorem set_combine_noMint {keys xs ys} (left : ValuesAvoid keys xs) (right : ValuesAvoid keys ys)
    (constructors : List ConName) (name : PrimName) (type : Ty)
    (allowed : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference") :
    OptionalOutcomeAvoid keys (setDelta constructors name [type] [] [] [.setV xs,.setV ys]) := by
  simp only [setDelta,ite_eq_left allowed]
  apply normalized_set_bind_noMint left
  intro entries normal
  apply normalized_set_bind_noMint right
  intro rightEntries rightNormal
  exact ((combine_noMint normal rightNormal name).mergeSort (providerEntryLE constructors)).setValue

private theorem pair_fallback_eq (constructors : List ConName) (name : PrimName) (xs ys : List Val) (type : Ty)
    (inactive : ¬(name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference")) :
    setDelta constructors name [type] [] [] [.setV xs,.setV ys] = member_response constructors name xs (.setV ys) := by
  simp only [setDelta,ite_eq_right inactive,member_response]

private theorem pair_delta {source rows xs ys x y} (related : Values source rows xs ys)
    (element : Value source rows x y) (constructors : List ConName) (name : PrimName) (type : Ty) :
    OptionalOutcomeRel source rows (setDelta constructors name [type] [] [] [.setV xs,x])
      (setDelta constructors name [type] [] [] [.setV ys,y]) := by
  have copy := element
  cases element with
  | set right =>
    by_cases combine : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference"
    · exact set_combine_delta related right constructors name type combine
    · rw [pair_fallback_eq constructors name _ _ type combine,pair_fallback_eq constructors name _ _ type combine]
      exact member_related related copy constructors name
  | _ =>
    change OptionalOutcomeRel source rows (member_response constructors name xs _) (member_response constructors name ys _)
    exact member_related related copy constructors name

private theorem pair_noMint {keys xs x} (avoid : ValuesAvoid keys xs) (element : ValueAvoid keys x)
    (constructors : List ConName) (name : PrimName) (type : Ty) :
    OptionalOutcomeAvoid keys (setDelta constructors name [type] [] [] [.setV xs,x]) := by
  cases x with
  | setV ys =>
    by_cases combine : name = "Set.union" ∨ name = "Set.intersection" ∨ name = "Set.difference"
    · exact set_combine_noMint avoid element.set_inv constructors name type combine
    · rw [pair_fallback_eq constructors name xs ys type combine]
      exact member_noMint avoid element constructors name
  | _ =>
    change OptionalOutcomeAvoid keys (member_response constructors name xs _)
    exact member_noMint avoid element constructors name

/-- Setの実δ全体は、集合を要素として受ける場合も含めて、入力列の対応を保つ。 -/
theorem set_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (setDelta constructors name ts es rs xs) (setDelta constructors name ts es rs ys) := by
  cases ts with
  | nil => exact .none
  | cons type rest => cases rest with
    | cons _ _ => exact .none
    | nil => cases es with
      | cons _ _ => exact .none
      | nil => cases rs with
        | cons _ _ => exact .none
        | nil => cases related with
          | nil => exact .refl _
          | cons head tail => cases tail with
            | nil => cases head with
              | list values =>
                by_cases fromList : name = "Set.fromList"
                · subst name; exact set_fromList_delta values constructors type
                · simp only [setDelta,fromList,ite_false]; exact .none
              | set values => exact set_unary_delta values constructors name type
              | _ => exact .none
            | cons second tail => cases tail with
              | nil => cases head with
                | set values => exact pair_delta values second constructors name type
                | _ => exact .none
              | cons _ _ => cases head with
                | set _ => cases second <;> exact .none
                | _ => exact .none

/-- Setの実δは、入力にない禁止名を結果へ作らない。 -/
theorem set_noMint {keys values} (avoid : ValuesAvoid keys values)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeAvoid keys (setDelta constructors name ts es rs values) := by
  cases ts with
  | nil => trivial
  | cons type rest => cases rest with
    | cons _ _ => trivial
    | nil => cases es with
      | cons _ _ => trivial
      | nil => cases rs with
        | cons _ _ => trivial
        | nil => cases values with
          | nil =>
            change OptionalOutcomeAvoid keys (if name = "Set.empty" then some (.val (.setV [])) else none)
            split
            · exact ValueAvoid.set (ValuesAvoid.nil _)
            · trivial
          | cons head tail =>
            have firstAvoid := (ValuesAvoid.cons.mp avoid).1
            have restAvoid := (ValuesAvoid.cons.mp avoid).2
            cases tail with
            | nil => cases head with
              | list values =>
                by_cases fromList : name = "Set.fromList"
                · subst name; exact set_fromList_noMint firstAvoid.list_inv constructors type
                · simp only [setDelta,fromList,ite_false]; trivial
              | setV values => exact set_unary_noMint firstAvoid.set_inv constructors name type
              | _ => trivial
            | cons second tail => cases tail with
              | nil => cases head with
                | setV values => exact pair_noMint firstAvoid.set_inv (ValuesAvoid.cons.mp restAvoid).1 constructors name type
                | _ => trivial
              | cons _ _ => cases head with
                | setV _ => cases second <;> trivial
                | _ => trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
