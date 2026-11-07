import Benitoite.Release.Refinement.Surface.PredicateSimulationNameAlgebra
import Benitoite.Release.Refinement.Surface.PredicateSimulationReplyAvoid
import Benitoite.Release.Refinement.RuntimeMatch

/-! # 照合で得た値と選んだ本体の内部名の不生成 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

mutual
  /-- 公開の診断の木は、任意の原入力から組込みの参照を作らない。 -/
  theorem public_tree_noMint (keys : List PrimName) (tree : ScopePublic.PublicTree) :
      ValueAvoid keys tree.toVal := by
    cases tree with
    | text text => exact .constant _ _
    | integer value => exact .constant _ _
    | bytes values => exact .bytes _
    | list type values => exact ValueAvoid.list (public_trees_noMint keys values)
    | none type => exact ValueAvoid.con (ValuesAvoid.nil keys) _ _
    | some type value => exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨public_tree_noMint keys value,.nil _⟩) _ _
    | con constructor values => exact ValueAvoid.con (public_trees_noMint keys values) _ _
  theorem public_trees_noMint (keys : List PrimName) (trees : List ScopePublic.PublicTree) :
      ValuesAvoid keys (ScopePublic.PublicTree.toVals trees) := by
    cases trees with
    | nil => exact .nil _
    | cons tree rest => exact ValuesAvoid.cons.mpr ⟨public_tree_noMint keys tree,public_trees_noMint keys rest⟩
end

private theorem detail_values_noMint (keys : List PrimName) (detail : AtError) : ValuesAvoid keys detail.values :=
  ValuesAvoid.cons.mpr ⟨public_tree_noMint keys detail.publicTree,.nil _⟩

private theorem list_middle_avoid {keys values} (avoid : ValuesAvoid keys values)
    (before after : Nat) (rest : Option Benitoite.Release.ListRest) :
    ValuesAvoid keys (match rest with
      | some .bind => [Val.list ((values.drop before).take (values.length - (before+after)))]
      | _ => []) := by
  cases rest with
  | none => exact .nil _
  | some rest => cases rest with
    | skip => exact .nil _
    | bind => exact ValuesAvoid.cons.mpr ⟨ValueAvoid.list ((avoid.drop before).take _),.nil _⟩

mutual
  /-- 照合は原入力の部分値と公開診断の木だけを束縛する。 -/
  theorem ValueAvoid.matchVal {keys value pattern bound} (avoid : ValueAvoid keys value)
      (matched : Refinement.matchVal pattern value = some bound) : ValuesAvoid keys bound := by
    cases pattern with
    | wild => cases matched; exact .nil _
    | var => cases matched; exact ValuesAvoid.cons.mpr ⟨avoid,.nil _⟩
    | const constant =>
      cases value with
      | const value =>
        simp only [Refinement.matchVal] at matched
        split at matched
        · cases matched; exact .nil _
        · cases matched
      | _ => cases matched
    | range lower upper =>
      cases value with
      | const value =>
        simp only [Refinement.matchVal] at matched
        split at matched
        · cases matched; exact .nil _
        · cases matched
      | _ => cases matched
    | con constructor patterns =>
      cases value with
      | con name types values =>
        simp only [Refinement.matchVal] at matched
        split at matched
        · exact ValuesAvoid.matchList avoid.con_inv matched
        · cases matched
      | atError detail =>
        simp only [Refinement.matchVal] at matched
        split at matched
        · exact ValuesAvoid.matchList (detail_values_noMint keys detail) matched
        · cases matched
      | _ => cases matched
    | list before rest after =>
      cases value with
      | list values =>
        simp only [Refinement.matchVal] at matched
        by_cases fits : (if rest.isSome then before.length + after.length ≤ values.length
            else before.length + after.length = values.length)
        · rw [ite_eq_left fits] at matched
          obtain ⟨left,leftMatch,remaining⟩ := Option.bind_eq_some_iff.mp matched
          obtain ⟨right,rightMatch,output⟩ := Option.bind_eq_some_iff.mp remaining
          have leftAvoid := ValuesAvoid.matchList (avoid.list_inv.take before.length) leftMatch
          have rightAvoid := ValuesAvoid.matchList (avoid.list_inv.drop (values.length-after.length)) rightMatch
          have middle := list_middle_avoid avoid.list_inv before.length after.length rest
          cases output
          exact ValuesAvoid.append.mpr ⟨ValuesAvoid.append.mpr ⟨leftAvoid,middle⟩,rightAvoid⟩
        · rw [ite_eq_right fits] at matched
          cases matched
      | _ => cases matched
  termination_by sizeOf pattern

  theorem ValuesAvoid.matchList {keys values patterns bound} (avoid : ValuesAvoid keys values)
      (matched : Refinement.matchList patterns values = some bound) : ValuesAvoid keys bound := by
    cases patterns with
    | nil => cases values with
      | nil => cases matched; exact .nil _
      | cons => cases matched
    | cons pattern patterns => cases values with
      | nil => cases matched
      | cons value values =>
        obtain ⟨head,tail⟩ := ValuesAvoid.cons.mp avoid
        obtain ⟨first,firstMatch,remaining⟩ := Option.bind_eq_some_iff.mp matched
        obtain ⟨rest,restMatch,output⟩ := Option.bind_eq_some_iff.mp remaining
        cases output
        exact ValuesAvoid.append.mpr ⟨head.matchVal firstMatch,ValuesAvoid.matchList tail restMatch⟩
  termination_by sizeOf patterns
