import Benitoite.Release.Refinement.Surface.PredicateSimulationResponseInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationStateAvoid
import Benitoite.Release.Refinement.Surface.PredicateSimulationStructure

/-! # 純粋応答とIO応答を読む実遷移の対応 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

/-- 元の実際の到達先とラベルを保ち、対応先の一段と元の禁止名不在を返す。 -/
def ResponseSynchronizedAt (source : Program) (rows : PredicateProjection.Table.Rows) (keys : List PrimName)
    (P Q : Refinement.Program) (B C : Builtins) (σ : PathEnv) (first second : State)
    {label : Option Event} {destination : State} (_step : Step P B σ first label destination) : Prop :=
  ∃ next, Step Q C σ second label next ∧ StateRel source rows destination next ∧ StateAvoid keys destination

abbrev responseTable (config : Check.BuiltinSource) (rows : PredicateProjection.Table.Rows) : Builtins :=
  (Check.BuiltinSource.resolved config rows).builtins

theorem primitive_inputs_avoid {rows : PredicateProjection.Table.Rows} {q k μ name ts es rs values}
    (avoid : NoGeneratedKeys rows (.run q k μ))
    (view : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) values) :
    rows.lookup name = none ∧ ValuesAvoid (rows.map Prod.fst) values := by
  have names := avoid.1.view
  rw [view] at names
  obtain ⟨head,arguments⟩ := NamesAvoid.append.mp names
  refine ⟨?_,valuesNames_avoid.mp arguments⟩
  cases selected : rows.lookup name with
  | none => rfl
  | some entry =>
    have member := ScopeSignatures.lookup_mem selected
    exact False.elim (head name (by simp [valueNames]) (List.mem_map_of_mem (f := Prod.fst) member))

theorem overlay_signature {config : Check.BuiltinSource} {rows : PredicateProjection.Table.Rows} {name signature}
    (absent : rows.lookup name = none) (found : config.builtins.sig name = some signature) :
    (responseTable config rows).sig name = some signature := by
  change (match rows.lookup name with | some row => some row.signature | none => config.builtins.sig name) = _
  rw [absent]
  exact found

theorem overlay_delta {config : Check.BuiltinSource} {rows : PredicateProjection.Table.Rows} {name}
    (absent : rows.lookup name = none) :
    (responseTable config rows).delta name = config.builtins.delta name := by
  funext ts es rs values
  change (match rows.lookup name with
    | some row => row.delta ts es rs values | none => config.builtins.delta name ts es rs values) = _
  rw [absent]

private theorem OptionalOutcomeRel.value_left {source rows value output}
    (related : OptionalOutcomeRel source rows (Option.some (Outcome.val value)) output) :
    ∃ target, output = Option.some (Outcome.val target) ∧ Value source rows value target := by
  cases related with
  | some related => cases related with
    | value related => exact ⟨_,rfl,related⟩

private theorem OptionalOutcomeRel.error_left {source rows message output}
    (related : OptionalOutcomeRel source rows (Option.some (Outcome.err message)) output) : output = Option.some (Outcome.err message) := by
  cases related with
  | some related => cases related; rfl

theorem ret_avoid {keys value k μ} (valueAvoid : ValueAvoid keys value)
    (continuation : ContAvoid keys k) (store : StoreAvoid keys μ) :
    StateAvoid keys (.run (.pure (.ret value)) k μ) :=
  ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,valueAvoid⟩,continuation,store⟩

variable {source : Program} {rows : PredicateProjection.Table.Rows} {P Q : Refinement.Program} {σ : PathEnv}
variable {config : Check.BuiltinSource}

