import Benitoite.Release.Refinement.StandardModelCompletion
import Benitoite.Release.Refinement.ProgramExtensionTransport
import Benitoite.Release.Refinement.StandardModelWellFormed

/-! # 合成済みの名前の行を利用者のプログラムと完成した表へ

利用者のプログラム P は合成プログラムを含み（`StandardModel.Includes`）、data 型の宣言の一覧 T を持つ。T で型の制約
（等値・鍵）と鍵の符号化を作った合成表と、合成済みの名前で一致する任意の表 B について、合成表の行の証明を
述べる（設計書 07-04「01-12 との対応」）。行の証明は、行の名前の lookup・δ・IO 応答と、P の共有の宣言（Option・
Result・Pair・要求・丸め方式・写像の鍵の宣言表と変性の検査）だけを読む（`StandardModel.RowEnv`）。共有の宣言は、
合成プログラムの宣言から旧宣言の移送の関係で P へ移す。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open StandardKeyTyping StandardCollections

/-! ## 署名は許容だけが制約の判定に依る -/

set_option maxHeartbeats 1600000 in
/-- 制約の判定で作った署名は、許容の欄を除いて合成表の署名と同じである。 -/
theorem Primitive.signatureWith_eq (sat : List TParam → Ty → TParam → Prop) (row : Primitive) :
    row.signatureWith sat = {row.signature with admits := (row.signatureWith sat).admits} := by
  cases row <;> rfl

/-- 制約を読む行はすべて種類が pure なので、pure でない行の署名は制約の判定によらない。 -/
theorem Primitive.signatureWith_of_not_pure (sat : List TParam → Ty → TParam → Prop) {row : Primitive}
    (h : row.signature.kind ≠ .pure) : row.signatureWith sat = row.signature := by
  cases row <;> first | rfl | (exfalso; exact h rfl)

theorem _root_.Benitoite.Release.Refinement.PrimSig.Scoped.with_admits {P : Program} {s : PrimSig} (f : List TParam → List Ty → Prop)
    (h : PrimSig.Scoped P s) : PrimSig.Scoped P {s with admits := f} :=
  ⟨h.names, h.source, h.kinds, h.sorted, h.declared, h.operation⟩

theorem _root_.Benitoite.Release.Refinement.PrimSig.Scoped.ofExtends {P P' : Program} (h : P.Extends P') {s : PrimSig} (hs : PrimSig.Scoped P s) :
    PrimSig.Scoped P' s :=
  ⟨hs.names, hs.source, hs.kinds.ofExtends h, hs.sorted, hs.declared.ofExtends h, hs.operation⟩

/-! ## 共有の宣言の移送 -/

section
variable {Q P : Program} (h : Q.Extends P)
include h

theorem ListOptionDeclarations.ofExtends (hd : StandardActualListBodies.ListOptionDeclarations Q) :
    StandardActualListBodies.ListOptionDeclarations P :=
  ⟨h.cons _ _ hd.none_decl, h.cons _ _ hd.some_decl, h.dataArity hd.arity,
    fun c cd hc he => hd.only c cd (h.consData hc he (Or.inl hd.arity.1)) he⟩

theorem HasDeclarations.ofExtends {ds} (hd : ScopeDeclarations.HasDeclarations Q ds) :
    ScopeDeclarations.HasDeclarations P ds :=
  fun d hm => ⟨h.dataArity (hd d hm).1, fun c hc => h.cons _ _ ((hd d hm).2 c hc)⟩

theorem DecimalDeclarations.ofExtends (hm : Q.HasData "RoundingMode") (hd : StandardDecimalResponse.Declarations Q) :
    StandardDecimalResponse.Declarations P :=
  ⟨h.cons _ _ hd.some_decl, h.cons _ _ hd.none_decl, h.dataArity hd.arity,
    fun c cd hc he => hd.modes c cd (h.consData hc he hm) he⟩

