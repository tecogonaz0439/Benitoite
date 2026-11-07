import Benitoite.Release.Refinement.Surface.PredicateSimulationNameAlgebra
import Benitoite.Release.Refinement.Surface.PredicateSimulationPatternAvoid
import Benitoite.Release.Refinement.Surface.PredicateSimulationAdministrativePath

/-! # 捕捉・継続・viewの生成名の不在

全捕捉スロットと閉包本体のinventoryを保持し、実規則が読む同じ値と本体へ分解する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

theorem ClosureAvoid.capture {keys q} (avoid : ClosureAvoid keys q) : CaptureAvoid keys q.capture := by
  cases q
  exact (NamesAvoid.append.mp avoid).1

theorem ClosureAvoid.code {keys q} (avoid : ClosureAvoid keys q) : CodeAvoid keys q.code := by
  cases q
  exact (NamesAvoid.append.mp avoid).2

theorem ClosureAvoid.apply {keys q values} (avoid : ClosureAvoid keys q) (arguments : ValuesAvoid keys values) :
    ClosureAvoid keys (q.apply values) := by
  cases q
  exact NamesAvoid.append.mpr ⟨avoid.capture.extendMany arguments,avoid.code⟩

theorem ClosureAvoid.instantiate {keys q values} (avoid : ClosureAvoid keys q) (arguments : ValuesAvoid keys values)
    (types : List Ty) (effects : List Eff) : ClosureAvoid keys (q.instantiate types effects values) := by
  cases q
  exact NamesAvoid.append.mpr ⟨avoid.capture.extendMany arguments,avoid.code.substTy 0 types effects⟩

private theorem slots_avoid_map {keys values f} (avoid : NamesAvoid keys (slotsNames values))
    (preserves : ∀ value, ValueAvoid keys value → ValueAvoid keys (f value)) :
    NamesAvoid keys (slotsNames (values.map (Option.map f))) := by
  induction values with
  | nil => exact NamesAvoid.nil _
  | cons value values ih =>
    obtain ⟨head,tail⟩ := NamesAvoid.append.mp avoid
    cases value with
    | none => exact ih tail
    | some value => exact NamesAvoid.append.mpr ⟨preserves value head,ih tail⟩

theorem CaptureAvoid.instR {keys cap} (avoid : CaptureAvoid keys cap) (ranges : List RangeExpr) :
    CaptureAvoid keys (cap.instR ranges) := by
  cases ranges with
  | nil => exact avoid
  | cons range ranges =>
    cases cap
    exact slots_avoid_map avoid (fun value fresh => fresh.instR (range :: ranges))

theorem ClosureAvoid.instR {keys q} (avoid : ClosureAvoid keys q) (ranges : List RangeExpr) :
    ClosureAvoid keys (q.instR ranges) := by
  cases ranges with
  | nil => exact avoid
  | cons range ranges =>
    cases q
    exact NamesAvoid.append.mpr ⟨avoid.capture.instR (range :: ranges),avoid.code.instR (range :: ranges)⟩

theorem ClosureAvoid.view {keys q} (avoid : ClosureAvoid keys q) : CodeAvoid keys q.view := by
  cases q with
  | mk cap body =>
    have capture := avoid.capture
    have code := avoid.code
    cases body with
    | ret value => exact ValueAvoid.close (value := value) code capture
    | escape value => exact ValueAvoid.close (value := value) code capture
    | app function values =>
      obtain ⟨head,arguments⟩ := NamesAvoid.append.mp code
      exact NamesAvoid.append.mpr ⟨ValueAvoid.close (value := function) head capture,
        valuesNames_avoid.mpr ((valuesNames_avoid.mp arguments).close capture)⟩
    | builderOp kind op localRef values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp code).close capture)
    | ite value yes no =>
      obtain ⟨heads,hno⟩ := NamesAvoid.append.mp code
      obtain ⟨hv,hyes⟩ := NamesAvoid.append.mp heads
      exact NamesAvoid.append.mpr ⟨NamesAvoid.append.mpr ⟨ValueAvoid.close (value := value) hv capture,hyes⟩,hno⟩
    | «match» value arms =>
      obtain ⟨hv,ha⟩ := NamesAvoid.append.mp code
      exact NamesAvoid.append.mpr ⟨ValueAvoid.close (value := value) hv capture,ha⟩
    | use value body =>
      obtain ⟨hv,hm⟩ := NamesAvoid.append.mp code
      exact NamesAvoid.append.mpr ⟨ValueAvoid.close (value := value) hv capture,hm⟩
    | resume continuation value =>
      obtain ⟨hk,hv⟩ := NamesAvoid.append.mp code
      exact NamesAvoid.append.mpr ⟨ValueAvoid.close (value := continuation) hk capture,ValueAvoid.close (value := value) hv capture⟩
    | externalCall function types values => exact valuesNames_avoid.mpr ((valuesNames_avoid.mp code).close capture)
    | checkAt kind name shape bases pattern input index =>
      cases bases with
      | none =>
        obtain ⟨hp,hi⟩ := NamesAvoid.append.mp code
        exact NamesAvoid.append.mpr ⟨ValueAvoid.close (value := pattern) hp capture,ValueAvoid.close (value := input) hi capture⟩
      | some value =>
        obtain ⟨heads,hi⟩ := NamesAvoid.append.mp code
        obtain ⟨hb,hp⟩ := NamesAvoid.append.mp heads
        exact NamesAvoid.append.mpr ⟨NamesAvoid.append.mpr ⟨ValueAvoid.close (value := value) hb capture,
          ValueAvoid.close (value := pattern) hp capture⟩,ValueAvoid.close (value := input) hi capture⟩
    | meth dictionary name types effects values =>
      obtain ⟨hd,ha⟩ := NamesAvoid.append.mp code
      exact NamesAvoid.append.mpr ⟨ValueAvoid.close (value := dictionary) hd capture,
        valuesNames_avoid.mpr ((valuesNames_avoid.mp ha).close capture)⟩
    | _ => exact code

