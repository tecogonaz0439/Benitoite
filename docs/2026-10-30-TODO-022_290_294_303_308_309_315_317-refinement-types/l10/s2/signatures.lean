import Lean
import Benitoite
namespace Benitoite.Release.Refinement

noncomputable def signature000 : Nat → Nat → Nat → Nat → Nat → Nat → SubstEnv → Prop := @SubstEnv.WFImages

-- Ty.rawShift_of_wf
theorem signature001 : ∀ {nr nv c : Nat} (k : Nat) (a : Ty) (_h : a.WF nr c nv), shiftTypes k c a = a := @Ty.rawShift_of_wf

-- Ty.rawShiftTys_of_wf
theorem signature002 : ∀ {nr nv c : Nat} (k : Nat) (as : List Ty) (_h : Ty.WFList nr c nv as), shiftTypesList k c as = as := @Ty.rawShiftTys_of_wf

-- Eff.rawShift_of_wf
theorem signature003 : ∀ {nr nv c : Nat} (k : Nat) (e : Eff) (_h : e.WF nr c nv), shiftRowsTypes k c e = e := @Eff.rawShift_of_wf

-- Tel.rawShift_of_wf
theorem signature004 : ∀ {nr nv c : Nat} (k : Nat) (t : Tel) (_h : t.WF nr c nv), shiftTelTypes k c t = t := @Tel.rawShift_of_wf

-- Ty.shift_of_wf
theorem signature005 : ∀ {nr nv c : Nat} (k : Nat) (a : Ty) (_h : a.WF nr c nv), Ty.shift k c a = a.norm := @Ty.shift_of_wf

-- Eff.shift_of_wf
theorem signature006 : ∀ {nr nv c : Nat} (k : Nat) (e : Eff) (_h : e.WF nr c nv), Eff.shift k c e = e.norm := @Eff.shift_of_wf

-- SubstEnv.WFImages.up
theorem signature007 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv}
    (_h : θ.WFImages nr nt nv mr mt mv), θ.up.WFImages nr nt (nv+1) mr mt (mv+1) := @SubstEnv.WFImages.up

-- Ty.rawBind_norm_wf
theorem signature008 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (a : Ty) (_h : a.WF nr nt nv) (_hi : θ.WFImages nr nt nv mr mt mv), (a.rawBind θ).norm.WF mr mt mv := @Ty.rawBind_norm_wf

-- rawBindTys_norm_wf
theorem signature009 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (as : List Ty) (_h : Ty.WFList nr nt nv as) (_hi : θ.WFImages nr nt nv mr mt mv), Ty.WFList mr mt mv (Ty.normTys (rawBindTys θ as)) := @rawBindTys_norm_wf

-- Eff.rawBind_norm_wf
theorem signature010 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (e : Eff) (_h : e.WF nr nt nv) (_hi : θ.WFImages nr nt nv mr mt mv), (Eff.rawBind θ e).norm.WF mr mt mv := @Eff.rawBind_norm_wf

-- Tel.rawBind_norm_wf
theorem signature011 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (t : Tel) (_h : t.WF nr nt nv) (_hi : θ.WFImages nr nt nv mr mt mv), (Tel.norm (Tel.rawBind θ t)).WF mr mt mv := @Tel.rawBind_norm_wf

-- Ty.bind_wf
theorem signature012 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (a : Ty) (_h : a.WF nr nt nv) (_hi : θ.WFImages nr nt nv mr mt mv), (a.bind θ).WF mr mt mv := @Ty.bind_wf

-- Eff.bind_wf
theorem signature013 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (e : Eff) (_h : e.WF nr nt nv) (_hi : θ.WFImages nr nt nv mr mt mv), (Eff.bind θ e).WF mr mt mv := @Eff.bind_wf

-- typeEnvAt_wfImages
theorem signature014 : ∀ {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a), (typeEnvAt c ts es).WFImages nr (c+ts.length) nv nr (n+c) nv := @typeEnvAt_wfImages

-- Ty.substAt_wf
theorem signature015 : ∀ {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a) (a : Ty) (_h : a.WF nr (c+ts.length) nv), (Ty.substAt c ts es a).WF nr (n+c) nv := @Ty.substAt_wf

-- Ty.subst_wf
theorem signature016 : ∀ {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a) (a : Ty) (_h : a.WF nr ts.length nv), (Ty.subst ts es a).WF nr n nv := @Ty.subst_wf

-- Eff.substAt_wf
theorem signature017 : ∀ {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a) (e : Eff) (_h : e.WF nr (c+ts.length) nv), (Eff.substAt c ts es e).WF nr (n+c) nv := @Eff.substAt_wf

-- Eff.subst_wf
theorem signature018 : ∀ {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a) (e : Eff) (_h : e.WF nr ts.length nv), (Eff.subst ts es e).WF nr n nv := @Eff.subst_wf

-- Ty.substList_wf
theorem signature019 : ∀ {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a) (as : List Ty) (_h : Ty.WFList nr ts.length nv as), Ty.WFList nr n nv (as.map (Ty.subst ts es)) := @Ty.substList_wf

-- Eff.AtomsWF
noncomputable def signature020 : ∀ (_nr : Nat) (_e : Eff), Prop := @Eff.AtomsWF

-- Eff.substAt_atoms_wf
theorem signature021 : ∀ {nr c : Nat} {ts : List Ty} {es : List Eff} {e : Eff}
    (_h : e.AtomsWF nr) (_he : ∀ f ∈ es, f.AtomsWF nr), (Eff.substAt c ts es e).AtomsWF nr := @Eff.substAt_atoms_wf

-- Ty.rawShift_eq_rawBind
theorem signature022 : ∀ (k c : Nat) (a : Ty), shiftTypes k c a = (a.rawBind) (SubstEnv.shiftTypes k c) := @Ty.rawShift_eq_rawBind

-- Ty.rawShiftTys_eq_rawBindTys
theorem signature023 : ∀ (k c : Nat) (as : List Ty), shiftTypesList k c as = (fun θ => rawBindTys θ as) (SubstEnv.shiftTypes k c) := @Ty.rawShiftTys_eq_rawBindTys

-- Eff.rawShift_eq_rawBind
theorem signature024 : ∀ (k c : Nat) (e : Eff), shiftRowsTypes k c e = (fun θ => Eff.rawBind θ e) (SubstEnv.shiftTypes k c) := @Eff.rawShift_eq_rawBind

