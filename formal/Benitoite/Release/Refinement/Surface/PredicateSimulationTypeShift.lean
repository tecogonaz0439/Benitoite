import Benitoite.Release.Refinement.TypeValueExchange
import Benitoite.Release.Refinement.ValueRenameAlgebra
import Benitoite.Release.Refinement.TypeShiftAlgebra

/-! # 型の具体化と呼出しの管理用の束縛の交換 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem ty_values_shift (a : Ty) (count cutoff : Nat) :
    a.substV (fun i => some (.var (shiftIndex count cutoff i))) = (a.shiftV count cutoff).norm := by
  simp only [Ty.substV, Ty.bind, Ty.shiftV_eq_renameTy, renameTy]
  rfl

private theorem eff_values_shift (effect : Eff) (count cutoff : Nat) :
    effect.substV (fun i => some (.var (shiftIndex count cutoff i))) = (effect.shiftV count cutoff).norm := by
  simp only [Eff.substV, Eff.bind, Eff.shiftV_eq_renameEff, renameEff]
  rfl

private theorem ty_type_shift (a : Ty) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
    (a.shiftV count cutoff).substAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff)) =
      (a.substAt index types effects).shiftV count cutoff := by
  have exchange := Ty.substAt_substV_images a index types effects
    (fun i => some (.var (shiftIndex count cutoff i)))
  have tm : Ty.substV (fun i => some (.var (shiftIndex count cutoff i))) =
      (fun a => (a.shiftV count cutoff).norm) := funext (fun a => ty_values_shift a count cutoff)
  have em : Eff.substV (fun i => some (.var (shiftIndex count cutoff i))) =
      (fun e => (e.shiftV count cutoff).norm) := funext (fun e => eff_values_shift e count cutoff)
  simp only [tm, em] at exchange
  have tmapped : types.map (fun a => (a.shiftV count cutoff).norm) =
      (types.map (Ty.shiftV count cutoff)).map Ty.norm := (List.map_map ..).symm
  have emapped : effects.map (fun e => (e.shiftV count cutoff).norm) =
      (effects.map (Eff.shiftV count cutoff)).map Eff.norm := (List.map_map ..).symm
  rw [tmapped, emapped] at exchange
  have normalized : (a.substAt index types effects).norm = a.substAt index types effects := Ty.norm_idem _
  have left := (Ty.norm_shiftV (a.substAt index types effects) count cutoff).trans
    (congrArg (fun a : Ty => a.shiftV count cutoff) normalized)
  rw [left] at exchange
  change (a.substAt index types effects).shiftV count cutoff =
    (a.shiftV count cutoff).norm.substAt index
      ((types.map (Ty.shiftV count cutoff)).map Ty.norm)
      ((effects.map (Eff.shiftV count cutoff)).map Eff.norm) at exchange
  rw [Ty.substAt_norm_source, Ty.substAt_norm_images_all] at exchange
  exact exchange.symm

private theorem eff_type_shift (effect : Eff) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
    Eff.substAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff)) (effect.shiftV count cutoff) =
      (Eff.substAt index types effects effect).shiftV count cutoff := by
  have exchange := Eff.substAt_substV_images effect index types effects
    (fun i => some (.var (shiftIndex count cutoff i)))
  have tm : Ty.substV (fun i => some (.var (shiftIndex count cutoff i))) =
      (fun a => (a.shiftV count cutoff).norm) := funext (fun a => ty_values_shift a count cutoff)
  have em : Eff.substV (fun i => some (.var (shiftIndex count cutoff i))) =
      (fun e => (e.shiftV count cutoff).norm) := funext (fun e => eff_values_shift e count cutoff)
  simp only [tm, em] at exchange
  have tmapped : types.map (fun a => (a.shiftV count cutoff).norm) =
      (types.map (Ty.shiftV count cutoff)).map Ty.norm := (List.map_map ..).symm
  have emapped : effects.map (fun e => (e.shiftV count cutoff).norm) =
      (effects.map (Eff.shiftV count cutoff)).map Eff.norm := (List.map_map ..).symm
  rw [tmapped, emapped] at exchange
  have normalized : (Eff.substAt index types effects effect).norm = Eff.substAt index types effects effect := Eff.norm_idem _
  have left := (Eff.norm_shiftV (Eff.substAt index types effects effect) count cutoff).trans
    (congrArg (fun e : Eff => e.shiftV count cutoff) normalized)
  rw [left] at exchange
  change (Eff.substAt index types effects effect).shiftV count cutoff =
    Eff.substAt index ((types.map (Ty.shiftV count cutoff)).map Ty.norm)
      ((effects.map (Eff.shiftV count cutoff)).map Eff.norm) (effect.shiftV count cutoff).norm at exchange
  have source : Eff.substAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (effect.shiftV count cutoff).norm =
      Eff.substAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (effect.shiftV count cutoff) := Eff.norm_rawBind _ _
  rw [Eff.substAt_norm_images_all, source] at exchange
  exact exchange.symm