/-- 通常の純粋な実応答は、元の受理と実到達先を保ち、対応先の一段へ進む。 -/
theorem response_primitive {q r name ts es rs xs ys k l μ ν signature value Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    [StandardModel.RowEnv Q (responseTable config rows)] (core : (responseTable config rows).CoreAssumptions Q)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : config.builtins.sig name = some signature) (kind : signature.kind = .pure)
    (response : config.builtins.delta name (Ty.normTys ts) (es.map Eff.norm) rs xs = Option.some (Outcome.val value))
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_Prim first found kind response) := by
  obtain ⟨absent,inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have targetSig := overlay_signature absent found
  have targetResponse : (responseTable config rows).delta name (Ty.normTys ts) (es.map Eff.norm) rs xs = Option.some (Outcome.val value) := by
    rw [overlay_delta absent]; exact response
  obtain ⟨related,outputAvoid⟩ := active_pure_response active core targetSig kind typed arguments inputsAvoid
  rw [targetResponse] at related outputAvoid
  obtain ⟨result,resultResponse,values⟩ := related.value_left
  exact ⟨_,.E_Prim second targetSig kind resultResponse,.run (.pure (.ret values)) continuation store,
    ret_avoid outputAvoid avoid.2.1 avoid.2.2⟩

/-- 純粋な失敗も同じ診断で対応先へ進み、元の継続とストアの禁止名不在を保つ。 -/
theorem response_primitive_error {q r name ts es rs xs ys k l μ ν signature message Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    [StandardModel.RowEnv Q (responseTable config rows)] (core : (responseTable config rows).CoreAssumptions Q)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : config.builtins.sig name = some signature) (kind : signature.kind = .pure)
    (response : config.builtins.delta name (Ty.normTys ts) (es.map Eff.norm) rs xs = Option.some (Outcome.err message))
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_Err first found kind response) := by
  obtain ⟨absent,inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have targetSig := overlay_signature absent found
  have targetResponse : (responseTable config rows).delta name (Ty.normTys ts) (es.map Eff.norm) rs xs = Option.some (Outcome.err message) := by
    rw [overlay_delta absent]; exact response
  have related := (active_pure_response active core targetSig kind typed arguments inputsAvoid).1
  rw [targetResponse] at related
  exact ⟨_,.E_Err second targetSig kind related.error_left,.error continuation store,avoid.2⟩


/-- IO事象に含まれる生の実引数と応答を保ち、元の実際の到達先へ対応する一段を返す。 -/
theorem response_io {q r name ts es rs xs ys k l μ ν signature value observations Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : config.builtins.sig name = some signature) (kind : signature.kind = .io)
    (unhandled : NoHandler k (.prim name))
    (response : config.builtins.ioResponse name (Ty.normTys ts) (es.map Eff.norm) xs (.val value) observations)
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_IO first found kind unhandled response) := by
  obtain ⟨absent,_inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have targetSig := overlay_signature absent found
  have same := active_io_inputs_equal active targetSig (Or.inl kind) typed arguments
  have targetResponse := (active_io_response active arguments name (Ty.normTys ts) (es.map Eff.norm)
    (.val value) observations).mp response
  subst xs
  have outputAvoid := active_io_noMint (keys := rows.map Prod.fst) active targetResponse
  exact ⟨_,.E_IO second targetSig kind ((continuation.noHandler _).mp unhandled) targetResponse,
    .run (.pure (.ret (.refl value))) continuation store,ret_avoid outputAvoid avoid.2.1 avoid.2.2⟩


/-- IO事象に含まれる生の実引数と応答を保ち、元の実際の到達先へ対応する一段を返す。 -/
theorem response_io_error {q r name ts es rs xs ys k l μ ν signature message observations Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : config.builtins.sig name = some signature) (kind : signature.kind = .io ∨ signature.kind = .exit)
    (unhandled : NoHandler k (.prim name))
    (response : config.builtins.ioResponse name (Ty.normTys ts) (es.map Eff.norm) xs (.err message) observations)
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_IOErr first found kind unhandled response) := by
  obtain ⟨absent,_inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have targetSig := overlay_signature absent found
  have same := active_io_inputs_equal active targetSig (kind) typed arguments
  have targetResponse := (active_io_response active arguments name (Ty.normTys ts) (es.map Eff.norm)
    (.err message) observations).mp response
  subst xs
  exact ⟨_,.E_IOErr second targetSig kind ((continuation.noHandler _).mp unhandled) targetResponse,
    .error continuation store,avoid.2⟩


