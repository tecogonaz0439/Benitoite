import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.PredicateGeneratedNames

/-! # プログラムの実入口での判定の呼出しの解決

全定義と全実装メソッドの元の本体から内部行を収集し、同じ表で本体を解決する。
独自の表は公開名の意味を保証しないため、その表の呼出しは保つ。
-/
namespace Benitoite.Release.Refinement.Surface.CheckPreparation
noncomputable section
open PredicateProjection

/-- 公開の標準名の意味が、構成データから定まる表。 -/
def enabled : Check.BuiltinSource → Bool
  | .standard _ | .predicates _ _ => true
  | .resolved base rows => enabled base && rows.all (fun row => row.1.startsWith "%Predicate.")
  | .custom _ | .unrestrictedRanges _ => false

theorem enabled_resolved_base {base rows} (active : enabled (.resolved base rows) = true) :
    enabled base = true := (Bool.and_eq_true_iff.mp active).1

private theorem api_no_prefix (api : PredicateResponse.API) :
    api.name.startsWith "%Predicate." = false := by
  cases api with
  | floating width test => cases width <;> cases test <;> cbv
  | _ => cbv

/-- 接頭辞を持つ内部行の表は、公開の判定の名前を登録しない。 -/
theorem prefixed_public_lookup_none {rows : Table.Rows}
    (prefixed : rows.all (fun row => row.1.startsWith "%Predicate.") = true)
    (api : PredicateResponse.API) : rows.lookup api.name = none := by
  cases found : rows.lookup api.name with
  | none => rfl
  | some row =>
    have member := ScopeSignatures.lookup_mem found
    have hasPrefix := List.all_eq_true.mp prefixed (api.name, row) member
    rw [api_no_prefix] at hasPrefix
    cases hasPrefix

theorem enabled_resolved_public {base rows} (active : enabled (.resolved base rows) = true)
    (api : PredicateResponse.API) : rows.lookup api.name = none :=
  prefixed_public_lookup_none (Bool.and_eq_true_iff.mp active).2 api

/-- 自動生成した行を重ねても、公開の標準名の解決を有効に保つ。 -/
theorem enabled_generated {base program sources forbidden} (active : enabled base = true) :
    enabled (.resolved base (PredicateRowCollection.collectAvoid program sources forbidden)) = true := by
  apply Bool.and_eq_true_iff.mpr
  refine ⟨active, List.all_eq_true.mpr ?_⟩
  intro pair member
  exact PredicateRowCollection.collectAvoid_prefix member

/-- 入力の有限な名前の一覧にある、全定義と全実装メソッドの本体。 -/
def sources (q : Check.Input) (p : Program) : List Expr :=
  (q.defs.flatMap fun name => match p.defs name with
    | none => [] | some d => Identity.preorderBlock d.body) ++
  (q.impls.flatMap fun name => match p.impls name with
    | none => [] | some id => q.methods.flatMap fun method => match id.methods method with
      | none => [] | some body => Identity.preorderBlock body)

/-- 同じ収集表によって、全定義と実装メソッドの本体を解決する。宣言は保つ。 -/
def resolveProgram (rows : Table.Rows) (p : Program) : Program :=
  { p with
    defs := fun name => (p.defs name).map fun d =>
      { d with body := PredicateProjectionCalls.resolveBlock rows p d.body }
    impls := fun name => (p.impls name).map fun id =>
      { id with methods := fun method => (id.methods method).map fun body =>
        PredicateProjectionCalls.resolveBlock rows p body } }

/-- 内部行の許容は型引数の個数だけを検査し、公開行の許容判定を保つ。 -/
def input (q : Check.Input) (rows : Table.Rows) : Check.Input :=
  { q with
    builtinSource := .resolved q.builtinSource rows
    admitsDec := fun name C types => match rows.lookup name with
      | some row => decide (types.length = row.signature.tparams.length)
      | none => q.admitsDec name C types }