-- Ty.VarsIn
noncomputable def signature025 : ∀ (_nr _nt _nv : Nat) (_pe : Nat → Prop) (_a : Ty), Prop := @Ty.VarsIn

-- Eff.VarsIn
noncomputable def signature026 : ∀ (_nr _nt _nv : Nat) (_pe : Nat → Prop) (_e : Eff), Prop := @Eff.VarsIn

-- Tel.VarsIn
noncomputable def signature027 : ∀ (_nr _nt _nv : Nat) (_pe : Nat → Prop) (_t : Tel), Prop := @Tel.VarsIn

-- Ty.VarsInList
noncomputable def signature028 : ∀ (_nr _nt _nv : Nat) (_pe : Nat → Prop) (_as : List Ty), Prop := @Ty.VarsInList

-- Ty.RowsInList.iff
theorem signature029 : ∀ {pe : Nat → Prop} {as : List Ty}, Ty.RowsInList pe as ↔ ∀ a ∈ as, a.RowsIn pe := @Ty.RowsInList.iff

-- Ty.VarsInList.iff
theorem signature030 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} {as : List Ty}, Ty.VarsInList nr nt nv pe as ↔ ∀ a ∈ as, a.VarsIn nr nt nv pe := @Ty.VarsInList.iff

-- Ty.RowsIn.mono
theorem signature031 : ∀ {pe pf : Nat → Prop} (_hp : ∀ i, pe i → pf i) (a : Ty) (_h : a.RowsIn pe), a.RowsIn pf := @Ty.RowsIn.mono

-- Ty.norm_rowsIn
theorem signature032 : ∀ {pe : Nat → Prop} (a : Ty) (_h : a.RowsIn pe), (Ty.norm a).RowsIn pe := @Ty.norm_rowsIn

-- Ty.rowsIn_true
theorem signature033 : ∀ (a : Ty), a.RowsIn (fun _ => True) := @Ty.rowsIn_true

-- Ty.VarsIn.wf
theorem signature034 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty) (_h : a.VarsIn nr nt nv pe), a.WF nr nt nv := @Ty.VarsIn.wf

-- Ty.VarsIn.rows
theorem signature035 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty) (_h : a.VarsIn nr nt nv pe), a.RowsIn pe := @Ty.VarsIn.rows

-- Ty.VarsIn.mono
theorem signature036 : ∀ {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (_ht : nt ≤ mt) (_hv : nv ≤ mv) (_hp : ∀ i, pe i → pf i) (a : Ty) (_h : a.VarsIn nr nt nv pe), a.VarsIn nr mt mv pf := @Ty.VarsIn.mono

-- Ty.norm_VarsIn
theorem signature037 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (a : Ty) (_h : a.VarsIn nr nt nv pe), (Ty.norm a).VarsIn nr nt nv pe := @Ty.norm_VarsIn

-- Eff.RowsIn.mono
theorem signature038 : ∀ {pe pf : Nat → Prop} (_hp : ∀ i, pe i → pf i) (e : Eff) (_h : e.RowsIn pe), e.RowsIn pf := @Eff.RowsIn.mono

-- Eff.norm_rowsIn
theorem signature039 : ∀ {pe : Nat → Prop} (e : Eff) (_h : e.RowsIn pe), (Eff.norm e).RowsIn pe := @Eff.norm_rowsIn

-- Eff.rowsIn_true
theorem signature040 : ∀ (e : Eff), e.RowsIn (fun _ => True) := @Eff.rowsIn_true

-- Eff.VarsIn.wf
theorem signature041 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff) (_h : e.VarsIn nr nt nv pe), e.WF nr nt nv := @Eff.VarsIn.wf

-- Eff.VarsIn.rows
theorem signature042 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff) (_h : e.VarsIn nr nt nv pe), e.RowsIn pe := @Eff.VarsIn.rows

-- Eff.VarsIn.mono
theorem signature043 : ∀ {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (_ht : nt ≤ mt) (_hv : nv ≤ mv) (_hp : ∀ i, pe i → pf i) (e : Eff) (_h : e.VarsIn nr nt nv pe), e.VarsIn nr mt mv pf := @Eff.VarsIn.mono

-- Eff.norm_VarsIn
theorem signature044 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (e : Eff) (_h : e.VarsIn nr nt nv pe), (Eff.norm e).VarsIn nr nt nv pe := @Eff.norm_VarsIn

-- Tel.RowsIn.mono
theorem signature045 : ∀ {pe pf : Nat → Prop} (_hp : ∀ i, pe i → pf i) (t : Tel) (_h : t.RowsIn pe), t.RowsIn pf := @Tel.RowsIn.mono

-- Tel.norm_rowsIn
theorem signature046 : ∀ {pe : Nat → Prop} (t : Tel) (_h : t.RowsIn pe), (Tel.norm t).RowsIn pe := @Tel.norm_rowsIn

-- Tel.rowsIn_true
theorem signature047 : ∀ (t : Tel), t.RowsIn (fun _ => True) := @Tel.rowsIn_true

-- Tel.VarsIn.wf
theorem signature048 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel) (_h : t.VarsIn nr nt nv pe), t.WF nr nt nv := @Tel.VarsIn.wf

-- Tel.VarsIn.rows
theorem signature049 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel) (_h : t.VarsIn nr nt nv pe), t.RowsIn pe := @Tel.VarsIn.rows

