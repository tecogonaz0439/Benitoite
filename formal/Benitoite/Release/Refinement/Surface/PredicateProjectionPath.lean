import Benitoite.Release.Refinement.Surface.Theorems
import Benitoite.Release.Refinement.PatternBindings
import Benitoite.Release.Refinement.PatternTypeSubst

/-! # 生成した欄の取り出しによる値の経路

一つの欄を束縛するパターンとその網羅性を、欄の有限列に沿って合成する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateProjection
open MatchFacts
noncomputable section

/-- 各段は、生成した取り出しのパターンを一つの値へ適用する。 -/
inductive AccessPath (P : Refinement.Program) : Ty → List FieldRef → Ty → Prop
  | nil (a : Ty) : AccessPath P a [] a
  | field {a b c : Ty} {pattern : Pat} {ref : FieldRef} {rest : List FieldRef} :
      PatTy P pattern a [b] → Exhaustive P a [pattern] →
      BinderPath pattern 0 [ref] → AccessPath P b rest c → AccessPath P a (ref :: rest) c

private theorem readPath_append (v : Val) (left right : List FieldRef) :
    readPath v (left ++ right) = (readPath v left).bind (fun w => readPath w right) := by
  induction left generalizing v with
  | nil => rfl
  | cons ref left ih =>
    cases hc : conFields? v with
    | none => simp [readPath, hc]
    | some pair =>
      rcases pair with ⟨constructor, fields⟩
      by_cases he : constructor = ref.constructor
      · cases hf : fields[ref.position]? with
        | none => simp [readPath, hc, he, hf]
        | some w => simpa [readPath, hc, he, hf] using ih w
      · simp [readPath, hc, he]

/-- 型付きの受け手から、全ての取り出しが成功した同じ欄の値と型を得る。 -/
theorem AccessPath.select {P B Ψ a route b v}
    (path : AccessPath P a route b) (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v a.norm) :
    ∃ w, readPath v route = some w ∧ HasTypeVQ P B Ψ Qempty [] [] [] w b.norm := by
  induction path generalizing v with
  | nil a => exact ⟨v, rfl, typed⟩
  | @field a b c pattern ref rest hp hex hb tail ih =>
    have inhabited : Inhabits P a.norm v := by
      simpa only [Ty.norm_idem] using inhabits_of_typed valid typed
    obtain ⟨p, hm, matched⟩ := hex v inhabited
    cases List.mem_singleton.mp hm
    obtain ⟨values, hv⟩ := Option.isSome_iff_exists.mp matched
    have bound := pattern_bindings_typed valid hp typed hv
    simp only [List.map_cons, List.map_nil] at bound
    cases bound with
    | cons hw hs =>
      cases hs
      obtain ⟨w, hw0, hread⟩ := BinderPath.matched hb hv
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hw0
      subst w
      obtain ⟨result, hr, ht⟩ := ih hw
      refine ⟨result, ?_, ht⟩
      change readPath v ([ref] ++ rest) = some result
      rw [readPath_append, hread, Option.bind_some]
      exact hr

/-- 型の具体化は、経路の各段のパターンと網羅性を保つ。 -/
theorem AccessPath.substAt {P a route b} (path : AccessPath P a route b)
    (formed : P.WellFormed) (index : Nat) (types : List Ty) (rows : List Eff) :
    AccessPath P (a.substAt index types rows) route (b.substAt index types rows) := by
  induction path with
  | nil a => exact .nil _
  | field hp hex hb tail ih =>
    exact .field (by simpa using hp.substAt formed index types rows)
      (hex.substAt formed index types rows) hb ih

/-- 同じ型の宣言を持つ核へ、生成した取り出しの経路を移す。 -/
theorem AccessPath.sameTypes {P P' a route b} (path : AccessPath P a route b)
    (same : P.SameTypes P') : AccessPath P' a route b := by
  induction path with
  | nil a => exact .nil _
  | field hp hex hb tail ih => exact .field (hp.sameTypes same) (hex.sameTypes same) hb ih

private theorem binderPath_single_ref {pattern i ref ref'}
    (path : BinderPath pattern i [ref]) (hc : ref'.constructor = ref.constructor)
    (hp : ref'.position = ref.position) : BinderPath pattern i [ref'] := by
  cases path with
  | con ha hb hc' hd =>
    cases hd
    exact .con ha (hc.trans hb) (hp.trans hc') .var

/-- 既存の取り出しの生成条件から、指定した欄一段の経路を作る。 -/
theorem AccessPath.accessor {D : Declarations} {P : Refinement.Program} {c cd k field ref}
    (same : D.core.SameTypes P) (accessor : AccessorOk D c cd k)
    (selected : cd.args[k]? = some field)
    (constructor : ref.constructor = c) (position : ref.position = k) :
    AccessPath P (.data cd.data ((List.range cd.ntys).map Ty.tvar)) [ref] field.norm := by
  obtain ⟨_, _, _, selectedType, hp, hn, _, hex, _⟩ := accessor
  have normalized : selectedType.norm = field.norm := by
    apply Ty.shiftV_injective 1 0
    simpa only [Ty.norm_shiftV, accessorBase, selected, Option.getD_some] using hn
  have pattern : PatTy P (accessorPattern c cd.args.length k)
      (.data cd.data ((List.range cd.ntys).map Ty.tvar)) [field.norm] := by
    simpa only [List.map_cons, List.map_nil, normalized] using
      (PatTy.P_Convert (b := .data cd.data ((List.range cd.ntys).map Ty.tvar)) rfl (hp.sameTypes same))
  exact .field pattern (hex.sameTypes same)
    (binderPath_single_ref (accessor_binderPath c cd k (List.getElem?_eq_some_iff.mp selected).1)
      constructor position) (.nil _)

end
end Benitoite.Release.Refinement.Surface.PredicateProjection
