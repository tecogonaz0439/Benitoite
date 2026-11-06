import Benitoite.Release.Refinement.SafeCheckReflection

/-! # 消去の終端観測と非停止の保存 -/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open CheckErasure RefinementCheck

/-- 終端で観測する値、失敗の payload、終了のコードと payload。 -/
inductive TerminalObservation where
  | value (v : Val)
  | error (payload : List ErrKind)
  | exit (code : Int) (payload : List ErrKind)

/-- ストアの内部の表現を観測に含めず、終端の全 payload を保つ。 -/
def terminal : State → Option TerminalObservation
  | .run q [] _ => match q.view with | .ret v => some (.value v) | _ => none
  | .error rs [] _ => some (.error rs)
  | .exit n rs [] _ => some (.exit n rs)
  | _ => none

/-- 元の終端の観測は、対応する消去後の状態でも同じである。 -/
theorem terminal_forward {s t obs} (h : StateRel s t) (ho : terminal s = some obs) : terminal t = some obs := by
  cases h with
  | run hq hk hm =>
    cases hk with
    | nil =>
      simp only [terminal] at ho ⊢
      split at ho
      · next v hv =>
        have ht := (hv ▸ hq.view).ret_inv
        simpa only [ht] using ho
      · cases ho
    | cons => cases ho
  | error hk hm => cases hk with
    | nil => exact ho
    | cons => cases ho
  | exit hk hm => cases hk with
    | nil => exact ho
    | cons => cases ho
  | matchRun => cases ho

/-- 消去後の終端へ対応する元の状態は、高々根の検査一段で同じ終端観測を持つ。 -/
theorem terminal_backward {P B σ s t obs} (ha : Agreement B) (h : StateRel s t)
    (ho : terminal t = some obs) : ∃ z, Steps P B σ s [] z ∧ terminal z = some obs := by
  classical
  cases h with
  | @run q q' k k' μ μ' hq hk hm =>
    cases hk with
    | nil =>
      by_cases root : ∃ t u v cap, Site t u v ∧ q.view = call t u v ∧ q' = Closure.mk cap (.ret (ok u v))
      · obtain ⟨t,u,v,cap,site,hview,htarget⟩ := root
        cases htarget
        have first := CheckErasure.erased_step (P := P) (σ := σ) (k := []) (μ := μ)
          hview ha.signature (ha.delta t u v) (site.stable.view Capture.empty).1
          site.normalSource site.normalExpected site.core site.accepts
        rw [CheckErasure.erase_check (site.stable.view Capture.empty).1 site.normalSource site.normalExpected site.core site.accepts] at first
        exact ⟨_,.cons first .nil,by simpa only [terminal,Closure.pure,Closure.view,Closure.code,Closure.capture,site.result_static] using ho⟩
      · simp only [terminal] at ho
        split at ho
        · next v hv =>
          have hsource := hq.ret_right root hv
          exact ⟨_,.nil,by simpa only [terminal,hsource] using ho⟩
        · cases ho
    | cons => cases ho
  | error hk hm => cases hk with
    | nil => exact ⟨_,.nil,ho⟩
    | cons => cases ho
  | exit hk hm => cases hk with
    | nil => exact ⟨_,.nil,ho⟩
    | cons => cases ho
  | matchRun => cases ho

/-- 有限の事象列と終端の値・失敗 payload・終了の観測が、両方向で一致する。 -/
theorem observations_preserved {P B σ s t} (ha : Agreement B) (hr : StateRel s t) :
    ∀ evs obs,
      (∃ z, Steps P B σ s evs z ∧ terminal z = some obs) ↔
      (∃ z, Steps (eraseProgram P) B σ t evs z ∧ terminal z = some obs) := by
  intro evs obs
  constructor
  · rintro ⟨z,hs,ho⟩
    obtain ⟨z',ht,hrel⟩ := finite_forward ha hr hs
    exact ⟨z',ht,terminal_forward hrel ho⟩
  · rintro ⟨z,hs,ho⟩
    obtain ⟨z',ht,hrel⟩ := finite_backward ha hr hs
    obtain ⟨z'',hfinal,hobs⟩ := terminal_backward ha hrel ho
    exact ⟨z'',by simpa only [List.append_nil] using steps_append ht hfinal,hobs⟩