theorem ContAvoid.append {keys first rest} (a : ContAvoid keys first) (b : ContAvoid keys rest) : ContAvoid keys (first ++ rest) := by
  intro frame member
  rcases List.mem_append.mp member with member | member
  · exact a frame member
  · exact b frame member

theorem ContAvoid.markPush {keys k} (avoid : ContAvoid keys k) : ContAvoid keys (markPush k) := by
  cases k with
  | nil => exact ContAvoid.cons.mpr ⟨trivial,ContAvoid.nil _⟩
  | cons frame rest => cases frame <;> first | exact avoid | exact ContAvoid.cons.mpr ⟨trivial,avoid⟩

theorem ContAvoid.member {keys k frame} (avoid : ContAvoid keys k) (member : frame ∈ k) : FrameAvoid keys frame := avoid frame member

theorem StoreAvoid.lookup {keys μ location cell} (avoid : StoreAvoid keys μ) (found : μ location = some cell) : CellAvoid keys cell :=
  avoid location cell found

theorem ValueAvoid.instantiate {keys value values} (avoid : ValueAvoid keys value) (arguments : ValuesAvoid keys values) :
    ValueAvoid keys (value.instantiate values) := avoid.close ((CaptureAvoid.empty keys).extendMany arguments)

theorem ValueAvoid.superStep {keys P value result} (program : ProgramAvoid keys P)
    (avoid : ValueAvoid keys value) (found : value.superStep P = some result) : ValueAvoid keys result := by
  cases value with
  | super inner index => cases inner with
    | dict name types arguments =>
      have argumentsFresh : ValuesAvoid keys arguments := valuesNames_avoid.mp avoid
      cases implementationFound : P.impls name with
      | none => simp only [Val.superStep,implementationFound] at found; cases found
      | some implementation =>
        simp only [Val.superStep,implementationFound] at found
        obtain ⟨value,selected,rfl⟩ := Option.map_eq_some_iff.mp found
        have original := (program.2 name implementation implementationFound).2 index value selected
        exact (original.substTy 0 types []).instantiate argumentsFresh
    | super inner nested =>
      change Option.map (fun result => Val.super result index) ((Val.super inner nested).superStep P) = some result at found
      obtain ⟨value,selected,rfl⟩ := Option.map_eq_some_iff.mp found
      exact ValueAvoid.superStep (value := Val.super inner nested) (result := value) program avoid selected
    | _ => cases found
  | _ => cases found
termination_by sizeOf value

/-- 管理用の六規則は、外部応答やsource型付けを使わず全inventoryの不在を保つ。 -/
theorem AdministrativeStep.noMint {source keys first last} (step : AdministrativeStep source first last)
    (avoid : StateAvoid keys first) : StateAvoid keys last := by
  cases step with
  | letIn cap first rest k μ =>
    obtain ⟨closure,cont,store⟩ := avoid
    have capture := closure.capture
    obtain ⟨left,right⟩ := CodeAvoid.letIn.mp closure.code
    exact ⟨ClosureAvoid.mk.mpr ⟨capture,left⟩,
      ContAvoid.cons.mpr ⟨ClosureAvoid.mk.mpr ⟨capture,right⟩,cont⟩,store⟩
  | returnValue view =>
    obtain ⟨closure,cont,store⟩ := avoid
    obtain ⟨next,rest⟩ := ContAvoid.cons.mp cont
    have value := closure.view
    rw [view] at value
    exact ⟨next.apply (ValuesAvoid.cons.mpr ⟨value,ValuesAvoid.nil _⟩),rest,store⟩
  | getter step missing accessor declaration count cap receiver next k μ view =>
    obtain ⟨closure,cont,store⟩ := avoid
    have capture := closure.capture
    have fresh : ValueAvoid keys receiver := by
      simpa only [Closure.capture,Capture.extend_env_zero] using capture.env 0
    have emptyBody : compNames (getterMatch step) = [] := by rfl
    have body : CodeAvoid keys (getterMatch step) := by
      change NamesAvoid keys (compNames (getterMatch step))
      rw [emptyBody]
      exact NamesAvoid.nil _
    exact ⟨ClosureAvoid.mk.mpr ⟨(CaptureAvoid.empty _).extendMany (ValuesAvoid.cons.mpr ⟨fresh,ValuesAvoid.nil _⟩),body⟩,
      ContAvoid.cons.mpr ⟨trivial,cont⟩,store⟩
  | matchStart view =>
    obtain ⟨closure,cont,store⟩ := avoid
    have code := closure.view
    rw [view] at code
    obtain ⟨value,arms⟩ := NamesAvoid.append.mp code
    exact ⟨value,closure.capture,arms,cont,store⟩
  | matchBody found matched zero =>
    obtain ⟨value,capture,arms,cont,store⟩ := avoid
    have arguments := value.firstAlt matched
    have body := (arms.get found).1
    exact ⟨ClosureAvoid.mk.mpr ⟨capture.extendMany arguments,body⟩,cont,store⟩
  | mark view =>
    obtain ⟨closure,cont,store⟩ := avoid
    have value := closure.view
    rw [view] at value
    exact ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,value⟩,(ContAvoid.cons.mp cont).2,store⟩

theorem AdministrativePath.noMint {source keys first last} (path : AdministrativePath source first last)
    (avoid : StateAvoid keys first) : StateAvoid keys last := by
  induction path with
  | nil state => exact avoid
  | cons step path ih => exact ih (step.noMint avoid)

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