-- Tel.VarsIn.mono
theorem signature050 : ∀ {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (_ht : nt ≤ mt) (_hv : nv ≤ mv) (_hp : ∀ i, pe i → pf i) (t : Tel) (_h : t.VarsIn nr nt nv pe), t.VarsIn nr mt mv pf := @Tel.VarsIn.mono

-- Tel.norm_VarsIn
theorem signature051 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (t : Tel) (_h : t.VarsIn nr nt nv pe), (Tel.norm t).VarsIn nr nt nv pe := @Tel.norm_VarsIn

-- Ty.RowsInList.mono
theorem signature052 : ∀ {pe pf : Nat → Prop} (_hp : ∀ i, pe i → pf i) (as : List Ty) (_h : Ty.RowsInList pe as), Ty.RowsInList pf as := @Ty.RowsInList.mono

-- Ty.normTys_rowsIn
theorem signature053 : ∀ {pe : Nat → Prop} (as : List Ty) (_h : Ty.RowsInList pe as), Ty.RowsInList pe (Ty.normTys as) := @Ty.normTys_rowsIn

-- Ty.rowsInList_true
theorem signature054 : ∀ (as : List Ty), Ty.RowsInList (fun _ => True) as := @Ty.rowsInList_true

-- Ty.VarsInList.wf
theorem signature055 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (as : List Ty) (_h : Ty.VarsInList nr nt nv pe as), Ty.WFList nr nt nv as := @Ty.VarsInList.wf

-- Ty.VarsInList.rows
theorem signature056 : ∀ {nr nt nv : Nat} {pe : Nat → Prop} (as : List Ty) (_h : Ty.VarsInList nr nt nv pe as), Ty.RowsInList pe as := @Ty.VarsInList.rows

-- Ty.VarsInList.mono
theorem signature057 : ∀ {nr nt nv mt mv : Nat} {pe pf : Nat → Prop}
    (_ht : nt ≤ mt) (_hv : nv ≤ mv) (_hp : ∀ i, pe i → pf i) (as : List Ty) (_h : Ty.VarsInList nr nt nv pe as), Ty.VarsInList nr mt mv pf as := @Ty.VarsInList.mono

-- shiftIndex_compare
theorem signature058 : ∀ (k c i j : Nat), compare (shiftIndex k c i) (shiftIndex k c j) = compare i j := @shiftIndex_compare

-- Ty.rawShift_canonical
theorem signature059 : ∀ (k c : Nat) {a : Ty} (_h : a.Canonical), (shiftTypes k c a).Canonical := @Ty.rawShift_canonical

-- Ty.shift_canonical
theorem signature060 : ∀ (k c : Nat) (a : Ty), (Ty.shift k c a).Canonical := @Ty.shift_canonical

-- Ty.shift_zero_norm
theorem signature061 : ∀ (c : Nat) (a : Ty), Ty.shift 0 c a = a.norm := @Ty.shift_zero_norm

-- Eff.rawShift_canonical
theorem signature062 : ∀ (k c : Nat) {e : Eff} (_h : e.Canonical), (shiftRowsTypes k c e).Canonical := @Eff.rawShift_canonical

-- Eff.shift_canonical
theorem signature063 : ∀ (k c : Nat) (e : Eff), (Eff.shift k c e).Canonical := @Eff.shift_canonical

-- Eff.shift_zero_norm
theorem signature064 : ∀ (c : Nat) (e : Eff), Eff.shift 0 c e = e.norm := @Eff.shift_zero_norm

-- Ty.shift_compare_norm
theorem signature065 : ∀ (k c : Nat) (a b : Ty), tyCompare (a.shift k c) (b.shift k c) = tyCompare a.norm b.norm := @Ty.shift_compare_norm

-- Ty.shift_compare
theorem signature066 : ∀ (k c : Nat) (a b : Ty) (_ha : a.Canonical) (_hb : b.Canonical), tyCompare (a.shift k c) (b.shift k c) = tyCompare a b := @Ty.shift_compare

-- shift_map
theorem signature067 : ∀ (k c : Nat) (as : List Ty) (_ha : ∀ a ∈ as, a.Canonical), as.map (Ty.shift k c) = as.map (shiftTypes k c) := @shift_map

-- Ty.shift_compareList
theorem signature068 : ∀ (k c : Nat) (as bs : List Ty) (_ha : ∀ a ∈ as, a.Canonical) (_hb : ∀ b ∈ bs, b.Canonical), Order.treesCompare Order.labelCompare (Ty.toTrees (as.map (Ty.shift k c))) (Ty.toTrees (bs.map (Ty.shift k c))) =
    Order.treesCompare Order.labelCompare (Ty.toTrees as) (Ty.toTrees bs) := @Ty.shift_compareList

-- Ty.sortUnique_shift
theorem signature069 : ∀ (k c : Nat) (as : List Ty) (_ha : ∀ a ∈ as, a.Canonical), Order.sortUnique tyCompare (as.map (Ty.shift k c)) = (Order.sortUnique tyCompare as).map (Ty.shift k c) := @Ty.sortUnique_shift

-- Eff.Allows
noncomputable def signature070 : ∀ (_σ : PathEnv) (_κ : EffName → Option Scope.Domain.Kind) (_e : Eff)
    (_l : EffName) (_t : Scope.Domain.Target), Prop := @Eff.Allows

-- Atom.TopImage
noncomputable def signature071 : Atom → Prop := @Atom.TopImage

-- Eff.TopAtoms
noncomputable def signature072 : ∀ (_e : Eff), Prop := @Eff.TopAtoms

-- Eff.substRho
noncomputable def signature073 : ∀ (_es : List Eff) (_e : Eff), Eff := @Eff.substRho

-- Eff.memFail_singleFail
theorem signature074 : ∀ (a b : Ty), (Eff.singleFail a).memFail b ↔ a.norm = b.norm := @Eff.memFail_singleFail

-- Eff.eq_of_sub_of_sub
theorem signature075 : ∀ {e f : Eff} (_he : e.Canonical) (_hf : f.Canonical) (_hef : Eff.Sub e f) (_hfe : Eff.Sub f e), e = f := @Eff.eq_of_sub_of_sub

-- Eff.allows_norm
theorem signature076 : ∀ {σ : PathEnv} {κ : EffName → Option Scope.Domain.Kind} {e : Eff} {l : EffName} {t : Scope.Domain.Target}, Eff.Allows σ κ e.norm l t ↔ Eff.Allows σ κ e l t := @Eff.allows_norm

-- Eff.TopAtoms.norm
theorem signature077 : ∀ {e : Eff} (_h : e.TopAtoms), e.norm.TopAtoms := @Eff.TopAtoms.norm

-- Eff.substRho_empty
theorem signature078 : ∀ (es : List Eff), Eff.substRho es Eff.empty = Eff.empty := @Eff.substRho_empty

-- Eff.substRho_name
theorem signature079 : ∀ {es : List Eff} {e : Eff} {l : EffName} {ix : RangeIx} (_h : e.mem (.name l ix)), (Eff.substRho es e).mem (.name l ix) := @Eff.substRho_name

-- TypeArgsKinded
noncomputable def signature080 : ∀ (_P : Program) (_C : List TParam) (_ts : List Ty) (_ks : List TyKind), Prop := @TypeArgsKinded

-- HasTypeVQ.V_Raise
theorem signature081 : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : List TParam} {Γ : Ctx} {Φ : List Pred} {t e : Ty}, Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) →
    Ordinary t → Ordinary e →
    HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) (.fn ["error"] [e] t (Eff.singleFail e)) := @HasTypeVQ.V_Raise

