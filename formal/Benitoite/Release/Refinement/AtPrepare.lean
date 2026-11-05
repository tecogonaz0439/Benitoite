import Benitoite.Release.Refinement.AtInput
import Benitoite.Release.Refinement.Capture
import Benitoite.Release.Refinement.Ground

/-! # Atの準備

準備は渡されたtokenだけを使う。実行のσを参照せず、未具体化の範囲変数をErrorにする。
-/
namespace Benitoite.Release.Refinement
open Scope.Domain

mutual
  def groundTy : Ty → Bool
    | .base _ | .bytes => true
    | .data _ ts => groundTys ts
    | .list a => groundTy a
    | .refined a p => groundTy a && decide (p.WF 1)
    | _ => false
  def groundTys : List Ty → Bool
    | [] => true
    | a :: ts => groundTy a && groundTys ts
end
mutual
  def groundVal : Val → Bool
    | .const _ | .bytesV _ => true
    | .list vs => groundVals vs
    | .con _ ts vs => groundTys ts && groundVals vs
    | _ => false
  def groundVals : List Val → Bool
    | [] => true
    | v :: vs => groundVal v && groundVals vs
end

theorem groundTy_notContCore {a : Ty} (h : groundTy a = true) : a.NotContCore := by
  cases a <;> simp only [groundTy, Bool.false_eq_true] at h <;> try contradiction
  all_goals try (intro b t e he; cases he)
  case refined a p =>
    simp only [Bool.and_eq_true] at h
    exact groundTy_notContCore (a := a) h.1

mutual
  theorem groundTy_wf {a : Ty} (h : groundTy a = true) : a.WF 0 nt nv := by
    cases a <;> simp only [groundTy, Bool.false_eq_true] at h <;> try contradiction
    all_goals try trivial
    case data d ts => exact groundTys_wf h
    case list a => exact groundTy_wf (a := a) h
    case refined a p =>
      simp only [Bool.and_eq_true,decide_eq_true_eq] at h
      obtain ⟨ha,hp⟩ := h
      exact ⟨groundTy_wf ha,Pred.varsIn_mono hp (by intro i hi; omega),
        groundTy_notContCore ha⟩
  theorem groundTys_wf {ts : List Ty} (h : groundTys ts = true) : Ty.WFList 0 nt nv ts := by
    cases ts with
    | nil => trivial
    | cons a ts =>
      simp only [groundTys, Bool.and_eq_true] at h
      exact ⟨groundTy_wf h.1, groundTys_wf h.2⟩
end
mutual
  theorem groundVal_ground {v : Val} (h : groundVal v = true) : v.Ground := by
    cases v <;> simp only [groundVal, Bool.false_eq_true] at h <;> try contradiction
    all_goals try trivial
    case list vs => exact groundVals_closed h
    case con c ts vs =>
      simp only [Bool.and_eq_true] at h
      exact ⟨by
        intro a ha
        exact (Ty.wfList_iff.mp (groundTys_wf h.1)) a ha,
        groundVals_closed h.2⟩
  theorem groundVals_closed {vs : List Val} (h : groundVals vs = true) : Val.ClosedList 0 0 vs := by
    cases vs with
    | nil => trivial
    | cons v vs =>
      simp only [groundVals, Bool.and_eq_true] at h
      exact ⟨groundVal_ground h.1, groundVals_closed h.2⟩
end

def AtRequest (B : Builtins) (name : OpaqueName) (v : Val) : Option Val :=
  match B.valContent name with | none => none | some _ => some v

private structure PreparationError where
  detail : AtError
  notStatic : detail.failure ≠ .staticIndex

private def prepareError (rawPattern rawTarget : Val) (σ : Option PathEnv)
    (p : Option RangeExpr) (t : Option TargetInput)
    (f : AtFailure) (hf : f ≠ .staticIndex) : PreparationError :=
  ⟨AtError.save rawPattern rawTarget σ p t f, hf⟩

noncomputable section
private def finishPreparation (B : Builtins) (kind : Kind) (name : OpaqueName)
    (rawPattern rawTarget : Val) (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput) (bound : RangeExpr) :
    Except PreparationError (Option PathEnv × RangeExpr × TargetInput) :=
  if B.valKind name ≠ some kind then
    .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) .invalidTarget (by decide))
  else if ¬ (bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical) then
    .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) .invalidPattern (by decide))
  else match snapshot, pat, target, bound with
    | none, .based b _, _, _ => .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) (.unbound b) (by intro h; cases h))
    | none, .secrets, _, _ => .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) .secretsUnbound (by decide))
    | none, _, .homePath _, _ => .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) (.unbound .home) (by decide))
    | none, _, .relativePath _, _ => .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) (.unbound .cwd) (by decide))
    | none, _, _, .based b _ => .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) (.unbound b) (by intro h; cases h))
    | none, _, _, .secrets => .error (prepareError rawPattern rawTarget snapshot (some pat) (some target) .secretsUnbound (by decide))
    | _, _, _, _ => .ok (snapshot, pat, target)