/-- IO事象に含まれる生の実引数と応答を保ち、元の実際の到達先へ対応する一段を返す。 -/
theorem response_exit {q r name ts es rs xs ys k l μ ν signature code observations Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : config.builtins.sig name = some signature) (kind : signature.kind = .exit)
    (unhandled : NoHandler k (.prim name))
    (response : config.builtins.ioResponse name (Ty.normTys ts) (es.map Eff.norm) xs (.exit code) observations)
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_Exit first found kind unhandled response) := by
  obtain ⟨absent,_inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have targetSig := overlay_signature absent found
  have same := active_io_inputs_equal active targetSig (Or.inr kind) typed arguments
  have targetResponse := (active_io_response active arguments name (Ty.normTys ts) (es.map Eff.norm)
    (.exit code) observations).mp response
  subst xs
  exact ⟨_,.E_Exit second targetSig kind ((continuation.noHandler _).mp unhandled) targetResponse,
    .exit continuation store,avoid.2⟩


/-- 対応先の実際の到達先とラベルを保ち、元の一段と禁止名不在を返す。 -/
def ResponseBackwardAt (source : Program) (rows : PredicateProjection.Table.Rows) (keys : List PrimName)
    (P Q : Refinement.Program) (B C : Builtins) (σ : PathEnv) (first second : State)
    {label : Option Event} {destination : State} (_step : Step Q C σ second label destination) : Prop :=
  ∃ next, Step P B σ first label next ∧ StateRel source rows next destination ∧ StateAvoid keys next

private theorem underlay_signature {rows : PredicateProjection.Table.Rows} {config : Check.BuiltinSource} {name signature}
    (absent : rows.lookup name = none) (found : (responseTable config rows).sig name = some signature) :
    config.builtins.sig name = some signature := by
  change (match rows.lookup name with | some row => some row.signature | none => config.builtins.sig name) = _ at found
  rw [absent] at found
  exact found

private theorem OptionalOutcomeRel.value_right {source rows value output}
    (related : OptionalOutcomeRel source rows output (Option.some (Outcome.val value))) :
    ∃ original, output = Option.some (Outcome.val original) ∧ Value source rows original value := by
  cases related with
  | some related => cases related with
    | value related => exact ⟨_,rfl,related⟩

private theorem OptionalOutcomeRel.error_right {source rows message output}
    (related : OptionalOutcomeRel source rows output (Option.some (Outcome.err message))) : output = Option.some (Outcome.err message) := by
  cases related with
  | some related => cases related; rfl

/-- 対応先の純粋応答の実一段から、元の対応する実一段と禁止名不在を得る。 -/
theorem response_primitive_backward {q r name ts es rs xs ys k l μ ν signature value Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    [StandardModel.RowEnv Q (responseTable config rows)] (core : (responseTable config rows).CoreAssumptions Q)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : (responseTable config rows).sig name = some signature) (kind : signature.kind = .pure)
    (response : (responseTable config rows).delta name (Ty.normTys ts) (es.map Eff.norm) rs ys = Option.some (Outcome.val value))
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_Prim second found kind response) := by
  obtain ⟨absent,inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have sourceSig := underlay_signature absent found
  obtain ⟨related,outputAvoid⟩ := active_pure_response active core found kind typed arguments inputsAvoid
  rw [response] at related
  obtain ⟨original,sourceResponse,values⟩ := related.value_right
  rw [sourceResponse] at outputAvoid
  have baseResponse : config.builtins.delta name (Ty.normTys ts) (es.map Eff.norm) rs xs = Option.some (Outcome.val original) := by
    rw [← overlay_delta absent]; exact sourceResponse
  exact ⟨_,.E_Prim first sourceSig kind baseResponse,.run (.pure (.ret values)) continuation store,
    ret_avoid outputAvoid avoid.2.1 avoid.2.2⟩