-- observationWF_up
theorem signature082 : ∀ {nv mv : Nat} {ν : ObservationEnv}
    (_h : ∀ i, i < nv → ∀ t, ν i = some t → termWF mv t), ∀ i, i < nv+1 → ∀ t, upValues ν i = some t → termWF (mv+1) t := @observationWF_up

-- rawApply_notContCore
theorem signature083 : ∀ {t : Ty} (_h : t.NotContCore) (as : List Ty), (rawApply t as).NotContCore := @rawApply_notContCore

-- rawApply_wf
theorem signature084 : ∀ {nr nt nv : Nat} {t : Ty} (_ht : t.WF nr nt nv) (as : List Ty)
    (_hs : Ty.WFList nr nt nv as), (rawApply t as).WF nr nt nv := @rawApply_wf

-- Tel.bind_wf
theorem signature085 : ∀ {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (t : Tel)
    (_h : t.WF nr nt nv) (_hi : θ.WFImages nr nt nv mr mt mv), (Tel.bind θ t).WF mr mt mv := @Tel.bind_wf

-- Tel.substAt_wf
theorem signature086 : ∀ {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (_ht : ∀ a ∈ ts, a.WF nr n nv) (_he : ∀ e ∈ es, e.WF nr n nv)
    (_ho : ∀ a ∈ ts, Ordinary a) (t : Tel) (_h : t.WF nr (c+ts.length) nv), (Tel.substAt c ts es t).WF nr (n+c) nv := @Tel.substAt_wf

-- typeEnvAt_agrees_id_below
theorem signature087 : ∀ (c : Nat) (ts : List Ty), SubstEnv.AgreesBelow c (typeEnvAt c ts []) (renEnv id) := @typeEnvAt_agrees_id_below

-- Ty.substAt_nil_of_wf
theorem signature088 : ∀ {nr nv c : Nat} (ts : List Ty) (a : Ty)
    (_h : a.WF nr c nv), a.substAt c ts [] = a.norm := @Ty.substAt_nil_of_wf

-- Eff.substAt_nil_of_wf
theorem signature089 : ∀ {nr nv c : Nat} (ts : List Ty) (e : Eff)
    (_h : e.WF nr c nv), Eff.substAt c ts [] e = e.norm := @Eff.substAt_nil_of_wf

-- Tel.substAt_nil_of_wf
theorem signature090 : ∀ {nr nv c : Nat} (ts : List Ty) (t : Tel)
    (_h : t.WF nr c nv), Tel.substAt c ts [] t = Tel.norm t := @Tel.substAt_nil_of_wf

-- rowCondition
noncomputable def signature091 : ∀ (_pe : Nat → Prop), Atom → Prop := @rowCondition

-- Ty.rowsIn_iff_support
theorem signature092 : ∀ (pe : Nat → Prop) (a : Ty), a.RowsIn pe ↔ a.Support (rowCondition pe) := @Ty.rowsIn_iff_support

-- Ty.rowsInList_iff_support
theorem signature093 : ∀ (pe : Nat → Prop) (as : List Ty), Ty.RowsInList pe as ↔ Ty.SupportList (rowCondition pe) as := @Ty.rowsInList_iff_support

-- Eff.rowsIn_iff_support
theorem signature094 : ∀ (pe : Nat → Prop) (e : Eff), e.RowsIn pe ↔ e.Support (rowCondition pe) := @Eff.rowsIn_iff_support

-- Tel.rowsIn_iff_support
theorem signature095 : ∀ (pe : Nat → Prop) (t : Tel), t.RowsIn pe ↔ t.Support (rowCondition pe) := @Tel.rowsIn_iff_support

-- rangeCondition
noncomputable def signature096 : ∀ (_nr : Nat), Atom → Prop := @rangeCondition

-- Ty.rangesScoped_iff_support
theorem signature097 : ∀ {nr nt nv : Nat} (a : Ty) (_hw : a.WF nr nt nv), a.RangesScoped nr ↔ a.Support (rangeCondition nr) := @Ty.rangesScoped_iff_support

-- rangesScopedTypes_iff_support
theorem signature098 : ∀ {nr nt nv : Nat} (as : List Ty)
      (_hw : Ty.WFList nr nt nv as), rangesScopedTypes nr as ↔ Ty.SupportList (rangeCondition nr) as := @rangesScopedTypes_iff_support

-- Eff.rangesScoped_iff_support
theorem signature099 : ∀ {nr nt nv : Nat} (e : Eff) (_hw : e.WF nr nt nv), e.RangesScoped nr ↔ e.Support (rangeCondition nr) := @Eff.rangesScoped_iff_support

-- Tel.rangesScoped_iff_support
theorem signature100 : ∀ {nr nt nv : Nat} (t : Tel) (_hw : t.WF nr nt nv), t.RangesScoped nr ↔ t.Support (rangeCondition nr) := @Tel.rangesScoped_iff_support

-- Ty.varsIn_iff_sourceScoped
theorem signature101 : ∀ (nr nt ne nv : Nat) (a : Ty), a.VarsIn nr nt nv (· < ne) ↔ a.SourceScoped nr nt ne nv := @Ty.varsIn_iff_sourceScoped

-- Eff.varsIn_iff_sourceScoped
theorem signature102 : ∀ (nr nt ne nv : Nat) (e : Eff), e.VarsIn nr nt nv (· < ne) ↔ e.SourceScoped nr nt ne nv := @Eff.varsIn_iff_sourceScoped

-- substAtoms_false
theorem signature103 : ∀ (es : List Eff), substAtoms es (fun _ => false) = fun _ => false := @substAtoms_false

-- rowFails_false
theorem signature104 : ∀ (es : List Eff), rowFails es (fun _ => false) = [] := @rowFails_false

-- HasTypeVQ.dict_typeScope
theorem signature105 : ∀ {P B Ψ Q C Γ Φ v a i ts vs}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ v a) (_hv : v = .dict i ts vs), ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t := @HasTypeVQ.dict_typeScope

-- SignatureInstance.method_typeScope
theorem signature106 : ∀ {P C Γ t ss τ es} {ms : MethSig} {cd : ClassDecl}
    (_h : SignatureInstance P C Γ t (ms.tparams.map TParamDecl.kind ++ [cd.argumentKind]) (ss ++ [τ]) es), ∀ a ∈ ss ++ [τ], a.WF 0 C.length Γ.length ∧ Ordinary a := @SignatureInstance.method_typeScope

-- HasTypeCQ.method_body_typeScope
theorem signature107 : ∀ {P B Ψ Q C Γ Φ R m a e D i ts vs name ss es ws}
    (_h : HasTypeCQ P B Ψ Q C Γ Φ R m a e D)
    (_hm : m = .meth (.dict i ts vs) name ss es ws), (∀ t ∈ ss ++ ts, t.WF 0 C.length Γ.length ∧ Ordinary t) ∧
    (∀ f ∈ es, f.WF 0 C.length Γ.length) := @HasTypeCQ.method_body_typeScope

-- HasTypeVQ.raise_typeScope
theorem signature108 : ∀ {P B Ψ Q C Γ Φ v a t e}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ v a) (_hv : v = .raise t e), (t.WF 0 C.length Γ.length ∧ Ordinary t) ∧ (e.WF 0 C.length Γ.length ∧ Ordinary e) := @HasTypeVQ.raise_typeScope