theorem MapSetDeclarations.ofExtends (hd : StandardCollections.MapSetDeclarations Q) :
    StandardCollections.MapSetDeclarations P :=
  ⟨h.cons _ _ hd.pair, h.dataArity hd.pairArity,
    fun c cd hc he => hd.pairOnly c cd (h.consData hc he (Or.inl hd.pairArity.1)) he,
    h.cons _ _ hd.someDecl, h.cons _ _ hd.noneDecl, h.dataArity hd.optionArity⟩

end

/-! ## 合成済みの名前で一致する表の行の環境 -/

/-- 合成済みの名前で、宣言の一覧で作った合成表と一致する表の行の環境。 -/
@[instance_reducible]
def RowEnv.ofAgree {L : NameLists} (hL : L.WF) {externals} {P : Program} (T : DataTable P) {B : Builtins}
    (hI : Includes externals P) (agree : Builtins.ComposedAgree L T.base B) : RowEnv P B where
  sig row := by
    have hm : row.name ∈ L.composed := hL.composedAll _ (by simp [baseBuiltins, signature, primitive_lookup])
    rw [agree.sig _ hm, agree.sat]
    show (primitive row.name).map _ = _
    rw [primitive_lookup]
    rfl
  valKind := agree.valKind
  valContent := agree.valContent
  admitsR := agree.admitsR
  delta row hk := by
    have hm : row.name ∈ L.composed := hL.composedAll _ (by simp [baseBuiltins, signature, primitive_lookup])
    rw [agree.delta _ hm]
    show (primitive row.name).elim _ _ = _
    rw [primitive_lookup]
    exact congrFun (Primitive.deltaWith_of_not_readsKeys hk _) row.name
  io row ts es ws out obs := by
    have hm : row.name ∈ L.composed := hL.composedAll _ (by simp [baseBuiltins, signature, primitive_lookup])
    rw [agree.ioResponse _ hm]
    show (∃ r, primitive row.name = some r ∧ r.provider.ioResponse row.name ts es ws out obs) ↔ _
    rw [primitive_lookup]
    simp
  check := {
    file := ScopeDeclarations.HasHttp.file (HasDeclarations.ofExtends hI.extends_ (http_declarations externals))
    error := hI.extends_.cons _ _ (check_declarations externals).error
    arity := hI.extends_.dataArity (check_declarations externals).arity }
  options := ListOptionDeclarations.ofExtends hI.extends_ (option_declarations externals)
  http := HasDeclarations.ofExtends hI.extends_ (http_declarations externals)
  rounding := DecimalDeclarations.ofExtends hI.extends_
    (Or.inl ⟨"RoundingMode.TowardZero", ⟨"RoundingMode", 0, []⟩, rfl, rfl⟩) (rounding_declarations externals)
  mapSet := MapSetDeclarations.ofExtends hI.extends_ (map_set_declarations externals)
  keys := T.table agree.sat
  valid := T.valid
  keyDelta row := by
    have hm : row.name ∈ L.composed := hL.composedAll _ (by simp [baseBuiltins, signature, primitive_lookup])
    rw [agree.delta _ hm]
    show (primitive row.name).elim _ _ = _
    rw [primitive_lookup]
    rfl

/-- 合成済みの名前の署名は、台帳の行の、宣言の一覧の制約で作った署名である。 -/
theorem composed_lookup {L : NameLists} {P : Program} (T : DataTable P) {B : Builtins}
    (agree : Builtins.ComposedAgree L T.base B) {b : PrimName} {sg : PrimSig} (hb : b ∈ L.composed)
    (hs : B.sig b = some sg) : ∃ row : Primitive, b = row.name ∧ sg = row.signatureWith T.sat := by
  rw [agree.sig b hb] at hs
  change (primitive b).map _ = some sg at hs
  obtain ⟨row, hr, rfl⟩ := Option.map_eq_some_iff.mp hs
  exact ⟨row, primitive_name hr, rfl⟩