theorem row_support (atoms : List Atom) (row : Row) :
    CheckArguments.SignatureSupport atoms row.signature.params row.signature.ret
      row.signature.eff row.signature.tel := by
  cases row with
  | scalar entry =>
    cases entry <;> try (rename_i w test; cases w <;> cases test)
    all_goals simp [CheckArguments.SignatureSupport, Row.signature, PredicateRows.Entry.signature,
      PredicateRows.Entry.input, PredicateRows.Entry.result, PrimSig.tel, signatureTel,
      Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty]
  | projected projection =>
    have types : Ty.SupportList (· ∈ atoms) (List.map Ty.tvar (List.range projection.ntys)) := by
      apply Ty.SupportList.iff.mpr
      intro a ha
      obtain ⟨i, hi, rfl⟩ := List.mem_map.mp ha
      trivial
    simpa [CheckArguments.SignatureSupport, Row.signature, Projection.signature,
      Projection.input, Projection.result, PredicateRows.Entry.result,
      PrimSig.tel, signatureTel, Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty] using
      (show (Ty.SupportList (· ∈ atoms) (List.map Ty.tvar (List.range projection.ntys))) ∧
        Ty.SupportList (· ∈ atoms) (List.map Ty.tvar (List.range projection.ntys)) from ⟨types, types⟩)

/-- 内部行の署名の支持と許容は定義から構成でき、入力に新しい信頼条件を足さない。 -/
theorem input_sound {q : Check.Input} (hq : q.Sound) (rows : Table.Rows) : (input q rows).Sound := by
  refine ⟨hq.formation, ?_, hq.sat, ?_, hq.ranges, hq.operators⟩
  · refine ⟨hq.tables.dictionaries, hq.tables.funs, ?_, hq.tables.ops,
      hq.tables.methods, hq.tables.externals⟩
    intro name signature found
    change (match rows.lookup name with
      | some row => some row.signature | none => q.B.sig name) = some signature at found
    cases selected : rows.lookup name with
    | none => exact hq.tables.prims name signature (by simpa only [selected] using found)
    | some row =>
      simp only [selected, Option.some.injEq] at found
      subst signature
      exact row_support _ row
  · intro name signature C types found accepted
    change (match rows.lookup name with
      | some row => some row.signature | none => q.B.sig name) = some signature at found
    change (match rows.lookup name with
      | some row => decide (types.length = row.signature.tparams.length)
      | none => q.admitsDec name C types) = true at accepted
    cases selected : rows.lookup name with
    | none =>
      exact hq.admits name signature C types (by simpa only [selected] using found)
        (by simpa only [selected] using accepted)
    | some row =>
      simp only [selected, Option.some.injEq] at found
      subst signature
      have count : types.length = row.signature.tparams.length := by simpa only [selected, decide_eq_true_eq] using accepted
      cases row with
      | scalar entry => exact List.eq_nil_of_length_eq_zero count
      | projected projection => simpa [Row.signature, Projection.signature] using count

structure Prepared where
  input : Check.Input
  program : Program

/-- 収集・登録・解決は一回の入口で行い、内部行のない入力はそのまま返す。 -/
def prepare (q : Check.Input) (p : Program) : Prepared :=
  if enabled q.builtinSource then
    let rows := PredicateRowCollection.collectAvoid p (sources q p) (PredicateGeneratedNames.forbidden q p)
    if rows.isEmpty then ⟨q, p⟩ else ⟨input q rows, resolveProgram rows p⟩
  else ⟨q, p⟩

/-- 実際の収集表は、元の核構文と構成済みの内部行の全ての名前を避ける。 -/
theorem collected_fresh {q : Check.Input} {p : Program} {key row}
    (member : (key, row) ∈ PredicateRowCollection.collectAvoid p (sources q p)
      (PredicateGeneratedNames.forbidden q p)) :
    key ∉ PredicateGeneratedNames.sourceNames q p ∧
      key ∉ PredicateGeneratedNames.builtinNames q.builtinSource := by
  have fresh := PredicateRowCollection.collectAvoid_fresh member
  constructor
  · intro found
    exact fresh (List.mem_append_left _ found)
  · intro found
    exact fresh (List.mem_append_right _ found)

theorem collected_def_fresh {q : Check.Input} {p : Program}
    (complete : ∀ name d, p.defs name = some d → name ∈ q.defs)
    {key row name d} (member : (key, row) ∈ PredicateRowCollection.collectAvoid p (sources q p)
      (PredicateGeneratedNames.forbidden q p))
    (found : (desugarProgram q.opPrim p).defs name = some d) :
    key ∉ PredicateGeneratedNames.compNames d.body := by
  intro present
  exact (collected_fresh member).1 (PredicateGeneratedNames.kernel_def_names complete found present)