-- HasTypeVQ.raise_subst_wf
theorem signature109 : ∀ {P B Ψ Q C Γ Φ t e T} {a : Ty}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (_ha : a.WF 0 1 Γ.length), (a.subst [t] []).WF 0 C.length Γ.length := @HasTypeVQ.raise_subst_wf

-- HasTypeVQ.raise_subst_le
theorem signature110 : ∀ {P B Ψ Q C Γ Φ t e T a b}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) (_hl : Ty.LeQ P Γ Φ a b), Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 [t] [])) Φ (a.subst [t] []) (b.subst [t] []) := @HasTypeVQ.raise_subst_le

-- HasTypeVQ.op_subst_wf
theorem signature111 : ∀ {P B Ψ Q C Γ Φ o ts T} {a : Ty}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) (_ha : a.WF 0 ts.length Γ.length), (a.subst ts []).WF 0 C.length Γ.length := @HasTypeVQ.op_subst_wf

-- HasTypeVQ.op_subst_le
theorem signature112 : ∀ {P B Ψ Q C Γ Φ o ts T a b}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) (_hl : Ty.LeQ P Γ Φ a b), Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 ts [])) Φ (a.subst ts []) (b.subst ts []) := @HasTypeVQ.op_subst_le

-- HasTypeVQ.op_return_subst
theorem signature113 : ∀ {P B Ψ Q C Γ Φ o ts T}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T), HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 ts [])) Φ none
      ((Comp.ret (.var 0)).substTy ts []) ((Ty.tvar 0).subst ts []) Eff.empty [] := @HasTypeVQ.op_return_subst

