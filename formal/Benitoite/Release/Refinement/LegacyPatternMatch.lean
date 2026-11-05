import Benitoite.Release.Refinement.LegacyPatterns
import Benitoite.Release.Refinement.ScopePublicValues

namespace Benitoite.Release.Refinement
noncomputable section

/-- 公開の欄の型の旧 Release の型。埋め込むと同じ核の型になる。 -/
def ScopePublic.PublicTy.oldTy : ScopePublic.PublicTy → Benitoite.Release.Ty
  | .string => .base .string
  | .integer => .base .integer
  | .bytes => .bytes
  | .list a => .list a.oldTy
  | .option a => .data "Option" [a.oldTy]
  | .data d => .data d []

theorem ScopePublic.PublicTy.embed_oldTy : ∀ a : ScopePublic.PublicTy, embedTy a.oldTy = a.ty
  | .string | .integer | .bytes | .data _ => rfl
  | .list a => by simp [ScopePublic.PublicTy.oldTy, ScopePublic.PublicTy.ty, embedTy,
      ScopePublic.PublicTy.embed_oldTy a]
  | .option a => by simp [ScopePublic.PublicTy.oldTy, ScopePublic.PublicTy.ty, embedTy, embedTys,
      ScopePublic.PublicTy.embed_oldTy a]

mutual
  /-- 公開の値の旧 Release の照合の値。バイト列は照合が中を読まない値に写す。 -/
  def ScopePublic.PublicTree.legacy : ScopePublic.PublicTree → Benitoite.Release.Val
    | .text s => .const (.string s)
    | .integer n => .const (.integer n)
    | .bytes _ => .fnRef "" [] []
    | .list _ xs => .list (ScopePublic.PublicTree.legacyList xs)
    | .none _ => .con "Option.None" [] []
    | .some _ x => .con "Option.Some" [] [x.legacy]
    | .con c xs => .con c [] (ScopePublic.PublicTree.legacyList xs)
  def ScopePublic.PublicTree.legacyList : List ScopePublic.PublicTree → List Benitoite.Release.Val
    | [] => []
    | x :: xs => x.legacy :: ScopePublic.PublicTree.legacyList xs
end

def legacyPatternConst : Const → Benitoite.Release.Const
  | .integer n => .integer n
  | .float64 _ => .float 0
  | .string s => .string s
  | .character c => .character c
  | .boolean b => .boolean b
  | .unit => .unit
  | .byte n => .byte n
  | .decimal n s => .decimal n s
  | .opaque o i => .opaque o i
  | .integer8 n => .integer8 n
  | .integer16 n => .integer16 n
  | .integer32 n => .integer32 n
  | .unsignedInteger16 n => .unsignedInteger16 n
  | .unsignedInteger32 n => .unsignedInteger32 n
  | .unsignedInteger64 n => .unsignedInteger64 n
  | .float32 b => .float32 b

mutual
  noncomputable def legacyPatternVal : Val → Benitoite.Release.Val
    | .const c => .const (legacyPatternConst c)
    | .con c _ args => .con c [] (legacyPatternVals args)
    | .list xs => .list (legacyPatternVals xs)
    | .checked t | .checkedRequest t _ | .checkedAt _ _ t _ => .checked t
    | .atError d => .con "Scope.ScopeError.At" [] [d.publicTree.legacy]
    | _ => .fnRef "" [] []
  noncomputable def legacyPatternVals : List Val → List Benitoite.Release.Val
    | [] => []
    | v :: vs => legacyPatternVal v :: legacyPatternVals vs
end

theorem legacyPatternVals_eq_map (vs : List Val) :
    legacyPatternVals vs = vs.map legacyPatternVal := by
  induction vs <;> simp_all [legacyPatternVals]

theorem legacyPatternConst_type (c : Const) :
    embedTy (legacyPatternConst c).type = c.type := by cases c <;> rfl

private theorem legacy_patternMatches (p : Benitoite.Release.Const) (c : Const) :
    p.matches (legacyPatternConst c) = patternMatches p c := by
  cases p <;> cases c <;> rfl

