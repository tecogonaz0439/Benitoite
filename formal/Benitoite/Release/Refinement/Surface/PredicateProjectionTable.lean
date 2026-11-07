import Benitoite.Release.Refinement.Surface.PredicateProjectionResponse
import Benitoite.Release.Refinement.Surface.PredicateRowsTable
import Benitoite.Release.Refinement.StandardModelComposedRows

/-! # 判定の内部行を加えた標準の表

合成済みの行を保ち、有限の内部行だけを仮定側の表に登録する。内部行の応答と形成の条件は、行の定義から証明する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateProjection.Table
open PredicateRows
noncomputable section

abbrev Rows := List (PrimName × Row)

def RowValid (P : Refinement.Program) : Row → Prop
  | .scalar entry => entry.Valid
  | .projected projection => PredicateProjection.Valid P projection

private theorem admit_length (row : Row) (C : List TParam) (types : List Ty) :
    row.signature.admits C types ↔ types.length = row.signature.tparams.length := by
  cases row
  · simp [Row.signature, Entry.signature, List.length_eq_zero_iff]
  · simp [Row.signature, Projection.signature]

private theorem row_pure (row : Row) : row.signature.kind = .pure := by
  cases row <;> rfl

private theorem row_opEff (row : Row) : row.signature.opEff = none := by
  cases row <;> rfl


def lookup (rows : Rows) (name : PrimName) : Option Row := rows.lookup name

def names (rows : Rows) : StandardModel.NameLists :=
  { StandardModel.nameLists with delta := StandardModel.nameLists.delta ++ rows.map Prod.fst }

/-- 固定したパターンの形成と、既存の区分の名前との非衝突。 -/
def Rows.Valid (P : Refinement.Program) (rows : Rows) : Prop :=
  (∀ name entry, (name, entry) ∈ rows → RowValid P entry) ∧
  ∀ name entry, (name, entry) ∈ rows →
    name ∉ StandardModel.nameLists.composed ∧ name ∉ StandardModel.nameLists.io ∧
      name ∉ StandardModel.nameLists.state ∧ name ∉ StandardModel.nameLists.outside ∧
      name ∉ StandardModel.nameLists.delta

/-- scalar の行の名前と順序を保って、合成用の和へ写す。 -/
def scalarRows (rows : PredicateRows.Rows) : Rows :=
  rows.map (fun (name, entry) => (name, Row.scalar entry))

theorem scalar_valid {P : Refinement.Program} {rows : PredicateRows.Rows}
    (valid : PredicateRows.Rows.Valid rows) : Rows.Valid P (scalarRows rows) := by
  constructor
  · intro name row hm
    obtain ⟨⟨name', entry⟩, he, hh⟩ := List.mem_map.mp hm
    cases hh
    exact valid.1 _ _ he
  · intro name row hm
    obtain ⟨⟨name', entry⟩, he, hh⟩ := List.mem_map.mp hm
    cases hh
    exact valid.2 _ _ he

def assumed (rows : Rows) : StandardModel.AssumedTable where
  sig := fun name => (lookup rows name).map Row.signature
  delta := fun name ts es rs vs => (lookup rows name).bind fun entry => entry.delta ts es rs vs
  ioResponse := fun _ _ _ _ _ _ => False
  isResource := fun _ => false
  releaseResponse := fun _ _ => False
  effKind := fun _ => none

def builtins {P : Refinement.Program} (T : StandardModel.DataTable P) (rows : Rows) : Builtins :=
  StandardModel.complete (names rows) T (assumed rows)

private theorem lookup_mem {rows : Rows} {name : PrimName} {entry : Row}
    (h : lookup rows name = some entry) : (name, entry) ∈ rows := by
  exact ScopeSignatures.lookup_mem h

