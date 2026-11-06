import Benitoite.Release.Refinement.Surface.PredicateSimulationSteps
import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses

/-! # 判定の名前解決と実行の構造規則

応答を読む規則を除き、捕捉・継続・ストアの対応から両側の実際の一段を構成する。
元のプログラムの型付けは要求しない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

theorem ClosedCode.pure {source rows m n} (h : Code source rows m n) :
    ClosedCode source rows (.pure m) (.pure n) := .mk (.mk .nil) h

theorem ContRel.markPush {source rows k l} (h : ContRel source rows k l) :
    ContRel source rows (markPush k) (markPush l) := by
  cases h with
  | nil => exact .cons .mark .nil
  | cons hf hk =>
    have whole := ContRel.cons hf hk
    cases hf <;> first | exact whole | exact .cons .mark whole

theorem ContRel.releases {source rows k l} (h : ContRel source rows k l) :
    ContRel source rows (releases k) (releases l) := by
  induction h with
  | nil => exact .nil
  | cons hf hk ih =>
    cases hf with
    | release hv => exact .cons (.release hv) ih
    | drop location => exact .cons (.drop location) ih
    | _ => exact ih

private theorem optionalValues_refl {source rows} (values : Option (List Val)) :
    Option.Rel (Values source rows) values values := by
  cases values with
  | none => exact .none
  | some values => exact .some (.refl values)

private theorem optionalValues_append {source rows a a' b b'}
    (ha : Option.Rel (Values source rows) a a') (hb : Option.Rel (Values source rows) b b') :
    Option.Rel (Values source rows) (do let xs ← a; let ys ← b; pure (xs ++ ys))
      (do let xs ← a'; let ys ← b'; pure (xs ++ ys)) := by
  cases ha with
  | none => exact .none
  | some ha => cases hb with
    | none => exact .none
    | some hb => exact .some (ha.append hb)