/-- 対応先の純粋な失敗の実一段から、元の同じ診断の一段を得る。 -/
theorem response_primitive_error_backward {q r name ts es rs xs ys k l μ ν signature message Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    [StandardModel.RowEnv Q (responseTable config rows)] (core : (responseTable config rows).CoreAssumptions Q)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : (responseTable config rows).sig name = some signature) (kind : signature.kind = .pure)
    (response : (responseTable config rows).delta name (Ty.normTys ts) (es.map Eff.norm) rs ys = Option.some (Outcome.err message))
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_Err second found kind response) := by
  obtain ⟨absent,inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have sourceSig := underlay_signature absent found
  have related := (active_pure_response active core found kind typed arguments inputsAvoid).1
  rw [response] at related
  have baseResponse : config.builtins.delta name (Ty.normTys ts) (es.map Eff.norm) rs xs = Option.some (Outcome.err message) := by
    rw [← overlay_delta absent]; exact related.error_right
  exact ⟨_,.E_Err first sourceSig kind baseResponse,.error continuation store,avoid.2⟩


/-- 対応先のIO事象と実際の到達先に、同じ生の実引数を持つ元の実一段を対応させる。 -/
theorem response_io_backward {q r name ts es rs xs ys k l μ ν signature value observations Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : (responseTable config rows).sig name = some signature) (kind : signature.kind = .io)
    (unhandled : NoHandler l (.prim name))
    (response : (responseTable config rows).ioResponse name (Ty.normTys ts) (es.map Eff.norm) ys (.val value) observations)
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_IO second found kind unhandled response) := by
  obtain ⟨absent,_inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have sourceSig := underlay_signature absent found
  have same := active_io_inputs_equal active found (Or.inl kind) typed arguments
  have sourceResponse := (active_io_response active arguments name (Ty.normTys ts) (es.map Eff.norm)
    (.val value) observations).mpr response
  subst xs
  have outputAvoid := active_io_noMint (keys := rows.map Prod.fst) active sourceResponse
  exact ⟨_,.E_IO first sourceSig kind ((continuation.noHandler _).mpr unhandled) sourceResponse,
    .run (.pure (.ret (.refl value))) continuation store,ret_avoid outputAvoid avoid.2.1 avoid.2.2⟩


/-- 対応先のIO事象と実際の到達先に、同じ生の実引数を持つ元の実一段を対応させる。 -/
theorem response_io_error_backward {q r name ts es rs xs ys k l μ ν signature message observations Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : (responseTable config rows).sig name = some signature) (kind : signature.kind = .io ∨ signature.kind = .exit)
    (unhandled : NoHandler l (.prim name))
    (response : (responseTable config rows).ioResponse name (Ty.normTys ts) (es.map Eff.norm) ys (.err message) observations)
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_IOErr second found kind unhandled response) := by
  obtain ⟨absent,_inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have sourceSig := underlay_signature absent found
  have same := active_io_inputs_equal active found (kind) typed arguments
  have sourceResponse := (active_io_response active arguments name (Ty.normTys ts) (es.map Eff.norm)
    (.err message) observations).mpr response
  subst xs
  exact ⟨_,.E_IOErr first sourceSig kind ((continuation.noHandler _).mpr unhandled) sourceResponse,
    .error continuation store,avoid.2⟩


/-- 対応先のIO事象と実際の到達先に、同じ生の実引数を持つ元の実一段を対応させる。 -/
theorem response_exit_backward {q r name ts es rs xs ys k l μ ν signature code observations Ψ a e}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) xs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ys)
    (found : (responseTable config rows).sig name = some signature) (kind : signature.kind = .exit)
    (unhandled : NoHandler l (.prim name))
    (response : (responseTable config rows).ioResponse name (Ty.normTys ts) (es.map Eff.norm) ys (.exit code) observations)
    (typed : BuiltinArgs Q (responseTable config rows) Ψ name signature (Ty.normTys ts) (es.map Eff.norm) rs ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_Exit second found kind unhandled response) := by
  obtain ⟨absent,_inputsAvoid⟩ := primitive_inputs_avoid avoid first
  have sourceSig := underlay_signature absent found
  have same := active_io_inputs_equal active found (Or.inr kind) typed arguments
  have sourceResponse := (active_io_response active arguments name (Ty.normTys ts) (es.map Eff.norm)
    (.exit code) observations).mpr response
  subst xs
  exact ⟨_,.E_Exit first sourceSig kind ((continuation.noHandler _).mpr unhandled) sourceResponse,
    .exit continuation store,avoid.2⟩


