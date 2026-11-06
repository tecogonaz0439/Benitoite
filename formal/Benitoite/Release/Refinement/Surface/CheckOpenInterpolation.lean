import Benitoite.Release.Refinement.Surface.CheckInterpolation
import Benitoite.Release.Refinement.Surface.CheckOpenInput
import Benitoite.Release.Refinement.Surface.CheckOpenArguments

/-!
# 開いた範囲文脈のリストの展開と文字列補間の検査

束縛した実引数を依存列に沿って検査し、中間の型と効果を一つずつ照合する。
案内は中間型と有限な証明書だけを持つ（設計書 01-12「リストの展開」「文字列補間」）。
-/
namespace Benitoite.Release.Refinement.Surface.CheckOpen

open Check CheckArguments CheckSubtyping CheckCompare

private theorem ty_shift_support {s : List Atom} {a : Ty} (h : a.Support (· ∈ s)) (k : Nat) :
    (a.shiftV k 0).Support (· ∈ s) := (Ty.support_shiftV_iff _ _ _ _).mpr h

private theorem eff_shift_support {s : List Atom} {e : Eff} (h : e.Support (· ∈ s)) (k : Nat) :
    (Eff.shiftV k 0 e).Support (· ∈ s) := (Eff.support_shiftV_iff _ _ _ _).mpr h

private theorem tel_shift_support {s : List Atom} {t : Tel} (h : t.Support (· ∈ s)) (k : Nat) :
    (Tel.shiftV k 0 t).Support (· ∈ s) := by
  simpa only [Ty.shiftV, Ty.Support] using ty_shift_support (a := .dependentFn t) h k

private theorem values_append_support {s xs ys} (hx : ValuesSupport s xs) (hy : ValuesSupport s ys) :
    ValuesSupport s (xs ++ ys) := by
  induction xs with
  | nil => exact hy
  | cons x xs ih => exact ⟨hx.1, ih hx.2⟩

mutual
  private theorem value_shift_support {s v} (h : ValueSupport s v) (k : Nat) :
      ValueSupport s (v.rename (· + k)) := by
    cases v <;> try trivial
    case list vs => exact values_shift_support h k
    case super v cl => exact value_shift_support (v := v) h k
    case dict i ts vs =>
      refine ⟨?_, values_shift_support h.2 k⟩
      apply Ty.SupportList.iff.mpr
      intro a ha
      obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
      have hi : shiftIndex k 0 = (· + k) := by funext j; simp [shiftIndex]
      rw [← hi, ← Ty.shiftV_eq_renameTy]
      exact ty_shift_support (Ty.SupportList.iff.mp h.1 b hb) k
  termination_by sizeOf v
  decreasing_by all_goals subst_vars <;> simp_wf <;> omega
  private theorem values_shift_support {s vs} (h : ValuesSupport s vs) (k : Nat) :
      ValuesSupport s (Val.renameList (· + k) vs) := by
    cases vs with
    | nil => trivial
    | cons v vs => exact ⟨value_shift_support (v := v) h.1 k, values_shift_support (vs := vs) h.2 k⟩
  termination_by sizeOf vs
  decreasing_by all_goals subst_vars <;> simp_wf <;> omega
end

private theorem dictionary_arguments_support {s ds values} (hd : DictsSupport s ds)
    (hv : ValuesSupport s values) (k : Nat) :
    ValuesSupport s (ds.map (fun d => d.toVal.rename (· + k)) ++ values) :=
  values_append_support (dicts_renamed_support hd k) hv

private theorem one_argument {D B ks C Γ0 k Γ Φ v a} (h : OpenSurface.ArgElems D B ks C Γ0 k Γ Φ [v] a) :
    ∃ b, OpenSurface.ArgVal D B ks C Γ0 k Γ Φ v b ∧ Ty.LeQ D.core Γ Φ b a := by
  cases h with
  | cons hv hs _ => exact ⟨_, hv, hs⟩

private theorem format_arguments_support (s : List Atom) (spec : FormatSpec) :
    ValuesSupport s spec.arguments := by
  unfold FormatSpec.arguments
  split
  · generalize spec.constants _ = cs
    induction cs with
    | nil => trivial
    | cons c cs ih => exact ⟨trivial, ih⟩
  · trivial

