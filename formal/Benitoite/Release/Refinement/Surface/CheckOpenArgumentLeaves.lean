import Benitoite.Release.Refinement.Surface.CheckArguments
import Benitoite.Release.Refinement.Surface.CheckBuiltinSource
import Benitoite.Release.Refinement.Surface.CheckOpenAdmissible
import Benitoite.Release.Refinement.Surface.OpenRangeFormationCheck
import Benitoite.Release.Refinement.Surface.RangeStandard
import Benitoite.Release.Refinement.Surface.PredicateRangeLeaves

/-! # 開いた実引数の許容を有限の検査へ接続する -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenArguments
open CheckArguments CheckCompare CheckAdmissible
open Check (BuiltinSource)

/-- 任意の表では範囲閉の型引数を確認し、標準行と判定の内部行の構成データを持つ表では、その定義から示した保存を用いる。 -/
def typeArguments (q : CheckFormation.Input) (source : BuiltinSource) (ts : List Ty) : Bool :=
  match source with
  | .standard _ | .predicates _ _ => true
  | .resolved base _ => typeArguments q base ts
  | .custom _ | .unrestrictedRanges _ => ts.all (OpenRangeFormationCheck.ty q.atoms 0)

private theorem closed_types {q : CheckFormation.Input} {ts : List Ty}
    (ht : Ty.SupportList (· ∈ q.atoms) ts)
    (h : ts.all (OpenRangeFormationCheck.ty q.atoms 0) = true) : ∀ a ∈ ts, a.RangesScoped 0 := by
  intro a ha
  exact OpenRangeFormationCheck.ty_sound (Ty.SupportList.iff.mp ht a ha) (List.all_eq_true.mp h a ha)

/-- 制約の照合の一回の成功を、範囲の全具体化の葉へ接続する。 -/
def satAll (q : CheckFormation.Input) (source : BuiltinSource) (sat : SatDec) (C : TypeCtx)
    (ts : List Ty) (ps : List TParam) : Bool :=
  CheckArguments.satAll q.atoms sat C ts ps && typeArguments q source ts

theorem satAll_sound {q : CheckFormation.Input} {source : BuiltinSource} {sat C ts ps}
    (hs : SatSound source.builtins sat) (ht : Ty.SupportList (· ∈ q.atoms) ts)
    (h : satAll q source sat C ts ps = true) :
    OpenSurface.Satisfies source.builtins q.rangeKinds C ts ps := by
  obtain ⟨ha, hc⟩ := Bool.and_eq_true_iff.mp h
  have ht' := CheckArguments.satAll_sound hs ht ha
  cases source with
  | standard P => exact RangeStandard.satisfies_of_check ht'
  | predicates data entries =>
    exact PredicateRangeLeaves.satisfies_of_check
      ((PredicateProjection.Table.sat_eq data entries).trans (StandardModel.DataTable.sat_eq data)) ht'
  | resolved base entries =>
    exact satAll_sound (source := base) hs ht (Bool.and_eq_true_iff.mpr ⟨ha, hc⟩)
  | custom B => exact OpenLeafFormation.satisfies_of_closed ht' (closed_types ht hc)
  | unrestrictedRanges B => exact OpenLeafFormation.satisfies_of_closed ht' (closed_types ht hc)

theorem primitive_leaf {q : CheckFormation.Input} {source : BuiltinSource} {b s C nv Q ts es}
    (hs : source.builtins.sig b = some s)
    (h : OpenLeafFormation.PrimitiveCheck q.rangeKinds C nv s Q ts es)
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hc : typeArguments q source ts = true) :
    OpenSurface.Primitive q.rangeKinds C nv s Q ts es := by
  cases source with
  | standard P => exact RangeStandard.primitive_of_check hs h
  | predicates data entries =>
    rcases PredicateProjection.Table.lookup_cases data hs with ⟨row, _, rfl⟩ | ⟨row, _, rfl⟩
    · exact PredicateRangeLeaves.primitive_standard
        (S := Benitoite.Release.dataSummaries (data.declarations.map StandardKeyTyping.DataDecl.summaryInput)) h
    · exact PredicateRangeLeaves.primitive_internal h
  | resolved base entries =>
    change (match entries.lookup b with
      | some row => some row.signature | none => base.builtins.sig b) = some s at hs
    cases found : entries.lookup b with
    | none => exact primitive_leaf (source := base) (by simpa only [found] using hs) h ht hc
    | some row =>
      simp only [found, Option.some.injEq] at hs
      subst s
      exact PredicateRangeLeaves.primitive_internal h
  | custom B => exact OpenLeafFormation.primitive_of_closed h (closed_types ht hc)
  | unrestrictedRanges B => exact OpenLeafFormation.primitive_of_closed h (closed_types ht hc)

theorem admissible_leaf {q : CheckFormation.Input} {source : BuiltinSource} {C nv ps ne Qs Q ts es e}
    (h : OpenLeafFormation.AdmitsCheck source.builtins q.rangeKinds C nv ps ne Qs Q ts es e)
    (ht : Ty.SupportList (· ∈ q.atoms) ts) (hc : typeArguments q source ts = true) :
    OpenSurface.Admits source.builtins q.rangeKinds C nv ps ne Qs Q ts es e := by
  cases source with
  | standard P => exact RangeStandard.admits_of_check h
  | predicates data entries =>
    exact PredicateRangeLeaves.admits_of_check
      ((PredicateProjection.Table.sat_eq data entries).trans (StandardModel.DataTable.sat_eq data)) h
  | resolved base entries =>
    have hb : OpenLeafFormation.AdmitsCheck base.builtins q.rangeKinds C nv ps ne Qs Q ts es e :=
      ⟨h.types, h.typeScope, h.rowCount, h.rowScope, h.sourceRows, h.sourceQ, h.noFailRows⟩
    intro σ
    have ha := admissible_leaf (source := base) hb ht hc σ
    exact ⟨ha.types, ha.typeScope, ha.rowCount, ha.rowScope, ha.sourceRows, ha.sourceQ, ha.noFailRows⟩
  | custom B => exact OpenLeafFormation.admits_of_closed h (closed_types ht hc)
  | unrestrictedRanges B => exact OpenLeafFormation.admits_of_closed h (closed_types ht hc)