/-- 宣言の一覧の制約の判定は、その要約の表による制約の骨格の判定である。 -/
theorem DataTable.sat_eq {P : Program} (T : DataTable P) :
    T.sat = ModelConstraints.sat (Benitoite.Release.dataSummaries (T.declarations.map DataDecl.summaryInput)) := rfl

/-! ## 合成済みの名前の16欄 -/

private theorem shape_ok {L : NameLists} (hL : L.WF) {P : Program} (T : DataTable P) {B : Builtins}
    (agree : Builtins.ComposedAgree L T.base B) {b : PrimName} {s : PrimSig}
    (h : (builtins (program [])).ShapeOk b s) : B.ShapeOk b s := by
  obtain ⟨l, bs, ho, hn, he, hb, hm⟩ := h
  have hl : l ∈ L.composedEffects := hL.effects l (by
    change (effects l).isSome = true
    change effects l = some bs at he
    simp [he])
  obtain ⟨bs', he', hb'⟩ := agree.effects l bs b he hb
  refine ⟨l, bs', ho, hn, he', hb', ?_⟩
  rw [agree.effKind l hl, agree.valKind]
  exact hm

/-- 合成済みの名前の行の条件。 -/
theorem composed_rows (L : NameLists) (externals : List (ExternalKey × ExternalDecl)) :
    ComposedRowsStatement L externals := by
  intro hL P T B hI agree
  haveI env : RowEnv P B := RowEnv.ofAgree hL T hI agree
  have hsat : B.sat = ModelConstraints.sat
      (Benitoite.Release.dataSummaries (T.declarations.map DataDecl.summaryInput)) := agree.sat
  have base := core (externals := [])
  refine {
    admits_rename := ?_, admits_values := ?_, admits_renameTypes := ?_, admits_subst := ?_,
    delta_typed := ?_, io_typed := ?_, io_kind := ?_, io_exists := ?_, sig_scoped := ?_,
    admits_sat := ?_, pathBases_shape := ?_, io_op := ?_, opEff_io := ?_, store_shape := ?_,
    store_admits := ?_, io_target := ?_ }
  · intro b sg C Γ Δ ts ξ hb hs _ _ _ h
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    exact admits_rename_with _ row ξ h
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hb hs _ _ h
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    exact admits_values_with _ row ν h
  · intro b sg C C' Γ Δ ts ρ hb hs ren _ _ h
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    exact admits_renameTypes_with _ row ren h
  · intro b sg C0 C1 ts ts' es' hb hs h wf images count
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    exact admits_subst_with _ row hsat h wf images count
  · intro Ψ b sg ts es rs ws a e hb hs kind args
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind = .pure := by rw [Primitive.signatureWith_eq] at kind; exact kind
    have hs' : B.sig row.name = some (row.signatureWith B.sat) := RowLookup.sig row
    rw [agree.sat] at hs'
    have hrow : PureRowOn P B row.name := by
      rcases pure_classes row hk with h | h | h | h
      · exact numeric_rows_of row h
      · exact operator_rows_of row h
      · exact collection_rows_of row h
      · exact scope_rows_of row h
    exact hrow Ψ _ ts es rs ws a e hs args
  · intro Ψ b sg ts es rs ws a e out obs hb hs kind args response
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind = .io ∨ row.signature.kind = .exit := by
      rw [Primitive.signatureWith_eq] at kind; exact kind
    obtain ⟨typed, adequate, _⟩ := (io_rows_of row (io_classes row hk) Ψ _ ts es rs ws a e hs args).1 out obs response
    exact ⟨typed, adequate⟩
  · intro Ψ b sg ts es rs ws a e out obs hb hs args response
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have io : row.io = true := by
      have hr := (RowLookup.io row ts es ws out obs).mp response
      exact response_classes hr
    exact ((io_rows_of row io Ψ _ ts es rs ws a e hs args).1 out obs response).2.2.1
  · intro Ψ b sg ts es rs ws a e hb hs kind args
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind = .io ∨ row.signature.kind = .exit := by
      rw [Primitive.signatureWith_eq] at kind; exact kind
    exact (io_rows_of row (io_classes row hk) Ψ _ ts es rs ws a e hs args).2
  · intro b s hb hs
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have h0 := sig_scoped externals row.name row.signature (row_lookup _ row)
    rw [Primitive.signatureWith_eq]
    exact (h0.ofExtends hI.extends_).with_admits _
  · intro b s C ts hb hs h
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    exact admits_sat_with _ row hsat h
  · intro b s hb hs kind
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind ≠ .pure := by rw [Primitive.signatureWith_eq] at kind; rw [kind]; decide
    rw [Primitive.signatureWith_of_not_pure _ hk] at kind ⊢
    have h0 := base.pathBases_shape row.name row.signature (row_lookup _ row) kind
    obtain ⟨bs, hbs, hm⟩ := h0.membership
    have hbs' : T.base.effects processEnvironmentEff = some bs := hbs
    obtain ⟨bs', he', hb'⟩ := agree.effects _ _ _ hbs' hm
    exact ⟨h0.types, h0.rows, h0.ranges, h0.arguments, h0.result, h0.effect, h0.operation, bs', he', hb'⟩
  · intro b s hb hs kind
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind ≠ .pure := by
      rw [Primitive.signatureWith_eq] at kind; rcases kind with h | h <;> rw [h] <;> decide
    rw [Primitive.signatureWith_of_not_pure _ hk] at kind ⊢
    exact shape_ok hL T agree (base.io_op row.name row.signature (row_lookup _ row) kind)
  · intro b s l hb hs op
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    rw [Primitive.signatureWith_eq] at op ⊢
    exact base.opEff_io row.name row.signature l (row_lookup _ row) op
  · intro b s hb hs kind
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    rw [Primitive.signatureWith_eq] at kind ⊢
    exact base.store_shape row.name row.signature (row_lookup _ row) kind
  · intro b s C ts hb hs pure io exit issue count
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind ≠ .pure := by rw [Primitive.signatureWith_eq] at pure; exact pure
    rw [Primitive.signatureWith_of_not_pure _ hk] at pure io exit issue count ⊢
    exact base.store_admits row.name row.signature C ts (row_lookup _ row) pure io exit issue count
  · intro Ψ b sg ts es rs ws a e out obs hb hs kind args response
    obtain ⟨row, rfl, rfl⟩ := composed_lookup T agree hb hs
    have hk : row.signature.kind = .io ∨ row.signature.kind = .exit := by
      rw [Primitive.signatureWith_eq] at kind; exact kind
    exact ((io_rows_of row (io_classes row hk) Ψ _ ts es rs ws a e hs args).1 out obs response).2.2.2