/-- リストの展開の四つの形を検査する。 -/
def checkSpreadAt (q : Input) (C : TypeCtx) (Γ0 : Ctx) (t : Tel) (ds : List DictEv)
    (k : Nat) (Γ : Ctx) (Φ : List Pred) (before : List Val) (spread : Val) (after : List Val)
    (result : Ty) (e : Eff) (path : List Nat) : Guide → Bool
  | .node .Spread_only h [] => match before, after with
    | [], [] => allChecks [
        CheckOpenArguments.elems q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path [spread] result (h.args 0),
        annotation q C Γ path result]
    | _, _ => false
  | .node .Spread_front h [] => match before, after with
    | [], x :: xs => allChecks [
        CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
          (ds.map (fun d => d.toVal.rename (· + k)) ++ [spread, .list (x :: xs)])
          (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
        (h.le 0).checkAs q.formation.atoms q.D.core Γ Φ q.proofSteps (h.ty 0) result,
        effCovers q.formation.atoms e (h.eff 0),
        annotation q C Γ path result]
    | _, _ => false
  | .node .Spread_back h [] => match before, after with
    | y :: ys, [] => allChecks [
        CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
          (ds.map (fun d => d.toVal.rename (· + k)) ++ [.list (y :: ys), spread])
          (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
        (h.le 0).checkAs q.formation.atoms q.D.core Γ Φ q.proofSteps (h.ty 0) result,
        effCovers q.formation.atoms e (h.eff 0),
        annotation q C Γ path result]
    | _, _ => false
  | .node .Spread_middle h [] => match before, after with
    | y :: ys, x :: xs => allChecks [
        CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
          (ds.map (fun d => d.toVal.rename (· + k)) ++ [.list (y :: ys), spread])
          (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
        decide (Ordinary (h.ty 0)),
        annotation q C Γ path (h.ty 0),
        effCovers q.formation.atoms e (h.eff 0),
        CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 (k + 1) (Γ.extend (h.ty 0)) (Φ.map Pred.lift) q.proofSteps path
          (ds.map (fun d => d.toVal.rename (· + (k + 1))) ++
            [.var 0, .list (Val.renameList (· + 1) (x :: xs))])
          (Tel.shiftV (k + 1) 0 t) (h.ty 1) (h.eff 1) (h.args 1),
        (h.le 0).checkAs q.formation.atoms q.D.core (Γ.extend (h.ty 0)) (Φ.map Pred.lift) q.proofSteps
          (h.ty 1) (result.shiftV 1 0),
        effCovers q.formation.atoms (Eff.shiftV 1 0 e) (h.eff 1),
        annotation q C Γ path result]
    | _, _ => false
  | _ => false

/-- 中間の結果を一つずつ束縛して文字列を連結する。 -/
def checkJoinAt (q : Input) (C : TypeCtx) (Γ0 : Ctx) (t : Tel) (k : Nat) (Γ : Ctx) (Φ : List Pred)
    (depth : Nat) (left : Val) (rights : List Val) (e : Eff) (path : List Nat) : Guide → Bool
  | .node .Join_last h [] => match rights with
    | [right] => allChecks [
        CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
          [left, right.rename (· + depth)] (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
        (h.le 0).checkAs q.formation.atoms q.D.core Γ Φ q.proofSteps (h.ty 0) (.base .string),
        effCovers q.formation.atoms e (h.eff 0)]
    | _ => false
  | .node .Join_step h [g] => match rights with
    | right :: x :: xs => allChecks [
        CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
          [left, right.rename (· + depth)] (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
        decide (Ordinary (h.ty 0)),
        annotation q C Γ path (h.ty 0),
        effCovers q.formation.atoms e (h.eff 0),
        checkJoinAt q C Γ0 t (k + 1) (Γ.extend (h.ty 0)) (Φ.map Pred.lift) (depth + 1) (.var 0)
          (x :: xs) (Eff.shiftV 1 0 e) (child path 0) g]
    | _ => false
  | _ => false
termination_by structural guide => guide

/-- 空・一部分・二部分以上の連結を、同じ規則の案内で照合する。 -/
def checkJoinPartsAt (q : Input) (caller : List Bool) (C : TypeCtx) (Γ0 : Ctx)
    (k : Nat) (Γ : Ctx) (Φ : List Pred) (values : List Val) (e : Eff) (path : List Nat) : Guide → Bool
  | .node .JoinParts_empty _ [] => match values with | [] => true | _ => false
  | .node .JoinParts_single h [] => match values with
    | [v] => CheckOpenArguments.elems q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path [v] (.base .string) (h.args 0)
    | _ => false
  | .node .JoinParts_many h [g] => match values with
    | v :: x :: xs => match q.opPrim (.binary .add) (.base .string) with
      | some (b, []) => match CheckOpenArguments.head q.formation q.D q.builtinSource q.satDec q.admitsDec q.admitsRDec caller C Γ0 path
          (.primName b [] [] []) (h.head 0) with
        | some (t, []) => checkJoinAt q C Γ0 t k Γ Φ 0 v (x :: xs) e (child path 0) g
        | _ => false
      | _ => false
    | _ => false
  | _ => false

/-- 値・変換関数・部分を同じ順に消費し、変換の中間の結果だけを追加で束縛する。 -/
def checkInterpAt (q : Input) (caller : List Bool) (C : TypeCtx) (Γ0 : Ctx)
    (k : Nat) (Γ : Ctx) (Φ : List Pred) (parts : List InterpPart) (values : List Val) (converters : Exprs)
    (acc : List Val) (e : Eff) (path : List Nat) : Guide → Bool
  | .node .Interp_done _ [g] => match parts with
    | [] => checkJoinPartsAt q caller C Γ0 k Γ Φ acc e (child path 0) g
    | _ => false
  | .node .Interp_text _ [g] => match parts with
    | .text text :: ps => checkInterpAt q caller C Γ0 k Γ Φ ps values converters
        (if text = "" then acc else acc ++ [.const (.string text)]) e (child path 0) g
    | _ => false
  | .node .Interp_stringExpr _ [g] => match parts, values with
    | .stringExpr :: ps, v :: vs => checkInterpAt q caller C Γ0 k Γ Φ ps vs converters (acc ++ [v]) e (child path 0) g
    | _, _ => false
  | .node .Interp_converted h [g] => match parts, values, converters with
    | .converted _ :: ps, v :: vs, .cons f fs =>
      match CheckOpenArguments.head q.formation q.D q.builtinSource q.satDec q.admitsDec q.admitsRDec caller C Γ0 path f (h.head 0) with
      | some (t, ds) => allChecks [
          CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
            (ds.map (fun d => d.toVal.rename (· + k)) ++ [v]) (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
          decide (Ordinary (h.ty 0)),
          annotation q C Γ path (h.ty 0),
          effCovers q.formation.atoms e (h.eff 0),
          checkInterpAt q caller C Γ0 (k + 1) (Γ.extend (h.ty 0)) (Φ.map Pred.lift) ps
            (Val.renameList (· + 1) vs) fs (Val.renameList (· + 1) acc ++ [.var 0])
            (Eff.shiftV 1 0 e) (child path 0) g]
      | none => false
    | _, _, _ => false
  | .node .Interp_formatted h [g] => match parts, values, converters with
    | .formatted _ spec :: ps, v :: vs, .cons f fs =>
      match CheckOpenArguments.head q.formation q.D q.builtinSource q.satDec q.admitsDec q.admitsRDec caller C Γ0 path f (h.head 0) with
      | some (t, ds) => allChecks [
          CheckOpenArguments.valsTel q.formation q.D q.builtinSource q.satDec C Γ0 k Γ Φ q.proofSteps path
            (ds.map (fun d => d.toVal.rename (· + k)) ++ v :: spec.arguments)
            (Tel.shiftV k 0 t) (h.ty 0) (h.eff 0) (h.args 0),
          decide (Ordinary (h.ty 0)),
          annotation q C Γ path (h.ty 0),
          effCovers q.formation.atoms e (h.eff 0),
          checkInterpAt q caller C Γ0 (k + 1) (Γ.extend (h.ty 0)) (Φ.map Pred.lift) ps
            (Val.renameList (· + 1) vs) fs (Val.renameList (· + 1) acc ++ [.var 0])
            (Eff.shiftV 1 0 e) (child path 0) g]
      | none => false
    | _, _, _ => false
  | _ => false
termination_by structural guide => guide

theorem checkSpreadAt_sound {q C Γ0 t ds k Γ Φ before spread after result e path guide}
    (hq : OpenSound q) (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (ht : t.Support (· ∈ q.formation.atoms)) (hd : DictsSupport q.formation.atoms ds)
    (hb : ValuesSupport q.formation.atoms before) (hs : ValueSupport q.formation.atoms spread)
    (ha : ValuesSupport q.formation.atoms after) (hr : result.Support (· ∈ q.formation.atoms))
    (he : e.Support (· ∈ q.formation.atoms)) (hg : guide.Support q.formation.atoms)
    (h : checkSpreadAt q C Γ0 t ds k Γ Φ before spread after result e path guide = true) :
    OpenSurface.SpreadTy q.D q.B q.formation.rangeKinds C Γ0 t ds k Γ Φ before spread after result e := by
  cases guide with
  | unknown => cases h
  | failure _ => cases h
  | node rule hint children =>
    cases rule <;> try cases h
    case Spread_only =>
      cases children <;> cases before <;> cases after <;>
        simp only [checkSpreadAt, Bool.false_eq_true] at h
      simp only [allChecks, Bool.and_eq_true, and_true] at h
      obtain ⟨a, hv, hle⟩ := one_argument (CheckOpenArguments.elems_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
        ⟨hs, trivial⟩ hr (hg.1.args 0) h.1)
      exact .only hv hle (annotation_sound hq hΓ hr h.2)
    case Spread_front =>
      cases children <;> cases before <;> cases after <;>
        simp only [checkSpreadAt, Bool.false_eq_true] at h
      rename_i x xs
      simp only [allChecks, Bool.and_eq_true, and_true] at h
      exact .front
        (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
          (dictionary_arguments_support (values := [spread, .list (x :: xs)]) hd ⟨hs, ha, trivial⟩ k) (tel_shift_support ht k)
          (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1)
        ((hint.le 0).checkAs_sound (hg.1.ty 0) hr (hg.1.le 0) h.2.1)
        (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2.1)
        (annotation_sound hq hΓ hr h.2.2.2)
    case Spread_back =>
      cases children <;> cases before <;> cases after <;>
        simp only [checkSpreadAt, Bool.false_eq_true] at h
      rename_i y ys
      simp only [allChecks, Bool.and_eq_true, and_true] at h
      exact .back
        (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
          (dictionary_arguments_support (values := [.list (y :: ys), spread]) hd ⟨hb, hs, trivial⟩ k) (tel_shift_support ht k)
          (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1)
        ((hint.le 0).checkAs_sound (hg.1.ty 0) hr (hg.1.le 0) h.2.1)
        (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2.1)
        (annotation_sound hq hΓ hr h.2.2.2)
    case Spread_middle =>
      cases children <;> cases before <;> cases after <;>
        simp only [checkSpreadAt, Bool.false_eq_true] at h
      rename_i y ys x xs
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at h
      exact .middle
        (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
          (dictionary_arguments_support (values := [.list (y :: ys), spread]) hd ⟨hb, hs, trivial⟩ k) (tel_shift_support ht k)
          (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1) h.2.1
        (annotation_sound hq hΓ (hg.1.ty 0) h.2.2.1)
        (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2.2.1)
        (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 (hΓ.extend (hg.1.ty 0))
          (dictionary_arguments_support (values := [.var 0, .list (Val.renameList (· + 1) (x :: xs))])
            hd ⟨trivial, values_shift_support ha 1, trivial⟩ (k + 1))
          (tel_shift_support ht (k + 1)) (hg.1.ty 1) (hg.1.eff 1) (hg.1.args 1) h.2.2.2.2.1)
        ((hint.le 0).checkAs_sound (hg.1.ty 1) (ty_shift_support hr 1) (hg.1.le 0) h.2.2.2.2.2.1)
        (effCovers_sound (hg.1.eff 1) ((Eff.support_iff _).mp (eff_shift_support he 1)).2 h.2.2.2.2.2.2.1)
        (annotation_sound hq hΓ hr h.2.2.2.2.2.2.2)

theorem checkJoinAt_sound {q C Γ0 t k Γ Φ depth left rights e path guide}
    (hq : OpenSound q) (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (ht : t.Support (· ∈ q.formation.atoms)) (hl : ValueSupport q.formation.atoms left)
    (hr : ValuesSupport q.formation.atoms rights) (he : e.Support (· ∈ q.formation.atoms))
    (hg : guide.Support q.formation.atoms)
    (h : checkJoinAt q C Γ0 t k Γ Φ depth left rights e path guide = true) :
    OpenSurface.JoinTy q.D q.B q.formation.rangeKinds C Γ0 t k Γ Φ depth left rights e := by
  cases guide with
  | unknown => cases h
  | failure _ => cases h
  | node rule hint children =>
    cases rule <;> try cases h
    case Join_last =>
      cases children <;> cases rights <;> simp only [checkJoinAt, Bool.false_eq_true] at h
      rename_i right rest
      cases rest <;> simp only [Bool.false_eq_true] at h
      simp only [allChecks, Bool.and_eq_true, and_true] at h
      exact .last
        (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
          ⟨hl, value_shift_support hr.1 depth, trivial⟩ (tel_shift_support ht k)
          (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1)
        ((hint.le 0).checkAs_sound (hg.1.ty 0) trivial (hg.1.le 0) h.2.1)
        (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2)
    case Join_step =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> simp only [checkJoinAt, Bool.false_eq_true] at h
        cases rights with
        | nil => cases h
        | cons right rest =>
          cases rest with
          | nil => cases h
          | cons x xs =>
            simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at h
            exact .step
              (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
                ⟨hl, value_shift_support hr.1 depth, trivial⟩ (tel_shift_support ht k)
                (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1) h.2.1
              (annotation_sound hq hΓ (hg.1.ty 0) h.2.2.1)
              (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2.2.1)
              (checkJoinAt_sound hq hΓ0 (hΓ.extend (hg.1.ty 0)) ht trivial hr.2
                (eff_shift_support he 1) hg.2.1 h.2.2.2.2)

theorem checkJoinPartsAt_sound {q caller C Γ0 k Γ Φ values e path guide}
    (hq : OpenSound q) (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hv : ValuesSupport q.formation.atoms values) (he : e.Support (· ∈ q.formation.atoms))
    (hg : guide.Support q.formation.atoms)
    (h : checkJoinPartsAt q caller C Γ0 k Γ Φ values e path guide = true) :
    OpenSurface.JoinPartsTy q.D q.B q.formation.rangeKinds (CheckAdmissible.NoFailCtxOf caller) C Γ0 q.opPrim k Γ Φ values e := by
  cases guide with
  | unknown => cases h
  | failure _ => cases h
  | node rule hint children =>
    cases rule <;> try cases h
    case JoinParts_empty =>
      cases children <;> cases values <;> simp only [checkJoinPartsAt, Bool.false_eq_true] at h
      exact .empty
    case JoinParts_single =>
      cases children <;> cases values <;> simp only [checkJoinPartsAt, Bool.false_eq_true] at h
      rename_i v rest
      cases rest <;> simp only [Bool.false_eq_true] at h
      obtain ⟨b, hv', hle⟩ := one_argument (CheckOpenArguments.elems_sound (a := .base .string) hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
        hv trivial (hg.1.args 0) h)
      exact .single hv' hle
    case JoinParts_many =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> simp only [checkJoinPartsAt, Bool.false_eq_true] at h
        cases values with
        | nil => cases h
        | cons v rest =>
          cases rest with
          | nil => cases h
          | cons x xs =>
            dsimp only [checkJoinPartsAt] at h
            split at h
            · rename_i b hop
              split at h
              · rename_i t hhead
                have hi := primitive_empty_support hq.tables (b := b) (ts := []) trivial
                have ht := CheckOpenArguments.head_result_support hq.tables hi (hg.1.head 0) hhead
                exact .many hop (CheckOpenArguments.head_sound hq.formation hq.tables hq.sat hq.admits hq.ranges hΓ0 hi (hg.1.head 0) hhead)
                  (checkJoinAt_sound hq hΓ0 hΓ ht.1 hv.1 hv.2 he hg.2.1 h)
              · cases h
            · cases h

theorem checkInterpAt_sound {q caller C Γ0 k Γ Φ parts values converters acc e path guide}
    (hq : OpenSound q) (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hv : ValuesSupport q.formation.atoms values) (hf : ExprsSupport q converters)
    (ha : ValuesSupport q.formation.atoms acc) (he : e.Support (· ∈ q.formation.atoms))
    (hg : guide.Support q.formation.atoms)
    (h : checkInterpAt q caller C Γ0 k Γ Φ parts values converters acc e path guide = true) :
    OpenSurface.InterpTy q.D q.B q.formation.rangeKinds (CheckAdmissible.NoFailCtxOf caller) C Γ0 q.opPrim k Γ Φ parts values converters acc e := by
  cases guide with
  | unknown => cases h
  | failure _ => cases h
  | node rule hint children =>
    cases rule <;> try cases h
    case Interp_done =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> cases parts <;> simp only [checkInterpAt, Bool.false_eq_true] at h
        exact .done (checkJoinPartsAt_sound hq hΓ0 hΓ ha he hg.2.1 h)
    case Interp_text =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> simp only [checkInterpAt, Bool.false_eq_true] at h
        cases parts with
        | nil => cases h
        | cons part ps =>
          cases part <;> try cases h
          rename_i text
          have hac : ValuesSupport q.formation.atoms
              (if text = "" then acc else acc ++ [.const (.string text)]) := by
            split
            · exact ha
            · exact values_append_support ha ⟨trivial, trivial⟩
          exact .text (checkInterpAt_sound hq hΓ0 hΓ hv hf hac he hg.2.1 h)
    case Interp_stringExpr =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> simp only [checkInterpAt, Bool.false_eq_true] at h
        cases parts with
        | nil => cases h
        | cons part ps =>
          cases part <;> try cases h
          cases values with
          | nil => cases h
          | cons v vs =>
            exact .stringExpr (checkInterpAt_sound hq hΓ0 hΓ hv.2 hf
              (values_append_support ha ⟨hv.1, trivial⟩) he hg.2.1 h)
    case Interp_converted =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> simp only [checkInterpAt, Bool.false_eq_true] at h
        cases parts with
        | nil => cases h
        | cons part ps =>
          cases part <;> try cases h
          rename_i conversionType
          cases values with
          | nil => cases h
          | cons v vs =>
            cases converters with
            | nil => cases h
            | cons f fs =>
              dsimp only [checkInterpAt] at h
              split at h
              · rename_i t ds hhead
                simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at h
                have hi := source_head_inputs hf.1
                have ht := CheckOpenArguments.head_result_support hq.tables hi (hg.1.head 0) hhead
                have hd : DictsSupport q.formation.atoms ds := by
                  rw [ht.2]
                  exact source_head_dictionaries hf.1
                exact .converted
                  (CheckOpenArguments.head_sound hq.formation hq.tables hq.sat hq.admits hq.ranges hΓ0 hi (hg.1.head 0) hhead)
                  (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
                    (dictionary_arguments_support (values := [v]) hd ⟨hv.1, trivial⟩ k)
                    (tel_shift_support ht.1 k) (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1)
                  h.2.1 (annotation_sound hq hΓ (hg.1.ty 0) h.2.2.1)
                  (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2.2.1)
                  (checkInterpAt_sound hq hΓ0 (hΓ.extend (hg.1.ty 0)) (values_shift_support hv.2 1) hf.2
                    (values_append_support (values_shift_support ha 1) ⟨trivial, trivial⟩)
                    (eff_shift_support he 1) hg.2.1 h.2.2.2.2)
              · cases h
    case Interp_formatted =>
      cases children with
      | nil => cases h
      | cons g children =>
        cases children <;> simp only [checkInterpAt, Bool.false_eq_true] at h
        cases parts with
        | nil => cases h
        | cons part ps =>
          cases part <;> try cases h
          rename_i conversionType spec
          cases values with
          | nil => cases h
          | cons v vs =>
            cases converters with
            | nil => cases h
            | cons f fs =>
              dsimp only [checkInterpAt] at h
              split at h
              · rename_i t ds hhead
                simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at h
                have hi := source_head_inputs hf.1
                have ht := CheckOpenArguments.head_result_support hq.tables hi (hg.1.head 0) hhead
                have hd : DictsSupport q.formation.atoms ds := by
                  rw [ht.2]
                  exact source_head_dictionaries hf.1
                exact .formatted
                  (CheckOpenArguments.head_sound hq.formation hq.tables hq.sat hq.admits hq.ranges hΓ0 hi (hg.1.head 0) hhead)
                  (CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ
                    (dictionary_arguments_support (values := v :: spec.arguments) hd
                      ⟨hv.1, format_arguments_support _ spec⟩ k)
                    (tel_shift_support ht.1 k) (hg.1.ty 0) (hg.1.eff 0) (hg.1.args 0) h.1)
                  h.2.1 (annotation_sound hq hΓ (hg.1.ty 0) h.2.2.1)
                  (effCovers_sound (hg.1.eff 0) ((Eff.support_iff e).mp he).2 h.2.2.2.1)
                  (checkInterpAt_sound hq hΓ0 (hΓ.extend (hg.1.ty 0)) (values_shift_support hv.2 1) hf.2
                    (values_append_support (values_shift_support ha 1) ⟨trivial, trivial⟩)
                    (eff_shift_support he 1) hg.2.1 h.2.2.2.2)
              · cases h

end Benitoite.Release.Refinement.Surface.CheckOpen