/-- 範囲実引数の種類を位置ごとに照合する。 -/
def rangeArgument (ks : List Scope.Domain.Kind) (x : RangeIx) (k : Scope.Domain.Kind) : Bool :=
  match x with
  | .fixed r => decide (r.WF ∧ r.Canonical ∧ r.FitsKind k)
  | .rvar i => decide (ks[i]? = some k)

def rangeArguments (ks : List Scope.Domain.Kind) : List RangeIx → List Scope.Domain.Kind → Bool
  | [], [] => true
  | x :: xs, k :: kinds => rangeArgument ks x k && rangeArguments ks xs kinds
  | _, _ => false

theorem rangeArguments_sound {ks xs kinds} (h : rangeArguments ks xs kinds = true) :
    RangeArguments ks xs kinds := by
  induction xs generalizing kinds with
  | nil => cases kinds <;> first | exact ⟨rfl, by intro i ix k hi; cases hi⟩ | cases h
  | cons x xs ih =>
    cases kinds with
    | nil => cases h
    | cons k kinds =>
      obtain ⟨hx, hxs⟩ := Bool.and_eq_true_iff.mp h
      obtain ⟨hl, ht⟩ := ih hxs
      refine ⟨by simpa using hl, ?_⟩
      intro i ix kind hi hk
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at hi hk
        subst ix; subst kind
        cases x <;> simpa only [RangeArgument, rangeArgument, decide_eq_true_eq] using hx
      | succ i => exact ht i ix kind hi hk

/-- 標準表の範囲の許容を、構文上の被覆と既知の署名名で照合する。 -/
def standardRanges (b : PrimName) (xs : List RangeIx) : Bool :=
  xs.all (fun x => decide (x = .fixed .top)) ||
    ((decide (b = "Scope.widenPathIn" ∨ b = "Http.widenRequestIn")) &&
      match xs with | [inner, outer] => decide (outer = .fixed .top ∨ outer.Covers inner) | _ => false) ||
    (decide (b = "File.readTextIn" ∨ b = "File.readBytesIn" ∨ b = "File.writeTextIn" ∨
      b = "File.appendTextIn" ∨ b = "File.writeBytesIn" ∨ b = "File.appendBytesIn" ∨
      b = "Http.sendIn" ∨ b = "Scope.checkPathIn" ∨ b = "Http.checkRequestIn" ∨
      b = "Scope.pathInValue" ∨ b = "Http.requestInValue") && decide (xs.length = 1))

theorem standardRanges_sound {b xs} (h : standardRanges b xs = true) : RangeStandard.RangeCheck b xs := by
  simp only [standardRanges, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
  rcases h with (htop | ⟨hb, hxs⟩) | ⟨hb, hlen⟩
  · exact Or.inl (fun x hx => of_decide_eq_true (List.all_eq_true.mp htop x hx))
  · right; left
    cases xs with
    | nil => cases hxs
    | cons inner rest =>
      cases rest with
      | nil => cases hxs
      | cons outer rest =>
        cases rest with
        | cons _ _ => cases hxs
        | nil => exact ⟨hb, inner, outer, rfl, of_decide_eq_true hxs⟩
  · exact Or.inr (Or.inr ⟨hb, hlen⟩)

/-- 表の構成方法に従って、開いた範囲又は閉じた範囲の許容を一度検査する。 -/
def ranges (source : BuiltinSource) (admits : RangeAdmitsDec) (b : PrimName) (s : PrimSig)
    (xs : List RangeIx) : Bool :=
  match source with
  | .standard _ | .predicates _ _ => standardRanges b xs
  | .resolved base _ => ranges base admits b s xs
  | .unrestrictedRanges _ => true
  | .custom _ => match closedRanges xs with
    | none => false
    | some rs => CheckArguments.rangeAdmissible admits b s rs

theorem ranges_sound {q : CheckFormation.Input} {source : BuiltinSource} {admits b s xs}
    (hs : RangeAdmitsSound source.builtins admits)
    (hx : RangeArguments q.rangeKinds xs s.rkinds) (h : ranges source admits b s xs = true) :
    OpenSurface.RangesAdmit source.builtins q.rangeKinds b s xs := by
  cases source with
  | standard P => exact RangeStandard.ranges_of_check hx (standardRanges_sound h)
  | @predicates P data entries =>
    exact RangeStandard.ranges_of_check (P := P) hx (standardRanges_sound h)
  | resolved base entries => exact ranges_sound (source := base) hs hx h
  | unrestrictedRanges B =>
    intro σ
    have hf := OpenSurface.ranges_fit_close hx σ.property
    exact ⟨hf.1, hf.2.1, hf.2.2, Or.inr trivial⟩
  | custom B =>
    cases hrs : closedRanges xs with
    | none => simp [ranges, hrs] at h
    | some rs =>
      have he := (closedRanges_eq_some xs rs).mp hrs
      subst xs
      exact OpenLeafFormation.ranges_of_fixed
        (CheckArguments.rangeAdmissible_sound hs (by simpa [ranges, closedRanges_fixed] using h))

end Benitoite.Release.Refinement.Surface.CheckOpenArguments
