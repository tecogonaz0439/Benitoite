import Benitoite.Release.Refinement.CallBodyScope

/-! # 実行時のコードの型置換による閉性と固定した起点の保持 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem type_inst_wf {ts : List Ty} {es : List Eff} {c nv : Nat} {a : Ty}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (h : a.WF 0 (c+ts.length) nv) :
    (a.substAt c ts es).WF 0 c nv := by
  simpa only [Nat.zero_add] using Ty.substAt_wf c ts es
    (type_image_value_wf ht nv) (row_image_value_wf he nv) ho a h

private theorem types_inst_wf {ts as : List Ty} {es : List Eff} {c nv : Nat}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (h : ∀ a ∈ as, a.WF 0 (c+ts.length) nv) :
    ∀ a ∈ as.map (substTypeAt c ts es), a.WF 0 c nv := by
  intro a ha
  obtain ⟨b,hb,rfl⟩ := List.mem_map.mp ha
  exact type_inst_wf ht he ho (h b hb)

private theorem rows_inst_wf {ts : List Ty} {es fs : List Eff} {c nv : Nat}
    (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
    (ho : ∀ a ∈ ts, Ordinary a) (h : ∀ f ∈ fs, f.WF 0 (c+ts.length) nv ∧ f.Canonical) :
    ∀ f ∈ fs.map (substRowAt c ts es), f.WF 0 c nv ∧ f.Canonical := by
  intro f hf
  obtain ⟨g,hg,rfl⟩ := List.mem_map.mp hf
  exact ⟨by simpa only [Nat.zero_add,Eff.substAt] using (Eff.substAt_wf c ts es
    (type_image_value_wf ht nv) (row_image_value_wf he nv) ho g (h g hg).1),
    Eff.norm_idem _⟩

mutual
  theorem Val.ClosedAt.runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {v : Val}
      (h : v.ClosedAt (c+ts.length) nv) {σ : PathEnv} (had : v.Adequate σ)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      (v.substTyAt c ts es).ClosedAt c nv ∧ (v.substTyAt c ts es).Adequate σ := by
    cases v
    case var => exact ⟨h,had⟩
    case const => exact ⟨h,had⟩
    case loc => exact ⟨h,had⟩
    case bytesV => exact ⟨h,had⟩
    case checked => exact ⟨h,had⟩
    case pathBases => exact ⟨h,had⟩
    case scopePattern => exact ⟨h,had⟩
    case atError => exact ⟨h,had⟩
    case checkedAt r snapshot target req => cases req <;> exact ⟨h,had⟩
    case checkedRequest => exact ⟨h,had⟩
    case closure => exact ⟨h,had⟩
    case fnRef => exact ⟨⟨types_inst_wf ht he ho h.1,rows_inst_wf ht he ho h.2⟩,trivial⟩
    case prim => exact ⟨⟨types_inst_wf ht he ho h.1,rows_inst_wf ht he ho h.2.1,h.2.2⟩,trivial⟩
    case externalRef => exact ⟨types_inst_wf ht he ho h,trivial⟩
    case externalHandle => exact ⟨types_inst_wf ht he ho h,trivial⟩
    case op => exact ⟨types_inst_wf ht he ho h,trivial⟩
    case raise => exact ⟨⟨type_inst_wf ht he ho h.1,type_inst_wf ht he ho h.2⟩,trivial⟩
    case con n as vs =>
      have hh := closedValues_runtime_type_inst h.2 had ht he ho
      exact ⟨⟨types_inst_wf ht he ho h.1,hh.1⟩,hh.2⟩
    case dict n as vs =>
      have hh := closedValues_runtime_type_inst h.2 had ht he ho
      exact ⟨⟨types_inst_wf ht he ho h.1,hh.1⟩,hh.2⟩
    case list vs => exact closedValues_runtime_type_inst h had ht he ho
    case setV vs => exact closedValues_runtime_type_inst h had ht he ho
    case mapV ks vs =>
      have hk := closedValues_runtime_type_inst h.1 had.1 ht he ho
      have hv := closedValues_runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hk.1,hv.1⟩,hk.2,hv.2⟩
    case super v s => exact Val.ClosedAt.runtime_type_inst (v := v) h had ht he ho
    case lam ns ps body =>
      have hb := Comp.ClosedAt.runtime_type_inst h.2.2 had ht he ho
      simpa only [Val.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        List.length_map,Val.ClosedAt,Val.Adequate] using
        And.intro (And.intro (show NamesWF ns (ps.map (substTypeAt c ts es)) from
          ⟨by simpa only [List.length_map] using h.1.1,h.1.2⟩)
          (And.intro (types_inst_wf ht he ho h.2.1) hb.1)) hb.2
    case dependentLam t body =>
      have hb := Comp.ClosedAt.runtime_type_inst h.2 had ht he ho
      have hi := typeEnvAt_wfImages c ts es (type_image_value_wf ht nv) (row_image_value_wf he nv) ho
      have hw := Tel.bind_wf t h.1 hi
      simpa only [Val.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        Val.ClosedAt,Val.Adequate,telBinders_bind,Nat.zero_add] using And.intro (And.intro hw hb.1) hb.2
  termination_by structural v
  theorem closedValues_runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {vs : List Val}
      (h : Val.ClosedList (c+ts.length) nv vs) {σ : PathEnv} (had : adequateVals σ vs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      Val.ClosedList c nv (Val.substTyAtList c ts es vs) ∧ adequateVals σ (Val.substTyAtList c ts es vs) := by
    cases vs with
    | nil => exact ⟨trivial,trivial⟩
    | cons v vs =>
      have hv := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hs := closedValues_runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hv.1,hs.1⟩,hv.2,hs.2⟩
  termination_by structural vs
  theorem Comp.ClosedAt.runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {m : Comp}
      (h : m.ClosedAt (c+ts.length) nv) {σ : PathEnv} (had : m.Adequate σ)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      (m.substTyAt c ts es).ClosedAt c nv ∧ (m.substTyAt c ts es).Adequate σ := by
    cases m
    case ret v => exact Val.ClosedAt.runtime_type_inst h had ht he ho
    case escape v => exact Val.ClosedAt.runtime_type_inst h had ht he ho
    case app f vs =>
      have hf := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hvs := closedValues_runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hf.1,hvs.1⟩,hf.2,hvs.2⟩
    case letIn m n =>
      have hm := Comp.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hn := Comp.ClosedAt.runtime_type_inst h.2 had.2 ht he ho
      simpa only [Comp.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        Comp.ClosedAt,Comp.Adequate] using And.intro (And.intro hm.1 hn.1) (And.intro hm.2 hn.2)
    case ite v m n =>
      have hv := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hm := Comp.ClosedAt.runtime_type_inst h.2.1 had.2.1 ht he ho
      have hn := Comp.ClosedAt.runtime_type_inst h.2.2 had.2.2 ht he ho
      exact ⟨⟨hv.1,hm.1,hn.1⟩,hv.2,hm.2,hn.2⟩
    case «match» v arms =>
      have hv := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have ha := closedArms_runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hv.1,ha.1⟩,hv.2,ha.2⟩
    case lazyC m => exact Comp.ClosedAt.runtime_type_inst (m := m) h had ht he ho
    case use v m =>
      have hv := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hm := Comp.ClosedAt.runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hv.1,hm.1⟩,hv.2,hm.2⟩
    case handle m cs =>
      have hm := Comp.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hc := closedClauses_runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hm.1,hc.1⟩,hm.2,hc.2⟩
    case resume k v =>
      have hk := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hv := Val.ClosedAt.runtime_type_inst h.2 had.2 ht he ho
      exact ⟨⟨hk.1,hv.1⟩,hk.2,hv.2⟩
    case externalCall f as vs =>
      have hv := closedValues_runtime_type_inst h.2 had ht he ho
      exact ⟨⟨types_inst_wf ht he ho h.1,hv.1⟩,hv.2⟩
    case issuePathBases => exact ⟨h,had⟩
    case meth v name as fs vs =>
      have hv := Val.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
      have hvs := closedValues_runtime_type_inst h.2.2.2 had.2 ht he ho
      exact ⟨⟨hv.1,types_inst_wf ht he ho h.2.1,rows_inst_wf ht he ho h.2.2.1,hvs.1⟩,hv.2,hvs.2⟩
    case builderLet kind body =>
      have hb := Comp.ClosedAt.runtime_type_inst h.2 had ht he ho
      cases kind <;> simp only [Comp.substTyAt,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
        Comp.ClosedAt,Comp.Adequate] <;> exact ⟨⟨by first | trivial | exact type_inst_wf ht he ho h.1,hb.1⟩,hb.2⟩
    case builderOp kind op ref vs =>
      have hv := closedValues_runtime_type_inst h.2.2 had ht he ho
      cases kind <;> cases ref
      all_goals exact ⟨⟨by first | trivial | exact type_inst_wf ht he ho h.1,h.2.1,hv.1⟩,hv.2⟩
    case checkAt k o sh bs p v ix =>
      cases bs
      all_goals
        have hp := Val.ClosedAt.runtime_type_inst h.2.2.2.1 had.2.1 ht he ho
        have hv := Val.ClosedAt.runtime_type_inst h.2.2.2.2 had.2.2 ht he ho
        first
        | exact ⟨⟨type_inst_wf ht he ho h.1,h.2.1,trivial,hp.1,hv.1⟩,trivial,hp.2,hv.2⟩
        | skip
      case some b =>
          have hp := Val.ClosedAt.runtime_type_inst h.2.2.2.1 had.2.1 ht he ho
          have hv := Val.ClosedAt.runtime_type_inst h.2.2.2.2 had.2.2 ht he ho
          have hb := Val.ClosedAt.runtime_type_inst h.2.2.1 had.1 ht he ho
          exact ⟨⟨type_inst_wf ht he ho h.1,h.2.1,hb.1,hp.1,hv.1⟩,hb.2,hp.2,hv.2⟩
  termination_by structural m
  theorem closedArms_runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {arms : List Arm}
      (h : Arm.ClosedList (c+ts.length) nv arms) {σ : PathEnv} (had : adequateArms σ arms)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      Arm.ClosedList c nv (Arm.substTyAtList c ts es arms) ∧ adequateArms σ (Arm.substTyAtList c ts es arms) := by
    cases arms with
    | nil => exact ⟨trivial,trivial⟩
    | cons a arms =>
      cases a with
      | mk alts guard body =>
        cases guard with
        | none =>
          have hb := Comp.ClosedAt.runtime_type_inst h.2.1 had.2.1 ht he ho
          have hs := closedArms_runtime_type_inst h.2.2 had.2.2 ht he ho
          simpa only [Arm.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
            Arm.ClosedList,adequateArms] using And.intro (And.intro trivial (And.intro hb.1 hs.1))
              (And.intro trivial (And.intro hb.2 hs.2))
        | some g =>
          have hb := Comp.ClosedAt.runtime_type_inst h.2.1 had.2.1 ht he ho
          have hs := closedArms_runtime_type_inst h.2.2 had.2.2 ht he ho
          have hg := Comp.ClosedAt.runtime_type_inst h.1 had.1 ht he ho
          simpa only [Arm.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
            Arm.ClosedList,adequateArms] using And.intro (And.intro hg.1 (And.intro hb.1 hs.1))
              (And.intro hg.2 (And.intro hb.2 hs.2))
  termination_by structural arms
  theorem closedClauses_runtime_type_inst {ts : List Ty} {es : List Eff} {c nv : Nat} {cs : List Clause}
      (h : Clause.ClosedList (c+ts.length) nv cs) {σ : PathEnv} (had : adequateClauses σ cs)
      (ht : ∀ a ∈ ts, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0)
      (ho : ∀ a ∈ ts, Ordinary a) :
      Clause.ClosedList c nv (Clause.substTyAtList c ts es cs) ∧ adequateClauses σ (Clause.substTyAtList c ts es cs) := by
    cases cs with
    | nil => exact ⟨trivial,trivial⟩
    | cons cl cs =>
      cases cl with
      | mk o n k m =>
        have hm := Comp.ClosedAt.runtime_type_inst (c := c+k) (by simpa only [Nat.add_right_comm] using h.1) had.1 ht he ho
        have hs := closedClauses_runtime_type_inst h.2 had.2 ht he ho
        simpa only [Clause.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
          Clause.ClosedList,adequateClauses] using And.intro (And.intro hm.1 hs.1) (And.intro hm.2 hs.2)
      | fail e m =>
        have hm := Comp.ClosedAt.runtime_type_inst (c := c+1) (by simpa only [Nat.add_right_comm] using h.2.1) had.1 ht he ho
        have hs := closedClauses_runtime_type_inst h.2.2 had.2 ht he ho
        simpa only [Clause.substTyAtList,map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he,
          Clause.ClosedList,adequateClauses,Ty.substAt] using And.intro
            (And.intro (type_inst_wf ht he ho h.1) (And.intro hm.1 hs.1)) (And.intro hm.2 hs.2)
  termination_by structural cs
end

end
end Benitoite.Release.Refinement
