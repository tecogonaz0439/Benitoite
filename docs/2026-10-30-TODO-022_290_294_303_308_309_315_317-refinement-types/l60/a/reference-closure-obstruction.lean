import Lean
import Benitoite
namespace Benitoite.RefinementReferenceClosure
open Benitoite.Release.Refinement
open Benitoite.Release (Qempty)
noncomputable section

def collisionNames : List String := ["List.map", "List.filter", "Map.map", "Map.filter", "Set.map", "Set.filter", "Range.minimum", "Range.maximum", "Range.value", "Range.lengthMinimum", "Range.lengthMaximum", "Range.checkedLength", "Range.lengthValues", "Range.indexValue", "Range.indexValues", "NonEmptyList.map", "List.mapFrom"]

theorem filter_helper_outside : "List.filterFrom" ∉ collisionNames := by decide

theorem filter_reference_fixed (rename : String → String)
    (support : ∀ name, name ∉ collisionNames → rename name = name) :
    rename "List.filterFrom" = "List.filterFrom" := support _ filter_helper_outside

theorem filter_lookup_incompatible (P : Program)
    (ordinary : P.defs "List.filterFrom" = some (StandardBodies.listFromDefinition true))
    (refined : P.defs "List.filterFrom" = some (StandardHeadTail.fromDefinition true)) : False := by
  have different : (StandardBodies.listFromDefinition true).params ≠
      (StandardHeadTail.fromDefinition true).params := by intro h; cases h
  exact different (congrArg Def.params (Option.some.inj (ordinary.symm.trans refined)))

theorem ordinary_public_body :
    (StandardBodies.listHigherRow true).body = some
      (.app (.fnRef "List.filterFrom" [.tvar 0] [Eff.row 0])
        [.var 1,.var 0,.const (.integer ⟨0,by decide⟩),.list []]) := rfl

theorem refined_public_body : StandardHeadTail.publicBody true =
    .app (.fnRef "List.filterFrom" [.tvar 0] [Eff.row 0])
      [.var 1,.var 0,.var 1,.list []] := rfl

/-- 本体を写したDefも、元の依存列を保持する限り同じ拒否が成り立つ。 -/
theorem ordinary_call_rejected {P B Ψ Q C Γ Φ R T E L d}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (regular : CaptureContextRegular P C Γ) (ctx : Ctx.WF 0 C.length Γ)
    (lookup : P.defs "List.filterFrom" = some d)
    (tel : d.tel = (StandardHeadTail.fromDefinition true).tel)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R
      (.app (.fnRef "List.filterFrom" [.tvar 0] [Eff.row 0])
        [.var 1,.var 0,.const (.integer ⟨0,by decide⟩),.list []]) T E L) : False := by
  obtain ⟨t,r,e,fn,args,_,_⟩ := typed.app_tel rfl hw hs hd regular
  obtain ⟨source,u,found,_,_,inst,core,rel⟩ := fn.inv_fnRef rfl
  have deq : source = d := Option.some.inj (found.symm.trans lookup)
  subst source
  have ueq : t = u := Option.some.inj core
  subst u
  obtain ⟨b,f,original,_,_⟩ := rel.apply ctx inst.result args
  rw [tel] at original
  cases original with
  | param first vx rest =>
    cases rest with
    | param second vf rest =>
      cases rest with
      | param third zero rest =>
        have bad := (zero.inv_const rfl).2
        cases bad
abbrev ordinaryFilter : Def := ((StandardBodies.listHigherRow true).definition).getD
  (StandardBodies.listFromDefinition true)

theorem ordinary_filter_not_typed {P B d}
    (lookup : P.defs "List.filterFrom" = some d)
    (tel : d.tel = (StandardHeadTail.fromDefinition true).tel)
    (typed : ordinaryFilter.WellTyped P B) : False := by
  obtain ⟨_,_,annotation,body⟩ := typed
  let A : Ty := .list (.tvar 0)
  let F : Ty := .fn ["value"] [.tvar 0] (.base .boolean) (Eff.row 0)
  have first : Ty.Annotation P ordinaryFilter.tparams [] A :=
    ⟨annotation.wf.1,annotation.sorted.1,annotation.declared.1⟩
  have second : Ty.Annotation P ordinaryFilter.tparams (Ctx.extend [] A) F :=
    ⟨annotation.wf.2.1,annotation.sorted.2.1,annotation.declared.2.1⟩
  have empty : CaptureContextRegular P ordinaryFilter.tparams [] := by
    constructor
    · intro i a hi; cases hi
    · intro i a hi; cases hi
  have ctx : Ctx.WF 0 ordinaryFilter.tparams.length ([] : Ctx) := by
    intro i a hi; cases hi
  cases body with
  | param body => cases body with
    | param body => cases body with
      | done call =>
        exact ordinary_call_rejected StoreTy.WF.empty StoreTy.Sorted.empty
          (by intro l cell h; cases h) ((empty.extend first).extend second)
          ((ctx.extend first.wf).extend second.wf) lookup tel call

/-- 公開filterの本体で唯一の関数参照へ名前の写像を当てたDef。 -/
def ordinaryFilterCopy (rename : String → String) : Def :=
  { ordinaryFilter with body := (.app (.fnRef (rename "List.filterFrom") [.tvar 0] [Eff.row 0])
      [.var 1,.var 0,.const (.integer ⟨0,by decide⟩),.list []]) }

theorem ordinary_filter_copy_eq (rename : String → String)
    (support : ∀ name, name ∉ collisionNames → rename name = name) :
    ordinaryFilterCopy rename = ordinaryFilter := by
  unfold ordinaryFilterCopy
  rw [filter_reference_fixed rename support]
  rfl

/-- 17名以外を固定する全写像に対する拒否。単射にもそのまま適用できる。 -/
theorem ordinary_filter_copy_not_typed (rename : String → String)
    (support : ∀ name, name ∉ collisionNames → rename name = name) {P B d}
    (lookup : P.defs "List.filterFrom" = some d)
    (tel : d.tel = (StandardHeadTail.fromDefinition true).tel)
    (typed : (ordinaryFilterCopy rename).WellTyped P B) : False := by
  rw [ordinary_filter_copy_eq rename support] at typed
  exact ordinary_filter_not_typed lookup tel typed

end
end Benitoite.RefinementReferenceClosure


/- private・生成宣言も含む、この再現入力の全宣言の公理依存。 -/
open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let localNames := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if localNames.isEmpty then break
    for n in localNames do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      elabCommand (← `(#print axioms $(mkIdent n)))