mutual
  private theorem external_check_cons (types : P.SameTypes Q) (value : Val) (a : Ty) :
      externalCheck P value a = externalCheck Q value a := by
    cases a with
    | refined a predicate => simp only [externalCheck,external_check_cons types value a]
    | list a => cases value <;> simp only [externalCheck] <;> exact external_check_each_cons types _ a
    | set a => cases value <;> simp only [externalCheck] <;> exact external_check_each_cons types _ a
    | map a b =>
      cases value <;> simp only [externalCheck]
      case mapV keys values => rw [external_check_each_cons types keys a,external_check_each_cons types values b]
    | data name parameters =>
      cases value <;> simp only [externalCheck]
      case con constructor actual values =>
        rw [types.cons]
        cases found : Q.cons constructor with
        | none => rfl
        | some declaration =>
          exact congrArg (fun accepted => decide (declaration.data = name ∧ declaration.ntys = parameters.length) && accepted)
            (external_check_fields_cons types values (declaration.args.map (Ty.subst parameters [])))
    | _ => cases value <;> simp only [externalCheck]
  termination_by (sizeOf value,sizeOf a)
  private theorem external_check_each_cons (types : P.SameTypes Q) (values : List Val) (a : Ty) :
      externalCheckEach P values a = externalCheckEach Q values a := by
    cases values with
    | nil => simp only [externalCheckEach]
    | cons value values =>
      simp only [externalCheckEach]
      rw [external_check_cons types value a,external_check_each_cons types values a]
  termination_by (sizeOf values,sizeOf a)
  private theorem external_check_fields_cons (types : P.SameTypes Q) (values : List Val) (as : List Ty) :
      externalCheckFields P values as = externalCheckFields Q values as := by
    cases values with
    | nil => cases as <;> simp only [externalCheckFields]
    | cons value values => cases as with
      | nil => simp only [externalCheckFields]
      | cons a as =>
        simp only [externalCheckFields]
        rw [external_check_cons types value a,external_check_fields_cons types values as]
  termination_by (sizeOf values,sizeOf as)
end

private theorem external_receive_sameTypes (types : P.SameTypes Q) (declaration : ExternalSignature)
    (parameters : List Ty) (values : List Val) (out : Outcome) :
    externalReceive P declaration parameters values out = externalReceive Q declaration parameters values out := by
  unfold externalReceive
  congr 1
  funext pair
  cases out <;> simp only [externalCheckedOutcome,external_check_cons types]

private theorem external_received_noMint {keys raw received declaration parameters values}
    (avoid : OutcomeAvoid keys raw)
    (receive : externalReceive P declaration parameters values raw = some received) : OutcomeAvoid keys received := by
  unfold externalReceive at receive
  obtain ⟨⟨a,e⟩,_instantiated,rfl⟩ := Option.map_eq_some_iff.mp receive
  cases raw with
  | val value =>
    simp only [externalCheckedOutcome]
    split
    · exact avoid
    · trivial
  | err _ | exit _ => trivial


