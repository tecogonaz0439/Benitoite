import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.PredicateRowCollection

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
  | .resolved base _ => enabled base
  | .custom _ | .unrestrictedRanges _ => false

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
    let rows := PredicateRowCollection.collect p (sources q p)
    if rows.isEmpty then ⟨q, p⟩ else ⟨input q rows, resolveProgram rows p⟩
  else ⟨q, p⟩

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

/-- 独自の表は、従来の同じプログラムを同じ表で検査する。 -/
theorem prepare_custom (q : Check.Input) (p : Program) (B : Builtins)
    (source : q.builtinSource = .custom B) : prepare q p = ⟨q,p⟩ := by
  simp only [prepare, source, enabled, Bool.false_eq_true, ite_false]

end
end Benitoite.Release.Refinement.Surface.CheckPreparation