-- HasTypeCQ.method_subst_wf
theorem signature114 : ∀ {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D} {a : Ty}
    (_h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (_ha : a.WF 0 (ss++ts).length Γ.length), (a.subst (ss++ts) es).WF 0 C.length Γ.length := @HasTypeCQ.method_subst_wf

-- HasTypeCQ.method_subst_le
theorem signature115 : ∀ {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D a b}
    (_h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D)
    (_hl : Ty.LeQ P Γ Φ a b), Ty.LeQ P (Γ.bindTypes (typeEnvAt 0 (ss++ts) es)) Φ (a.subst (ss++ts) es) (b.subst (ss++ts) es) := @HasTypeCQ.method_subst_le

-- HasTypeCQ.method_return_subst
theorem signature116 : ∀ {P B Ψ Q C Γ Φ R i ts vs name ss es ws T e D}
    (_h : HasTypeCQ P B Ψ Q C Γ Φ R (.meth (.dict i ts vs) name ss es ws) T e D), HasTypeCQ P B Ψ Q C (Ctx.bindTypes [some (.tvar 0)] (typeEnvAt 0 (ss++ts) es)) Φ none
      ((Comp.ret (.var 0)).substTy (ss++ts) es) ((Ty.tvar 0).subst (ss++ts) es) Eff.empty [] := @HasTypeCQ.method_return_subst

-- embedTy_ordinary_iff
theorem signature117 : ∀ (a : Benitoite.Release.Ty), Ordinary (embedTy a) ↔ a.NotCont := @embedTy_ordinary_iff

-- LegacyTypesInput.of_notCont
theorem signature118 : ∀ {K P0 Δ ts ks}
    (_hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t)
    (_h : ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k), LegacyTypesInput K P0 Δ ts ks := @LegacyTypesInput.of_notCont

-- LegacyTypesInput.iff_of_notCont
theorem signature119 : ∀ {K P0 Δ ts ks} (_hc : ∀ t ∈ ts, Benitoite.Release.Ty.NotCont t), LegacyTypesInput K P0 Δ ts ks ↔
      ts.length = ks.length ∧ ∀ (i : Nat) (a : Benitoite.Release.Ty) (k : TyKind), ts[i]? = some a → ks[i]? = some k → LegacyTypeInput K P0 Δ a k := @LegacyTypesInput.iff_of_notCont

-- notCont_of_legacyVarsIn
theorem signature120 : ∀ {nr nt : Nat} {pe : Nat → Prop} {a : Benitoite.Release.Ty}
    (_h : a.VarsIn nr nt pe), a.NotCont := @notCont_of_legacyVarsIn

-- notCont_of_legacyVarsInList
theorem signature121 : ∀ {nr nt : Nat} {pe : Nat → Prop} {ts : List Benitoite.Release.Ty}
    (_h : Benitoite.Release.Ty.VarsInList nr nt pe ts), ∀ a ∈ ts, a.NotCont := @notCont_of_legacyVarsInList

-- embedTy_ordinary_of_varsIn
theorem signature122 : ∀ {nr nt : Nat} {pe : Nat → Prop} {a : Benitoite.Release.Ty}
    (_h : a.VarsIn nr nt pe), Ordinary (embedTy a) := @embedTy_ordinary_of_varsIn

-- LegacyBuilderInput.iff_of_notCont
theorem signature123 : ∀ {K P0 Δ k}
    (_h : Benitoite.Release.Ty.NotCont k.contents), LegacyBuilderInput K P0 Δ k ↔ LegacyTypeInput K P0 Δ k.contents .value := @LegacyBuilderInput.iff_of_notCont

-- LegacyValueInput.raise_of_varsIn
theorem signature124 : ∀ {K P0 B0 B Δ a e}
    (_h : Benitoite.Release.Val.VarsIn Δ.kinds.length (fun _ => True) (.raise a e))
    (_ha : LegacyTypeInput K P0 Δ a .value) (_he : LegacyTypeInput K P0 Δ e .value), LegacyValueInput K P0 B0 B Δ (.raise a e) := @LegacyValueInput.raise_of_varsIn

-- LegacyBuilderInput.iff
theorem signature125 : ∀ {K P0 Δ k}, LegacyBuilderInput K P0 Δ k ↔ LegacyTypeInput K P0 Δ k.contents .value := @LegacyBuilderInput.iff

-- Ty.HasKind.constructor_ordinary
theorem signature126 : ∀ {P K a n} (_h : Ty.HasKind P K a (.constructor n)), Ordinary a := @Ty.HasKind.constructor_ordinary

-- TypeArgsKinded.ordinary
theorem signature127 : ∀ {P C ts ks} (_h : TypeArgsKinded P C ts ks), ∀ a ∈ ts, Ordinary a := @TypeArgsKinded.ordinary

-- TypeArgsKinded.shift
theorem signature128 : ∀ {P C ts ks} (_h : TypeArgsKinded P C ts ks) (k c : Nat), TypeArgsKinded P C (ts.map (Ty.shiftV k c)) ks := @TypeArgsKinded.shift

-- TypeArgsKinded.subst
theorem signature129 : ∀ {P C ts ks} (_h : TypeArgsKinded P C ts ks) (ν : Nat → Val), TypeArgsKinded P C (ts.map (substTyValues ν)) ks := @TypeArgsKinded.subst

-- Ty.ordinary_bind_values
theorem signature130 : ∀ (a : Ty) (σ : Nat → Val), (substTyValues σ a).Ordinary ↔ a.Ordinary := @Ty.ordinary_bind_values

-- TypeArgsKinded.shiftTypes
theorem signature131 : ∀ {P C C' ts ks} (_h : TypeArgsKinded P C ts ks)
    (k c : Nat) (_hn : C'.length=C.length+k), TypeArgsKinded P C' (ts.map (shiftTypes k c)) ks := @TypeArgsKinded.shiftTypes

-- TypeArgsKinded.norm
theorem signature132 : ∀ {P C ts ks} (_h : TypeArgsKinded P C ts ks), TypeArgsKinded P C (Ty.normTys ts) ks := @TypeArgsKinded.norm

-- SignatureInstance.ordinary
theorem signature133 : ∀ {P C Γ t ks ts es}
    (_h : SignatureInstance P C Γ t ks ts es), ∀ a ∈ ts, Ordinary a := @SignatureInstance.ordinary

-- SignatureInstance.typeScope
theorem signature134 : ∀ {P C Γ t ks ts es}
    (_h : SignatureInstance P C Γ t ks ts es), ∀ a ∈ ts, a.WF 0 C.length Γ.length ∧ Ordinary a := @SignatureInstance.typeScope

-- TypeArgsKindedAt
noncomputable def signature135 : ∀ (_P : Program) (_D : List TParamDecl) (_ts : List Ty) (_ks : List TyKind), Prop := @TypeArgsKindedAt

-- TypeArgsKindedAt.forget
theorem signature136 : ∀ {P D ts ks} (_h : TypeArgsKindedAt P D ts ks), TypeArgsKinded P (D.map TParamDecl.constraints) ts ks := @TypeArgsKindedAt.forget

-- TypeArgsKindedAt.shift
theorem signature137 : ∀ {P D ts ks} (_h : TypeArgsKindedAt P D ts ks) (k c : Nat), TypeArgsKindedAt P D (ts.map (Ty.shiftV k c)) ks := @TypeArgsKindedAt.shift

-- TypeArgsKindedAt.subst
theorem signature138 : ∀ {P D ts ks} (_h : TypeArgsKindedAt P D ts ks) (ν : Nat → Val), TypeArgsKindedAt P D (ts.map (substTyValues ν)) ks := @TypeArgsKindedAt.subst

-- HasTypeCQ.operation_call
theorem signature139 : ∀ {P B Ψ R o v a e L od ts}
    (_h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o ts) [v]) a e L)
    (_hd : P.ops o = some od), ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f := @HasTypeCQ.operation_call

-- ClosureTy.pure_operation
theorem signature140 : ∀ {P B Ψ R a e o v od ts}
    (_hA : Builtins.ValueAssumptions P B) (_hw : Ψ.WF)
    (_h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (_hd : P.ops o = some od), ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f := @ClosureTy.pure_operation

-- ClosureTy.pure_operation_signature
theorem signature141 : ∀ {P B Ψ R a e o v od ts}
    (_h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (_hd : P.ops o = some od), Ty.Annotation P [] [] (.dependentFn (instantiatedTel od.tel ts [])) := @ClosureTy.pure_operation_signature

-- HasTypeVQ.op_typeScope
theorem signature142 : ∀ {P B Ψ Q C Γ Φ o ts a}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) a), ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t := @HasTypeVQ.op_typeScope

-- ClosureTy.pure_operation_typeScope
theorem signature143 : ∀ {P B Ψ R a e o v ts}
    (_h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e), ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t := @ClosureTy.pure_operation_typeScope

-- StateTyE.operation_typeScope
theorem signature144 : ∀ {P B σ Eb o ts v k μ}
    (_h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o ts) [v])) k μ)), ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t := @StateTyE.operation_typeScope

-- LegacyKindArgs
noncomputable def signature145 : ∀ (_K : DeclarationKinds) (_P0 : Benitoite.Release.Program)
    (_κ : KindCtx) (_ts : List Benitoite.Release.Ty) (_ks : List TyKind), Prop := @LegacyKindArgs

-- LegacyTypesInput
noncomputable def signature146 : ∀ (_K : DeclarationKinds) (_P0 : Benitoite.Release.Program)
    (_Δ : LegacyInputCtx) (_ts : List Benitoite.Release.Ty) (_ks : List TyKind), Prop := @LegacyTypesInput