/-- 外部応答の同じABI入力と受信検査から、実際の応答の一段と元の禁止名不在を得る。 -/
theorem response_external {q r function ts xs ys k l μ ν declaration value raw observations Ψ a e}
    (types : P.SameTypes Q) (formed : Q.WellFormed) (valid : Q.VarianceValid)
    (core : (responseTable config rows).CoreAssumptions Q)
    (first : q.view = .externalCall function ts xs) (second : r.view = .externalCall function ts ys)
    (found : P.externalFunction function = some declaration)
    (response : config.builtins.externalResponse function ts xs raw observations)
    (receive : externalReceive P declaration ts xs raw = some (.val value))
    (typed : ExternalArgs Q (responseTable config rows) Ψ declaration ts ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_External first found response receive) := by
  have targetFound : Q.externalFunction function = some declaration := by
    simpa only [Refinement.Program.externalFunction,types.externals] using found
  have same := external_arguments_equal formed valid (formed.external.function_lookup targetFound) typed arguments
  subst xs
  have targetReceive : externalReceive Q declaration ts ys raw = some (.val value) := by
    rw [← external_receive_sameTypes types]
    exact receive
  have carrier := (core.external_typed Ψ function declaration ts ys a e raw observations
    formed.external targetFound typed response).1
  have outputAvoid := external_received_noMint (keys := rows.map Prod.fst) (external_outcome_noMint carrier) receive
  exact ⟨_,.E_External second targetFound response targetReceive,
    .run (.pure (.ret (.refl value))) continuation store,ret_avoid outputAvoid avoid.2.1 avoid.2.2⟩


/-- 外部応答の同じABI入力と受信検査から、実際の応答の一段と元の禁止名不在を得る。 -/
theorem response_external_error {q r function ts xs ys k l μ ν declaration message raw observations Ψ a e}
    (types : P.SameTypes Q) (formed : Q.WellFormed) (valid : Q.VarianceValid)
    (first : q.view = .externalCall function ts xs) (second : r.view = .externalCall function ts ys)
    (found : P.externalFunction function = some declaration)
    (response : config.builtins.externalResponse function ts xs raw observations)
    (receive : externalReceive P declaration ts xs raw = some (.err message))
    (typed : ExternalArgs Q (responseTable config rows) Ψ declaration ts ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_ExternalErr first found response receive) := by
  have targetFound : Q.externalFunction function = some declaration := by
    simpa only [Refinement.Program.externalFunction,types.externals] using found
  have same := external_arguments_equal formed valid (formed.external.function_lookup targetFound) typed arguments
  subst xs
  have targetReceive : externalReceive Q declaration ts ys raw = some (.err message) := by
    rw [← external_receive_sameTypes types]
    exact receive
  exact ⟨_,.E_ExternalErr second targetFound response targetReceive,.error continuation store,avoid.2⟩


/-- 外部応答の同じABI入力と受信検査から、実際の応答の一段と元の禁止名不在を得る。 -/
theorem response_external_backward {q r function ts xs ys k l μ ν declaration value raw observations Ψ a e}
    (types : P.SameTypes Q) (formed : Q.WellFormed) (valid : Q.VarianceValid)
    (core : (responseTable config rows).CoreAssumptions Q)
    (first : q.view = .externalCall function ts xs) (second : r.view = .externalCall function ts ys)
    (found : Q.externalFunction function = some declaration)
    (response : (responseTable config rows).externalResponse function ts ys raw observations)
    (receive : externalReceive Q declaration ts ys raw = some (.val value))
    (typed : ExternalArgs Q (responseTable config rows) Ψ declaration ts ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_External second found response receive) := by
  have sourceFound : P.externalFunction function = some declaration := by
    simpa only [Refinement.Program.externalFunction,types.externals] using found
  have same := external_arguments_equal formed valid (formed.external.function_lookup found) typed arguments
  subst xs
  have sourceReceive : externalReceive P declaration ts ys raw = some (.val value) := by
    rw [external_receive_sameTypes types]
    exact receive
  have carrier := (core.external_typed Ψ function declaration ts ys a e raw observations
    formed.external found typed response).1
  have outputAvoid := external_received_noMint (keys := rows.map Prod.fst) (external_outcome_noMint carrier) sourceReceive
  exact ⟨_,.E_External first sourceFound response sourceReceive,
    .run (.pure (.ret (.refl value))) continuation store,ret_avoid outputAvoid avoid.2.1 avoid.2.2⟩