/-- 実行の段の逆向きの関係。Acc は全ての選択が有限であることを表す。 -/
def Transition (P : Program) (B : Builtins) (σ : PathEnv) (t s : State) : Prop := ∃ label, Step P B σ s label t

theorem Descends.acc {P B σ s t} (h : Descends P B σ t s) (ha : Acc (Transition P B σ) s) :
    Acc (Transition P B σ) t := by
  induction h with
  | one step => exact ha.inv ⟨_,step⟩
  | more step _ ih => exact ih (ha.inv ⟨_,step⟩)

/-- 一段の整礎性から、少なくとも一段を持つ到達の整礎性を得る。 -/
theorem descends_accessible {P B σ s} (h : Acc (Transition P B σ) s) : Acc (Descends P B σ) s := by
  induction h with
  | intro s hs ih =>
    refine Acc.intro s ?_
    intro t hpath
    cases hpath with
    | one step => exact ih _ ⟨_,step⟩
    | more step rest => exact (ih _ ⟨_,step⟩).inv rest

/-- 元の実行の全選択が有限なら、消去後の実行の全選択も有限である。 -/
theorem termination_forward {P B σ s t} (ha : Agreement B) (hr : StateRel s t)
    (ht : Acc (Transition P B σ) s) : Acc (Transition (eraseProgram P) B σ) t := by
  have hnonempty := descends_accessible ht
  induction hnonempty generalizing t with
  | intro s hs ih =>
    refine Acc.intro t ?_
    intro t' hstep
    obtain ⟨label,step⟩ := hstep
    obtain ⟨s',_,nonempty,hrel⟩ := state_reflect ha hr step
    exact ih _ nonempty hrel (nonempty.acc ht)

