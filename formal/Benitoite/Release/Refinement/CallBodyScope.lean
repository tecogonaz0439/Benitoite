import Benitoite.Release.Refinement.ClosureApply
import Benitoite.Release.Refinement.TypeSubstCallSites

/-! # 宣言本体の具体化後の閉性（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section
set_option maxRecDepth 4096

theorem type_image_value_wf {ts : List Ty} (ht : ∀ a ∈ ts, a.WF 0 0 0) (nv : Nat) :
    ∀ a ∈ ts, a.WF 0 0 nv := by
  intro a ha
  have hw := Ty.wf_shiftV (ht a ha) nv 0
  simpa only [Ty.shiftV_of_wf_zero (ht a ha),Nat.zero_add] using hw

theorem row_image_value_wf {es : List Eff} (he : ∀ e ∈ es, e.WF 0 0 0) (nv : Nat) :
    ∀ e ∈ es, e.WF 0 0 nv := by
  intro e hh
  have hw := Eff.wf_shiftV (he e hh) nv 0
  simpa only [Eff.shiftV_of_wf_zero (he e hh),Nat.zero_add] using hw

theorem source_type_inst_wf {ts es c ne nv a}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : a.SourceScoped 0 (c+ts.length) ne nv) :
    (substTypeAt c ts es a).WF 0 c nv := by
  simpa only [Nat.zero_add,Ty.substAt,substTypeAt] using Ty.substAt_wf c ts es
    (type_image_value_wf ht nv) (row_image_value_wf he nv) ho a ha.1

theorem source_row_inst_wf {ts es c ne nv e}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : e.SourceScoped 0 (c+ts.length) ne nv) :
    (substRowAt c ts es e).WF 0 c nv ∧ (substRowAt c ts es e).Canonical := by
  refine ⟨?_,Eff.norm_idem _⟩
  simpa only [Nat.zero_add,Eff.substAt,substRowAt] using Eff.substAt_wf c ts es
    (type_image_value_wf ht nv) (row_image_value_wf he nv) ho e ha.1

theorem source_types_inst_wf {ts es c ne nv as}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : scopedTypes 0 (c+ts.length) ne nv as) :
    ∀ a ∈ as.map (substTypeAt c ts es), a.WF 0 c nv := by
  intro a h
  obtain ⟨b,hb,rfl⟩ := List.mem_map.mp h
  have get : ∀ b ∈ as, b.SourceScoped 0 (c+ts.length) ne nv := by
    clear h hb b
    induction as with
    | nil => intro b hb; cases hb
    | cons x xs ih =>
      intro b hb
      rcases List.mem_cons.mp hb with rfl | hb
      · exact ha.1
      · exact ih ha.2 b hb
  exact source_type_inst_wf ht he ho (get b hb)

theorem source_rows_inst_wf {ts es c ne nv fs}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (ha : scopedRows 0 (c+ts.length) ne nv fs) :
    ∀ e ∈ fs.map (substRowAt c ts es), e.WF 0 c nv ∧ e.Canonical := by
  intro e h
  obtain ⟨b,hb,rfl⟩ := List.mem_map.mp h
  have get : ∀ b ∈ fs, b.SourceScoped 0 (c+ts.length) ne nv := by
    clear h hb b
    induction fs with
    | nil => intro b hb; cases hb
    | cons x xs ih =>
      intro b hb
      rcases List.mem_cons.mp hb with rfl | hb
      · exact ha.1
      · exact ih ha.2 b hb
  exact source_row_inst_wf ht he ho (get b hb)