/-- 外部応答の同じABI入力と受信検査から、実際の応答の一段と元の禁止名不在を得る。 -/
theorem response_external_error_backward {q r function ts xs ys k l μ ν declaration message raw observations Ψ a e}
    (types : P.SameTypes Q) (formed : Q.WellFormed) (valid : Q.VarianceValid)
    (first : q.view = .externalCall function ts xs) (second : r.view = .externalCall function ts ys)
    (found : Q.externalFunction function = some declaration)
    (response : (responseTable config rows).externalResponse function ts ys raw observations)
    (receive : externalReceive Q declaration ts ys raw = some (.err message))
    (typed : ExternalArgs Q (responseTable config rows) Ψ declaration ts ys a e)
    (arguments : Values source rows xs ys) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q k μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q k μ) (.run r l ν) (.E_ExternalErr second found response receive) := by
  have sourceFound : P.externalFunction function = some declaration := by
    simpa only [Refinement.Program.externalFunction,types.externals] using found
  have same := external_arguments_equal formed valid (formed.external.function_lookup found) typed arguments
  subst xs
  have sourceReceive : externalReceive P declaration ts ys raw = some (.err message) := by
    rw [external_receive_sameTypes types]
    exact receive
  exact ⟨_,.E_ExternalErr first sourceFound response sourceReceive,.error continuation store,avoid.2⟩


private theorem active_release_constant {configuration : Check.BuiltinSource} {value result}
    (active : CheckPreparation.enabled configuration = true)
    (response : configuration.builtins.releaseResponse value result) :
    ∃ name payload, value = .const (.opaque name payload) := by
  induction configuration with
  | custom _ | unrestrictedRanges _ => cases active
  | standard program B built =>
    subst built
    obtain ⟨name,payload,same,_resource⟩ := response
    exact ⟨name,payload,same⟩
  | predicates data entries B built =>
    subst built
    rcases response with response | impossible
    · obtain ⟨name,payload,same,_resource⟩ := response
      exact ⟨name,payload,same⟩
    · exact False.elim impossible
  | resolved base _ ih => exact ih (CheckPreparation.enabled_resolved_base active) response

/-- 有効な表の解放応答は、イベントに含まれる元と対応先の資源値が同じ定数であることを与える。 -/
theorem active_release_inputs_equal {configuration : Check.BuiltinSource} {v w result}
    (active : CheckPreparation.enabled configuration = true) (related : Value source rows v w)
    (response : configuration.builtins.releaseResponse v result) : v = w := by
  obtain ⟨name,payload,rfl⟩ := active_release_constant active response
  exact related.constant_left.symm