-- LegacyBuilderInput
noncomputable def signature147 : ∀ (_K : DeclarationKinds) (_P0 : Benitoite.Release.Program)
    (_Δ : LegacyInputCtx) (_k : Benitoite.Release.BuilderKind), Prop := @LegacyBuilderInput

-- HasTypeVQ.constructor_field_inputs
theorem signature148 : ∀ {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (_hc : P.cons c = some cd)
    (_hT : T.norm.core = .data cd.data us) (_ha : cd.args[i]? = some a)
    (_valid : P.VarianceValid)
    (_targetTypes : TypeAnnotations P C Γ us) (_targetOrd : ∀ t ∈ us, Ordinary t), Ty.Annotation P C Γ (a.subst ts []) ∧ Ty.Annotation P C Γ (a.subst us []) ∧
      VarianceSubstInput P C Γ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us := @HasTypeVQ.constructor_field_inputs

-- HasTypeVQ.con_field_by_type
theorem signature149 : ∀ {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (_hc : P.cons c = some cd)
    (_hT : T.norm.core = .data cd.data us) (_ha : cd.args[i]? = some a)
    (_valid : P.VarianceValid)
    (_targetTypes : TypeAnnotations P C Γ us) (_targetOrd : ∀ t ∈ us, Ordinary t), ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v (a.subst us []) := @HasTypeVQ.con_field_by_type

-- HasTypeVQ.field_facts_by_type
theorem signature150 : ∀ {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (_h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (_hc : P.cons c = some cd)
    (_hT : T.norm.core = .data cd.data us) (_ha : cd.args[i]? = some a)
    (_valid : P.VarianceValid)
    (_targetTypes : TypeAnnotations P C Γ us) (_targetOrd : ∀ t ∈ us, Ordinary t)
    (_hs : (Val.toTermSlots vs)[i]? = some (some t)), ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t) := @HasTypeVQ.field_facts_by_type

-- Ty.shiftTypes_compare
theorem signature151 : ∀ (k c : Nat) (a b : Ty), tyCompare (shiftTypes k c a) (shiftTypes k c b) = tyCompare a b := @Ty.shiftTypes_compare

-- Ty.trees_shiftTypes_compare
theorem signature152 : ∀ (k c : Nat) (as bs : List Ty), Order.treesCompare Order.labelCompare (Ty.toTrees (shiftTypesList k c as)) (Ty.toTrees (shiftTypesList k c bs)) =
    Order.treesCompare Order.labelCompare (Ty.toTrees as) (Ty.toTrees bs) := @Ty.trees_shiftTypes_compare

-- Eff.tree_shiftTypes_compare
theorem signature153 : ∀ (k c : Nat) (e f : Eff), Order.treeCompare Order.labelCompare (Eff.toTree (shiftRowsTypes k c e)) (Eff.toTree (shiftRowsTypes k c f)) =
    Order.treeCompare Order.labelCompare (Eff.toTree e) (Eff.toTree f) := @Eff.tree_shiftTypes_compare

-- Ty.norm_shiftTypes
theorem signature154 : ∀ (a : Ty) (k c : Nat), (shiftTypes k c a).norm = shiftTypes k c a.norm := @Ty.norm_shiftTypes

-- Ty.normTys_shiftTypes
theorem signature155 : ∀ (as : List Ty) (k c : Nat), Ty.normTys (shiftTypesList k c as) = shiftTypesList k c (Ty.normTys as) := @Ty.normTys_shiftTypes

-- Eff.norm_shiftTypes
theorem signature156 : ∀ (e : Eff) (k c : Nat), (shiftRowsTypes k c e).norm = shiftRowsTypes k c e.norm := @Eff.norm_shiftTypes

-- shiftTypes_zero
theorem signature157 : ∀ (a : Ty) (c : Nat), shiftTypes 0 c a = a := @shiftTypes_zero

-- shiftTypesList_zero
theorem signature158 : ∀ (as : List Ty) (c : Nat), shiftTypesList 0 c as = as := @shiftTypesList_zero

-- shiftRowsTypes_zero
theorem signature159 : ∀ (e : Eff) (c : Nat), shiftRowsTypes 0 c e = e := @shiftRowsTypes_zero

end Benitoite.Release.Refinement
open Lean Elab Command in
run_cmd do
  let names := [
    `Benitoite.Release.Refinement.signature000,
    `Benitoite.Release.Refinement.signature001,
    `Benitoite.Release.Refinement.signature002,
    `Benitoite.Release.Refinement.signature003,
    `Benitoite.Release.Refinement.signature004,
    `Benitoite.Release.Refinement.signature005,
    `Benitoite.Release.Refinement.signature006,
    `Benitoite.Release.Refinement.signature007,
    `Benitoite.Release.Refinement.signature008,
    `Benitoite.Release.Refinement.signature009,
    `Benitoite.Release.Refinement.signature010,
    `Benitoite.Release.Refinement.signature011,
    `Benitoite.Release.Refinement.signature012,
    `Benitoite.Release.Refinement.signature013,
    `Benitoite.Release.Refinement.signature014,
    `Benitoite.Release.Refinement.signature015,
    `Benitoite.Release.Refinement.signature016,
    `Benitoite.Release.Refinement.signature017,
    `Benitoite.Release.Refinement.signature018,
    `Benitoite.Release.Refinement.signature019,
    `Benitoite.Release.Refinement.signature020,
    `Benitoite.Release.Refinement.signature021,
    `Benitoite.Release.Refinement.signature022,
    `Benitoite.Release.Refinement.signature023,
    `Benitoite.Release.Refinement.signature024,
    `Benitoite.Release.Refinement.signature025,
    `Benitoite.Release.Refinement.signature026,
    `Benitoite.Release.Refinement.signature027,
    `Benitoite.Release.Refinement.signature028,
    `Benitoite.Release.Refinement.signature029,
    `Benitoite.Release.Refinement.signature030,
    `Benitoite.Release.Refinement.signature031,
    `Benitoite.Release.Refinement.signature032,
    `Benitoite.Release.Refinement.signature033,
    `Benitoite.Release.Refinement.signature034,
    `Benitoite.Release.Refinement.signature035,
    `Benitoite.Release.Refinement.signature036,
    `Benitoite.Release.Refinement.signature037,
    `Benitoite.Release.Refinement.signature038,
    `Benitoite.Release.Refinement.signature039,
    `Benitoite.Release.Refinement.signature040,
    `Benitoite.Release.Refinement.signature041,
    `Benitoite.Release.Refinement.signature042,
    `Benitoite.Release.Refinement.signature043,
    `Benitoite.Release.Refinement.signature044,
    `Benitoite.Release.Refinement.signature045,
    `Benitoite.Release.Refinement.signature046,
    `Benitoite.Release.Refinement.signature047,
    `Benitoite.Release.Refinement.signature048,
    `Benitoite.Release.Refinement.signature049,
    `Benitoite.Release.Refinement.signature050,
    `Benitoite.Release.Refinement.signature051,
    `Benitoite.Release.Refinement.signature052,
    `Benitoite.Release.Refinement.signature053,
    `Benitoite.Release.Refinement.signature054,
    `Benitoite.Release.Refinement.signature055,
    `Benitoite.Release.Refinement.signature056,
    `Benitoite.Release.Refinement.signature057,
    `Benitoite.Release.Refinement.signature058,
    `Benitoite.Release.Refinement.signature059,
    `Benitoite.Release.Refinement.signature060,
    `Benitoite.Release.Refinement.signature061,
    `Benitoite.Release.Refinement.signature062,
    `Benitoite.Release.Refinement.signature063,
    `Benitoite.Release.Refinement.signature064,
    `Benitoite.Release.Refinement.signature065,
    `Benitoite.Release.Refinement.signature066,
    `Benitoite.Release.Refinement.signature067,
    `Benitoite.Release.Refinement.signature068,
    `Benitoite.Release.Refinement.signature069,
    `Benitoite.Release.Refinement.signature070,
    `Benitoite.Release.Refinement.signature071,
    `Benitoite.Release.Refinement.signature072,
    `Benitoite.Release.Refinement.signature073,
    `Benitoite.Release.Refinement.signature074,
    `Benitoite.Release.Refinement.signature075,
    `Benitoite.Release.Refinement.signature076,
    `Benitoite.Release.Refinement.signature077,
    `Benitoite.Release.Refinement.signature078,
    `Benitoite.Release.Refinement.signature079,
    `Benitoite.Release.Refinement.signature080,
    `Benitoite.Release.Refinement.signature081,
    `Benitoite.Release.Refinement.signature082,
    `Benitoite.Release.Refinement.signature083,
    `Benitoite.Release.Refinement.signature084,
    `Benitoite.Release.Refinement.signature085,
    `Benitoite.Release.Refinement.signature086,
    `Benitoite.Release.Refinement.signature087,
    `Benitoite.Release.Refinement.signature088,
    `Benitoite.Release.Refinement.signature089,
    `Benitoite.Release.Refinement.signature090,
    `Benitoite.Release.Refinement.signature091,
    `Benitoite.Release.Refinement.signature092,
    `Benitoite.Release.Refinement.signature093,
    `Benitoite.Release.Refinement.signature094,
    `Benitoite.Release.Refinement.signature095,
    `Benitoite.Release.Refinement.signature096,
    `Benitoite.Release.Refinement.signature097,
    `Benitoite.Release.Refinement.signature098,
    `Benitoite.Release.Refinement.signature099,
    `Benitoite.Release.Refinement.signature100,
    `Benitoite.Release.Refinement.signature101,
    `Benitoite.Release.Refinement.signature102,
    `Benitoite.Release.Refinement.signature103,
    `Benitoite.Release.Refinement.signature104,
    `Benitoite.Release.Refinement.signature105,
    `Benitoite.Release.Refinement.signature106,
    `Benitoite.Release.Refinement.signature107,
    `Benitoite.Release.Refinement.signature108,
    `Benitoite.Release.Refinement.signature109,
    `Benitoite.Release.Refinement.signature110,
    `Benitoite.Release.Refinement.signature111,
    `Benitoite.Release.Refinement.signature112,
    `Benitoite.Release.Refinement.signature113,
    `Benitoite.Release.Refinement.signature114,
    `Benitoite.Release.Refinement.signature115,
    `Benitoite.Release.Refinement.signature116,
    `Benitoite.Release.Refinement.signature117,
    `Benitoite.Release.Refinement.signature118,
    `Benitoite.Release.Refinement.signature119,
    `Benitoite.Release.Refinement.signature120,
    `Benitoite.Release.Refinement.signature121,
    `Benitoite.Release.Refinement.signature122,
    `Benitoite.Release.Refinement.signature123,
    `Benitoite.Release.Refinement.signature124,
    `Benitoite.Release.Refinement.signature125,
    `Benitoite.Release.Refinement.signature126,
    `Benitoite.Release.Refinement.signature127,
    `Benitoite.Release.Refinement.signature128,
    `Benitoite.Release.Refinement.signature129,
    `Benitoite.Release.Refinement.signature130,
    `Benitoite.Release.Refinement.signature131,
    `Benitoite.Release.Refinement.signature132,
    `Benitoite.Release.Refinement.signature133,
    `Benitoite.Release.Refinement.signature134,
    `Benitoite.Release.Refinement.signature135,
    `Benitoite.Release.Refinement.signature136,
    `Benitoite.Release.Refinement.signature137,
    `Benitoite.Release.Refinement.signature138,
    `Benitoite.Release.Refinement.signature139,
    `Benitoite.Release.Refinement.signature140,
    `Benitoite.Release.Refinement.signature141,
    `Benitoite.Release.Refinement.signature142,
    `Benitoite.Release.Refinement.signature143,
    `Benitoite.Release.Refinement.signature144,
    `Benitoite.Release.Refinement.signature145,
    `Benitoite.Release.Refinement.signature146,
    `Benitoite.Release.Refinement.signature147,
    `Benitoite.Release.Refinement.signature148,
    `Benitoite.Release.Refinement.signature149,
    `Benitoite.Release.Refinement.signature150,
    `Benitoite.Release.Refinement.signature151,
    `Benitoite.Release.Refinement.signature152,
    `Benitoite.Release.Refinement.signature153,
    `Benitoite.Release.Refinement.signature154,
    `Benitoite.Release.Refinement.signature155,
    `Benitoite.Release.Refinement.signature156,
    `Benitoite.Release.Refinement.signature157,
    `Benitoite.Release.Refinement.signature158,
    `Benitoite.Release.Refinement.signature159
  ]
  logInfo m!"LOCAL_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
