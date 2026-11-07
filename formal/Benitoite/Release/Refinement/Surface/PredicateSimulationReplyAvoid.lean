import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses
import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariants

/-! # 固定した応答の構成で内部名を作らない性質 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

private theorem values_names {keys values} : NamesAvoid keys (valuesNames values) ↔ ValuesAvoid keys values := by
  induction values with
  | nil => simp [NamesAvoid, ValuesAvoid, valuesNames]
  | cons value rest ih =>
    change NamesAvoid keys (valueNames value ++ valuesNames rest) ↔ _
    constructor
    · intro h v member
      rcases List.mem_cons.mp member with rfl | member
      · exact fun name present => h name (List.mem_append_left _ present)
      · exact ih.mp (fun name present => h name (List.mem_append_right _ present)) v member
    · intro h name member
      rcases List.mem_append.mp member with member | member
      · exact h value List.mem_cons_self name member
      · exact ih.mpr (fun v present => h v (List.mem_cons_of_mem _ present)) name member

theorem ValueAvoid.bytes {keys} (bytes : List Nat) : ValueAvoid keys (.bytesV bytes) := by
  intro name member
  cases member

theorem ValueAvoid.handle {keys} (handle : ExternalHandle) (types : List Ty) :
    ValueAvoid keys (.externalHandle handle types) := by
  intro name member
  cases member

theorem ValueAvoid.list {keys values} (h : ValuesAvoid keys values) : ValueAvoid keys (.list values) :=
  values_names.mpr h

theorem ValueAvoid.list_inv {keys values} (h : ValueAvoid keys (.list values)) : ValuesAvoid keys values :=
  values_names.mp h

theorem ValueAvoid.con {keys values} (h : ValuesAvoid keys values) (constructor : ConName) (types : List Ty) :
    ValueAvoid keys (.con constructor types values) := values_names.mpr h

theorem ValueAvoid.con_inv {keys constructor types values} (h : ValueAvoid keys (.con constructor types values)) :
    ValuesAvoid keys values := values_names.mp h

theorem ValueAvoid.map {keys left right} (h : ValuesAvoid keys left) (g : ValuesAvoid keys right) :
    ValueAvoid keys (.mapV left right) := by
  intro name member
  rcases List.mem_append.mp member with member | member
  · exact values_names.mpr h name member
  · exact values_names.mpr g name member

theorem ValueAvoid.map_inv {keys left right} (h : ValueAvoid keys (.mapV left right)) :
    ValuesAvoid keys left ∧ ValuesAvoid keys right := by
  exact ⟨values_names.mp (fun name member => h name (List.mem_append_left _ member)),
    values_names.mp (fun name member => h name (List.mem_append_right _ member))⟩

theorem ValueAvoid.set {keys values} (h : ValuesAvoid keys values) : ValueAvoid keys (.setV values) :=
  values_names.mpr h

theorem ValueAvoid.set_inv {keys values} (h : ValueAvoid keys (.setV values)) : ValuesAvoid keys values :=
  values_names.mp h

theorem ValuesAvoid.reverse {keys values} (h : ValuesAvoid keys values) : ValuesAvoid keys values.reverse :=
  fun value member => h value (List.mem_reverse.mp member)

theorem ValuesAvoid.take {keys values} (h : ValuesAvoid keys values) (count : Nat) :
    ValuesAvoid keys (values.take count) :=
  fun value member => h value (List.mem_of_mem_take member)

theorem ValuesAvoid.drop {keys values} (h : ValuesAvoid keys values) (count : Nat) :
    ValuesAvoid keys (values.drop count) :=
  fun value member => h value (List.mem_of_mem_drop member)

theorem ValuesAvoid.getElem? {keys values value} {index : Nat} (h : ValuesAvoid keys values)
    (found : values[index]? = some value) : ValueAvoid keys value :=
  h value (List.mem_of_getElem? found)

theorem public_predicate_noMint {keys name ts es rs values} (api : PredicateResponse.API) :
    OptionalOutcomeAvoid keys (api.delta name ts es rs values) := by
  unfold PredicateResponse.API.delta
  split
  · exact ValueAvoid.constant _ _
  · trivial

theorem equality_noMint {keys a b equal} :
    OutcomeAvoid keys (StandardStructuralEqualityResponse.reply equal a b) := by
  unfold StandardStructuralEqualityResponse.reply
  split
  · exact ValueAvoid.constant _ _
  · trivial

theorem check_run_noMint {keys value} (avoid : ValueAvoid keys value)
    (render : Ty → String) (input output : Ty) : OutcomeAvoid keys (RefinementCheck.run render input output value) := by
  unfold RefinementCheck.run
  split
  · exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨avoid, ValuesAvoid.nil _⟩) _ _
  · intro name member
    cases member