private theorem tel_values_shift (telescope : Tel) (count cutoff : Nat) :
    telescope.substV (fun i => some (.var (shiftIndex count cutoff i))) = (Tel.shiftV count cutoff telescope).norm := by
  simp only [Tel.substV, Tel.bind, Tel.shiftV_eq_rawBind]
  rfl

private theorem tel_type_shift (telescope : Tel) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
    Tel.bind (typeEnvAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff)))
        (Tel.shiftV count cutoff telescope) =
      Tel.shiftV count cutoff (Tel.bind (typeEnvAt index types effects) telescope) := by
  have exchange := Tel.substAt_substV_images telescope index types effects
    (fun i => some (.var (shiftIndex count cutoff i)))
  have tm : Ty.substV (fun i => some (.var (shiftIndex count cutoff i))) =
      (fun a => (a.shiftV count cutoff).norm) := funext (fun a => ty_values_shift a count cutoff)
  have em : Eff.substV (fun i => some (.var (shiftIndex count cutoff i))) =
      (fun e => (e.shiftV count cutoff).norm) := funext (fun e => eff_values_shift e count cutoff)
  simp only [tm, em, tel_values_shift] at exchange
  have tmapped : types.map (fun a => (a.shiftV count cutoff).norm) =
      (types.map (Ty.shiftV count cutoff)).map Ty.norm := (List.map_map ..).symm
  have emapped : effects.map (fun e => (e.shiftV count cutoff).norm) =
      (effects.map (Eff.shiftV count cutoff)).map Eff.norm := (List.map_map ..).symm
  rw [tmapped, emapped] at exchange
  have normalized : (Tel.substAt index types effects telescope).norm = Tel.substAt index types effects telescope := Tel.norm_idem _
  have left := (Tel.norm_shiftV (Tel.substAt index types effects telescope) count cutoff).trans
    (congrArg (Tel.shiftV count cutoff) normalized)
  rw [left] at exchange
  change Tel.shiftV count cutoff (Tel.substAt index types effects telescope) =
    Tel.substAt index ((types.map (Ty.shiftV count cutoff)).map Ty.norm)
      ((effects.map (Eff.shiftV count cutoff)).map Eff.norm) (Tel.shiftV count cutoff telescope).norm at exchange
  rw [Tel.substAt_norm_images_all] at exchange
  have source : Tel.substAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (Tel.shiftV count cutoff telescope).norm =
      Tel.substAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (Tel.shiftV count cutoff telescope) := Tel.norm_rawBind _ _
  rw [source] at exchange
  exact exchange.symm

/-- 型注釈の型具体化は、管理用の値の束縛を追加する操作と可換である。 -/
theorem type_subst_shift (type : Ty) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
    substTypeAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (renameTy (shiftIndex count cutoff) type) =
      renameTy (shiftIndex count cutoff) (substTypeAt index types effects type) := by
  simpa only [substTypeAt, Ty.substAt, ← Ty.shiftV_eq_renameTy] using ty_type_shift type index types effects count cutoff

private theorem row_shift (effect : Eff) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
    substRowAt index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (renameEff (shiftIndex count cutoff) effect) =
      renameEff (shiftIndex count cutoff) (substRowAt index types effects effect) := by
  simpa only [substRowAt, Eff.substAt, ← Eff.shiftV_eq_renameEff] using eff_type_shift effect index types effects count cutoff

private def typeKind (index : Nat) (types : List Ty) (effects : List Eff) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (substTypeAt index types effects a)

private theorem builderLet_type (kind : BuilderKind) (body : Comp) (index : Nat) (types : List Ty) (effects : List Eff) :
    (Comp.builderLet kind body).substTyAt index types effects =
      .builderLet (typeKind index types effects kind)
        (body.substTyAt index (types.map (Ty.shiftV 1 0)) (effects.map (Eff.shiftV 1 0))) := by cases kind <;> rfl

private theorem builderOp_type (kind : BuilderKind) (op : BuilderOp) (reference : LocalRef) (arguments : List Val)
    (index : Nat) (types : List Ty) (effects : List Eff) :
    (Comp.builderOp kind op reference arguments).substTyAt index types effects =
      .builderOp (typeKind index types effects kind) op reference (Val.substTyAtList index types effects arguments) := by
  cases kind <;> rfl

private theorem kind_shift (kind : BuilderKind) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
    typeKind index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
      (renameKind (shiftIndex count cutoff) kind) =
      renameKind (shiftIndex count cutoff) (typeKind index types effects kind) := by
  cases kind <;> simp only [typeKind, renameKind, type_subst_shift]

