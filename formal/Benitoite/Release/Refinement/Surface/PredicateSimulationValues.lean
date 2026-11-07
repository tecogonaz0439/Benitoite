import Benitoite.Release.Refinement.Surface.PredicateCalls
import Benitoite.Release.Refinement.Surface.PredicateProjectionTable
import Benitoite.Release.Refinement.Capture
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationSimpleValues
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionAlgebra

/-! # 判定の名前解決に伴う値とコードの対応

閉包の本体を対応させ、型と有限の観測は同じまま保つ。最終観測の選択はここで定めない。
登録した判定と取り出しの公開呼出しを、同じ判定を行う内部行への呼出しへ対応させる。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

mutual
  /-- 値の内容を保ち、関数の本体だけをコードの対応で比較する。 -/
  inductive Value (source : Program) (rows : PredicateProjection.Table.Rows) : Val → Val → Prop
    | var (i) : Value source rows (.var i) (.var i)
    | constant (c) : Value source rows (.const c) (.const c)
    | function (f ts es rs) : Value source rows (.fnRef f ts es rs) (.fnRef f ts es rs)
    | primitive (b ts es rs) : Value source rows (.prim b ts es rs) (.prim b ts es rs)
    | lam {ns ps m n} : Code source rows m n → Value source rows (.lam ns ps m) (.lam ns ps n)
    | dependentLam {t m n} : Code source rows m n → Value source rows (.dependentLam t m) (.dependentLam t n)
    | closure {t q r} : ClosedCode source rows q r → Value source rows (.closure t q) (.closure t r)
    | con {c ts vs ws} : Values source rows vs ws → Value source rows (.con c ts vs) (.con c ts ws)
    | list {vs ws} : Values source rows vs ws → Value source rows (.list vs) (.list ws)
    | operation (o ts) : Value source rows (.op o ts) (.op o ts)
    | raise (a e) : Value source rows (.raise a e) (.raise a e)
    | location (l) : Value source rows (.loc l) (.loc l)
    | map {ks ls vs ws} : Values source rows ks ls → Values source rows vs ws → Value source rows (.mapV ks vs) (.mapV ls ws)
    | set {vs ws} : Values source rows vs ws → Value source rows (.setV vs) (.setV ws)
    | bytes (bs) : Value source rows (.bytesV bs) (.bytesV bs)
    | dictionary {i ts vs ws} : Values source rows vs ws → Value source rows (.dict i ts vs) (.dict i ts ws)
    | super {v w s} : Value source rows v w → Value source rows (.super v s) (.super w s)
    | externalFunction (f ts) : Value source rows (.externalRef f ts) (.externalRef f ts)
    | externalHandle (h ts) : Value source rows (.externalHandle h ts) (.externalHandle h ts)
    | pathBases (s) : Value source rows (.pathBases s) (.pathBases s)
    | scopePattern (r) : Value source rows (.scopePattern r) (.scopePattern r)
    | checkedAt {r s t v w} : OptionalValue source rows v w → Value source rows (.checkedAt r s t v) (.checkedAt r s t w)
    | atError (d) : Value source rows (.atError d) (.atError d)
    | checked (t) : Value source rows (.checked t) (.checked t)
    | checkedRequest {t v w} : Value source rows v w → Value source rows (.checkedRequest t v) (.checkedRequest t w)
  inductive Values (source : Program) (rows : PredicateProjection.Table.Rows) : List Val → List Val → Prop
    | nil : Values source rows [] []
    | cons {v w vs ws} : Value source rows v w → Values source rows vs ws → Values source rows (v :: vs) (w :: ws)
  inductive OptionalValue (source : Program) (rows : PredicateProjection.Table.Rows) : Option Val → Option Val → Prop
    | none : OptionalValue source rows none none
    | some {v w} : Value source rows v w → OptionalValue source rows (some v) (some w)
  inductive Slots (source : Program) (rows : PredicateProjection.Table.Rows) : List (Option Val) → List (Option Val) → Prop
    | nil : Slots source rows [] []
    | cons {v w vs ws} : OptionalValue source rows v w → Slots source rows vs ws → Slots source rows (v :: vs) (w :: ws)
  /-- 未適用の引数を閉じずに、本体と外側の捕捉スロットを対応させる。 -/
  inductive ClosedCode (source : Program) (rows : PredicateProjection.Table.Rows) : Closure → Closure → Prop
    | mk {cap cap' m n} : Captures source rows cap cap' → Code source rows m n → ClosedCode source rows (.mk cap m) (.mk cap' n)
  inductive Captures (source : Program) (rows : PredicateProjection.Table.Rows) : Capture → Capture → Prop
    | mk {vs ws} : Slots source rows vs ws → Captures source rows (.mk vs) (.mk ws)
  /-- 構文の合同性と、実際に登録した判定の管理用の束縛の省略。 -/
  inductive Code (source : Program) (rows : PredicateProjection.Table.Rows) : Comp → Comp → Prop
    | builder {k m n} : Code source rows m n → Code source rows (.builderLet k m) (.builderLet k n)
    | builderOp {k o r vs ws} : Values source rows vs ws → Code source rows (.builderOp k o r vs) (.builderOp k o r ws)
    | ret {v w} : Value source rows v w → Code source rows (.ret v) (.ret w)
    | letIn {m m' n n'} : Code source rows m m' → Code source rows n n' → Code source rows (.letIn m n) (.letIn m' n')
    | app {f g vs ws} : Value source rows f g → Values source rows vs ws → Code source rows (.app f vs) (.app g ws)
    | ite {v w m m' n n'} : Value source rows v w → Code source rows m m' → Code source rows n n' → Code source rows (.ite v m n) (.ite w m' n')
    | matchC {v w as bs} : Value source rows v w → Arms source rows as bs → Code source rows (.match v as) (.match w bs)
    | lazyC {m n} : Code source rows m n → Code source rows (.lazyC m) (.lazyC n)
    | escape {v w} : Value source rows v w → Code source rows (.escape v) (.escape w)
    | use {v w m n} : Value source rows v w → Code source rows m n → Code source rows (.use v m) (.use w n)
    | handle {m n cs ds} : Code source rows m n → Clauses source rows cs ds → Code source rows (.handle m cs) (.handle n ds)
    | resume {v w k l} : Value source rows v w → Value source rows k l → Code source rows (.resume k v) (.resume l w)
    | externalCall {f ts vs ws} : Values source rows vs ws → Code source rows (.externalCall f ts vs) (.externalCall f ts ws)
    | pathBases (b) : Code source rows (.issuePathBases b) (.issuePathBases b)
    | checkAt {k o sh bs cs p q v w ix} : OptionalValue source rows bs cs → Value source rows p q → Value source rows v w →
        Code source rows (.checkAt k o sh bs p v ix) (.checkAt k o sh cs q w ix)
    | method {d e m ts es vs ws} : Value source rows d e → Values source rows vs ws → Code source rows (.meth d m ts es vs) (.meth e m ts es ws)
    | scalar {api entry key positions values v w} : rows.lookup key = some (.scalar entry) →
        values.length = api.inputs.length →
        ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) v →
        SimpleValues values → Value source rows v w →
        Code source rows (scalarCall api positions values) (.app (.prim key [] [] []) [w])
    | projected {api key projection positions computations symbolic root steps types target} :
        rows.lookup key = some (.projected projection) →
        projection.route = steps.map PredicateAccessorTargets.Step.reference →
        ProjectionArguments source root steps computations symbolic →
        ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0) →
        computations.length = api.inputs.length → types.length = projection.ntys →
        SimpleValue root → Value source rows root target →
        Code source rows (sourceCall api positions computations) (.app (.prim key types [] []) [target])
  inductive Arms (source : Program) (rows : PredicateProjection.Table.Rows) : List Arm → List Arm → Prop
    | nil : Arms source rows [] []
    | plain {alts m n as bs} : Code source rows m n → Arms source rows as bs →
        Arms source rows (.mk alts none m :: as) (.mk alts none n :: bs)
    | guard {alts g h m n as bs} : Code source rows g h → Code source rows m n → Arms source rows as bs →
        Arms source rows (.mk alts (some g) m :: as) (.mk alts (some h) n :: bs)
  inductive Clauses (source : Program) (rows : PredicateProjection.Table.Rows) : List Clause → List Clause → Prop
    | nil : Clauses source rows [] []
    | operation {o a nt m n cs ds} : Code source rows m n → Clauses source rows cs ds →
        Clauses source rows (.mk o a nt m :: cs) (.mk o a nt n :: ds)
    | fail {e m n cs ds} : Code source rows m n → Clauses source rows cs ds →
        Clauses source rows (.fail e m :: cs) (.fail e n :: ds)
