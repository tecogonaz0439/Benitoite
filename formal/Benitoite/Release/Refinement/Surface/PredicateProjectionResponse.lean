import Benitoite.Release.Refinement.Surface.PredicateProjectionPath
import Benitoite.Release.Refinement.Surface.PredicateProjectionObservation
import Benitoite.Release.Refinement.Surface.PredicateRowsResponse

/-! # 欄の経路を判定する内部行の全入力の応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProjection
open PredicateRows PredicateResponse MatchFacts
noncomputable section

/-- 経路の型付けは生成済みの取り出しの条件から構成し、署名の形成は同じ宣言の表で検査する。 -/
structure Valid (P : Refinement.Program) (projection : Projection) : Prop where
  entry : projection.entry.Valid
  path : ∃ leaf, AccessPath P projection.input projection.route leaf ∧
    leaf.norm.core = .base projection.entry.input
  nonempty : projection.route ≠ []
  sorted : RouteSorted projection.route projection.entry.sort
  signature : PrimSig.Scoped P projection.signature

/-- 型の宣言が同じであれば、経路と内部署名の条件も同じである。 -/
theorem Valid.sameTypes {P P' : Refinement.Program} {projection : Projection}
    (valid : Valid P projection) (same : P.SameTypes P') : Valid P' projection := by
  obtain ⟨leaf, path, scalar⟩ := valid.path
  exact ⟨valid.entry, ⟨leaf, path.sameTypes same, scalar⟩, valid.nonempty, valid.sorted,
    ⟨valid.signature.names, valid.signature.source, valid.signature.kinds.sameTypes same,
      valid.signature.sorted, valid.signature.declared.sameTypes same, valid.signature.operation⟩⟩

theorem instantiated (projection : Projection) (types : List Ty) :
    instantiatedTel (Tel.instR [] projection.signature.tel) types [] =
      .param "receiver" (projection.input.subst types [])
        (.done (projection.result (.var 1)) Eff.empty) := by
  simp [Projection.signature, PrimSig.tel, signatureTel, instantiatedTel,
    Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind,
    Projection.result,
    Entry.result, agreement, agreementAt, predicate_bind,
    Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, rawBindTys,
    Tel.norm, Ty.norm, Ty.normTys, Ty.refineNorm, Ty.packRefinements,
    Ty.refinementPredicates, Pred.conjuncts, Pred.ofConjuncts,
    Eff.rawBind, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up,
    upValues, termBind, termBind?, predBind, substAtoms_nil,
    instAtoms_nil, rowFails, Projection.input,
    List.map_map, Function.comp_def]

private theorem scalar_bind (θ : SubstEnv) (tag : BaseTy) :
    ∀ a : Ty, a.core = .base tag → (a.rawBind θ).core = .base tag
  | .refined a _, h => by rw [Ty.rawBind, Ty.core]; exact scalar_bind θ tag a h
  | .base _, h => h
  | .opaque _ _, h | .data _ _, h | .list _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h | .lazy _, h
  | .cont _ _ _, h | .map _ _, h | .set _, h | .bytes, h | .dict _ _, h | .tapp _ _, h | .ctor _, h
  | .dependentFn _, h | .external _ _, h | .scoped _ _ _, h | .pathBases, h | .scopePattern _, h => by
    cases h

private theorem scalar_subst {a : Ty} {tag : BaseTy}
    (scalar : a.norm.core = .base tag) (types : List Ty) :
    (a.substAt 0 types []).norm.core = .base tag := by
  simp only [Ty.substAt, substTypeAt, Ty.bind, Ty.norm_idem]
  rw [← Ty.norm_rawBind]
  rw [Ty.core_norm, scalar_bind _ tag a.norm scalar]
  rfl

private theorem scalar_observation (entry : Entry) (c : Const)
    (tag : c.type.norm.core = .base entry.input) :
    ∃ o, (Val.const c).toTerm?.bind (Term.observe (fun _ => none)) = some o ∧
      o.sort = entry.sort := by
  cases entry <;> try (rename_i w test; cases w using FloatWidth.casesOn)
  all_goals cases c <;> cases tag
  all_goals exact ⟨_, rfl, rfl⟩

/-- 既存のプログラムの整形式を使い、型引数を具体化した経路にも同じ判定の応答を与える。 -/
theorem response {P B Ψ name types rows ranges values a e}
    (projection : Projection) (valid : Valid P projection) (formed : P.WellFormed)
    (variance : P.VarianceValid)
    (args : BuiltinArgs P B Ψ name projection.signature types rows ranges values a e) :
    ∃ out, projection.delta types rows ranges values = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult values out ∧ ∀ n, out ≠ .exit n := by
  have ht : types.length = projection.ntys := by simpa [Projection.signature] using args.admissible.typeCount
  have he : rows = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have hr : ranges = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst rows; subst ranges
  have arguments := args.arguments
  rw [instantiated] at arguments
  cases arguments with
  | param ha hv tail =>
    rename_i receiver otherValues
    obtain ⟨leafType, path, scalar⟩ := valid.path
    have path' := path.substAt formed 0 types []
    obtain ⟨leaf, read, typed⟩ := path'.select variance hv.V_Normal
    obtain ⟨c, rfl, _, tag⟩ := typed.canonical_scalar (by
      simpa only [Ty.norm_idem] using scalar_subst scalar types)
    obtain ⟨constructor, fields, observedRoot⟩ := read_data valid.nonempty read
    have ground : receiver.Ground := args.ground receiver (by exact List.mem_cons_self)
    have closedRoot := Val.observation_wf ground observedRoot
    have shiftedRoot : termBind (fun j => some (.var (j+1))) (.dataValue constructor fields) =
        .dataValue constructor fields := by
      simp only [termBind, Term.bind_closed closedRoot, Option.getD_some]
    have htail : Tel.bind (Tel.argumentsEnv receiver) (.done (projection.result (.var 1)) Eff.empty) =
        .done (projection.result (.dataValue constructor fields)) Eff.empty := by
      change Tel.done (Ty.bind _ (projection.result (.var 1))) (Eff.bind _ Eff.empty) = _
      rw [result_bind]
      simp [Tel.argumentsEnv, valEnv, upValues, observedRoot,
        shiftedRoot, Eff.bind, Eff.rawBind, Eff.norm, Eff.empty,
        substAtoms_nil, instAtoms_nil, rowFails]
    rw [htail] at tail
    cases tail with
    | done ha =>
      obtain ⟨o, ho, hsort⟩ := scalar_observation projection.entry c tag
      have observed := read_observation read
        (by rw [observedRoot]; rfl) valid.sorted ho hsort
      have eval := predicate_observed projection.entry valid.entry tag
        (route_closed closedRoot projection.route)
        (route_shape valid.nonempty valid.sorted (by rfl)) (observed.trans ho.symm)
      have result := BooleanResult.typed (B := B) (Ψ := Ψ) args.arguments.resultAnnotation
        (PredicateRows.result_accepts projection.entry eval)
      refine ⟨.val (.const (.boolean (projection.run [receiver]))), by simp [Projection.delta, ht], ?_,
        by intro σ _ _; trivial, by intro n; simp⟩
      simpa only [Projection.run, read, Option.elim_some] using
        (show Outcome.Typed P B Ψ (.val (.const (.boolean (projection.entry.run [.const c]))))
          (projection.result (.dataValue constructor fields)) from ⟨result, trivial⟩)

end
end Benitoite.Release.Refinement.Surface.PredicateProjection
