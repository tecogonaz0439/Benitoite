import Benitoite.Release.Refinement.Surface.PredicateSimulationListProviders

/-! # 固定したIO応答の同じ観測と、結果の内部名不生成 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

mutual
  theorem Value.groundVal {source rows x y} (related : Value source rows x y) : groundVal x = groundVal y := by
    cases related with
    | con children => exact congrArg (fun b => _ && b) children.groundVals
    | list children => exact children.groundVals
    | _ => rfl
  theorem Values.groundVals {source rows xs ys} (related : Values source rows xs ys) : groundVals xs = groundVals ys := by
    cases related with
    | nil => rfl
    | cons head tail => simp only [groundVals,head.groundVal,tail.groundVals]
end

mutual
  /-- 実IO要求のground検査を通る値は、関係する対応元と同じ値である。 -/
  theorem Value.eq_of_ground_right {source rows x y} (related : Value source rows x y)
      (ground : Refinement.groundVal y = true) : x = y := by
    cases related with
    | constant c => rfl
    | bytes bs => rfl
    | con children =>
      have fields := (Bool.and_eq_true_iff.mp ground).2
      rw [Values.eq_of_ground_right children fields]
    | list children => rw [Values.eq_of_ground_right children ground]
    | _ => cases ground
  theorem Values.eq_of_ground_right {source rows xs ys} (related : Values source rows xs ys)
      (ground : groundVals ys = true) : xs = ys := by
    cases related with
    | nil => rfl
    | cons head tail =>
      have fields := Bool.and_eq_true_iff.mp ground
      rw [head.eq_of_ground_right fields.1, tail.eq_of_ground_right fields.2]
end

theorem Value.eq_of_ground_left {source rows x y} (related : Value source rows x y)
    (ground : Refinement.groundVal x = true) : x = y :=
  related.eq_of_ground_right (related.groundVal ▸ ground)

mutual
  /-- 実要求のground検査を通る値は、組込み名を持つ構文を含まない。 -/
  theorem ground_value_noMint {keys value} (ground : Refinement.groundVal value = true) : ValueAvoid keys value := by
    cases value with
    | const c => exact ValueAvoid.constant _ c
    | bytesV bytes => exact ValueAvoid.bytes bytes
    | list values => exact ValueAvoid.list (ground_values_noMint ground)
    | con constructor types values =>
      exact ValueAvoid.con (ground_values_noMint (Bool.and_eq_true_iff.mp ground).2) constructor types
    | _ => cases ground
  theorem ground_values_noMint {keys values} (ground : Refinement.groundVals values = true) : ValuesAvoid keys values := by
    cases values with
    | nil => exact ValuesAvoid.nil _
    | cons head tail =>
      have parts := Bool.and_eq_true_iff.mp ground
      exact ValuesAvoid.cons.mpr ⟨ground_value_noMint parts.1,ground_values_noMint parts.2⟩
end

theorem Value.target {source rows x y} (related : Value source rows x y) : x.target? = y.target? := by
  cases related <;> rfl

theorem Values.firstTarget {source rows xs ys} (related : Values source rows xs ys) :
    (xs[0]?).bind Val.target? = (ys[0]?).bind Val.target? := by
  cases related with
  | nil => rfl
  | cons head _ => exact head.target

private theorem request_value_left {source rows x y target}
    (related : Value source rows x y) (sent : ScopedIOResponse.RequestSent .send [x] target) : x = y := by
  obtain ⟨value,request,single,shape,_,ground,_⟩ := sent rfl
  have same : value = x := (List.cons.inj single).1.symm
  subst value
  rcases shape with shape | ⟨range,snapshot,shape⟩
  · subst x
    cases related with
    | checkedRequest child => rw [child.eq_of_ground_left ground]
  · subst x
    cases related with
    | checkedAt child =>
      cases child with
      | some request => rw [request.eq_of_ground_left ground]

private theorem request_value_right {source rows x y target}
    (related : Value source rows x y) (sent : ScopedIOResponse.RequestSent .send [y] target) : x = y := by
  obtain ⟨value,request,single,shape,_,ground,_⟩ := sent rfl
  have same : value = y := (List.cons.inj single).1.symm
  subst value
  rcases shape with shape | ⟨range,snapshot,shape⟩
  · subst y
    cases related with
    | checkedRequest child => rw [child.eq_of_ground_right ground]
  · subst y
    cases related with
    | checkedAt child =>
      cases child with
      | some request => rw [request.eq_of_ground_right ground]

private theorem request_values_left {source rows xs ys target} (related : Values source rows xs ys)
    (sent : ScopedIOResponse.RequestSent .send xs target) : xs = ys := by
  obtain ⟨value,request,single,rest⟩ := sent rfl
  subst xs
  cases related with
  | cons head tail =>
    cases tail
    rw [request_value_left head (fun _ => ⟨_,_,rfl,rest⟩)]

