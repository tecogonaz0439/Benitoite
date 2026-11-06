import Benitoite.Release.Refinement.Surface.CheckEntrypoints
import Benitoite.Release.Refinement.Surface.CheckDeclarationBase

/-! 関数と型クラスの実装を、宣言の署名と本体の表層の規則で検査する。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDeclarations
open CheckAdmissible

/-- 依存列の末尾で、推論と再検査の診断を保持する。 -/
def bodyResult (q : Check.Input) (rows : List Bool) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (body : Block) (a : Ty) (e : Eff) : Check.Result Unit :=
  match (CheckInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e).toCheck with
  | .error err => .error err
  | .ok result =>
    let g := CheckFinite.guide q.formation.atoms result.guide
    if Check.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e g then .ok ()
    else .error (Check.proofFailure path q.proofSteps g)

/-- 依存列の末尾における、表層のブロックの実際の検査。 -/
def bodyChecker : BlockChecker := fun q rows C Γ Φ path body a e =>
  (bodyResult q rows C Γ Φ path body a e).toBool

private def bodyTelResult (q : Check.Input) (rows : List Bool) (C : TypeCtx)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : Tel → Block → Check.Result Unit
  | .done a e, body => bodyResult q rows C Γ Φ path body a e
  | .param _ a rest, body => bodyTelResult q rows C (Γ.extend a) (Φ.map Pred.lift) path rest body

/-- 依存列の束縛の下で、実際の本体の推論又は証明書の会計が停止した。 -/
def BodyTelStopped (q : Check.Input) (rows : List Bool) (C : TypeCtx)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : Tel → Block → Prop
  | .done a e, body => Check.InferenceStopped q
      (CheckInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e)
  | .param _ a rest, body => BodyTelStopped q rows C (Γ.extend a) (Φ.map Pred.lift) path rest body