private theorem legacy_patternRange (lo hi : Benitoite.Release.Const) (c : Const) :
    Benitoite.Release.Const.inRange lo hi (legacyPatternConst c) = patternRange lo hi c := by
  cases lo <;> cases hi <;> cases c <;> rfl

mutual
  theorem ScopePublic.PublicTree.legacy_toVal :
      ∀ t : ScopePublic.PublicTree, legacyPatternVal t.toVal = t.legacy
    | .text _ | .integer _ | .bytes _ => rfl
    | .none _ => by simp [ScopePublic.PublicTree.toVal, legacyPatternVal, legacyPatternVals,
        ScopePublic.PublicTree.legacy]
    | .list _ xs => by
      simp only [ScopePublic.PublicTree.toVal, legacyPatternVal, ScopePublic.PublicTree.legacy,
        ScopePublic.PublicTree.legacy_toVals xs]
    | .some _ x => by
      simp only [ScopePublic.PublicTree.toVal, legacyPatternVal, legacyPatternVals, ScopePublic.PublicTree.legacy,
        ScopePublic.PublicTree.legacy_toVal x]
    | .con _ xs => by
      simp only [ScopePublic.PublicTree.toVal, legacyPatternVal, ScopePublic.PublicTree.legacy,
        ScopePublic.PublicTree.legacy_toVals xs]
  theorem ScopePublic.PublicTree.legacy_toVals :
      ∀ xs : List ScopePublic.PublicTree,
        legacyPatternVals (ScopePublic.PublicTree.toVals xs) = ScopePublic.PublicTree.legacyList xs
    | [] => rfl
    | x :: xs => by
      simp only [ScopePublic.PublicTree.toVals, legacyPatternVals, ScopePublic.PublicTree.legacyList,
        ScopePublic.PublicTree.legacy_toVal x, ScopePublic.PublicTree.legacy_toVals xs]
end

private theorem legacy_atError_values (d : AtError) :
    legacyPatternVals d.values = [d.publicTree.legacy] := by
  simp [Detail.values, legacyPatternVals, ScopePublic.PublicTree.legacy_toVal]

mutual
  theorem legacy_matchVal (p : Pat) (v : Val) :
      Benitoite.Release.Pat.matchVal p (legacyPatternVal v) =
        (matchVal p v).map legacyPatternVals := by
    cases p <;> cases v <;>
      simp only [legacyPatternVal,matchVal,Benitoite.Release.Pat.matchVal,
        legacy_patternMatches,legacy_patternRange,legacy_matchList,
        Option.map_none,Option.map_some,legacyPatternVals]
    all_goals try (split <;> rfl)
    case list.list before rest after elems =>
      simp only [legacyPatternVals_eq_map,List.length_map,←List.map_take,←List.map_drop]
      simp only [←legacyPatternVals_eq_map,legacy_matchList]
      by_cases hc : (if rest.isSome then before.length + after.length ≤ elems.length
        else before.length + after.length = elems.length)
      · simp only [hc,ite_true]
        cases matchList before (elems.take before.length) <;>
          cases matchList after (elems.drop (elems.length-after.length)) <;>
          cases rest with
          | none => simp [legacyPatternVals_eq_map,List.map_append]
          | some r => cases r <;> simp [legacyPatternVals_eq_map,List.map_append,
              legacyPatternVal,List.map_take,List.map_drop]
      · simp only [hc,ite_false,Option.map_none]
    case con.atError c ps d =>
      rw [←legacy_atError_values,legacy_matchList]
      split <;> rfl
  theorem legacy_matchList (ps : List Pat) (vs : List Val) :
      Benitoite.Release.Pat.matchList ps (legacyPatternVals vs) =
        (matchList ps vs).map legacyPatternVals := by
    cases ps <;> cases vs <;>
      simp only [legacyPatternVals,Benitoite.Release.Pat.matchList,matchList,
        legacy_matchVal,legacy_matchList,Option.map_none,Option.map_some,legacyPatternVals]
    case cons.cons p ps v vs =>
      cases matchVal p v <;> cases matchList ps vs <;>
        simp [legacyPatternVals_eq_map,List.map_append]
end

end
end Benitoite.Release.Refinement