end

/-- 公開形が読む文字列と範囲は、関数の本体の対応に依存しない。 -/
theorem Value.inputOfVal {source rows v w} (h : Value source rows v w) : ScopePublic.inputOfVal v = ScopePublic.inputOfVal w := by
  cases h <;> rfl

mutual
  /-- 有限の観測は閉包のコードを読まない。 -/
  theorem Value.toTerm {source rows v w} (h : Value source rows v w) : v.toTerm? = w.toTerm? := by
    cases h with
    | con h => simp only [Val.toTerm?, Values.toTerm h]
    | list h => simp only [Val.toTerm?, Values.toTerm h]
    | map h g => simp only [Val.toTerm?, Values.toTerm h, Values.toTerm g]
    | set h => simp only [Val.toTerm?, Values.toTerm h]
    | _ => rfl
  theorem Values.toTerm {source rows vs ws} (h : Values source rows vs ws) : Val.toTermSlots vs = Val.toTermSlots ws := by
    cases h with
    | nil => rfl
    | cons h g => simp only [Val.toTermSlots, h.toTerm, Values.toTerm g]
end

/-- 型と効果の値置換は、対応する値の同じ有限観測を使う。 -/
theorem valueEnvs {source rows ν ξ} (h : ∀ i, Value source rows (ν i) (ξ i)) : valEnv ν = valEnv ξ := by
  have he : (fun i => (ν i).toTerm?) = (fun i => (ξ i).toTerm?) := funext (fun i => (h i).toTerm)
  exact congrArg (fun obs => SubstEnv.mk Ty.tvar [] [] obs) he