theorem names_wf {P : Refinement.Program} {rows : Rows} (valid : rows.Valid P) : (names rows).WF := by
  have hw := StandardModel.nameLists_wf
  refine ⟨hw.composedAll, ?_, ?_, hw.ioDisjoint, ?_, hw.effects, hw.resources⟩
  · intro name hm ha
    simp only [names, StandardModel.NameLists.assumed, List.mem_append] at ha
    rcases ha with ((ha | ha) | ha) | ha
    · exact hw.disjoint name hm (by simp [StandardModel.NameLists.assumed, ha])
    · obtain ⟨entry, he, rfl⟩ := List.mem_map.mp ha
      exact (valid.2 _ _ he).1 hm
    · exact hw.disjoint name hm (by simp [StandardModel.NameLists.assumed, ha])
    · exact hw.disjoint name hm (by simp [StandardModel.NameLists.assumed, ha])
  · intro name hm
    simp only [names, List.mem_append] at hm
    rcases hm with hm | hm
    · exact hw.deltaDisjoint name hm
    · obtain ⟨entry, he, rfl⟩ := List.mem_map.mp hm
      exact ⟨(valid.2 _ _ he).2.1, (valid.2 _ _ he).2.2.1⟩
  · intro name hm
    refine ⟨(hw.outside name hm).1, ?_⟩
    intro ha
    simp only [names, StandardModel.NameLists.assumed, List.mem_append] at ha
    rcases ha with ((ha | ha) | ha) | ha
    · exact (hw.outside name hm).2 (by simp [StandardModel.NameLists.assumed, ha])
    · obtain ⟨entry, he, rfl⟩ := List.mem_map.mp ha
      exact (valid.2 _ _ he).2.2.2.1 hm
    · exact (hw.outside name hm).2 (by simp [StandardModel.NameLists.assumed, ha])
    · exact (hw.outside name hm).2 (by simp [StandardModel.NameLists.assumed, ha])

private theorem assumed_member {rows : Rows} {name : PrimName} {entry : Row}
    (h : lookup rows name = some entry) : name ∈ (names rows).assumed := by
  have hm := List.mem_map_of_mem (f := Prod.fst) (lookup_mem h)
  simp only [names, StandardModel.NameLists.assumed, List.mem_append]
  exact Or.inl (Or.inl (Or.inr hm))