private theorem optionalValues_between {source rows a a' b b' middle middle'}
    (ha : Option.Rel (Values source rows) a a') (hb : Option.Rel (Values source rows) b b')
    (hm : Values source rows middle middle') :
    Option.Rel (Values source rows) (do let xs ← a; let ys ← b; pure (xs ++ middle ++ ys))
      (do let xs ← a'; let ys ← b'; pure (xs ++ middle' ++ ys)) := by
  cases ha with
  | none => exact .none
  | some ha => cases hb with
    | none => exact .none
    | some hb => exact .some ((ha.append hm).append hb)

private theorem optionalValues_cons {source rows a a' b b'}
    (ha : OptionalValue source rows a a') (hb : Option.Rel (Values source rows) b b') :
    Option.Rel (Values source rows) (do let x ← a; let xs ← b; pure (x :: xs))
      (do let x ← a'; let xs ← b'; pure (x :: xs)) := by
  cases ha with
  | none => exact .none
  | some ha => cases hb with
    | none => exact .none
    | some hb => exact .some (.cons ha hb)

private theorem optionRel_some {α β} {R : α → β → Prop} {value : α} {result : Option β}
    (h : Option.Rel R (some value) result) : ∃ target, result = some target ∧ R value target := by
  cases h with
  | some related => exact ⟨_,rfl,related⟩

private theorem optionRel_none {α β} {R : α → β → Prop} {result : Option β}
    (h : Option.Rel R none result) : result = none := by
  cases h
  rfl

theorem Value.constant_left {source rows c w} (h : Value source rows (.const c) w) : w = .const c := by
  cases h
  rfl

theorem Value.closure_left {source rows signature body w} (h : Value source rows (.closure signature body) w) :
    ∃ target, w = .closure signature target ∧ ClosedCode source rows body target := by
  cases h with
  | closure related => exact ⟨_,rfl,related⟩

mutual
  theorem Value.matchVal {source rows v w} (h : Value source rows v w) (pat : Pat) :
      Option.Rel (Values source rows) (matchVal pat v) (matchVal pat w) := by
    cases pat with
    | wild => exact .some .nil
    | var => exact .some (.cons h .nil)
    | const c => cases h with
      | constant d => simp only [matchVal]; split <;> first | exact .some .nil | exact .none
      | _ => exact .none
    | range lo hi => cases h with
      | constant d => simp only [matchVal]; split <;> first | exact .some .nil | exact .none
      | _ => exact .none
    | con c ps => cases h with
      | con values =>
        simp only [matchVal]
        split
        · exact Values.matchList values ps
        · exact .none
      | atError d => exact optionalValues_refl _
      | _ => exact .none
    | list before rest after => cases h with
      | @list vs ws values =>
        simp only [matchVal, values.length]
        by_cases accepted : (if rest.isSome then before.length + after.length ≤ ws.length else before.length + after.length = ws.length)
        · simp only [ite_eq_left accepted]
          apply optionalValues_between
          · exact Values.matchList (values.take before.length) before
          · exact Values.matchList (values.drop (_ - after.length)) after
          · cases rest with
            | none => exact .nil
            | some rest => cases rest with
              | skip => exact .nil
              | bind => exact .cons (.list ((values.drop before.length).take _)) .nil
        · simp only [ite_eq_right accepted]; exact .none
      | _ => exact .none
  termination_by sizeOf pat

  theorem Values.matchList {source rows vs ws} (h : Values source rows vs ws) (patterns : List Pat) :
      Option.Rel (Values source rows) (matchList patterns vs) (matchList patterns ws) := by
    cases patterns with
    | nil => cases h <;> first | exact .some .nil | exact .none
    | cons p ps => cases h with
      | nil => exact .none
      | cons hv tail => exact optionalValues_append (Value.matchVal hv p) (Values.matchList tail ps)
  termination_by sizeOf patterns
end

theorem Values.selectSlots {source rows vs ws} (h : Values source rows vs ws) (slots : List Nat) :
    Option.Rel (Values source rows) (selectSlots vs slots) (selectSlots ws slots) := by
  induction slots with
  | nil => exact .some .nil
  | cons i slots ih =>
    exact optionalValues_cons (h.getElem? i) ih

theorem Value.firstAlt {source rows v w} (h : Value source rows v w) (alternatives : List Alt) :
    Option.Rel (Values source rows) (firstAlt v alternatives) (firstAlt w alternatives) := by
  induction alternatives with
  | nil => exact .none
  | cons alternative rest ih =>
    simp only [Refinement.firstAlt]
    have related := h.matchVal alternative.pat
    cases found : Refinement.matchVal alternative.pat v with
    | none =>
      rw [found] at related
      rw [optionRel_none related]
      exact ih
    | some values =>
      rw [found] at related
      obtain ⟨targets,targetFound,valuesRel⟩ := optionRel_some related
      rw [targetFound]
      exact valuesRel.selectSlots alternative.slots

inductive ArmRel (source : Program) (rows : PredicateProjection.Table.Rows) : Arm → Arm → Prop
  | plain {alts m n} : Code source rows m n → ArmRel source rows (.mk alts none m) (.mk alts none n)
  | guarded {alts g h m n} : Code source rows g h → Code source rows m n →
      ArmRel source rows (.mk alts (some g) m) (.mk alts (some h) n)

theorem Arms.getElem? {source rows arms targets} (h : Arms source rows arms targets) (i : Nat) :
    Option.Rel (ArmRel source rows) arms[i]? targets[i]? := by
  cases h with
  | nil => exact .none
  | plain body tail => cases i with
    | zero => exact .some (.plain body)
    | succ i => exact tail.getElem? i
  | guard hg body tail => cases i with
    | zero => exact .some (.guarded hg body)
    | succ i => exact tail.getElem? i

inductive ClauseRel (source : Program) (rows : PredicateProjection.Table.Rows) : Clause → Clause → Prop
  | operation {op arity ntypes m n} : Code source rows m n →
      ClauseRel source rows (.mk op arity ntypes m) (.mk op arity ntypes n)
  | failure {error m n} : Code source rows m n → ClauseRel source rows (.fail error m) (.fail error n)

theorem ClauseRel.body {source rows a b} (h : ClauseRel source rows a b) :
    Code source rows a.body b.body := by cases h <;> assumption

theorem Clauses.handles {source rows clauses targets} (h : Clauses source rows clauses targets) (op : OpRef) :
    handles clauses op = handles targets op := by
  cases h with
  | nil => rfl
  | @operation op' arity ntypes m n cs ds hm tail =>
    exact congrArg (fun flag => (op' == op) || flag) (tail.handles op)
  | fail hm tail =>
    exact congrArg (fun flag => (OpRef.fail == op) || flag) (tail.handles op)

theorem Clauses.findClause {source rows clauses targets} (h : Clauses source rows clauses targets) (op : OpRef) :
    Option.Rel (ClauseRel source rows) (findClause clauses op) (findClause targets op) := by
  cases h with
  | nil => exact .none
  | operation hm tail =>
    simp only [Refinement.findClause,List.find?_cons,Clause.op]
    split
    · exact .some (.operation hm)
    · exact tail.findClause op
  | fail hm tail =>
    simp only [Refinement.findClause,List.find?_cons,Clause.op]
    split
    · exact .some (.failure hm)
    · exact tail.findClause op

theorem ContRel.member_right {source rows k l g} (h : ContRel source rows k l) (member : g ∈ l) :
    ∃ f, f ∈ k ∧ FrameRel source rows f g := by
  induction h with
  | nil => cases member
  | cons hf hk ih =>
    rcases List.mem_cons.mp member with rfl | member
    · exact ⟨_,by simp,hf⟩
    · obtain ⟨f,member,related⟩ := ih member
      exact ⟨f,List.mem_cons_of_mem _ member,related⟩

theorem ContRel.member_left {source rows k l f} (h : ContRel source rows k l) (member : f ∈ k) :
    ∃ g, g ∈ l ∧ FrameRel source rows f g := by
  induction h with
  | nil => cases member
  | cons hf hk ih =>
    rcases List.mem_cons.mp member with rfl | member
    · exact ⟨_,by simp,hf⟩
    · obtain ⟨g,member,related⟩ := ih member
      exact ⟨g,List.mem_cons_of_mem _ member,related⟩

theorem ContRel.noHandler {source rows k l} (h : ContRel source rows k l) (op : OpRef) :
    NoHandler k op ↔ NoHandler l op := by
  constructor
  · intro absent cap clauses member
    obtain ⟨frame,original,related⟩ := h.member_right member
    cases related with
    | handleF hc hh => exact hh.handles op ▸ absent _ _ original
  · intro absent cap clauses member
    obtain ⟨frame,target,related⟩ := h.member_left member
    cases related with
    | handleF hc hh => exact (hh.handles op).symm ▸ absent _ _ target

theorem ContRel.split_frame {source rows beforeFrames frame rest target}
    (h : ContRel source rows (beforeFrames ++ frame :: rest) target) :
    ∃ before next after, target = before ++ next :: after ∧
      ContRel source rows beforeFrames before ∧ FrameRel source rows frame next ∧ ContRel source rows rest after := by
  induction beforeFrames generalizing target with
  | nil => cases h with
    | cons head tail => exact ⟨[],_,_,rfl,.nil,head,tail⟩
  | cons first beforeFrames ih => cases h with
    | cons head tail =>
      obtain ⟨before,next,after,rfl,hbefore,hframe,hafter⟩ := ih tail
      exact ⟨_ :: before,next,after,rfl,.cons head hbefore,hframe,hafter⟩

theorem ContRel.splitAt {source rows k l op beforeFrames cap clauses rest}
    (h : ContRel source rows k l) (split : SplitAt op k beforeFrames cap clauses rest) :
    ∃ before targetCap targetClauses after, SplitAt op l before targetCap targetClauses after ∧
      ContRel source rows beforeFrames before ∧ Captures source rows cap targetCap ∧
      Clauses source rows clauses targetClauses ∧ ContRel source rows rest after := by
  obtain ⟨rfl,handled,absent⟩ := split
  obtain ⟨before,next,after,equal,hbefore,hframe,hafter⟩ := h.split_frame
  cases hframe with
  | handleF hc hh =>
    exact ⟨before,_,_,after,⟨equal,hh.handles op ▸ handled,(hbefore.noHandler op).mp absent⟩,
      hbefore,hc,hh,hafter⟩

/-- 実際のsourceの到達先を添字に保ち、targetの一段と到達後の対応を返す。 -/
def SynchronizedAt (source : Program) (rows : PredicateProjection.Table.Rows)
    (P Q : Refinement.Program) (B C : Builtins) (σ : PathEnv) (first second : State)
    {destination : State} (_step : Step P B σ first none destination) : Prop :=
  ∃ next, Step Q C σ second none next ∧ StateRel source rows destination next

variable {source : Program} {rows : PredicateProjection.Table.Rows}
variable {P Q : Refinement.Program} {B C : Builtins} {σ : PathEnv}

theorem structural_let {cap cap' m m' n n' k l μ ν}
    (hc : Captures source rows cap cap') (hm : Code source rows m m') (hn : Code source rows n n')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.letIn m n)) k μ) (.run (.mk cap' (.letIn m' n')) l ν) (.E_Let rfl) := by
  exact ⟨_,.E_Let rfl,.run (.mk hc hm) (.cons (.letF (.mk hc hn)) hk) hμ⟩

theorem structural_return {cap cap' v w q r k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w) (hq : ClosedCode source rows q r)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ret v)) (.letF q :: k) μ) (.run (.mk cap' (.ret w)) (.letF r :: l) ν) (.E_Return rfl) := by
  exact ⟨_,.E_Return rfl,.run (hq.apply (.cons (hv.close hc) .nil)) hk hμ⟩

theorem structural_lambda {cap cap' f g vs ws body signature k l μ ν}
    (hc : Captures source rows cap cap') (hf : Value source rows f g) (ha : Values source rows vs ws)
    (function : closeVal Capture.empty (closeVal cap f) = .closure signature body)
    (arity : (closeVals cap vs).length = signature.arity)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.app f vs)) k μ) (.run (.mk cap' (.app g ws)) l ν) (.E_Lam rfl function arity) := by
  have closed := (hf.close hc).close (Captures.mk Slots.nil)
  change Value source rows (closeVal Capture.empty (closeVal cap f)) (closeVal Capture.empty (closeVal cap' g)) at closed
  rw [function] at closed
  obtain ⟨target,targetFunction,hbody⟩ := closed.closure_left
  exact ⟨_,.E_Lam rfl targetFunction ((ha.close hc).length ▸ arity),
    .run (hbody.apply (ha.close hc)) hk.markPush hμ⟩

theorem structural_function {q r f ts es rs vs ws definition k l μ ν}
    (program : ProgramRel source rows P Q)
    (first : q.view = .app (.fnRef f ts es (List.map RangeIx.fixed rs)) vs)
    (second : r.view = .app (.fnRef f ts es (List.map RangeIx.fixed rs)) ws)
    (found : P.defs f = some definition) (ha : Values source rows vs ws)
    (arity : vs.length = definition.params.length) (types : ts.length = definition.ntys)
    (effects : es.length = definition.neffs)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_Fun first found arity types effects) := by
  have declarations := program.definitions f
  rw [found] at declarations
  cases target : Q.defs f with
  | none => rw [target] at declarations; cases declarations
  | some d =>
    rw [target] at declarations
    cases declarations with
    | some hd =>
      refine ⟨_,
        .E_Fun second target ?_ ?_ ?_,?_⟩
      · exact ha.length ▸ hd.params ▸ arity
      · simpa only [Refinement.Def.ntys, ← hd.tparams] using types
      · exact hd.neffs ▸ effects
      · exact .run (.mk ((Captures.mk Slots.nil).extendMany ha) ((hd.body.instR rs).substTy 0 ts es))
          hk.markPush hμ

theorem structural_if_true {cap cap' v w m m' n n' k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (condition : closeVal cap v = .const (.boolean true)) (hm : Code source rows m m')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ite v m n)) k μ) (.run (.mk cap' (.ite w m' n')) l ν)
      (.E_IfT (by change Comp.ite (closeVal cap v) m n = _; rw [condition])) := by
  have closed := hv.close hc
  rw [condition] at closed
  have same := closed.constant_left
  exact ⟨_,.E_IfT (by change Comp.ite (closeVal cap' w) m' n' = _; rw [same]),.run (.mk hc hm) hk hμ⟩

theorem structural_if_false {cap cap' v w m m' n n' k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (condition : closeVal cap v = .const (.boolean false)) (hn : Code source rows n n')
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ite v m n)) k μ) (.run (.mk cap' (.ite w m' n')) l ν)
      (.E_IfF (by change Comp.ite (closeVal cap v) m n = _; rw [condition])) := by
  have closed := hv.close hc
  rw [condition] at closed
  have same := closed.constant_left
  exact ⟨_,.E_IfF (by change Comp.ite (closeVal cap' w) m' n' = _; rw [same]),.run (.mk hc hn) hk hμ⟩

theorem structural_match {cap cap' v w arms targets k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (ha : Arms source rows arms targets) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.match v arms)) k μ) (.run (.mk cap' (.match w targets)) l ν) (.E_Match rfl) := by
  exact ⟨_,.E_Match rfl,.matchRun (hv.close hc) hc ha hk hμ⟩

theorem structural_match_skip {cap cap' v w arms targets next alts guard body k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (ha : Arms source rows arms targets) (found : arms[next]? = some (.mk alts guard body))
    (missed : firstAlt v alts = none) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.matchRun v cap arms next k μ) (.matchRun w cap' targets next l ν) (.E_MatchSkip found missed) := by
  have related := ha.getElem? next
  rw [found] at related
  obtain ⟨target,targetFound,arm⟩ := optionRel_some related
  have matched := hv.firstAlt alts
  rw [missed] at matched
  have targetMissed := optionRel_none matched
  cases arm <;> exact ⟨_,.E_MatchSkip targetFound targetMissed,
    .matchRun hv hc ha hk hμ⟩

theorem structural_match_body {cap cap' v w arms targets next alts body arguments k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (ha : Arms source rows arms targets) (found : arms[next]? = some (.mk alts none body))
    (matched : firstAlt v alts = some arguments) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.matchRun v cap arms next k μ) (.matchRun w cap' targets next l ν) (.E_MatchBody found matched) := by
  have related := ha.getElem? next
  rw [found] at related
  obtain ⟨target,targetFound,arm⟩ := optionRel_some related
  have matchedRel := hv.firstAlt alts
  rw [matched] at matchedRel
  obtain ⟨targetArguments,targetMatched,argumentsRel⟩ := optionRel_some matchedRel
  cases arm with
  | plain bodyRel => exact ⟨_,.E_MatchBody targetFound targetMatched,
    .run (.mk (hc.extendMany argumentsRel) bodyRel) hk hμ⟩

theorem structural_match_guard {cap cap' v w arms targets next alts guard body arguments k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (ha : Arms source rows arms targets) (found : arms[next]? = some (.mk alts (some guard) body))
    (matched : firstAlt v alts = some arguments) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.matchRun v cap arms next k μ) (.matchRun w cap' targets next l ν) (.E_MatchGuard found matched) := by
  have related := ha.getElem? next
  rw [found] at related
  obtain ⟨target,targetFound,arm⟩ := optionRel_some related
  have matchedRel := hv.firstAlt alts
  rw [matched] at matchedRel
  obtain ⟨targetArguments,targetMatched,argumentsRel⟩ := optionRel_some matchedRel
  cases arm with
  | guarded guardRel bodyRel =>
    exact ⟨_,.E_MatchGuard targetFound targetMatched,
      .run (.mk (hc.extendMany argumentsRel) guardRel)
        (.cons (.guardF hv hc ha (.mk (hc.extendMany argumentsRel) bodyRel)) hk) hμ⟩

theorem structural_use {cap cap' v w m n k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w) (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.use v m)) k μ) (.run (.mk cap' (.use w n)) l ν) (.E_Use rfl) := by
  exact ⟨_,.E_Use rfl,.run (.mk hc hm) (.cons (.release (hv.close hc)) hk) hμ⟩

theorem structural_handle {cap cap' m n clauses targets k l μ ν}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hh : Clauses source rows clauses targets) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.handle m clauses)) k μ) (.run (.mk cap' (.handle n targets)) l ν) (.E_Handle rfl) := by
  exact ⟨_,.E_Handle rfl,.run (.mk hc hm) (.cons (.handleF hc hh) hk) hμ⟩

theorem structural_operation {q r op ts vs ws k l μ ν beforeFrames hcap clauses rest clause location}
    (first : q.view = .app (.op op ts) vs) (second : r.view = .app (.op op ts) ws)
    (ha : Values source rows vs ws) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (split : SplitAt (.user op) k beforeFrames hcap clauses rest)
    (found : findClause clauses (.user op) = some clause) (fresh : μ location = none) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_Op first split found fresh) := by
  obtain ⟨before,targetCap,targetClauses,after,targetSplit,hbefore,hcapRel,clausesRel,hafter⟩ := hk.splitAt split
  have selected := clausesRel.findClause (.user op)
  rw [found] at selected
  obtain ⟨targetClause,targetFound,clauseRel⟩ := optionRel_some selected
  exact ⟨_,.E_Op second targetSplit targetFound (hμ.fresh fresh),
    .run (.mk (hcapRel.extendMany (ha.append (.cons (.location location) .nil))) (clauseRel.body.substTy 0 ts []))
      (.cons (.drop location) hafter)
      (hμ.set (.cont (hbefore.append (.cons (.handleF hcapRel clausesRel) .nil))))⟩

theorem structural_primitive_operation {q r name ts es rs vs ws signature k l μ ν beforeFrames hcap clauses rest clause location}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) vs)
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) ws)
    (sourceSig : B.sig name = some signature) (targetSig : C.sig name = some signature)
    (kind : signature.kind = .io ∨ signature.kind = .exit)
    (ha : Values source rows vs ws) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (split : SplitAt (.prim name) k beforeFrames hcap clauses rest)
    (found : findClause clauses (.prim name) = some clause) (fresh : μ location = none) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_OpPrim first sourceSig kind split found fresh) := by
  obtain ⟨before,targetCap,targetClauses,after,targetSplit,hbefore,hcapRel,clausesRel,hafter⟩ := hk.splitAt split
  have selected := clausesRel.findClause (.prim name)
  rw [found] at selected
  obtain ⟨targetClause,targetFound,clauseRel⟩ := optionRel_some selected
  exact ⟨_,
    .E_OpPrim second targetSig kind targetSplit targetFound (hμ.fresh fresh),
    .run (.mk (hcapRel.extendMany (ha.append (.cons (.location location) .nil))) (clauseRel.body.substTy 0 ts []))
      (.cons (.drop location) hafter)
      (hμ.set (.cont (hbefore.append (.cons (.handleF hcapRel clausesRel) .nil))))⟩

theorem structural_lazy {cap cap' m n k l μ ν location}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) (fresh : μ location = none) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.lazyC m)) k μ) (.run (.mk cap' (.lazyC n)) l ν) (.E_Lazy rfl fresh) := by
  exact ⟨_,.E_Lazy rfl (hμ.fresh fresh),
    .run (.pure (.ret (.location location))) hk (hμ.set (.thunk (.mk hc hm)))⟩

theorem structural_update {cap cap' v w k l μ ν location}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ret v)) (.update location :: k) μ)
      (.run (.mk cap' (.ret w)) (.update location :: l) ν) (.E_Update rfl) := by
  exact ⟨_,.E_Update rfl,
    .run (.pure (.ret (hv.close hc))) hk (hμ.set (.done (hv.close hc)))⟩

theorem StoreRel.lookup {source rows μ ν location cell} (h : StoreRel source rows μ ν)
    (found : μ location = some cell) : ∃ target, ν location = some target ∧ CellRel source rows cell target := by
  have related := h location
  rw [found] at related
  exact optionRel_some related

theorem structural_drop_used {cap cap' v w k l μ ν location}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (found : μ location = some .used) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ret v)) (.drop location :: k) μ)
      (.run (.mk cap' (.ret w)) (.drop location :: l) ν) (.E_Drop rfl found) := by
  obtain ⟨target,targetFound,related⟩ := hμ.lookup found
  cases related with
  | used => exact ⟨_,.E_Drop rfl targetFound,.run (.pure (.ret (hv.close hc))) hk hμ⟩

theorem structural_drop_continuation {cap cap' v w k l μ ν location saved}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (found : μ location = some (.cont saved)) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ret v)) (.drop location :: k) μ)
      (.run (.mk cap' (.ret w)) (.drop location :: l) ν) (.E_DropRel rfl found) := by
  obtain ⟨target,targetFound,related⟩ := hμ.lookup found
  cases related with
  | cont continuation => exact ⟨_,.E_DropRel rfl targetFound,
      .run (.pure (.ret (hv.close hc))) (continuation.releases.append hk) (hμ.set .used)⟩

theorem structural_mark {cap cap' v w k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ret v)) (.mark :: k) μ) (.run (.mk cap' (.ret w)) (.mark :: l) ν) (.E_Mark rfl) := by
  exact ⟨_,.E_Mark rfl,.run (.pure (.ret (hv.close hc))) hk hμ⟩

theorem structural_handle_return {cap cap' v w hcap hcap' clauses targets k l μ ν}
    (hc : Captures source rows cap cap') (hv : Value source rows v w)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.ret v)) (.handleF hcap clauses :: k) μ)
      (.run (.mk cap' (.ret w)) (.handleF hcap' targets :: l) ν) (.E_HRet rfl) := by
  exact ⟨_,.E_HRet rfl,.run (.pure (.ret (hv.close hc))) hk hμ⟩

/-- 解放とdropを除き、失敗・終了時に無観測で取り除くフレーム。 -/
inductive PassiveFrame : Frame → Prop
  | letF (q) : PassiveFrame (.letF q)
  | mark : PassiveFrame .mark
  | update (location) : PassiveFrame (.update location)
  | handleF (cap clauses) : PassiveFrame (.handleF cap clauses)
  | guardF (value cap arms next body) : PassiveFrame (.guardF value cap arms next body)

theorem structural_error_pop {frame target errors k l μ ν}
    (passive : PassiveFrame frame) (related : FrameRel source rows frame target)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.error errors (frame :: k) μ) (.error errors (target :: l) ν) (destination := .error errors k μ) (by cases passive <;> first | exact .E_ErrPopLet | exact .E_ErrPopMark | exact .E_ErrPopUpdate | exact .E_ErrPopHandle | exact .E_ErrPopGuard) := by
  cases passive <;> cases related <;> first
    | exact ⟨_,.E_ErrPopLet,.error hk hμ⟩
    | exact ⟨_,.E_ErrPopMark,.error hk hμ⟩
    | exact ⟨_,.E_ErrPopUpdate,.error hk hμ⟩
    | exact ⟨_,.E_ErrPopHandle,.error hk hμ⟩
    | exact ⟨_,.E_ErrPopGuard,.error hk hμ⟩

theorem structural_exit_pop {frame target code errors k l μ ν}
    (passive : PassiveFrame frame) (related : FrameRel source rows frame target)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.exit code errors (frame :: k) μ) (.exit code errors (target :: l) ν) (destination := .exit code errors k μ) (by cases passive <;> first | exact .E_ExitPopLet | exact .E_ExitPopMark | exact .E_ExitPopUpdate | exact .E_ExitPopHandle | exact .E_ExitPopGuard) := by
  cases passive <;> cases related <;> first
    | exact ⟨_,.E_ExitPopLet,.exit hk hμ⟩
    | exact ⟨_,.E_ExitPopMark,.exit hk hμ⟩
    | exact ⟨_,.E_ExitPopUpdate,.exit hk hμ⟩
    | exact ⟨_,.E_ExitPopHandle,.exit hk hμ⟩
    | exact ⟨_,.E_ExitPopGuard,.exit hk hμ⟩

theorem structural_builder {cap cap' kind m n k l μ ν location}
    (hc : Captures source rows cap cap') (hm : Code source rows m n)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) (fresh : μ location = none) :
    SynchronizedAt source rows P Q B C σ
      (.run (.mk cap (.builderLet kind m)) k μ) (.run (.mk cap' (.builderLet kind n)) l ν) (.E_BuilderNew rfl fresh) := by
  have kinds : substKind cap.env kind = substKind cap'.env kind := by
    cases kind <;> simp only [substKind, substTyValues_eq hc.env]
  have body : Code source rows (m.subst builderValueSubst (builderLocalSubst location))
      (n.subst builderValueSubst (builderLocalSubst location)) :=
    hm.subst _ _ _ (fun i => Value.refl _) simple_builder_substitution
  have empty : BuilderRel source rows (substKind cap.env kind).empty (substKind cap'.env kind).empty := by
    rw [kinds]
    cases substKind cap'.env kind <;> first | exact .string _ | exact .bytes _ | exact .list .nil
  exact ⟨_,.E_BuilderNew rfl (hμ.fresh fresh),
    .run (.mk hc body) hk (hμ.set (.builder empty))⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