private theorem finishPreparation_target {B kind name rawPattern rawTarget snapshot pat target bound snapshot' pat' target'}
    (h : finishPreparation B kind name rawPattern rawTarget snapshot pat target bound = .ok (snapshot',pat',target')) :
    target' = target := by
  unfold finishPreparation at h
  split at h
  · cases h
  · split at h
    · cases h
    · cases snapshot <;> cases pat <;> cases target <;> cases bound <;> cases h <;> rfl

private theorem except_bind_ok {ε α β : Type} {x : Except ε α} {f : α → Except ε β} {y : β}
    (h : x.bind f = .ok y) : ∃ a, x = .ok a ∧ f a = .ok y := by
  cases x with
  | error e => cases h
  | ok a => exact ⟨a,rfl,h⟩

private def prepareCore (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName)
    (bases : Option Val) (pattern input : Val) (bound : RangeExpr) :
    Except PreparationError (Option PathEnv × RangeExpr × TargetInput) :=
  let pval := closeVal cap pattern
  let ival := closeVal cap input
  Except.bind (match parseAtPattern kind pval with
    | none => .error (prepareError pval ival none none none .invalidPattern (by decide))
    | some r => .ok r) fun pat =>
  Except.bind (match B.valContent name with
    | none => match parseAtInput kind ival with
      | none => .error (prepareError pval ival none (some pat) none .invalidTarget (by decide))
      | some t => .ok t
    | some _ => (if groundVal ival then
        match ival.reqTarget with
        | none => .error (prepareError pval ival none (some pat) none .invalidTarget (by decide))
        | some t => .ok (.absolute t)
      else .error (prepareError pval ival none (some pat) none .invalidTarget (by decide)))) fun target =>
  Except.bind (match bases with
    | none => .ok none
    | some b => match closeVal cap b with
      | .pathBases σ => (if σ.Valid then .ok (some σ)
          else .error (prepareError pval ival none (some pat) (some target) .invalidTarget (by decide)))
      | _ => .error (prepareError pval ival none (some pat) (some target) .invalidTarget (by decide))) fun snapshot =>
  finishPreparation B kind name pval ival snapshot pat target bound

def AtPrepare (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName)
    (bases : Option Val) (pattern input : Val) (index : RangeIx) :
    Except AtError (Option PathEnv × RangeExpr × TargetInput × RangeExpr) :=
  match index with
  | .rvar _ => .error (AtError.save (closeVal cap pattern) (closeVal cap input) none none none .staticIndex)
  | .fixed bound => match prepareCore B cap kind name bases pattern input bound with
    | .error e => .error e.detail
    | .ok (snapshot, pat, target) => .ok (snapshot, pat, target, bound)

def AtPrepared (B : Builtins) (cap : Capture) (kind : Kind) (name : OpaqueName)
    (bases : Option Val) (pattern input : Val) (index : RangeIx)
    (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput) (bound : RangeExpr) : Prop :=
  AtPrepare B cap kind name bases pattern input index = .ok (snapshot, pat, target, bound)

/-- 解析に成功した入力と同じ有効な起点値を、固定上限の準備へ渡す。 -/
theorem AtPrepared.of_path_bases {B cap kind name bases pattern input pat target bound σ}
    (hk : B.valKind name = some kind) (hc : B.valContent name = none)
    (hp : parseAtPattern kind (closeVal cap pattern) = some pat)
    (hi : parseAtInput kind (closeVal cap input) = some target)
    (hb : closeVal cap bases = .pathBases σ) (hσ : σ.Valid)
    (hbound : bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical) :
    AtPrepared B cap kind name (some bases) pattern input (.fixed bound)
      (some σ) pat target bound := by
  simp [AtPrepared,AtPrepare,prepareCore,hp,hi,hb,hσ,hc,finishPreparation,hk,hbound,Except.bind]

theorem AtPrepared.fixed_index {B cap kind name bases pattern input index snapshot pat target bound}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    index = .fixed bound := by
  cases index with
  | rvar i => cases h
  | fixed r =>
    unfold AtPrepared AtPrepare at h
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e => simp [he] at h
    | ok value => rcases value with ⟨σ,p,t⟩; simp only [he, Except.ok.injEq, Prod.mk.injEq] at h; exact congrArg RangeIx.fixed h.2.2.2

theorem AtPrepared.request {B cap kind name bases pattern input index snapshot pat target bound T}
    (hc : B.valContent name = some T)
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    groundVal (closeVal cap input) = true ∧
      ∃ t, (closeVal cap input).reqTarget = some t ∧ target = .absolute t := by
  unfold AtPrepared AtPrepare at h
  cases index with
  | rvar i => cases h
  | fixed r =>
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e => simp [he] at h
    | ok value =>
      rcases value with ⟨snapshot',pat',target'⟩
      simp only [he,Except.ok.injEq,Prod.mk.injEq] at h
      obtain ⟨rfl,rfl,rfl,_⟩ := h
      unfold prepareCore at he
      obtain ⟨pat0,_,he⟩ := except_bind_ok he
      obtain ⟨a,hgr,he⟩ := except_bind_ok he
      have ha : groundVal (closeVal cap input) = true ∧
          ∃ t, (closeVal cap input).reqTarget = some t ∧ a = .absolute t := by
        simp only [hc] at hgr
        cases hg : groundVal (closeVal cap input) with
        | false => simp [hg] at hgr
        | true =>
          simp only [hg,ite_true] at hgr
          cases hr : (closeVal cap input).reqTarget with
          | none => simp [hr] at hgr
          | some t0 => simp only [hr,Except.ok.injEq] at hgr; exact ⟨rfl,t0,rfl,hgr.symm⟩
      obtain ⟨snapshot0,_,he⟩ := except_bind_ok he
      have ht := finishPreparation_target he
      rw [ht]
      exact ha

/-- 準備の snapshot は、渡された bases の閉じた値に由来する。 -/
theorem AtPrepared.snapshot_source {B cap kind name bases pattern input index snapshot pat target bound ρ}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (hρ : snapshot = some ρ) :
    ∃ b, bases = some b ∧ closeVal cap b = .pathBases ρ := by
  unfold AtPrepared AtPrepare at h
  cases index with
  | rvar i => cases h
  | fixed r =>
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e => simp [he] at h
    | ok value =>
      rcases value with ⟨snapshot',pat',target'⟩
      simp only [he,Except.ok.injEq,Prod.mk.injEq] at h
      obtain ⟨rfl,rfl,rfl,_⟩ := h
      unfold prepareCore at he
      obtain ⟨_,_,he⟩ := except_bind_ok he
      obtain ⟨_,_,he⟩ := except_bind_ok he
      obtain ⟨snap,hs,he⟩ := except_bind_ok he
      have hsnap : snapshot' = snap := by
        unfold finishPreparation at he
        split at he
        · cases he
        · split at he
          · cases he
          · cases snap <;> cases snapshot' <;> cases ‹RangeExpr› <;>
              cases ‹TargetInput› <;> cases r <;> cases he <;> rfl
      rw [hsnap] at hρ
      cases bases with
      | none => cases hs; cases hρ
      | some b =>
        refine ⟨b,rfl,?_⟩
        cases hb : closeVal cap b <;> simp only [hb] at hs <;> try cases hs
        case pathBases σ =>
          split at hs
          · cases hs; cases hρ; rfl
          · cases hs

/-- 解析に成功した条件と静的上限の形成、および snapshot なしの絶対形。 -/
theorem AtPrepared.formed {B cap kind name bases pattern input index snapshot pat target bound}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    (pat.FitsKind kind ∧ pat.WF ∧ pat.Canonical) ∧
    (bound.FitsKind kind ∧ bound.WF ∧ bound.Canonical) ∧
    (snapshot = none → ∃ p t b, pat = .absolute p ∧ target = .absolute t ∧ bound = .absolute b) := by
  unfold AtPrepared AtPrepare at h
  cases index with
  | rvar i => cases h
  | fixed r =>
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e => simp [he] at h
    | ok value =>
      rcases value with ⟨snapshot',pat',target'⟩
      simp only [he,Except.ok.injEq,Prod.mk.injEq] at h
      obtain ⟨rfl,rfl,rfl,rfl⟩ := h
      unfold prepareCore at he
      obtain ⟨p,hp,he⟩ := except_bind_ok he
      obtain ⟨t,_,he⟩ := except_bind_ok he
      obtain ⟨snap,_,he⟩ := except_bind_ok he
      have hpw : p.FitsKind kind ∧ p.WF ∧ p.Canonical := by
        have hp' : parseAtPattern kind (closeVal cap pattern) = some p := by
          cases hh : parseAtPattern kind (closeVal cap pattern) <;> simp_all
        cases hv : closeVal cap pattern <;> simp only [hv,parseAtPattern] at hp' <;> try cases hp'
        split at hp'
        · cases hp'; assumption
        · cases hp' 
      unfold finishPreparation at he
      split at he
      · cases he
      · split at he
        · cases he
        · rename_i hw
          have hw := Classical.not_not.mp hw
          cases snap <;> cases p <;> cases t <;> cases r <;> cases he
          all_goals refine ⟨hpw,hw,?_⟩
          all_goals intro hn
          all_goals first | exact ⟨_,_,_,rfl,rfl,rfl⟩ | cases hn

/-- 成功した準備の入力と bases は、それぞれ二経路のいずれかである。 -/
theorem AtPrepared.origins {B cap kind name bases pattern input index snapshot pat target bound}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    (B.valContent name = none ∧ parseAtInput kind (closeVal cap input) = some target ∨
      ∃ T t, B.valContent name = some T ∧ groundVal (closeVal cap input) = true ∧
        (closeVal cap input).reqTarget = some t ∧ target = .absolute t) ∧
    (bases = none ∧ snapshot = none ∨
      ∃ b σ, bases = some b ∧ closeVal cap b = .pathBases σ ∧ σ.Valid ∧ snapshot = some σ) := by
  unfold AtPrepared AtPrepare at h
  cases index with
  | rvar i => cases h
  | fixed r =>
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e => simp [he] at h
    | ok value =>
      rcases value with ⟨snapshot',pat',target'⟩
      simp only [he,Except.ok.injEq,Prod.mk.injEq] at h
      obtain ⟨rfl,rfl,rfl,_⟩ := h
      unfold prepareCore at he
      obtain ⟨p,_,he⟩ := except_bind_ok he
      obtain ⟨t,hi,he⟩ := except_bind_ok he
      obtain ⟨snap,hb,he⟩ := except_bind_ok he
      have heq : (snapshot',pat',target') = (snap,p,t) := by
        unfold finishPreparation at he
        split at he
        · cases he
        · split at he
          · cases he
          · split at he <;> cases he <;> rfl
      obtain ⟨rfl,rfl,rfl⟩ := Prod.mk.inj heq
      constructor
      · cases hc : B.valContent name with
        | none =>
          refine Or.inl ⟨rfl,?_⟩
          simp only [hc] at hi
          cases hx : parseAtInput kind (closeVal cap input) <;> simp_all
        | some T =>
          simp only [hc] at hi
          split at hi
          · rename_i hg
            cases hr : (closeVal cap input).reqTarget <;> simp only [hr] at hi
            · cases hi
            · cases hi; exact Or.inr ⟨T,_,rfl,hg,rfl,rfl⟩
          · cases hi
      · cases bases with
        | none => cases hb; exact Or.inl ⟨rfl,rfl⟩
        | some b =>
          cases hv : closeVal cap b <;> simp only [hv] at hb <;> try cases hb
          split at hb
          · rename_i hvalid
            cases hb; exact Or.inr ⟨b,_,rfl,hv,hvalid,rfl⟩
          · cases hb

theorem AtPrepare.fixed_index {index : RangeIx} (h : index.WF 0) : ∃ bound, index = .fixed bound := by
  cases index with
  | fixed r => exact ⟨r, rfl⟩
  | rvar i => exact False.elim (Nat.not_lt_zero i h)

theorem AtPrepare.no_staticIndex {B cap kind name bases pattern input index detail}
    (hw : index.WF 0) (h : AtPrepare B cap kind name bases pattern input index = .error detail) :
    detail.failure ≠ .staticIndex := by
  obtain ⟨r, rfl⟩ := AtPrepare.fixed_index hw
  unfold AtPrepare at h
  cases he : prepareCore B cap kind name bases pattern input r with
  | error e => simp only [he, Except.error.injEq] at h; cases h; exact e.notStatic
  | ok value => rcases value with ⟨σ,p,t⟩; simp [he] at h

/-- 保存値の九欄は、全入力と全失敗種別について同じ入力と解決結果を持つ。 -/
theorem AtError.save_exact (p t : Val) (snapshot : Option PathEnv)
    (pp : Option RangeExpr) (pt : Option TargetInput) (f : AtFailure) :
    let d := AtError.save p t snapshot pp pt f
    d.originalPattern = p ∧ d.originalTarget = t ∧ d.failure = f ∧
    d.parsedPattern = pp ∧ d.parsedTarget = pt ∧
    d.resolvedPatterns = pp.bind (resolveSnapshot snapshot) ∧
    d.resolvedTarget = pt.bind (resolveTargetSnapshot snapshot) ∧
    d.patternBase = pp.bind RangeExpr.base? ∧ d.targetBase = pt.bind TargetInput.base? :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

private def PreparationError.Saved (p t : Val) (e : PreparationError) : Prop :=
  ∃ snapshot pp pt, e.detail = AtError.save p t snapshot pp pt e.detail.failure

private theorem error_bind_property {ε α β : Type} {x : Except ε α} {f : α → Except ε β}
    {e : ε} {property : ε → Prop}
    (hx : ∀ e, x = .error e → property e)
    (hf : ∀ a e, f a = .error e → property e)
    (he : x.bind f = .error e) : property e := by
  cases x with
  | error e => cases he; exact hx e rfl
  | ok a => exact hf a e he

private theorem finishPreparation_saved {B kind name rawPattern rawTarget snapshot pat target bound e}
    (h : finishPreparation B kind name rawPattern rawTarget snapshot pat target bound = .error e) :
    e.Saved rawPattern rawTarget := by
  unfold finishPreparation at h
  split at h
  · cases h; exact ⟨_,_,_,rfl⟩
  · split at h
    · cases h; exact ⟨_,_,_,rfl⟩
    · split at h <;> cases h <;> exact ⟨_,_,_,rfl⟩

private theorem prepareCore_saved {B cap kind name bases pattern input bound e}
    (h : prepareCore B cap kind name bases pattern input bound = .error e) :
    e.Saved (closeVal cap pattern) (closeVal cap input) := by
  unfold prepareCore at h
  apply error_bind_property (he := h)
  · intro e he
    split at he <;> cases he
    exact ⟨_,_,_,rfl⟩
  · intro pat e he
    apply error_bind_property (he := he)
    · intro e he
      split at he
      · split at he <;> cases he
        exact ⟨_,_,_,rfl⟩
      · split at he
        · split at he <;> cases he
          exact ⟨_,_,_,rfl⟩
        · cases he; exact ⟨_,_,_,rfl⟩
    · intro target e he
      apply error_bind_property (he := he)
      · intro e he
        split at he
        · cases he
        · split at he
          · split at he <;> cases he
            exact ⟨_,_,_,rfl⟩
          · cases he; exact ⟨_,_,_,rfl⟩
      · intro snapshot e he
        exact finishPreparation_saved he

private theorem finishPreparation_public {B kind name rawPattern rawTarget snapshot pat target bound e}
    (h : finishPreparation B kind name rawPattern rawTarget snapshot pat target bound = .error e) :
    e.detail.failure ≠ .outsideScope := by
  unfold finishPreparation at h
  split at h
  · cases h; simp [prepareError, AtError.save]
  · split at h
    · cases h; simp [prepareError, AtError.save]
    · split at h <;> cases h <;> simp [prepareError, AtError.save]

private theorem prepareCore_public {B cap kind name bases pattern input bound e}
    (h : prepareCore B cap kind name bases pattern input bound = .error e) :
    e.detail.failure ≠ .outsideScope := by
  unfold prepareCore at h
  apply error_bind_property (property := fun e : PreparationError => e.detail.failure ≠ .outsideScope) (he := h)
  · intro e he
    split at he <;> cases he
    simp [prepareError, AtError.save]
  · intro pat e he
    apply error_bind_property (property := fun e : PreparationError => e.detail.failure ≠ .outsideScope) (he := he)
    · intro e he
      split at he
      · split at he <;> cases he
        simp [prepareError, AtError.save]
      · split at he
        · split at he <;> cases he
          simp [prepareError, AtError.save]
        · cases he; simp [prepareError, AtError.save]
    · intro target e he
      apply error_bind_property (property := fun e : PreparationError => e.detail.failure ≠ .outsideScope) (he := he)
      · intro e he
        split at he
        · cases he
        · split at he
          · split at he <;> cases he
            simp [prepareError, AtError.save]
          · cases he; simp [prepareError, AtError.save]
      · intro snapshot e he
        exact finishPreparation_public he

/-- 準備の失敗は、返す枝のない `outsideScope` を種別に持たない。 -/
theorem AtPrepare.no_outsideScope {B cap kind name bases pattern input index detail}
    (h : AtPrepare B cap kind name bases pattern input index = .error detail) :
    detail.failure ≠ .outsideScope := by
  cases index with
  | rvar i => cases h; simp [AtError.save]
  | fixed r =>
    unfold AtPrepare at h
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e =>
      simp only [he, Except.error.injEq] at h
      cases h
      exact prepareCore_public he
    | ok value => rcases value with ⟨σ,p,t⟩; simp [he] at h

/-- 準備のどの失敗でも、閉じた元入力と解析・解決の区別を同じ記録に保つ。 -/
theorem AtPrepare.error_saved {B cap kind name bases pattern input index detail}
    (h : AtPrepare B cap kind name bases pattern input index = .error detail) :
    ∃ snapshot pp pt, detail = AtError.save (closeVal cap pattern) (closeVal cap input)
      snapshot pp pt detail.failure := by
  cases index with
  | rvar i => cases h; exact ⟨none,none,none,rfl⟩
  | fixed r =>
    unfold AtPrepare at h
    cases he : prepareCore B cap kind name bases pattern input r with
    | error e =>
      simp only [he,Except.error.injEq] at h
      cases h
      exact prepareCore_saved he
    | ok result => rcases result with ⟨_,_,_⟩; simp [he] at h

example {B cap kind name bases pattern input index detail}
    (h : AtPrepare B cap kind name bases pattern input index = .error detail) :
    detail.originalPattern = closeVal cap pattern ∧ detail.originalTarget = closeVal cap input ∧
    ∃ snapshot, detail.resolvedPatterns = detail.parsedPattern.bind (resolveSnapshot snapshot) ∧
      detail.resolvedTarget = detail.parsedTarget.bind (resolveTargetSnapshot snapshot) ∧
      detail.patternBase = detail.parsedPattern.bind RangeExpr.base? ∧
      detail.targetBase = detail.parsedTarget.bind TargetInput.base? := by
  obtain ⟨snapshot,pp,pt,hs⟩ := AtPrepare.error_saved h
  have exactFields := AtError.save_exact (closeVal cap pattern) (closeVal cap input) snapshot pp pt detail.failure
  rw [hs]
  exact ⟨exactFields.1,exactFields.2.1,snapshot,rfl,rfl,rfl,rfl⟩

example {B cap kind name bases pattern input r}
    (hp : parseAtPattern kind (closeVal cap pattern) = none) :
    AtPrepare B cap kind name bases pattern input (.fixed r) =
      .error (AtError.save (closeVal cap pattern) (closeVal cap input) none none none .invalidPattern) := by
  simp [AtPrepare,prepareCore,hp,Except.bind,prepareError]

example {B cap kind name bases pattern input r pat}
    (hp : parseAtPattern kind (closeVal cap pattern) = some pat)
    (hc : B.valContent name = none) (hi : parseAtInput kind (closeVal cap input) = none) :
    AtPrepare B cap kind name bases pattern input (.fixed r) =
      .error (AtError.save (closeVal cap pattern) (closeVal cap input) none (some pat) none .invalidTarget) := by
  simp [AtPrepare,prepareCore,hp,hc,hi,Except.bind,prepareError]

example {B cap kind name bases pattern input r pat T}
    (hp : parseAtPattern kind (closeVal cap pattern) = some pat)
    (hc : B.valContent name = some T) (hg : groundVal (closeVal cap input) = false) :
    AtPrepare B cap kind name bases pattern input (.fixed r) =
      .error (AtError.save (closeVal cap pattern) (closeVal cap input) none (some pat) none .invalidTarget) := by
  simp [AtPrepare,prepareCore,hp,hc,hg,Except.bind,prepareError]

example {B cap kind name bases pattern input r pat T}
    (hp : parseAtPattern kind (closeVal cap pattern) = some pat)
    (hc : B.valContent name = some T) (hg : groundVal (closeVal cap input) = true)
    (hi : (closeVal cap input).reqTarget = none) :
    AtPrepare B cap kind name bases pattern input (.fixed r) =
      .error (AtError.save (closeVal cap pattern) (closeVal cap input) none (some pat) none .invalidTarget) := by
  simp [AtPrepare,prepareCore,hp,hc,hg,hi,Except.bind,prepareError]

end
end Benitoite.Release.Refinement