/-- 内部名の lookup は、固定した判定の同じ署名で成功する。 -/
theorem lookup_signature {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    (valid : rows.Valid P) {name : PrimName} {entry : Row} (h : lookup rows name = some entry) :
    (builtins T rows).sig name = some entry.signature := by
  have hnc : name ∉ (names rows).composed := (valid.2 _ _ (lookup_mem h)).1
  have hm := assumed_member h
  simp only [builtins, StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase,
    ite_eq_right hnc, ite_eq_left hm, assumed, h, Option.map_some]

private theorem assumed_entry {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    (valid : rows.Valid P) {name : PrimName} {s : PrimSig}
    (hm : name ∈ (names rows).assumed) (hs : (builtins T rows).sig name = some s) :
    ∃ entry, lookup rows name = some entry ∧ s = entry.signature ∧ RowValid P entry := by
  have hnc : name ∉ (names rows).composed := fun h => (names_wf valid).disjoint name h hm
  have he : (lookup rows name).map Row.signature = some s := by
    simpa only [builtins, StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase,
      ite_eq_right hnc, ite_eq_left hm, assumed] using hs
  obtain ⟨entry, hentry, rfl⟩ := Option.map_eq_some_iff.mp he
  exact ⟨entry, hentry, rfl, valid.1 _ _ (lookup_mem hentry)⟩

private theorem internal_delta {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    (valid : rows.Valid P) {name : PrimName} {entry : Row} (h : lookup rows name = some entry) :
    (builtins T rows).delta name = entry.delta := by
  have hnc := (valid.2 _ _ (lookup_mem h)).1
  funext ts es rs vs
  simp [builtins, StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase,
    names, hnc, assumed, h]

private theorem internal_io {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    (valid : rows.Valid P) {name : PrimName} (hm : name ∈ (names rows).assumed) {ts es vs out obs}
    (h : (builtins T rows).ioResponse name ts es vs out obs) : False := by
  have hnc : name ∉ (names rows).composed := fun hc => (names_wf valid).disjoint name hc hm
  simp only [builtins, StandardModel.complete, ExternalModel.builtins, StandardModel.completeBase,
    ite_eq_right hnc, assumed] at h

/-- 完成した表の型制約は、同じ宣言の一覧の要約を読む。 -/
theorem sat_eq {P : Refinement.Program} (T : StandardModel.DataTable P) (rows : Rows) :
    (builtins T rows).sat = T.sat := rfl

/-- 署名の成功は、合成済みの標準行か、登録した内部行のどちらかである。 -/
theorem lookup_cases {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    {name : PrimName} {signature : PrimSig}
    (found : (builtins T rows).sig name = some signature) :
    (∃ row : StandardModel.Primitive, name = row.name ∧ signature = row.signatureWith T.sat) ∨
      (∃ row : Row, lookup rows name = some row ∧ signature = row.signature) := by
  by_cases composed : name ∈ (names rows).composed
  · have hs : (StandardModel.primitive name).map (StandardModel.Primitive.signatureWith T.sat) =
        some signature := by
      simpa only [builtins, StandardModel.complete, ExternalModel.builtins,
        StandardModel.completeBase, ite_eq_left composed,
        StandardModel.DataTable.base, StandardModel.baseBuiltinsFor] using found
    obtain ⟨row, hr, rfl⟩ := Option.map_eq_some_iff.mp hs
    exact Or.inl ⟨row, StandardModel.primitive_name hr, rfl⟩
  · by_cases internal : name ∈ (names rows).assumed
    · have hs : (lookup rows name).map Row.signature = some signature := by
        simpa only [builtins, StandardModel.complete, ExternalModel.builtins,
          StandardModel.completeBase, ite_eq_right composed, ite_eq_left internal, assumed] using found
      obtain ⟨row, hr, rfl⟩ := Option.map_eq_some_iff.mp hs
      exact Or.inr ⟨row, hr, rfl⟩
    · simp only [builtins, StandardModel.complete, ExternalModel.builtins,
        StandardModel.completeBase, ite_eq_right composed, ite_eq_right internal] at found
      cases found

/-- 内部行の全条件は、同じ署名の形成と全入力の応答の型付けから得る。 -/
theorem row_conditions {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    (valid : rows.Valid P) (formed : P.WellFormed) :
    Builtins.RowConditions (· ∈ (names rows).assumed) P (builtins T rows) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro b sg C Γ Δ ts ξ hm hs _ _ _ ha
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    apply (admit_length entry _ _).mpr
    simpa only [List.length_map] using (admit_length entry _ _).mp ha
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hm hs _ _ ha
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    apply (admit_length entry _ _).mpr
    simpa only [List.length_map] using (admit_length entry _ _).mp ha
  · intro b sg C C' Γ Δ ts ρ hm hs _ _ _ ha
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    apply (admit_length entry _ _).mpr
    simpa only [List.length_map] using (admit_length entry _ _).mp ha
  · intro b sg C0 C1 ts ts' es' hm hs ha _ _ _
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    apply (admit_length entry _ _).mpr
    simpa only [List.length_map] using (admit_length entry _ _).mp ha
  · intro Ψ b sg ts es rs ws a e hm hs _ args
    obtain ⟨entry, he, rfl, hv⟩ := assumed_entry T valid hm hs
    have answered : ∃ out, entry.delta ts es rs ws = some out ∧ Outcome.Typed P (builtins T rows) Ψ out a ∧
        AdequateResult ws out ∧ ∀ n, out ≠ .exit n := by
      cases entry with
      | scalar entry => exact PredicateRows.response entry hv args
      | projected projection => exact PredicateProjection.response projection hv formed T.valid args
    obtain ⟨out, hd, ht, ha, hn⟩ := answered
    exact ⟨out, by rw [internal_delta T valid he]; exact hd, hn, ht, ha⟩
  · intro Ψ b sg ts es rs ws a e out obs hm hs _ _ hi
    exact (internal_io T valid hm hi).elim

  · intro Ψ b sg ts es rs ws a e out obs hm hs _ hi
    exact (internal_io T valid hm hi).elim
  · intro Ψ b sg ts es rs ws a e hm hs hk _
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    rcases hk with hk | hk <;> rw [row_pure] at hk <;> cases hk
  · intro b s hm hs
    obtain ⟨entry, _, rfl, hv⟩ := assumed_entry T valid hm hs
    cases entry with
    | scalar entry => exact signature_scoped P entry
    | projected projection => exact hv.signature
  · intro b s C ts hm hs ha
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    have count : ts.length = entry.signature.tparams.length := by
      simpa only [Ty.normTys_eq_map, List.length_map] using (admit_length entry _ _).mp ha
    refine ⟨by simpa only [List.length_map] using count, ?_⟩
    intro i a parameter htype hparam
    cases entry with
    | scalar entry => cases hparam
    | projected projection =>
      have member := List.mem_of_getElem? hparam
      simp only [Row.signature, Projection.signature, List.map_replicate,
        TypeCtx.valueParam, List.mem_replicate] at member
      obtain ⟨_, rfl⟩ := member
      exact ModelConstraints.sat_unconstrained _ _ _
  · intro b s hm hs hk
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    rw [row_pure] at hk
    cases hk
  · intro b s hm hs hk
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    rcases hk with hk | hk <;> rw [row_pure] at hk <;> cases hk
  · intro b s l hm hs hl
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    rw [row_opEff] at hl
    cases hl
  · intro b s hm hs _
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    cases entry <;> trivial
  · intro b s C ts hm hs hk _ _ _ _
    obtain ⟨entry, _, rfl, _⟩ := assumed_entry T valid hm hs
    exact (hk (row_pure entry)).elim
  · intro Ψ b sg ts es rs ws a e out obs hm hs _ _ hi
    exact (internal_io T valid hm hi).elim

/-- 仮定側に登録した内部行も、追加の応答の信頼条件なしに表の契約を満たす。 -/
theorem completion {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Rows}
    (valid : rows.Valid P) (formed : P.WellFormed) : StandardModel.Completion (names rows) T (assumed rows) := by
  refine ⟨?_, ?_, ?_, row_conditions T valid formed, ?_, ?_, ?_, ?_, ?_⟩
  · intro name hs
    obtain ⟨s, hs⟩ := Option.isSome_iff_exists.mp hs
    obtain ⟨entry, he, _⟩ := Option.map_eq_some_iff.mp hs
    exact assumed_member he
  · intro name s hs _
    obtain ⟨entry, _, rfl⟩ := Option.map_eq_some_iff.mp hs
    exact row_pure entry
  · intro name s hs hm
    obtain ⟨entry, he, rfl⟩ := Option.map_eq_some_iff.mp hs
    have fresh := (valid.2 _ _ (lookup_mem he)).2
    exact (hm.elim fresh.1 fresh.2.1).elim
  · intro Ψ v o ho _ hr
    change (if o ∈ (names rows).resources then false else T.base.isResource o) = true at hr
    simp [ho] at hr
  · intro o h; cases h
  · intros; rfl
  · intro name s hs
    obtain ⟨entry, _, rfl⟩ := Option.map_eq_some_iff.mp hs
    rw [row_opEff]
    intro h; cases h
  · intro Ψ v o r _ _ h; exact h.elim

/-- 合成済みの標準行と内部行は、同じ完成した表の Core と対象の条件を満たす。 -/
theorem core {externals : List (ExternalKey × ExternalDecl)} {P : Refinement.Program}
    (T : StandardModel.DataTable P) (included : StandardModel.Includes externals P) {rows : Rows}
    (valid : rows.Valid P) (formed : P.WellFormed) :
    (builtins T rows).CoreAssumptions P ∧ (builtins T rows).TargetAgreement P :=
  StandardModel.completion_core (names rows) externals (names_wf valid) P T
    (assumed rows) included (completion T valid formed)

end
end Benitoite.Release.Refinement.Surface.PredicateProjection.Table
