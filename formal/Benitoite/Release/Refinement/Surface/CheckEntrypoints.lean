import Benitoite.Release.Refinement.Surface.CheckInfer
import Benitoite.Release.Refinement.Surface.CheckFinite
import Benitoite.Release.Refinement.Surface.CheckDiagnostics

/-! ソースから型・効果・案内を計算し、同じ規則で再検査する公開入口。 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 計算した案内の型と効果を、有限の原子の表現に揃える。 -/
def finiteSynth (q : Input) (s : CheckInfer.Synth) : CheckInfer.Synth :=
  { type := CheckFinite.ty q.formation.atoms s.type
    effect := CheckFinite.eff q.formation.atoms s.effect
    guide := CheckFinite.guide q.formation.atoms s.guide }

/-- 再検査が失敗した案内の問い合わせを、実際の会計の結果で分類する。 -/
def proofFailure (path : List Nat) (limit : Nat) (g : Guide) : Error :=
  match CheckDiagnostics.guideDecision limit g with
  | .unknown _ => ⟨path, "proof accounting stopped", .unknown⟩
  | _ => ⟨path, "type or certificate check failed", .rejected⟩

/-- unknown の診断は、同じ問い合わせでの実際の打ち切りを持つ。 -/
theorem proofFailure_unknown {path limit g} (h : (proofFailure path limit g).kind = .unknown) :
    ∃ c ∈ CheckDiagnostics.guideQueries g, CheckDiagnostics.StoppedQuery limit c := by
  cases hd : CheckDiagnostics.guideDecision limit g with
  | proved => simp only [proofFailure, hd] at h; cases h
  | rejected => simp only [proofFailure, hd] at h; cases h
  | unknown reason => exact CheckDiagnostics.guide_unknown_stopped hd

/-- 不正と判定された証明書は、他の問い合わせの打ち切りに優先して拒否になる。 -/
theorem proofFailure_malformed {path limit g c query}
    (hc : c ∈ CheckDiagnostics.guideQueries g) (hq : c.query = some query)
    (hm : checkAccounted limit c.actions (Pred.ofConjuncts query.premises) query.goal c.certificate =
      .stopped .malformed) : (proofFailure path limit g).kind = .rejected := by
  simp only [proofFailure, CheckDiagnostics.guide_malformed_rejected hc hq hm]

/-- 推論の打ち切り、又は生成した問い合わせの会計の打ち切り。 -/
def InferenceStopped (q : Input) (r : CheckInfer.Result CheckInfer.Synth) : Prop :=
  (∃ path reason, r = .error (.stopped path reason)) ∨
  ∃ s, r = .ok s ∧ ∃ c ∈ CheckDiagnostics.guideQueries (finiteSynth q s).guide,
    CheckDiagnostics.StoppedQuery q.proofSteps c

private def recheck (q : Input) (path : List Nat) (test : CheckInfer.Synth → Bool)
    (r : CheckInfer.Result CheckInfer.Synth) : Result Inferred :=
  match r.toCheck with
  | .error err => .error err
  | .ok s =>
    let result := finiteSynth q s
    if test result then .ok (result.type, result.effect)
    else .error (proofFailure path q.proofSteps result.guide)

private theorem recheck_ok {q path test r a ε} (h : recheck q path test r = .ok (a, ε)) :
    ∃ s, r = .ok s ∧ test (finiteSynth q s) = true ∧
      (finiteSynth q s).type = a ∧ (finiteSynth q s).effect = ε := by
  cases hr : r.toCheck with
  | error err => simp only [recheck, hr] at h; cases h
  | ok s =>
    have hs := CheckInfer.Result.toCheck_ok.mp hr
    simp only [recheck, hr] at h
    split at h
    · next ht =>
      obtain ⟨ha, he⟩ := Prod.mk.inj (Except.ok.inj h)
      exact ⟨s, hs, ht, ha, he⟩
    · cases h

private theorem recheck_unknown {q path test r error}
    (h : recheck q path test r = .error error) (hu : error.kind = .unknown) : InferenceStopped q r := by
  cases hr : r.toCheck with
  | error err =>
    simp only [recheck, hr] at h
    cases h
    exact Or.inl (CheckInfer.Result.toCheck_unknown hr hu)
  | ok s =>
    simp only [recheck, hr] at h
    split at h
    · cases h
    · cases h
      exact Or.inr ⟨s, CheckInfer.Result.toCheck_ok.mp hr, proofFailure_unknown hu⟩

/-- 規則の案内を入力へ求めず、ソースから生成した案内だけを再検査する。 -/
def checkExpr (q : Input) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (path : List Nat) (e : Expr) : Result Inferred :=
  recheck q path (fun result => checkExprAt q [] [] C Γ Φ R p path e result.type result.effect result.guide)
    (CheckInfer.inferExpr q ⟨q.logicCertificates⟩ [] [] C Γ Φ R p path e)

def checkBlock (q : Input) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (path : List Nat) (body : Block) : Result Inferred :=
  recheck q path (fun result => checkBlockAt q [] [] C Γ Φ R p path body result.type result.effect result.guide)
    (CheckInfer.inferBlock q ⟨q.logicCertificates⟩ [] [] C Γ Φ R p path body)

/-- 成功した実入口には、同じ型と効果で再検査した支持付きの案内がある。 -/
theorem checkExpr_ok {q C Γ Φ R p path e a ε} (h : checkExpr q C Γ Φ R p path e = .ok (a, ε)) :
    ∃ g, g.Support q.formation.atoms ∧ checkExprAt q [] [] C Γ Φ R p path e a ε g = true := by
  obtain ⟨s, _, hc, ha, he⟩ := recheck_ok h
  rw [← ha, ← he]
  exact ⟨_, CheckFinite.guide_support _ _, hc⟩

theorem checkBlock_ok {q C Γ Φ R p path body a ε} (h : checkBlock q C Γ Φ R p path body = .ok (a, ε)) :
    ∃ g, g.Support q.formation.atoms ∧ checkBlockAt q [] [] C Γ Φ R p path body a ε g = true := by
  obtain ⟨s, _, hc, ha, he⟩ := recheck_ok h
  rw [← ha, ← he]
  exact ⟨_, CheckFinite.guide_support _ _, hc⟩

/-- 式の入口で unknown を返すなら、推論又は証明書の検査が打ち切られている。 -/
theorem checkExpr_unknown {q C Γ Φ R p path e error}
    (h : checkExpr q C Γ Φ R p path e = .error error) (hu : error.kind = .unknown) :
    InferenceStopped q (CheckInfer.inferExpr q ⟨q.logicCertificates⟩ [] [] C Γ Φ R p path e) :=
  recheck_unknown h hu

/-- ブロックの入口でも、子の打ち切りを拒否へ変えない。 -/
theorem checkBlock_unknown {q C Γ Φ R p path body error}
    (h : checkBlock q C Γ Φ R p path body = .error error) (hu : error.kind = .unknown) :
    InferenceStopped q (CheckInfer.inferBlock q ⟨q.logicCertificates⟩ [] [] C Γ Φ R p path body) :=
  recheck_unknown h hu

end Benitoite.Release.Refinement.Surface.Check