theorem collected_method_fresh {q : Check.Input} {p : Program}
    {key row name id method body} (member : (key, row) ∈ PredicateRowCollection.collectAvoid p (sources q p)
      (PredicateGeneratedNames.forbidden q p))
    (listed : name ∈ q.impls) (methodListed : method ∈ q.methods)
    (found : (desugarProgram q.opPrim p).impls name = some id)
    (methodFound : id.methods method = some body) : key ∉ PredicateGeneratedNames.compNames body := by
  intro present
  exact (collected_fresh member).1
    (PredicateGeneratedNames.kernel_method_names listed methodListed found methodFound present)

private theorem rows_lookup_none {rows : Table.Rows} {key}
    (absent : key ∉ rows.map Prod.fst) : rows.lookup key = none := by
  cases found : rows.lookup key with
  | none => rfl
  | some row =>
    have member := ScopeSignatures.lookup_mem found
    exact False.elim (absent (List.mem_map_of_mem member))

private theorem builtin_sig_none {source : Check.BuiltinSource} {key}
    (active : enabled source = true) (standard : key ∉ StandardModel.nameLists.composed)
    (absent : key ∉ PredicateGeneratedNames.builtinNames source) : source.builtins.sig key = none := by
  induction source with
  | custom _ | unrestrictedRanges _ => cases active
  | standard program =>
    cases found : (StandardModel.builtins program).sig key with
    | none => first | rfl | exact found
    | some signature =>
      obtain ⟨row, member, same, _⟩ := (StandardModel.builtins_lookup_iff program key signature).mp found
      apply False.elim
      apply standard
      change key ∈ StandardModel.Primitive.all.map StandardModel.Primitive.name
      exact List.mem_map.mpr ⟨row, member, same.symm⟩
  | predicates data rows =>
    have unregistered := rows_lookup_none absent
    change (if key ∈ StandardModel.nameLists.composed then _ else
      if key ∈ (Table.names rows).assumed then (rows.lookup key).map Row.signature else none) = none
    rw [ite_eq_right standard, unregistered]
    split <;> rfl
  | resolved base rows ih =>
    have baseAbsent : key ∉ PredicateGeneratedNames.builtinNames base :=
      fun h => absent (List.mem_append_left _ h)
    have rowsAbsent : key ∉ rows.map Prod.fst := fun h => absent (List.mem_append_right _ h)
    have unregistered := rows_lookup_none rowsAbsent
    change (match rows.lookup key with | some row => some row.signature | none => base.builtins.sig key) = none
    rw [unregistered]
    exact ih (enabled_resolved_base active) baseAbsent

/-- 追加する全ての名前は、解決前の入力の署名表でも未登録である。 -/
theorem collected_builtin_fresh {q : Check.Input} {p : Program} {key row}
    (active : enabled q.builtinSource = true)
    (member : (key, row) ∈ PredicateRowCollection.collectAvoid p (sources q p)
      (PredicateGeneratedNames.forbidden q p)) : q.B.sig key = none := by
  exact builtin_sig_none active (PredicateRowCollection.collectAvoid_standard_fresh member).1
    (collected_fresh member).2

/-- 準備した入力は恒等、又は一つの収集表による登録と本体の解決である。 -/
theorem prepare_cases (q : Check.Input) (p : Program) :
    prepare q p = ⟨q,p⟩ ∨ ∃ rows, prepare q p = ⟨input q rows, resolveProgram rows p⟩ := by
  unfold prepare
  split
  · dsimp only
    split
    · exact Or.inl rfl
    · exact Or.inr ⟨_, rfl⟩
  · exact Or.inl rfl

/-- 準備が内部行を登録するときは、各キーの元の核本体からの不在と元の表からの不在も得る。 -/
theorem prepare_cases_fresh (q : Check.Input) (p : Program) :
    prepare q p = ⟨q,p⟩ ∨ ∃ rows, prepare q p = ⟨input q rows, resolveProgram rows p⟩ ∧
      ∀ key row, (key, row) ∈ rows →
        key ∉ PredicateGeneratedNames.sourceNames q p ∧ q.B.sig key = none := by
  unfold prepare
  split
  · next active =>
    dsimp only
    split
    · exact Or.inl rfl
    · refine Or.inr ⟨_, rfl, ?_⟩
      intro key row member
      exact ⟨(collected_fresh member).1, collected_builtin_fresh active member⟩
  · exact Or.inl rfl