private def methodsResult (q : Check.Input) (i : ImplName) (path : List Nat)
    (id : ImplDecl) (cd : ClassDecl) (views : MethName → CoverageView) : List MethName → Check.Result Unit
  | [] => .ok ()
  | m :: rest => Except.bind (match cd.methods m, id.methods m with
    | some ms, some body =>
      let bodyQ := {q with D := q.D.withView (views m), proofSteps := q.methodSteps i m}
      bodyTelResult bodyQ (telQ ms.neffs ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
        (bindParams [] (id.dictTys.map (shiftType q ms.tparams.length))) []
        (path ++ [q.methods.idxOf m]) (methodTel q id ms) body
    | _, _ => .ok ()) (fun _ => methodsResult q i path id cd views rest)

/-- 実装のいずれかのメソッドで、宣言どおりの文脈における本体の検査が停止した。 -/
def MethodsStopped (q : Check.Input) (i : ImplName) (path : List Nat)
    (id : ImplDecl) (cd : ClassDecl) (views : MethName → CoverageView) : Prop :=
  ∃ m ∈ q.methods, ∃ ms body, cd.methods m = some ms ∧ id.methods m = some body ∧
    BodyTelStopped {q with D := q.D.withView (views m), proofSteps := q.methodSteps i m}
      (telQ ms.neffs ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
      (bindParams [] (id.dictTys.map (shiftType q ms.tparams.length))) []
      (path ++ [q.methods.idxOf m]) (methodTel q id ms) body

private def structuralChecker : BlockChecker := fun _ _ _ _ _ _ _ _ _ => true

/-- 成功を変更せず、失敗時だけ詳細な本体の診断を求める。 -/
private def diagnosed (base : Check.Result Unit) (details : Unit → Check.Result Unit) : Check.Result Unit :=
  match base with
  | .ok () => .ok ()
  | .error original => match details () with
    | .ok () => .error original
    | .error err => .error err

private theorem diagnosed_ok {base details} (h : diagnosed base details = .ok ()) : base = .ok () := by
  cases base with
  | ok value => cases value; rfl
  | error err => cases hd : details () <;> simp [diagnosed, hd] at h

private theorem diagnosed_unknown {base details error}
    (h : diagnosed base details = .error error) (hu : error.kind = .unknown)
    (hb : ∀ err, base = .error err → err.kind = .rejected) : details () = .error error := by
  cases hbase : base with
  | ok value => cases value; simp [diagnosed, hbase] at h
  | error original =>
    cases hd : details () with
    | ok value =>
      cases value
      simp only [diagnosed, hbase, hd, Except.error.injEq] at h
      subst error
      rw [hb original hbase] at hu
      cases hu
    | error err =>
      simp only [diagnosed, hbase, hd, Except.error.injEq] at h
      cases h
      rfl

private theorem require_rejected {path reason test error}
    (h : Check.require path reason test = .error error) : error.kind = .rejected := by
  unfold Check.require at h
  split at h
  · cases h
  · cases h; rfl

/-- 関数の指定は、呼出し側の既定の証明の上限より優先する。 -/
def definitionInput (q : Check.Input) (d : Def) : Check.Input :=
  {q with proofSteps := d.proofSteps.getD q.proofSteps}

private def definitionDetails (q : Check.Input) (path : List Nat) (d : Def) : Check.Result Unit :=
  if (checkDefWith structuralChecker q path d).toBool then
    bodyTelResult q (telQ d.neffs d.toFunDecl.tel) d.tparams [] [] (path ++ [1]) d.toFunDecl.tel d.body
  else .ok ()

/-- 関数の署名の依存列で、本体の型と効果を照合する。証明の上限の明示指定は正である。 -/
def checkDef (q : Check.Input) (path : List Nat) (d : Def) : Check.Result Unit :=
  Except.bind (Check.require path "proof step limit must be positive"
    (match d.proofSteps with | none => true | some n => decide (0 < n)))
    (fun _ => diagnosed (checkDefWith bodyChecker (definitionInput q d) path d)
      (fun _ => definitionDetails (definitionInput q d) path d))

private def implementationDetails (q : Check.Input) (i : ImplName) (path : List Nat)
    (id : ImplDecl) (views : MethName → CoverageView) : Check.Result Unit :=
  if (checkImplWith structuralChecker q i path id views).toBool then
    match q.D.classes id.cls with
    | none => .ok ()
    | some cd => methodsResult q i (path ++ [1]) id cd views q.methods
  else .ok ()

/-- 実装の全メソッド・上位の辞書と、メソッドの実名を照合する。 -/
def checkImpl (q : Check.Input) (i : ImplName) (path : List Nat) (id : ImplDecl)
    (views : MethName → CoverageView := fun _ => q.D.view) : Check.Result Unit :=
  diagnosed (checkImplWith bodyChecker q i path id views)
    (fun _ => implementationDetails q i path id views)

/-- 詳細な診断を付けた関数検査の成功は、署名と本体の検査の成功を保つ。 -/
theorem checkDef_ok {q path d} (h : checkDef q path d = .ok ()) :
    checkDefWith bodyChecker (definitionInput q d) path d = .ok () := by
  unfold checkDef at h
  cases hv : Check.require path "proof step limit must be positive"
      (match d.proofSteps with | none => true | some n => decide (0 < n)) with
  | error err => simp [hv, Except.bind] at h
  | ok value => exact diagnosed_ok (by simpa only [hv, Except.bind] using h)

/-- 詳細な診断を付けた実装検査の成功は、署名と本体の検査の成功を保つ。 -/
theorem checkImpl_ok {q i path id views} (h : checkImpl q i path id views = .ok ()) :
    checkImplWith bodyChecker q i path id views = .ok () := diagnosed_ok h

private theorem bodyResult_unknown {q rows C Γ Φ path body a e error}
    (h : bodyResult q rows C Γ Φ path body a e = .error error) (hu : error.kind = .unknown) :
    Check.InferenceStopped q
      (CheckInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e) := by
  cases hr : (CheckInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e).toCheck with
  | error err =>
    simp only [bodyResult, hr] at h
    cases h
    exact Or.inl (CheckInfer.Result.toCheck_unknown hr hu)
  | ok s =>
    simp only [bodyResult, hr] at h
    split at h
    · cases h
    · cases h
      exact Or.inr ⟨s, CheckInfer.Result.toCheck_ok.mp hr, Check.proofFailure_unknown hu⟩

private theorem bodyTelResult_unknown {q rows C Γ Φ path t body error}
    (h : bodyTelResult q rows C Γ Φ path t body = .error error) (hu : error.kind = .unknown) :
    BodyTelStopped q rows C Γ Φ path t body := by
  cases t with
  | done a e => exact bodyResult_unknown h hu
  | param name a rest =>
    exact bodyTelResult_unknown (Γ := Γ.extend a) (Φ := Φ.map Pred.lift) (t := rest) h hu

private theorem methodsResult_unknown {q i path id cd views methods error}
    (h : methodsResult q i path id cd views methods = .error error) (hu : error.kind = .unknown) :
    ∃ m ∈ methods, ∃ ms body, cd.methods m = some ms ∧ id.methods m = some body ∧
      BodyTelStopped {q with D := q.D.withView (views m), proofSteps := q.methodSteps i m}
        (telQ ms.neffs ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
        (bindParams [] (id.dictTys.map (shiftType q ms.tparams.length))) []
        (path ++ [q.methods.idxOf m]) (methodTel q id ms) body := by
  cases methods with
  | nil => cases h
  | cons m rest =>
    simp only [methodsResult] at h
    cases hm : cd.methods m <;> cases hb : id.methods m <;> simp only [hm, hb] at h
    · obtain ⟨n, hn, data⟩ := methodsResult_unknown h hu
      exact ⟨n, List.mem_cons_of_mem _ hn, data⟩
    · obtain ⟨n, hn, data⟩ := methodsResult_unknown h hu
      exact ⟨n, List.mem_cons_of_mem _ hn, data⟩
    · obtain ⟨n, hn, data⟩ := methodsResult_unknown h hu
      exact ⟨n, List.mem_cons_of_mem _ hn, data⟩
    · rename_i ms body
      cases hc : bodyTelResult {q with D := q.D.withView (views m), proofSteps := q.methodSteps i m}
          (telQ ms.neffs ms.tel) (ms.tparams ++ TypeCtx.values id.tparams)
          (bindParams [] (id.dictTys.map (shiftType q ms.tparams.length))) []
          (path ++ [q.methods.idxOf m]) (methodTel q id ms) body with
      | error err =>
        simp only [hc, Except.bind, Except.error.injEq] at h
        subst err
        exact ⟨m, List.mem_cons_self, ms, body, hm, hb, bodyTelResult_unknown hc hu⟩
      | ok value =>
        simp only [hc, Except.bind] at h
        obtain ⟨n, hn, data⟩ := methodsResult_unknown h hu
        exact ⟨n, List.mem_cons_of_mem _ hn, data⟩

/-- 関数入口のunknownには、依存列の末尾での実際の打ち切りがある。 -/
theorem checkDef_unknown {q path d error} (h : checkDef q path d = .error error)
    (hu : error.kind = .unknown) :
    BodyTelStopped (definitionInput q d) (telQ d.neffs d.toFunDecl.tel) d.tparams [] []
      (path ++ [1]) d.toFunDecl.tel d.body := by
  unfold checkDef at h
  cases hv : Check.require path "proof step limit must be positive"
      (match d.proofSteps with | none => true | some n => decide (0 < n)) with
  | error err =>
    simp only [hv, Except.bind, Except.error.injEq] at h
    subst err
    rw [require_rejected hv] at hu
    cases hu
  | ok value =>
    simp only [hv, Except.bind] at h
    have hd := diagnosed_unknown h hu (fun _ hh => require_rejected hh)
    unfold definitionDetails at hd
    split at hd
    · exact bodyTelResult_unknown hd hu
    · cases hd

/-- 実装入口のunknownには、一覧にあるメソッド本体の実際の打ち切りがある。 -/
theorem checkImpl_unknown {q i path id views error} (h : checkImpl q i path id views = .error error)
    (hu : error.kind = .unknown) :
    ∃ cd, q.D.classes id.cls = some cd ∧ MethodsStopped q i (path ++ [1]) id cd views := by
  have hd := diagnosed_unknown h hu (fun _ hh => require_rejected hh)
  unfold implementationDetails at hd
  split at hd
  · cases hc : q.D.classes id.cls with
    | none => simp [hc] at hd
    | some cd => exact ⟨cd, rfl, methodsResult_unknown (by simpa only [hc] using hd) hu⟩
  · cases hd

end Benitoite.Release.Refinement.Surface.CheckDeclarations