/-- 合成表の資源の種類の解放の存在。 -/
theorem composed_release (L : NameLists) (externals : List (ExternalKey × ExternalDecl)) :
    ComposedReleaseStatement L externals := by
  intro hL P T B _ agree hrel Ψ v o hb typed _
  have ho : o ∉ L.resources := fun hm => by simp [hL.resources o hm] at hb
  have hk : B.valKind o = none := by
    rw [agree.valKind]
    have : (builtins (program [])).isResource o = true := hb
    have he : o = "File.Handle" := (resource_iff (program []) o).mp this
    subst he
    rfl
  obtain ⟨i, rfl⟩ := ResourceRelease.canonical typed hk
  exact ⟨none, hrel _ _ ⟨o, i, rfl, hb⟩⟩

/-! ## 表全体の欄と信頼条件の組立て -/

theorem DataTable.base_sig {P : Program} (T : DataTable P) (b : PrimName) :
    T.base.sig b = (primitive b).map (Primitive.signatureWith T.sat) := rfl

/-- 完成した表の、表全体の条件。 -/
theorem table_conditions (L : NameLists) (externals : List (ExternalKey × ExternalDecl)) :
    TableConditionsStatement L externals := by
  intro hL P T A _ hc
  have composedSig : ∀ b row, primitive b = some row →
      (complete L T A).sig b = some (row.signatureWith T.sat) := by
    intro b row hr
    have hm : b ∈ L.composed := hL.composedAll b (by simp [baseBuiltins, signature, hr])
    simp [complete, ExternalModel.builtins, completeBase, hm, DataTable.base_sig, hr]
  refine {
    sat_rename := fun C Γ Δ a p ξ _ _ _ h => (ModelConstraints.sat_rename _ _ a p ξ).mpr h
    sat_values := fun Ψ Q C Γ Δ Ξ ν a p _ _ h => (ModelConstraints.sat_values _ _ a p ν).mpr h
    sat_renameTypes := fun C D Γ Δ a p ρ ren _ _ h => ModelConstraints.sat_renameTypes ren h
    sat_subst := fun C0 C1 a p ts es h wf images count => ModelConstraints.sat_subst h wf images count
    external := ExternalModel.external_assumptions P _ _
    sat_unconstrained := fun _ _ => ModelConstraints.sat_unconstrained _ _ _
    effect_ops := ?_
    state_effect := complete_state_effect L T A hc
    ref_get := ?_
    ref_set := ?_ }
  · intro l bs b he hb
    change (match T.base.effects l with
      | some bs => some (bs ++ assumedOps L A l)
      | none => if assumedOps L A l = [] then none else some (assumedOps L A l)) = some bs at he
    have assumed : b ∈ assumedOps L A l → ∃ s, (complete L T A).sig b = some s ∧
        (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧ s.opEff = some l := by
      intro hm
      simp only [assumedOps, List.mem_filter, beq_iff_eq] at hm
      obtain ⟨ha, hs⟩ := hm
      cases hA : A.sig b with
      | none => simp [hA] at hs
      | some s =>
        simp only [hA, Option.bind_some] at hs
        have hnc : b ∉ L.composed := fun hc' => hL.disjoint b hc' ha
        have hsig : (complete L T A).sig b = some s := by
          simp [complete, ExternalModel.builtins, completeBase, hnc, ha, hA]
        exact ⟨s, hsig, hc.rows.opEff_io b s l ha hsig hs, hs⟩
    cases hbe : T.base.effects l with
    | none =>
      rw [hbe] at he
      simp only at he
      split at he
      · cases he
      · cases Option.some.inj he
        exact assumed hb
    | some bs0 =>
      rw [hbe] at he
      cases Option.some.inj he
      rcases List.mem_append.mp hb with hb | hb
      · have hbe' : (builtins (program [])).effects l = some bs0 := hbe
        obtain ⟨s0, hs0, hk, ho⟩ := effect_ops (program []) l bs0 b hbe' hb
        obtain ⟨row, hr, rfl⟩ := Option.map_eq_some_iff.mp (show (primitive b).map Primitive.signature = _ from hs0)
        refine ⟨_, composedSig b row hr, ?_, ?_⟩
        · rw [Primitive.signatureWith_eq]; exact hk
        · rw [Primitive.signatureWith_eq]; exact ho
      · exact assumed hb
  · exact ⟨_, composedSig Primitive.p279.name .p279 (primitive_lookup .p279), rfl⟩
  · exact ⟨_, composedSig Primitive.p280.name .p280 (primitive_lookup .p280), rfl⟩

/-- 完成した表の信頼条件と対象の条件。合成済みの名前は合成表の行の証明から、仮定側の名前は仮定側の表の契約から、
表全体の条件は宣言の一覧の制約と外部宣言から得る。 -/
theorem completion_core (L : NameLists) (externals : List (ExternalKey × ExternalDecl)) :
    CompletionCoreStatement L externals :=
  completion_core_of L externals (composed_rows L externals) (composed_release L externals)
    (table_conditions L externals)

/-! ## 合成プログラムを含む利用者のプログラムの検査 -/

/-- 合成済みの名前で一致する表の、本体の型付けの環境。 -/
@[instance_reducible]
def BodyEnv.ofAgree {L : NameLists} (hL : L.WF) {externals} {P : Program} (T : DataTable P) {B : Builtins}
    (hI : Includes externals P) (agree : Builtins.ComposedAgree L T.base B) : BodyEnv externals P B where
  toRowEnv := RowEnv.ofAgree hL T hI agree
  extends_ := hI.extends_

/-- 合成プログラムを含む利用者のプログラムは、追加した宣言が義務を満たせば、宣言の一覧で作った合成表と合成済みの
名前で一致する表で型付く。合成プログラムの本体は利用者のプログラムの上で直接に型付ける。 -/
theorem included_typed {L : NameLists} (hL : L.WF) {externals} {P : Program} (T : DataTable P) {B : Builtins}
    (hI : Includes externals P) (agree : Builtins.ComposedAgree L T.base B) (hw : P.ExternalWF)
    (hadd : Program.Additions (program externals) P B) : P.WellTyped B := by
  haveI := BodyEnv.ofAgree hL T hI agree
  refine ⟨T.valid, hw, fun f d hd => ?_, fun i id hi => ?_⟩
  · cases hp : (program externals).defs f with
    | none => exact (hadd.defs f d hp hd).1
    | some d0 =>
      have := Option.some.inj ((hI.extends_.defs f d0 hp).symm.trans hd)
      subst this
      exact definition_typed_of (externals := externals) f d0 hp
  · exact (hadd.impls i id rfl hi).1

/-- 合成プログラムを含む利用者のプログラムの整形式。 -/
theorem included_wellFormed {externals} {P : Program} {B : Builtins} (hI : Includes externals P)
    (hw : (program externals).ExternalWF) (hadd : Program.Additions (program externals) P B) : P.WellFormed :=
  (program_wellFormed externals hw).compose hI.extends_ (fun _ _ h => by cases h) hadd

/-- 合成プログラムを含む利用者のプログラムの効果の検査。合成プログラムは効果と操作を宣言しない。 -/
theorem included_effectsOk {externals} {P : Program} {B : Builtins} (hI : Includes externals P)
    (hadd : Program.Additions (program externals) P B) : P.EffectsOk B :=
  Program.EffectsOk.compose hI.extends_ (by
    refine ⟨fun l os o h _ => ?_, fun o od h => ?_, fun l os h => ?_⟩ <;>
      nomatch h) hadd

/-! ## 衝突18名の公開名 -/

/-- 衝突18名の公開名が指す精密側の本体。 -/
def collisionBody : String → Option Body
  | "List.filter" => some .b104 | "List.filterFrom" => some .b102 | "List.map" => some .b103
  | "List.mapFrom" => some .b101 | "Map.filter" => some .b109 | "Map.map" => some .b108
  | "NonEmptyList.map" => some .b105 | "Range.checkedLength" => some .b097
  | "Range.indexValue" => some .b099 | "Range.indexValues" => some .b100
  | "Range.lengthMaximum" => some .b096 | "Range.lengthMinimum" => some .b095
  | "Range.lengthValues" => some .b098 | "Range.maximum" => some .b093 | "Range.minimum" => some .b092
  | "Range.value" => some .b094 | "Set.filter" => some .b111 | "Set.map" => some .b110
  | _ => none

/-- 衝突18名それぞれの公開名は、同じ名前の精密側の本体の鍵へ写る。 -/
theorem collisionBody_spec : ∀ n ∈ FunctionNames.collisionNames,
    (collisionBody n).elim False (fun body => body.refined = true ∧ body.name = n) := by
  intro n hn
  simp only [FunctionNames.collisionNames, List.mem_cons, List.not_mem_nil, or_false] at hn
  rcases hn with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl <;> exact ⟨rfl, rfl⟩

/-- 合成プログラムを含むプログラムでは、衝突18名の公開名が指す内部名の lookup は、精密側の本体の定義を返す。 -/
theorem publicTarget_defs {externals} {P : Program} (h : (program externals).Extends P) {n : String}
    (hn : n ∈ FunctionNames.collisionNames) :
    ∃ body, collisionBody n = some body ∧ P.defs (FunctionNames.publicTarget n) = some body.definition := by
  have hs := collisionBody_spec n hn
  cases hb : collisionBody n with
  | none => rw [hb] at hs; exact hs.elim
  | some body =>
  rw [hb] at hs
  obtain ⟨hr, hname⟩ := hs
  refine ⟨body, rfl, ?_⟩
  rw [FunctionNames.publicTarget_collision hn, ← hname, ← hr, ← Body.key_correspondence]
  exact h.defs _ _ (body_lookup externals body)

/-! ## 合成プログラム自身への適用 -/

/-- 合成プログラムは自身を含む。 -/
theorem Includes.refl (externals : List (ExternalKey × ExternalDecl)) : Includes externals (program externals) where
  extends_ := Program.Extends.refl _
  internal _ _ h h' := by simp [h] at h'
  publicCollisions n hn := by
    simp only [FunctionNames.collisionNames, List.mem_cons, List.not_mem_nil, or_false] at hn
    rcases hn with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
      rfl | rfl <;> rfl

/-- 合成表は、合成プログラムの宣言の一覧で作った合成表と合成済みの名前で一致する。 -/
theorem builtins_agree (externals : List (ExternalKey × ExternalDecl)) :
    Builtins.ComposedAgree nameLists (dataTable externals).base (builtins (program externals)) := by
  rw [dataTable_base]
  exact ⟨fun _ _ => rfl, fun _ _ => rfl, fun _ _ => rfl, fun _ bs _ h hb => ⟨bs, h, hb⟩, fun _ _ => rfl,
    fun _ _ => rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- 合成プログラム自身は、追加の宣言の無い拡張である。 -/
theorem additions_refl (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF)
    (B : Builtins) : Program.Additions (program externals) (program externals) B where
  defs _ _ h h' := by simp [h] at h'
  impls _ _ h h' := by simp [h] at h'
  cons _ _ h h' := by simp [h] at h'
  ops _ _ h h' := by simp [h] at h'
  classes _ _ h h' := by simp [h] at h'
  metadata := (program_wellFormed externals hw).metadata
  dataVariance _ _ h h' := by simp [h] at h'
  conVariance _ _ h h' := by simp [h] at h'
  effectOps _ _ _ h h' := by simp [h] at h'
  opEffects _ _ h h' := by simp [h] at h'
  builtinEffects _ _ h h' := by simp [h] at h'

/-- 利用者のプログラムの検査の定理を合成プログラム自身へ当てると、合成プログラムの型付け・整形式・効果の検査を得る。 -/
example (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF) :
    (program externals).WellTyped (builtins (program externals)) ∧ (program externals).WellFormed ∧
      (program externals).EffectsOk (builtins (program externals)) :=
  ⟨included_typed nameLists_wf (dataTable externals) (Includes.refl externals) (builtins_agree externals) hw
      (additions_refl externals hw _),
    included_wellFormed (Includes.refl externals) hw (additions_refl externals hw (builtins (program externals))),
    included_effectsOk (Includes.refl externals) (additions_refl externals hw (builtins (program externals)))⟩

/-- 合成済みの名前の行の条件を合成表自身へ当てる（合成プログラムの宣言の一覧で作った表）。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    Builtins.RowConditions (· ∈ nameLists.composed) (program externals) (builtins (program externals)) :=
  composed_rows nameLists externals nameLists_wf _ (dataTable externals) _ (Includes.refl externals)
    (builtins_agree externals)

end
end Benitoite.Release.Refinement.StandardModel