/-- 消去後の実行の全選択が有限なら、元の実行の全選択も有限である。省略の段は silentRank を減らす。 -/
theorem termination_backward {P B σ s t} (ha : Agreement B) (hr : StateRel s t)
    (ht : Acc (Transition (eraseProgram P) B σ) t) : Acc (Transition P B σ) s := by
  induction ht generalizing s with
  | intro t ht ih =>
    have inner : ∀ n s, silentRank s = n → StateRel s t → Acc (Transition P B σ) s := by
      intro n
      induction n using Nat.strongRecOn with
      | ind n hn =>
        intro s he hr
        refine Acc.intro s ?_
        intro s' hstep
        obtain ⟨label,step⟩ := hstep
        obtain ⟨t',hm,hrel⟩ := state_step ha hr step
        rcases hm with matched | ⟨_,rfl,less⟩
        · exact ih _ ⟨_,matched⟩ hrel
        · exact hn (silentRank s') (by simpa only [he] using less) s' rfl hrel
    exact inner (silentRank s) s rfl hr

/-- 非停止の選択があることを、整礎でない遷移として表す。 -/
def Diverges (P : Program) (B : Builtins) (σ : PathEnv) (s : State) : Prop := ¬Acc (Transition P B σ) s

/-- 停止と非停止の保存。 -/
theorem divergence_preserved {P B σ s t} (ha : Agreement B) (hr : StateRel s t) :
    Diverges P B σ s ↔ Diverges (eraseProgram P) B σ t := by
  exact not_congr ⟨termination_forward ha hr,termination_backward ha hr⟩
/-- 整礎でない実行は、ラベルと状態を持つ無限の実行をちょうど表す。 -/
theorem diverges_iff_infinite {P B σ s} :
    Diverges P B σ s ↔ ∃ labels, InfiniteExecution P B σ s labels := by
  classical
  constructor
  · intro hs
    have next : ∀ x, Diverges P B σ x → ∃ label y, Step P B σ x label y ∧ Diverges P B σ y := by
      intro x hx
      apply Classical.byContradiction
      intro h
      apply hx
      refine Acc.intro x ?_
      intro y hstep
      obtain ⟨label,step⟩ := hstep
      apply Classical.byContradiction
      intro hy
      exact h ⟨label,y,step,hy⟩
    let pick (x : {x : State // Diverges P B σ x}) : {y : State // Diverges P B σ y} :=
      ⟨Classical.choose (Classical.choose_spec (next x.val x.property)),
        (Classical.choose_spec (Classical.choose_spec (next x.val x.property))).2⟩
    let states : Nat → {x : State // Diverges P B σ x} := fun n => Nat.rec ⟨s,hs⟩ (fun _ x => pick x) n
    let labels : Nat → Option Event := fun n => Classical.choose (next (states n).val (states n).property)
    refine ⟨labels,fun n => (states n).val,rfl,?_⟩
    intro n
    exact (Classical.choose_spec (Classical.choose_spec (next (states n).val (states n).property))).1
  · rintro ⟨labels,states,start,steps⟩ acc
    have impossible : ∀ x, Acc (Transition P B σ) x →
        ∀ (states : Nat → State) (labels : Nat → Option Event), states 0 = x →
          (∀ n, Step P B σ (states n) (labels n) (states (n+1))) → False := by
      intro x hx
      induction hx with
      | intro x hx ih =>
        intro states labels start steps
        have step0 := steps 0
        rw [start] at step0
        exact ih (states 1) ⟨labels 0,step0⟩ (fun n => states (n+1)) (fun n => labels (n+1)) rfl
          (fun n => steps (n+1))
    exact impossible s acc states labels start steps

/-- 無限の実行が存在することは、消去の前後で一致する。 -/
theorem infinite_preserved {P B σ s t} (ha : Agreement B) (hr : StateRel s t) :
    (∃ labels, InfiniteExecution P B σ s labels) ↔
      (∃ labels, InfiniteExecution (eraseProgram P) B σ t labels) := by
  rw [← diverges_iff_infinite,← diverges_iff_infinite]
  exact divergence_preserved ha hr

/-- 任意の有限の事象列の後に非停止を選べることも、両方向に保存する。 -/
theorem diverging_prefixes_preserved {P B σ s t} (ha : Agreement B) (hr : StateRel s t) (evs : List Event) :
    (∃ z, Steps P B σ s evs z ∧ Diverges P B σ z) ↔
      (∃ z, Steps (eraseProgram P) B σ t evs z ∧ Diverges (eraseProgram P) B σ z) := by
  constructor
  · rintro ⟨z,hs,hd⟩
    obtain ⟨z',ht,hrel⟩ := finite_forward ha hr hs
    exact ⟨z',ht,(divergence_preserved ha hrel).mp hd⟩
  · rintro ⟨z,hs,hd⟩
    obtain ⟨z',ht,hrel⟩ := finite_backward ha hr hs
    exact ⟨z',ht,(divergence_preserved ha hrel).mpr hd⟩

/-- 同じ事象列が要求する効果の被覆を、同じ効果の下で比較する。
`Event.Covered` は事象だけを読むため、`observations_preserved` の直接の系である。
型付けの効果の保存は、`computation_preservation` が同じ効果で結論する。 -/
theorem effects_preserved {P B σ s t} (ha : Agreement B) (hr : StateRel s t)
    (Γ : Ctx) (Φ : List Pred) (ε : Eff) (events : List Event) (obs : TerminalObservation) :
    (∃ z, Steps P B σ s events z ∧ terminal z = some obs ∧ ∀ ev ∈ events, Event.Covered B Γ Φ ε ev) ↔
      (∃ z, Steps (eraseProgram P) B σ t events z ∧ terminal z = some obs ∧ ∀ ev ∈ events, Event.Covered B Γ Φ ε ev) := by
  constructor
  · rintro ⟨z,hs,ho,he⟩
    obtain ⟨z',ht,hobs⟩ := (observations_preserved ha hr events obs).mp ⟨z,hs,ho⟩
    exact ⟨z',ht,hobs,he⟩
  · rintro ⟨z,hs,ho,he⟩
    obtain ⟨z',ht,hobs⟩ := (observations_preserved ha hr events obs).mpr ⟨z,hs,ho⟩
    exact ⟨z',ht,hobs,he⟩

end
end Benitoite.Release.Refinement.SafeCheckErasure