mutual
  /-- 管理用の束縛を追加した値の型注釈も、同じ深さで具体化する。 -/
  theorem value_type_shift (value : Val) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
      (value.rename (shiftIndex count cutoff)).substTyAt index
          (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff)) =
        (value.substTyAt index types effects).rename (shiftIndex count cutoff) := by
    cases value
    case lam names parameters body =>
      simp only [Val.rename, Val.substTyAt, List.map_map, Function.comp_def,
        type_subst_shift, List.length_map, upRen_shiftIndex]
      congr 1
      simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
        code_type_shift body index (types.map (Ty.shiftV parameters.length 0))
          (effects.map (Eff.shiftV parameters.length 0)) count (cutoff+parameters.length)
    case dependentLam telescope body =>
      simp only [Val.rename, Val.substTyAt, telBinders_rawBind, telBinders_bind, upRen_shiftIndex]
      congr 1
      · simpa only [← Tel.shiftV_eq_rawBind] using tel_type_shift telescope index types effects count cutoff
      · simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
          code_type_shift body index (types.map (Ty.shiftV (telBinders telescope) 0))
            (effects.map (Eff.shiftV (telBinders telescope) 0)) count (cutoff+telBinders telescope)
    all_goals simp only [Val.rename, Val.substTyAt, List.map_map, Function.comp_def,
      type_subst_shift, row_shift, value_type_shift, values_type_shift]
  termination_by structural value
  theorem values_type_shift (values : List Val) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
      Val.substTyAtList index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
          (Val.renameList (shiftIndex count cutoff) values) =
        Val.renameList (shiftIndex count cutoff) (Val.substTyAtList index types effects values) := by
    cases values <;> simp only [Val.renameList, Val.substTyAtList, value_type_shift, values_type_shift]
  termination_by structural values
  theorem code_type_shift (computation : Comp) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
      (computation.rename (shiftIndex count cutoff)).substTyAt index
          (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff)) =
        (computation.substTyAt index types effects).rename (shiftIndex count cutoff) := by
    cases computation
    case builderLet kind body =>
      simp only [Comp.rename, builderLet_type, kind_shift, upRen_shiftIndex]
      all_goals congr 1
      all_goals simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
        (code_type_shift body index (types.map (Ty.shiftV 1 0)) (effects.map (Eff.shiftV 1 0)) count (cutoff+1))
    case builderOp kind op reference arguments =>
      simp only [Comp.rename, builderOp_type, kind_shift, values_type_shift]
    case letIn body rest =>
      simp only [Comp.rename, Comp.substTyAt, code_type_shift, upRen_shiftIndex]
      congr 1
      simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
        (code_type_shift rest index (types.map (Ty.shiftV 1 0)) (effects.map (Eff.shiftV 1 0)) count (cutoff+1))
    case checkAt kind name shape bases pattern input range =>
      cases bases <;> simp only [Comp.rename, Comp.substTyAt, value_type_shift, type_subst_shift]
    all_goals simp only [Comp.rename, Comp.substTyAt, value_type_shift, values_type_shift,
      arms_type_shift, clauses_type_shift, code_type_shift, List.map_map, Function.comp_def, type_subst_shift, row_shift]
  termination_by structural computation
  theorem arms_type_shift (arms : List Arm) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
      Arm.substTyAtList index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
          (Arm.renameList (shiftIndex count cutoff) arms) =
        Arm.renameList (shiftIndex count cutoff) (Arm.substTyAtList index types effects arms) := by
    cases arms with
    | nil => rfl
    | cons arm rest =>
      cases arm with
      | mk alternatives guard body =>
        cases guard <;> simp only [Arm.renameList, Arm.substTyAtList, upRen_shiftIndex, arms_type_shift]
        all_goals congr 2
        all_goals try apply congrArg some
        all_goals simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
          (code_type_shift _ index (types.map (Ty.shiftV (Benitoite.Release.Arm.bindersOf alternatives) 0))
            (effects.map (Eff.shiftV (Benitoite.Release.Arm.bindersOf alternatives) 0)) count
            (cutoff+Benitoite.Release.Arm.bindersOf alternatives))
  termination_by structural arms
  theorem clauses_type_shift (clauses : List Clause) (index : Nat) (types : List Ty) (effects : List Eff) (count cutoff : Nat) :
      Clause.substTyAtList index (types.map (Ty.shiftV count cutoff)) (effects.map (Eff.shiftV count cutoff))
          (Clause.renameList (shiftIndex count cutoff) clauses) =
        Clause.renameList (shiftIndex count cutoff) (Clause.substTyAtList index types effects clauses) := by
    cases clauses with
    | nil => rfl
    | cons clause rest =>
      cases clause with
      | mk operation arity ntys body =>
        simp only [Clause.renameList, Clause.substTyAtList, upRen_shiftIndex, clauses_type_shift]
        congr 2
        simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
          (code_type_shift body (index+ntys) (types.map (Ty.shiftV (arity+1) 0))
            (effects.map (Eff.shiftV (arity+1) 0)) count (cutoff+(arity+1)))
      | fail error body =>
        simp only [Clause.renameList, Clause.substTyAtList, upRen_shiftIndex, clauses_type_shift, type_subst_shift]
        congr 2
        simpa only [List.map_map, Function.comp_def, Ty.shiftV_comm, Eff.shiftV_comm] using
          (code_type_shift body (index+1) (types.map (Ty.shiftV 2 0))
            (effects.map (Eff.shiftV 2 0)) count (cutoff+2))
  termination_by structural clauses
end

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