/-- 本体の解決は、関数・辞書・外部宣言を含む全ての宣言を保つ。 -/
theorem resolveProgram_declarations (rows : Table.Rows) (p : Program) :
    (resolveProgram rows p).declarations = p.declarations := by
  unfold Program.declarations Program.declarationsFor
  congr 1
  · funext name
    simp only [resolveProgram, Program.lookupFun]
    cases p.defs name <;> rfl
  · funext name
    simp only [resolveProgram]
    cases p.impls name <;> rfl

/-- 入力の準備も、利用者の宣言を変更しない。 -/
theorem prepare_declarations (q : Check.Input) (p : Program) :
    (prepare q p).program.declarations = p.declarations := by
  rcases prepare_cases q p with h | ⟨rows, h⟩
  · rw [h]
  · rw [h]; exact resolveProgram_declarations rows p

/-- 実入口で構成した入力は、元の入力の健全性から健全である。 -/
theorem prepare_sound {q : Check.Input} (hq : q.Sound) (p : Program) : (prepare q p).input.Sound := by
  rcases prepare_cases q p with h | ⟨rows,h⟩
  · rw [h]; exact hq
  · rw [h]; exact input_sound hq rows

/-- 独自の表は、同じプログラムを同じ表で検査する。 -/
theorem prepare_custom (q : Check.Input) (p : Program) (B : Builtins)
    (source : q.builtinSource = .custom B) : prepare q p = ⟨q,p⟩ := by
  simp only [prepare, source, enabled, Bool.false_eq_true, ite_false]

/-- 公開の判定を上書きする内部構成は、その入力とプログラムをそのまま返す。 -/
theorem prepare_public_override {q : Check.Input} (p : Program) (base : Refinement.Program) (row : Row)
    (source : q.builtinSource = .resolved (.standard base) [("Float.isFinite", row)]) :
    prepare q p = ⟨q,p⟩ := by
  have inactive : enabled q.builtinSource = false := by rw [source]; cbv
  simp only [prepare, inactive, Bool.false_eq_true, ite_false]

namespace Examples

private def entry : Row := .scalar (.floating .binary64 .finite)

private def body : Block := .last (.call (.primName "Float.isFinite" [] [] []) [none] [0]
  (.cons (.local 0) .nil))

private def definition (hidden : Bool) : Def where
  tparams := []
  neffs := 0
  names := ["x"]
  params := [.base .float]
  ret := .base .boolean
  eff := Eff.empty
  body := if hidden then .discard
    (.binary .add (.base .integer) (.literal (.integer ⟨0,by decide⟩))
      (.literal (.integer ⟨1,by decide⟩))) body else body

private def program (hidden : Bool) : Program where
  defs := fun name => if name = "test" then some (definition hidden) else none
  cons := fun _ => none

private def source (existing hidden : Bool) : Check.BuiltinSource :=
  let base := Check.BuiltinSource.standard (program hidden).declarations.core
  if existing then .resolved base [(PredicateRowCollection.name 7, entry)] else base

private def input (existing hidden : Bool) : Check.Input where
  D := (program hidden).declarations
  builtinSource := source existing hidden
  opPrim := fun _ _ => some (PredicateRowCollection.name 12, [])
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 1
  defs := ["test"]

/-- 内部行を含まない入力は0から、構成済みの行を持つ入力はその番号の後から生成する。 -/
example (existing : Bool) :
    (prepare (input existing false) (program false)).input.builtinSource =
      .resolved (source existing false)
        [(PredicateRowCollection.name (if existing then 8 else 0), entry)] := by
  cases existing <;> cbv

/-- 演算子の解決が核へ挿入する名前も避け、表にある7と元の核にある12の後から生成する。 -/
example : (prepare (input true true) (program true)).input.builtinSource =
    .resolved (source true true) [(PredicateRowCollection.name 13, entry)] := by
  cbv

end Examples

end
end Benitoite.Release.Refinement.Surface.CheckPreparation