/-- 対応先の解放応答からも、同じ向きの値の対応の両辺が同じ定数と分かる。 -/
theorem active_release_inputs_equal_right {configuration : Check.BuiltinSource} {v w result}
    (active : CheckPreparation.enabled configuration = true) (related : Value source rows v w)
    (response : configuration.builtins.releaseResponse w result) : v = w := by
  obtain ⟨name,payload,rfl⟩ := active_release_constant active response
  exact related.constant_right


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_release {q r value targetValue resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .ret value) (second : r.view = .ret targetValue)
    (returned : Value source rows value targetValue)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_Release first response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  have valueAvoid := avoid.1.view
  rw [first] at valueAvoid
  exact ⟨_,.E_Release second response,.run (.pure (.ret returned)) continuation store,
    ret_avoid valueAvoid restAvoid avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_release_error {q r value targetValue resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .ret value) (second : r.view = .ret targetValue)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_RelErr first response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  exact ⟨_,.E_RelErr second response,.error continuation store,restAvoid,avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_escape_release {q r value targetValue resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .escape value) (second : r.view = .escape targetValue)
    (returned : Value source rows value targetValue)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_EscRel first response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  have valueAvoid := avoid.1.view
  rw [first] at valueAvoid
  exact ⟨_,.E_EscRel second response,.run (.pure (.escape returned)) continuation store,
    ret_avoid valueAvoid restAvoid avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_escape_release_error {q r value targetValue resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .escape value) (second : r.view = .escape targetValue)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_EscRelErr first response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  exact ⟨_,.E_EscRelErr second response,.error continuation store,restAvoid,avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_error_release {errors resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.error errors (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.error errors (.release resource :: k) μ) (.error errors (.release targetResource :: l) ν) (.E_ErrRel response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  exact ⟨_,.E_ErrRel response,.error continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_error_release_error {errors resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.error errors (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.error errors (.release resource :: k) μ) (.error errors (.release targetResource :: l) ν) (.E_ErrRelErr response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  exact ⟨_,.E_ErrRelErr response,.error continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_exit_release {code errors resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.exit code errors (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.exit code errors (.release resource :: k) μ) (.exit code errors (.release targetResource :: l) ν) (.E_ExitRel response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  exact ⟨_,.E_ExitRel response,.exit continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_exit_release_error {code errors resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : config.builtins.releaseResponse resource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.exit code errors (.release resource :: k) μ)) :
    ResponseSynchronizedAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.exit code errors (.release resource :: k) μ) (.exit code errors (.release targetResource :: l) ν) (.E_ExitRelErr response) := by
  have same := active_release_inputs_equal (CheckPreparation.enabled_resolved_base active) released response
  subst targetResource
  exact ⟨_,.E_ExitRelErr response,.exit continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_release_backward {q r value targetValue resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .ret value) (second : r.view = .ret targetValue)
    (returned : Value source rows value targetValue)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_Release second response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  have valueAvoid := avoid.1.view
  rw [first] at valueAvoid
  exact ⟨_,.E_Release first response,.run (.pure (.ret returned)) continuation store,
    ret_avoid valueAvoid restAvoid avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_release_error_backward {q r value targetValue resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .ret value) (second : r.view = .ret targetValue)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_RelErr second response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  exact ⟨_,.E_RelErr first response,.error continuation store,restAvoid,avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_escape_release_backward {q r value targetValue resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .escape value) (second : r.view = .escape targetValue)
    (returned : Value source rows value targetValue)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_EscRel second response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  have valueAvoid := avoid.1.view
  rw [first] at valueAvoid
  exact ⟨_,.E_EscRel first response,.run (.pure (.escape returned)) continuation store,
    ret_avoid valueAvoid restAvoid avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_escape_release_error_backward {q r value targetValue resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (first : q.view = .escape value) (second : r.view = .escape targetValue)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.run q (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.run q (.release resource :: k) μ) (.run r (.release targetResource :: l) ν) (.E_EscRelErr second response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  have restAvoid := (ContAvoid.cons.mp avoid.2.1).2
  exact ⟨_,.E_EscRelErr first response,.error continuation store,restAvoid,avoid.2.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_error_release_backward {errors resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.error errors (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.error errors (.release resource :: k) μ) (.error errors (.release targetResource :: l) ν) (.E_ErrRel response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  exact ⟨_,.E_ErrRel response,.error continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_error_release_error_backward {errors resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.error errors (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.error errors (.release resource :: k) μ) (.error errors (.release targetResource :: l) ν) (.E_ErrRelErr response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  exact ⟨_,.E_ErrRelErr response,.error continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_exit_release_backward {code errors resource targetResource k l μ ν}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource none)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.exit code errors (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.exit code errors (.release resource :: k) μ) (.exit code errors (.release targetResource :: l) ν) (.E_ExitRel response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  exact ⟨_,.E_ExitRel response,.exit continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩


/-- 解放の同じ資源値と結果をイベントへ記録し、実際の到達先の対応と元の禁止名不在を保つ。 -/
theorem response_exit_release_error_backward {code errors resource targetResource k l μ ν message}
    (active : CheckPreparation.enabled (.resolved config rows) = true)
    (released : Value source rows resource targetResource)
    (response : (responseTable config rows).releaseResponse targetResource (some message))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (avoid : NoGeneratedKeys rows (.exit code errors (.release resource :: k) μ)) :
    ResponseBackwardAt source rows (rows.map Prod.fst) P Q config.builtins (responseTable config rows) σ
      (.exit code errors (.release resource :: k) μ) (.exit code errors (.release targetResource :: l) ν) (.E_ExitRelErr response) := by
  have same := active_release_inputs_equal_right active released response
  subst targetResource
  exact ⟨_,.E_ExitRelErr response,.exit continuation store,(ContAvoid.cons.mp avoid.1).2,avoid.2⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