/-- 有限な純粋応答の符号化は、型と定数・有限列だけを使い、組込み名を作らない。 -/
theorem pure_encode_noMint {keys} (kind : StandardPureResults.Kind) (value : kind.Payload) :
    ValueAvoid keys (kind.encode value) := by
  induction kind with
  | list element ih =>
    apply ValueAvoid.list
    intro encoded member
    obtain ⟨raw, _, rfl⟩ := List.mem_map.mp member
    exact ih raw
  | option element ih =>
    cases value with
    | none => exact ValueAvoid.con (ValuesAvoid.nil _) _ _
    | some raw => exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨ih raw, ValuesAvoid.nil _⟩) _ _
  | bytes => exact ValueAvoid.bytes _
  | _ => exact ValueAvoid.constant _ _

theorem pure_reply_noMint {keys} (kind : StandardPureResults.Kind) (result : Except String kind.Payload) :
    OutcomeAvoid keys (StandardPureResults.reply kind result) := by
  cases result with
  | error _ => trivial
  | ok value => exact pure_encode_noMint kind value

theorem string_ordinary_noMint {keys api name ts es rs values} :
    OptionalOutcomeAvoid keys (StandardStringOrdinaryResponse.API.delta api name ts es rs values) := by
  unfold StandardStringOrdinaryResponse.API.delta
  split
  · exact pure_reply_noMint _ _
  · trivial

theorem bytes_ordinary_noMint {keys api name ts es rs values} :
    OptionalOutcomeAvoid keys (StandardBytesOrdinaryResponse.API.delta api name ts es rs values) := by
  unfold StandardBytesOrdinaryResponse.API.delta
  split
  · exact pure_reply_noMint _ _
  · trivial

theorem numeric_remaining_noMint {keys api name ts es rs values} :
    OptionalOutcomeAvoid keys (StandardNumericRemainingResponse.API.delta api name ts es rs values) := by
  unfold StandardNumericRemainingResponse.API.delta
  split
  · exact pure_reply_noMint _ _
  · trivial

theorem string_table_noMint {keys base name ts es rs values} : OptionalOutcomeAvoid keys
    ((StandardStringOrdinaryResponse.table base).delta name ts es rs values) := by
  change OptionalOutcomeAvoid keys ((StandardStringOrdinaryResponse.dispatch name).bind _)
  cases StandardStringOrdinaryResponse.dispatch name with
  | none => trivial
  | some api => exact string_ordinary_noMint

theorem bytes_table_noMint {keys base name ts es rs values} : OptionalOutcomeAvoid keys
    ((StandardBytesOrdinaryResponse.table base).delta name ts es rs values) := by
  change OptionalOutcomeAvoid keys ((StandardBytesOrdinaryResponse.dispatch name).bind _)
  cases StandardBytesOrdinaryResponse.dispatch name with
  | none => trivial
  | some api => exact bytes_ordinary_noMint

theorem numeric_table_noMint {keys base name ts es rs values} : OptionalOutcomeAvoid keys
    ((StandardNumericRemainingResponse.table base).delta name ts es rs values) := by
  change OptionalOutcomeAvoid keys ((StandardNumericRemainingResponse.dispatch name).bind _)
  cases StandardNumericRemainingResponse.dispatch name with
  | none => trivial
  | some api => exact numeric_remaining_noMint

mutual
  private theorem carrier_names_empty {P B Ψ value a} (typed : ExternalCarrier P B Ψ value a) :
      valueNames value = [] := by
    match typed with
    | .scalar value =>
      obtain ⟨constant,rfl,_,_⟩ := value.canonical_scalar rfl
      rfl
    | .bytes value =>
      obtain ⟨bytes,rfl⟩ := value.canonical_bytes rfl
      rfl
    | .handle value =>
      obtain ⟨handle,types,rfl⟩ := value.canonical_external rfl
      rfl
    | .list values _ => exact carrier_each_names_empty values
    | .map keys values .. =>
      simp only [valueNames, carrier_each_names_empty keys, carrier_each_names_empty values, List.nil_append]
    | .set values .. => exact carrier_each_names_empty values
    | .data _ _ _ _ values _ => exact carrier_fields_names_empty values
    | .refined value _ => exact carrier_names_empty value
  private theorem carrier_each_names_empty {P B Ψ values a} (typed : ExternalCarrierEach P B Ψ values a) :
      valuesNames values = [] := by
    match typed with
    | .nil => rfl
    | .cons value rest =>
      simp only [valuesNames, carrier_names_empty value, carrier_each_names_empty rest, List.nil_append]
  private theorem carrier_fields_names_empty {P B Ψ values types} (typed : ExternalCarrierFields P B Ψ values types) :
      valuesNames values = [] := by
    match typed with
    | .nil => rfl
    | .cons value rest =>
      simp only [valuesNames, carrier_names_empty value, carrier_fields_names_empty rest, List.nil_append]
end

/-- 外部の生の結果のcarrierは診断値を含まず、どの禁止キーも新しく作らない。 -/
theorem external_outcome_noMint {keys P B Ψ out a} (typed : Outcome.Carrier P B Ψ out a) :
    OutcomeAvoid keys out := by
  cases out with
  | val value =>
    intro name member
    rw [carrier_names_empty typed.1] at member
    cases member
  | err _ | exit _ => trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