end

/-- 並べ替えで得た全値は、元の束縛列に含まれる。 -/
theorem ValuesAvoid.selectSlots {keys values slots result} (avoid : ValuesAvoid keys values)
    (selected : Refinement.selectSlots values slots = some result) : ValuesAvoid keys result :=
  fun value member => avoid value (selectSlots_mem selected value member)

/-- 最初に照合した選択肢から得た束縛にも、原入力にない参照はない。 -/
theorem ValueAvoid.firstAlt {keys value alternatives bound} (avoid : ValueAvoid keys value)
    (selected : Refinement.firstAlt value alternatives = some bound) : ValuesAvoid keys bound := by
  induction alternatives with
  | nil => cases selected
  | cons alternative rest ih =>
    simp only [Refinement.firstAlt] at selected
    cases matched : Refinement.matchVal alternative.pat value with
    | none => exact ih (by simpa only [matched] using selected)
    | some values =>
      exact (avoid.matchVal matched).selectSlots (by simpa only [matched] using selected)

/-- 選んだ腕の本体と存在するガードは、元の腕の列に含まれる。 -/
theorem ArmsAvoid.get {keys : List PrimName} {arms : List Arm} {index : Nat}
    {alternatives : List Benitoite.Release.Alt} {guard : Option Comp} {body : Comp} (avoid : ArmsAvoid keys arms)
    (selected : arms[index]? = some (.mk alternatives guard body)) :
    CodeAvoid keys body ∧ ∀ condition, guard = some condition → CodeAvoid keys condition := by
  induction arms generalizing index with
  | nil => simp at selected
  | cons arm rest ih =>
    cases arm with
    | mk alternatives' guard' body' =>
      cases guard' with
      | none =>
        have parts := NamesAvoid.append.mp avoid
        cases index with
        | zero => cases selected; exact ⟨parts.1,by intro condition impossible; cases impossible⟩
        | succ index => exact ih parts.2 selected
      | some condition =>
        obtain ⟨head,tail⟩ := NamesAvoid.append.mp avoid
        obtain ⟨guardAvoid,bodyAvoid⟩ := NamesAvoid.append.mp head
        cases index with
        | zero =>
          cases selected
          exact ⟨bodyAvoid,by intro value same; cases same; exact guardAvoid⟩
        | succ index => exact ih tail selected

private theorem clause_body_avoid {keys clauses clause} (avoid : ClausesAvoid keys clauses)
    (member : clause ∈ clauses) : CodeAvoid keys clause.body := by
  induction clauses with
  | nil => cases member
  | cons head rest ih =>
    cases head with
    | mk operation arity types body =>
      obtain ⟨head,tail⟩ := NamesAvoid.append.mp avoid
      rcases List.mem_cons.mp member with rfl | member
      · exact (NamesAvoid.append.mp head).2
      · exact ih tail member
    | fail error body =>
      obtain ⟨head,tail⟩ := NamesAvoid.append.mp avoid
      rcases List.mem_cons.mp member with rfl | member
      · exact head
      · exact ih tail member

/-- 節の検索は、元の列にある本体だけを選ぶ。 -/
theorem ClausesAvoid.find_body {keys clauses operation clause} (avoid : ClausesAvoid keys clauses)
    (selected : findClause clauses operation = some clause) : CodeAvoid keys clause.body :=
  clause_body_avoid avoid (List.mem_of_find?_eq_some selected)

/-- 解放のために残す継続も、元の継続の値と本体だけを持つ。 -/
theorem ContAvoid.releases {keys continuation} (avoid : ContAvoid keys continuation) :
    ContAvoid keys (Refinement.releases continuation) := by
  induction continuation with
  | nil => exact .nil _
  | cons frame rest ih =>
    obtain ⟨head,tail⟩ := ContAvoid.cons.mp avoid
    cases frame <;> first | exact ih tail | exact ContAvoid.cons.mpr ⟨head,ih tail⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