mutual
  theorem Val.SourceScoped.runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {v : Val}
      (h : v.SourceScoped 0 (c+ts.length) ne nv)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      (v.substTyAt c ts es).ClosedAt c nv ∧ (v.substTyAt c ts es).Adequate σ := by
    cases v <;> try (exact False.elim h)
    case var => exact ⟨h,trivial⟩
    case const => exact ⟨trivial,trivial⟩
    case bytesV => exact ⟨trivial,trivial⟩
    case scopePattern => exact ⟨trivial,trivial⟩
    case fnRef => exact ⟨⟨source_types_inst_wf ht he ho h.1,source_rows_inst_wf ht he ho h.2.1,
      fun ix hix => ⟨(h.2.2 ix hix).1, fun r heq => ((h.2.2 ix hix).2 r heq).1⟩⟩,trivial⟩
    case prim => exact ⟨⟨source_types_inst_wf ht he ho h.1,source_rows_inst_wf ht he ho h.2.1,
      fun ix hix => ⟨(h.2.2 ix hix).1, fun r heq => ((h.2.2 ix hix).2 r heq).1⟩⟩,trivial⟩
    case externalRef => exact ⟨source_types_inst_wf ht he ho h,trivial⟩
    case op => exact ⟨source_types_inst_wf ht he ho h,trivial⟩
    case raise => exact ⟨⟨source_type_inst_wf ht he ho h.1,source_type_inst_wf ht he ho h.2⟩,trivial⟩
    case con n as vs =>
      have hh := scopedValues_runtime_inst h.2 ht he ho σ
      exact ⟨⟨source_types_inst_wf ht he ho h.1,hh.1⟩,hh.2⟩
    case dict n as vs =>
      have hh := scopedValues_runtime_inst h.2 ht he ho σ
      exact ⟨⟨source_types_inst_wf ht he ho h.1,hh.1⟩,hh.2⟩
    case list vs => exact scopedValues_runtime_inst h ht he ho σ
    case setV vs => exact scopedValues_runtime_inst h ht he ho σ
    case mapV ks vs =>
      have hk := scopedValues_runtime_inst h.1 ht he ho σ
      have hv := scopedValues_runtime_inst h.2 ht he ho σ
      exact ⟨⟨hk.1,hv.1⟩,hk.2,hv.2⟩
    case super v s => exact Val.SourceScoped.runtime_inst (v := v) h ht he ho σ
    case lam ns ps body =>
      have hb := Comp.SourceScoped.runtime_inst h.2.2 ht he ho σ
      simpa only [Val.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        List.length_map,Val.ClosedAt,Val.Adequate] using
        And.intro (And.intro (show NamesWF ns (ps.map (substTypeAt c ts es)) from
          ⟨by simpa only [List.length_map] using h.1.1,h.1.2⟩)
          (And.intro (source_types_inst_wf ht he ho h.2.1) hb.1)) hb.2
    case dependentLam t body =>
      have hb := Comp.SourceScoped.runtime_inst h.2 ht he ho σ
      have hi := typeEnvAt_wfImages c ts es (type_image_value_wf ht nv) (row_image_value_wf he nv) ho
      have hw := Tel.bind_wf t h.1.1 hi
      simpa only [Val.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        Val.ClosedAt,Val.Adequate,telBinders_bind,Nat.zero_add] using And.intro (And.intro hw hb.1) hb.2
  termination_by structural v
  theorem scopedValues_runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {vs : List Val}
      (h : scopedValues 0 (c+ts.length) ne nv vs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      Val.ClosedList c nv (Val.substTyAtList c ts es vs) ∧ adequateVals σ (Val.substTyAtList c ts es vs) := by
    cases vs with
    | nil => exact ⟨trivial,trivial⟩
    | cons v vs =>
      have hv := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have hs := scopedValues_runtime_inst h.2 ht he ho σ
      exact ⟨⟨hv.1,hs.1⟩,hv.2,hs.2⟩
  termination_by structural vs
  theorem Comp.SourceScoped.runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {m : Comp}
      (h : m.SourceScoped 0 (c+ts.length) ne nv)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      (m.substTyAt c ts es).ClosedAt c nv ∧ (m.substTyAt c ts es).Adequate σ := by
    cases m
    case ret v => exact Val.SourceScoped.runtime_inst h ht he ho σ
    case escape v => exact Val.SourceScoped.runtime_inst h ht he ho σ
    case app f vs =>
      have hf := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have hvs := scopedValues_runtime_inst h.2 ht he ho σ
      exact ⟨⟨hf.1,hvs.1⟩,hf.2,hvs.2⟩
    case letIn m n =>
      have hm := Comp.SourceScoped.runtime_inst h.1 ht he ho σ
      have hn := Comp.SourceScoped.runtime_inst h.2 ht he ho σ
      simpa only [Comp.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        Comp.ClosedAt,Comp.Adequate] using And.intro (And.intro hm.1 hn.1) (And.intro hm.2 hn.2)
    case ite v m n =>
      have hv := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have hm := Comp.SourceScoped.runtime_inst h.2.1 ht he ho σ
      have hn := Comp.SourceScoped.runtime_inst h.2.2 ht he ho σ
      exact ⟨⟨hv.1,hm.1,hn.1⟩,hv.2,hm.2,hn.2⟩
    case «match» v arms =>
      have hv := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have ha := scopedArms_runtime_inst h.2 ht he ho σ
      exact ⟨⟨hv.1,ha.1⟩,hv.2,ha.2⟩
    case lazyC m => exact Comp.SourceScoped.runtime_inst (m := m) h ht he ho σ
    case use v m =>
      have hv := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have hm := Comp.SourceScoped.runtime_inst h.2 ht he ho σ
      exact ⟨⟨hv.1,hm.1⟩,hv.2,hm.2⟩
    case handle m cs =>
      have hm := Comp.SourceScoped.runtime_inst h.1 ht he ho σ
      have hc := scopedClauses_runtime_inst h.2 ht he ho σ
      exact ⟨⟨hm.1,hc.1⟩,hm.2,hc.2⟩
    case resume k v =>
      have hk := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have hv := Val.SourceScoped.runtime_inst h.2 ht he ho σ
      exact ⟨⟨hk.1,hv.1⟩,hk.2,hv.2⟩
    case externalCall f as vs =>
      have hv := scopedValues_runtime_inst h.2 ht he ho σ
      exact ⟨⟨source_types_inst_wf ht he ho h.1,hv.1⟩,hv.2⟩
    case issuePathBases => exact False.elim h
    case meth v name as fs vs =>
      have hv := Val.SourceScoped.runtime_inst h.1 ht he ho σ
      have hvs := scopedValues_runtime_inst h.2.2.2 ht he ho σ
      exact ⟨⟨hv.1,source_types_inst_wf ht he ho h.2.1,source_rows_inst_wf ht he ho h.2.2.1,hvs.1⟩,hv.2,hvs.2⟩
    case builderLet kind body =>
      have hb := Comp.SourceScoped.runtime_inst h.2 ht he ho σ
      cases kind <;> simp only [Comp.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        Comp.ClosedAt,Comp.Adequate] <;> exact ⟨⟨by first | trivial | exact source_type_inst_wf ht he ho h.1,hb.1⟩,hb.2⟩
    case builderOp kind op ref vs =>
      have hv := scopedValues_runtime_inst h.2.2 ht he ho σ
      cases kind <;> cases ref <;> first | exact False.elim h.2.1 | skip
      all_goals exact ⟨⟨by first | trivial | exact source_type_inst_wf ht he ho h.1,h.2.1,hv.1⟩,hv.2⟩
    case checkAt k o sh bs p v ix =>
      cases bs
      all_goals
        have hp := Val.SourceScoped.runtime_inst h.2.2.2.1 ht he ho σ
        have hv := Val.SourceScoped.runtime_inst h.2.2.2.2 ht he ho σ
        first
        | exact ⟨⟨source_type_inst_wf ht he ho h.1,h.2.1,trivial,hp.1,hv.1⟩,trivial,hp.2,hv.2⟩
        | have hb := Val.SourceScoped.runtime_inst h.2.2.1 ht he ho σ
          exact ⟨⟨source_type_inst_wf ht he ho h.1,h.2.1,hb.1,hp.1,hv.1⟩,hb.2,hp.2,hv.2⟩
  termination_by structural m
  theorem scopedArms_runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {arms : List Arm}
      (h : scopedArms 0 (c+ts.length) ne nv arms)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      Arm.ClosedList c nv (Arm.substTyAtList c ts es arms) ∧ adequateArms σ (Arm.substTyAtList c ts es arms) := by
    cases arms with
    | nil => exact ⟨trivial,trivial⟩
    | cons a arms =>
      cases a with
      | mk alts guard body =>
        cases guard with
        | none =>
          have hb := Comp.SourceScoped.runtime_inst h.2.1 ht he ho σ
          have hs := scopedArms_runtime_inst h.2.2 ht he ho σ
          simpa only [Arm.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
            Arm.ClosedList,adequateArms] using And.intro (And.intro trivial (And.intro hb.1 hs.1))
              (And.intro trivial (And.intro hb.2 hs.2))
        | some g =>
          have hb := Comp.SourceScoped.runtime_inst h.2.1 ht he ho σ
          have hs := scopedArms_runtime_inst h.2.2 ht he ho σ
          have hg := Comp.SourceScoped.runtime_inst h.1 ht he ho σ
          simpa only [Arm.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
            Arm.ClosedList,adequateArms] using And.intro (And.intro hg.1 (And.intro hb.1 hs.1))
              (And.intro hg.2 (And.intro hb.2 hs.2))
  termination_by structural arms
  theorem scopedClauses_runtime_inst {ts : List Ty} {es : List Eff} {c ne nv : Nat} {cs : List Clause}
      (h : scopedClauses 0 (c+ts.length) ne nv cs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) (σ : PathEnv) :
      Clause.ClosedList c nv (Clause.substTyAtList c ts es cs) ∧ adequateClauses σ (Clause.substTyAtList c ts es cs) := by
    cases cs with
    | nil => exact ⟨trivial,trivial⟩
    | cons cl cs =>
      cases cl with
      | mk o n k m =>
        have hm := Comp.SourceScoped.runtime_inst (c := c+k) (by simpa only [Nat.add_right_comm] using h.1) ht he ho σ
        have hs := scopedClauses_runtime_inst h.2 ht he ho σ
        simpa only [Clause.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
          Clause.ClosedList,adequateClauses] using And.intro (And.intro hm.1 hs.1) (And.intro hm.2 hs.2)
      | fail e m =>
        have hm := Comp.SourceScoped.runtime_inst (c := c+1) (by simpa only [Nat.add_right_comm] using h.2.1) ht he ho σ
        have hs := scopedClauses_runtime_inst h.2.2 ht he ho σ
        simpa only [Clause.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
          Clause.ClosedList,adequateClauses] using And.intro
            (And.intro (source_type_inst_wf ht he ho h.1) (And.intro hm.1 hs.1)) (And.intro hm.2 hs.2)
  termination_by structural cs
end

end
end Benitoite.Release.Refinement