theorem substTyValues_eq {source rows ν ξ} (h : ∀ i, Value source rows (ν i) (ξ i)) (a : Ty) :
    substTyValues ν a = substTyValues ξ a := by simp only [substTyValues, valueEnvs h]

theorem substEffValues_eq {source rows ν ξ} (h : ∀ i, Value source rows (ν i) (ξ i)) (e : Eff) :
    substEffValues ν e = substEffValues ξ e := by simp only [substEffValues, valueEnvs h]

/-- 捕捉スロットの穴と値の位置を保つので、環境の参照も対応する。 -/
theorem Slots.env {source rows vs ws} (h : Slots source rows vs ws) (i : Nat) :
    Value source rows (((vs[i]?).join).getD (.const .unit)) (((ws[i]?).join).getD (.const .unit)) := by
  cases h with
  | nil => exact .constant _
  | cons h tail =>
    cases i with
    | zero => cases h with
      | none => exact .constant _
      | some h => exact h
    | succ i => exact Slots.env tail i

theorem Captures.env {source rows cap cap'} (h : Captures source rows cap cap') (i : Nat) : Value source rows (cap.env i) (cap'.env i) := by
  cases h with
  | mk hs => exact hs.env i

theorem Captures.closeTy {source rows cap cap'} (h : Captures source rows cap cap') : cap.closeTy = cap'.closeTy := by
  funext a
  exact substTyValues_eq h.env a

theorem Captures.closeEff {source rows cap cap'} (h : Captures source rows cap cap') : cap.closeEff = cap'.closeEff := by
  funext e
  exact substEffValues_eq h.env e

theorem Captures.closeTel {source rows cap cap'} (h : Captures source rows cap cap') (t : Tel) : cap.closeTel t = cap'.closeTel t := by
  simp only [Capture.closeTel, valueEnvs h.env]

mutual
  /-- 捕捉を閉じてもラムダの引数は本体に残し、閉包の対応を保つ。 -/
  theorem Value.close {source rows v w cap cap'} (h : Value source rows v w) (hc : Captures source rows cap cap') :
      Value source rows (closeVal cap v) (closeVal cap' w) := by
    cases h with
    | var i => exact hc.env i
    | constant c => exact .constant c
    | function f ts es rs => simpa only [closeVal, hc.closeTy, hc.closeEff] using Value.function (source := source) (rows := rows) f (ts.map cap'.closeTy) (es.map cap'.closeEff) rs
    | primitive b ts es rs => simpa only [closeVal, hc.closeTy, hc.closeEff] using Value.primitive (source := source) (rows := rows) b (ts.map cap'.closeTy) (es.map cap'.closeEff) rs
    | lam h =>
      simp only [closeVal, hc.closeTel]
      exact .closure (.mk hc h)
    | dependentLam h =>
      simp only [closeVal, hc.closeTel]
      exact .closure (.mk hc h)
    | closure h => exact .closure h
    | con h => simpa only [closeVal, hc.closeTy] using Value.con (Values.close h hc)
    | list h => exact .list (Values.close h hc)
    | operation o ts => simpa only [closeVal, hc.closeTy] using Value.operation (source := source) (rows := rows) o (ts.map cap'.closeTy)
    | raise a e => simpa only [closeVal, hc.closeTy] using Value.raise (source := source) (rows := rows) (cap'.closeTy a) (cap'.closeTy e)
    | location l => exact .location l
    | map h g => exact .map (Values.close h hc) (Values.close g hc)
    | set h => exact .set (Values.close h hc)
    | bytes bs => exact .bytes bs
    | dictionary h => simpa only [closeVal, hc.closeTy] using Value.dictionary (Values.close h hc)
    | super h => exact .super (Value.close h hc)
    | externalFunction f ts => simpa only [closeVal, hc.closeTy] using Value.externalFunction (source := source) (rows := rows) f (ts.map cap'.closeTy)
    | externalHandle f ts => simpa only [closeVal, hc.closeTy] using Value.externalHandle (source := source) (rows := rows) f (ts.map cap'.closeTy)
    | pathBases s => exact .pathBases s
    | scopePattern r => exact .scopePattern r
    | checkedAt h => exact .checkedAt h
    | atError h => exact .atError h
    | checked t => exact .checked t
    | checkedRequest h => exact .checkedRequest h
  theorem Values.close {source rows vs ws cap cap'} (h : Values source rows vs ws) (hc : Captures source rows cap cap') :
      Values source rows (closeVals cap vs) (closeVals cap' ws) := by
    cases h with
    | nil => exact .nil
    | cons h g => exact .cons (h.close hc) (Values.close g hc)
end

theorem Captures.extend {source rows cap cap' v w} (hc : Captures source rows cap cap') (hv : Value source rows v w) :
    Captures source rows (cap.extend v) (cap'.extend w) := by
  cases hc with
  | mk h => exact .mk (.cons (.some hv) h)

theorem Values.extendMany {source rows vs ws} (h : Values source rows vs ws) :
    ∀ cap cap', Captures source rows cap cap' → Captures source rows (cap.extendMany vs) (cap'.extendMany ws) := by
  cases h with
  | nil => intro cap cap' hc; exact hc
  | cons h tail =>
    intro cap cap' hc
    exact Values.extendMany tail _ _ (hc.extend h)

theorem Captures.extendMany {source rows cap cap' vs ws} (hc : Captures source rows cap cap') (h : Values source rows vs ws) :
    Captures source rows (cap.extendMany vs) (cap'.extendMany ws) := h.extendMany cap cap' hc

theorem ClosedCode.apply {source rows q r vs ws} (h : ClosedCode source rows q r) (hv : Values source rows vs ws) :
    ClosedCode source rows (q.apply vs) (r.apply ws) := by
  cases h with
  | mk hc hcode => exact .mk (hc.extendMany hv) hcode

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