private theorem request_values_right {source rows xs ys target} (related : Values source rows xs ys)
    (sent : ScopedIOResponse.RequestSent .send ys target) : xs = ys := by
  obtain ⟨value,request,single,rest⟩ := sent rfl
  subst ys
  cases related with
  | cons head tail =>
    cases tail
    rw [request_value_right head (fun _ => ⟨_,_,rfl,rest⟩)]

/-- 送信条件の要求全体はground検査を通るため、同じ要求と端点を保持する。 -/
theorem request_sent {source rows xs ys} (related : Values source rows xs ys)
    (operation : ScopedIOResponse.Operation) (target : Scope.Domain.Target) :
    ScopedIOResponse.RequestSent operation xs target ↔ ScopedIOResponse.RequestSent operation ys target := by
  by_cases send : operation = .send
  · subst operation
    constructor
    · intro h; rwa [← request_values_left related h]
    · intro h; rwa [request_values_right related h]
  · exact ⟨fun _ h => (send h).elim,fun _ h => (send h).elim⟩

/-- 固定した範囲付きIO応答は、同じ対象列と同じ失敗・正常結果を持つ。 -/
theorem scoped_io_response {source rows xs ys} (related : Values source rows xs ys)
    (name ts es out observations) :
    ScopedIOResponse.ioResponse name ts es xs out observations ↔
      ScopedIOResponse.ioResponse name ts es ys out observations := by
  simp only [ScopedIOResponse.ioResponse,related.firstTarget,request_sent related]

private theorem read_observations {source rows xs ys} (related : Values source rows xs ys) :
    ModelTargets.readObs xs = ModelTargets.readObs ys := by
  cases related with
  | nil => rfl
  | cons head tail =>
    cases tail with
    | nil => cases head <;> rfl
    | cons _ _ =>
      cases head with
      | constant c => cases c <;> rfl
      | _ => rfl

private theorem exit_code {source rows xs ys} (related : Values source rows xs ys) :
    ModelTargets.exitCode xs = ModelTargets.exitCode ys := by
  cases related with
  | nil => rfl
  | cons head tail =>
    cases tail with
    | nil => cases head <;> rfl
    | cons _ _ =>
      cases head with
      | constant c => cases c <;> rfl
      | _ => rfl

/-- パス操作・print・exit・通常File.readTextの固定表も、同じ観測と応答を持つ。 -/
theorem model_targets_io_response {source rows xs ys} (related : Values source rows xs ys)
    (name ts es out observations) :
    ModelTargets.ioResponse name ts es xs out observations ↔ ModelTargets.ioResponse name ts es ys out observations := by
  simp only [ModelTargets.ioResponse,scoped_io_response related,exit_code related,read_observations related]

theorem scoped_reply_noMint {keys kind out} (reply : ScopedIOResponse.Reply kind out) : OutcomeAvoid keys out := by
  cases reply with
  | ok payload =>
    apply ValueAvoid.con
    apply ValuesAvoid.cons.mpr
    refine ⟨?_,ValuesAvoid.nil _⟩
    cases payload with
    | bytes bytes _ => exact ValueAvoid.bytes bytes
    | _ => exact ValueAvoid.constant _ _
  | error id => exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨ValueAvoid.constant _ _,ValuesAvoid.nil _⟩) _ _
  | err reason => trivial

theorem scoped_io_noMint {keys name ts es values out observations}
    (response : ScopedIOResponse.ioResponse name ts es values out observations) : OutcomeAvoid keys out :=
  scoped_reply_noMint response.choose_spec.2.2.2.1

theorem model_targets_io_noMint {keys name ts es values out observations}
    (response : ModelTargets.ioResponse name ts es values out observations) : OutcomeAvoid keys out := by
  rcases response with ⟨operation,_,_,reply⟩ | ⟨_,rfl,_⟩ | ⟨_,rfl,_⟩ | ⟨_,reply,_⟩
  · exact scoped_io_noMint reply
  · exact ValueAvoid.constant _ _
  · trivial
  · exact scoped_reply_noMint reply

theorem model_http_io_response {source rows xs ys} (related : Values source rows xs ys)
    (name ts es out observations) :
    ModelHttp.ioResponse name ts es xs out observations ↔ ModelHttp.ioResponse name ts es ys out observations := by
  simp only [ModelHttp.ioResponse,scoped_io_response related]

theorem model_http_io_noMint {keys name ts es values out observations}
    (response : ModelHttp.ioResponse name ts es values out observations) : OutcomeAvoid keys out :=
  scoped_io_noMint response.2

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
