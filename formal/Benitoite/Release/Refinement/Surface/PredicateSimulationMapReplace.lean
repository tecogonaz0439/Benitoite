import Benitoite.Release.Refinement.Surface.PredicateSimulationMapProviders

/-! # 同じ鍵を持つMapの値の置換と固定δ -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardCollections
noncomputable section

private theorem replace_related {source rows xs ys vs ws} (entries : MapEntriesRel source rows xs ys)
    (values : Values source rows vs ws) :
    OptionalMapEntriesRel source rows (StandardMapReplaceValues.replace xs vs) (StandardMapReplaceValues.replace ys ws) := by
  cases entries with
  | nil => cases values with
    | nil => exact .some .nil
    | cons _ _ => exact .none
  | @cons a b xs ys head tail => cases values with
    | nil => exact .none
    | @cons value target vs ws element rest =>
      have remaining := replace_related tail rest
      change OptionalMapEntriesRel source rows
        ((StandardMapReplaceValues.replace xs vs).bind (fun output => some ({a with value := value}::output)))
        ((StandardMapReplaceValues.replace ys ws).bind (fun output => some ({b with value := target}::output)))
      generalize left : StandardMapReplaceValues.replace xs vs = originals at remaining
      generalize right : StandardMapReplaceValues.replace ys ws = targets at remaining
      cases remaining with
      | none => exact .none
      | some related => exact .some (.cons ⟨head.1,head.2.1,element⟩ related)
termination_by xs.length

private theorem replace_noMint {keys entries values output} (source : MapEntriesAvoid keys entries)
    (inputs : ValuesAvoid keys values) (found : StandardMapReplaceValues.replace entries values = some output) :
    MapEntriesAvoid keys output := by
  induction entries generalizing values output with
  | nil => cases values with
    | nil => cases found; intro entry member; cases member
    | cons _ _ => cases found
  | cons head tail ih => cases values with
    | nil => cases found
    | cons value rest =>
      change ((StandardMapReplaceValues.replace tail rest).bind (fun output => some ({head with value := value}::output))) = some output at found
      cases remaining : StandardMapReplaceValues.replace tail rest with
      | none => rw [remaining] at found; cases found
      | some out =>
        rw [remaining] at found
        cases found
        intro entry member
        rcases List.mem_cons.mp member with rfl | member
        · exact ⟨(source head List.mem_cons_self).1,(ValuesAvoid.cons.mp inputs).1⟩
        · exact ih (fun entry member => source entry (List.mem_cons_of_mem _ member))
            (ValuesAvoid.cons.mp inputs).2 remaining entry member

private theorem replace_bind_noMint {keys entries values} (source : MapEntriesAvoid keys entries)
    (inputs : ValuesAvoid keys values) (emit : List MapEntry → Option Outcome)
    (safe : ∀ output, MapEntriesAvoid keys output → OptionalOutcomeAvoid keys (emit output)) :
    OptionalOutcomeAvoid keys ((StandardMapReplaceValues.replace entries values).bind emit) := by
  cases found : StandardMapReplaceValues.replace entries values with
  | none => trivial
  | some out => exact safe out (replace_noMint source inputs found)

theorem replace_values_layout_delta {source rows ks ls vs ws values targets}
    (keys : Values source rows ks ls) (originalValues : Values source rows vs ws) (newValues : Values source rows values targets)
    (constructors : List ConName) (a old b : Ty) :
    OptionalOutcomeRel source rows
      (StandardMapReplaceValues.delta constructors "%Map.replaceValues" [a,old,b] [] [] [.mapV ks vs,.list values])
      (StandardMapReplaceValues.delta constructors "%Map.replaceValues" [a,old,b] [] [] [.mapV ls ws,.list targets]) := by
  change OptionalOutcomeRel source rows ((normalizedMap constructors ks vs).bind _) ((normalizedMap constructors ls ws).bind _)
  apply OptionalMapEntriesRel.bind_out (normalized_map_related constructors keys originalValues)
  intro originals targets entries
  apply OptionalMapEntriesRel.bind_out (replace_related entries newValues)
  intro output targetOutput related
  exact map_fromList_delta (related.pairs a b) constructors a b

theorem replace_values_layout_noMint {keys ks vs values} (keyAvoid : ValuesAvoid keys ks)
    (originalAvoid : ValuesAvoid keys vs) (newAvoid : ValuesAvoid keys values) (constructors : List ConName) (a old b : Ty) :
    OptionalOutcomeAvoid keys
      (StandardMapReplaceValues.delta constructors "%Map.replaceValues" [a,old,b] [] [] [.mapV ks vs,.list values]) := by
  change OptionalOutcomeAvoid keys ((normalizedMap constructors ks vs).bind _)
  apply normalized_map_bind_noMint keyAvoid originalAvoid
  intro originals avoid
  apply replace_bind_noMint avoid newAvoid
  intro output normal
  exact map_noMint (ValuesAvoid.cons.mpr ⟨ValueAvoid.list (normal.pairs a b),ValuesAvoid.nil _⟩)
    constructors "Map.fromList" [a,b] [] []

/-- 値置換の固定δは、元の鍵と対応する新しい値の並びを保つ。 -/
theorem replace_values_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (StandardMapReplaceValues.delta constructors "%Map.replaceValues" ts es rs xs)
      (StandardMapReplaceValues.delta constructors "%Map.replaceValues" ts es rs ys) := by
  cases ts with
  | nil => exact .none
  | cons a rest => cases rest with
    | nil => exact .none
    | cons old rest => cases rest with
      | nil => exact .none
      | cons b rest => cases rest with
        | cons _ _ => exact .none
        | nil => cases es with
          | cons _ _ => exact .none
          | nil => cases rs with
            | cons _ _ => exact .none
            | nil => cases related with
              | nil => exact .none
              | cons first tail => cases tail with
                | nil => cases first <;> exact .none
                | cons second tail => cases tail with
                  | cons _ _ => cases first with
                    | map _ _ => cases second <;> exact .none
                    | _ => exact .none
                  | nil => cases first with
                    | map keys values => cases second with
                      | list newValues => exact replace_values_layout_delta keys values newValues constructors a old b
                      | _ => exact .none
                    | _ => exact .none

theorem replace_values_noMint {keys values} (avoid : ValuesAvoid keys values)
    (constructors : List ConName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeAvoid keys (StandardMapReplaceValues.delta constructors "%Map.replaceValues" ts es rs values) := by
  cases ts with
  | nil => trivial
  | cons a rest => cases rest with
    | nil => trivial
    | cons old rest => cases rest with
      | nil => trivial
      | cons b rest => cases rest with
        | cons _ _ => trivial
        | nil => cases es with
          | cons _ _ => trivial
          | nil => cases rs with
            | cons _ _ => trivial
            | nil => cases values with
              | nil => trivial
              | cons first tail =>
                have firstAvoid := (ValuesAvoid.cons.mp avoid).1
                have tailAvoid := (ValuesAvoid.cons.mp avoid).2
                cases tail with
                | nil => cases first <;> trivial
                | cons second tail => cases tail with
                  | cons _ _ => cases first with
                    | mapV _ _ => cases second <;> trivial
                    | _ => trivial
                  | nil => cases first with
                    | mapV ks vs => cases second with
                      | list newValues =>
                        exact replace_values_layout_noMint firstAvoid.map_inv.1 firstAvoid.map_inv.2
                          (ValuesAvoid.cons.mp tailAvoid).1.list_inv constructors a old b
                      | _ => trivial
                    | _ => trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
