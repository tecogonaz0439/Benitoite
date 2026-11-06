import Benitoite.Release.Refinement.Surface.CheckGuide

/-! ソースから生成した証明書の問い合わせを再検査し、打ち切りと拒否を入口へ伝える。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDiagnostics
open Check CheckArguments CheckSubtyping

mutual
  /-- 生成した部分型の候補に現れる全ての論理の証明書。 -/
  def leQueries : LeCertificate → List LogicCertificate
    | .trans a b => leQueries a ++ leQueries b
    | .list a | .lazy a | .mapValue _ a => leQueries a
    | .introduce _ _ proof => [proof]
    | .refine a _ _ proof => proof :: leQueries a
    | .dependentFn t => closureQueries t
    | .data _ args => typeArgumentsQueries args
    | _ => []
  def telQueries : TelCertificate → List LogicCertificate
    | .done a _ _ => leQueries a
    | .param _ a t => leQueries a ++ telQueries t
  def closureQueries : TelClosureCertificate → List LogicCertificate
    | .refl _ => []
    | .tail c t => closureQueries c ++ telQueries t
  def typeArgumentsQueries : TypeArgsCertificate → List LogicCertificate
    | .nil => []
    | .covariant a rest | .contravariant a rest => leQueries a ++ typeArgumentsQueries rest
    | .invariant _ _ rest => typeArgumentsQueries rest
end

mutual
  def argumentQueries : ArgGuide → List LogicCertificate
    | .var | .dictionary _ _ _ | .const => []
    | .list gs => elementsQueries gs
    | .refine _ _ _ proof g => proof :: argumentQueries g
  def elementQueries : ElemGuide → List LogicCertificate
    | .mk _ g c => argumentQueries g ++ leQueries c
  def elementsQueries : List ElemGuide → List LogicCertificate
    | [] => []
    | g :: gs => elementQueries g ++ elementsQueries gs
end

/-- 規則が持つ直接の含意・事実の含意・部分型・実引数の証明書を同じ列へ集める。 -/
def hintQueries (h : Hints) : List LogicCertificate :=
  h.proofs ++ h.proofLists.flatten ++ h.subtypes.flatMap leQueries ++
    (h.arguments.flatMap elementsQueries)

mutual
  /-- 案内の全ての子へ進み、問い合わせのソース位置を保つ。 -/
  def guideQueries : Guide → List LogicCertificate
    | .unknown | .failure _ => []
    | .node _ h cs => hintQueries h ++ guidesQueries cs
  def guidesQueries : List Guide → List LogicCertificate
    | [] => []
    | g :: gs => guideQueries g ++ guidesQueries gs
end

/-- 検出した不正は打ち切りに優先する。両方が打ち切りなら左の理由を保つ。 -/
private def combine : Decision → Decision → Decision
  | .rejected, _ | _, .rejected => .rejected
  | .unknown reason, _ => .unknown reason
  | _, .unknown reason => .unknown reason
  | .proved, .proved => .proved

/-- 問い合わせの位置を持たない証明書を、診断の成功としては扱わない。 -/
def certificateDecision (limit : Nat) (c : LogicCertificate) : Decision :=
  match c.query with
  | none => .rejected
  | some query => c.result limit query.premises query.goal

private def decisions (limit : Nat) : List LogicCertificate → Decision
  | [] => .proved
  | c :: cs => combine (certificateDecision limit c) (decisions limit cs)

/-- 案内に保持した問い合わせを再計算した三値の結果。型付けの受理には使わない。 -/
def guideDecision (limit : Nat) (g : Guide) : Decision := decisions limit (guideQueries g)

/-- ソース由来の問い合わせにおける、会計の実際の打ち切り。 -/
def StoppedQuery (limit : Nat) (c : LogicCertificate) : Prop :=
  ∃ query stop, c.query = some query ∧
    (stop = .stepsExhausted ∨ stop = .coefficientRepresentation) ∧
    StepAccounting.runActions (StepAccounting.initial limit) c.actions = .error stop

private theorem combine_unknown {a b : Decision} {reason : Option ProofStop}
    (h : combine a b = .unknown reason) : a = .unknown reason ∨ b = .unknown reason := by
  cases a <;> cases b <;> simp_all [combine]

private theorem certificate_unknown_stopped {limit : Nat} {c : LogicCertificate} {reason : Option ProofStop}
    (h : certificateDecision limit c = .unknown reason) : StoppedQuery limit c := by
  cases hq : c.query with
  | none => simp only [certificateDecision, hq] at h; cases h
  | some query =>
    have hh : c.result limit query.premises query.goal = .unknown reason := by
      simpa only [certificateDecision, hq] using h
    obtain ⟨stop, _, hs, ha⟩ := LogicCertificate.unknown_accounting hh
    exact ⟨query, stop, hq, hs, ha⟩

private theorem decisions_unknown {limit : Nat} {cs : List LogicCertificate} {reason : Option ProofStop}
    (h : decisions limit cs = .unknown reason) : ∃ c ∈ cs, StoppedQuery limit c := by
  induction cs with
  | nil => cases h
  | cons c cs ih =>
    rcases combine_unknown h with hc | hs
    · exact ⟨c, List.mem_cons_self, certificate_unknown_stopped hc⟩
    · obtain ⟨c', hm, hc'⟩ := ih hs
      exact ⟨c', List.mem_cons_of_mem _ hm, hc'⟩

/-- unknown は、同じ案内の問い合わせで会計が打ち切ったときだけ返る。 -/
theorem guide_unknown_stopped {limit : Nat} {g : Guide} {reason : Option ProofStop}
    (h : guideDecision limit g = .unknown reason) : ∃ c ∈ guideQueries g, StoppedQuery limit c :=
  decisions_unknown h

private theorem combine_rejected_right (a : Decision) : combine a .rejected = .rejected := by
  cases a <;> rfl

private theorem decisions_rejected {limit : Nat} {cs : List LogicCertificate} {c : LogicCertificate}
    (hc : c ∈ cs) (h : certificateDecision limit c = .rejected) : decisions limit cs = .rejected := by
  induction cs with
  | nil => cases hc
  | cons d ds ih =>
    rcases List.mem_cons.mp hc with rfl | hc
    · simp only [decisions, h, combine]
    · rw [decisions, ih hc, combine_rejected_right]

/-- 実際に malformed と判定された証明書は、ほかの問い合わせが打ち切られても拒否を入口へ返す。 -/
theorem guide_malformed_rejected {limit : Nat} {g : Guide} {c : LogicCertificate} {query : LogicQuery}
    (hc : c ∈ guideQueries g) (hq : c.query = some query)
    (hm : checkAccounted limit c.actions (Pred.ofConjuncts query.premises) query.goal c.certificate =
      .stopped .malformed) : guideDecision limit g = .rejected := by
  apply decisions_rejected hc
  simp only [certificateDecision, hq]
  exact LogicCertificate.malformed_rejected hm

end Benitoite.Release.Refinement.Surface.CheckDiagnostics
