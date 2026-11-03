import Benitoite.Release.Refinement.StepAccounting
import Benitoite.Release.Refinement.CoefficientModel

/-! # 基本操作の列の例示（設計書 01-12「篩の係数と基本操作の計上」） -/
namespace Benitoite.Release.Refinement.StepAccounting

structure Work (α : Type) where
  value : α
  actions : List Action

/-- byte の列を先頭から比較し、最初の不一致で止める。 -/
def compareBytes (phase : Phase) : List UInt8 → List UInt8 → Work Bool
  | [], [] => ⟨true,[.work phase .node]⟩
  | a::as, b::bs =>
    let head := [.work phase .node,
      .work phase .readByte,.work phase .readByte,.work phase .compareByte]
    if a = b then
      let rest := compareBytes phase as bs
      ⟨rest.value,head ++ [.work phase .edge,.work phase .edge] ++ rest.actions⟩
    else ⟨false,head⟩
  | _, _ => ⟨false,[.work phase .node]⟩

theorem compareBytes_eq (phase : Phase) (as bs : List UInt8) :
    (compareBytes phase as bs).value = true ↔ as = bs := by
  induction as generalizing bs with
  | nil => cases bs <;> simp [compareBytes]
  | cons a as ih =>
    cases bs with
    | nil => simp [compareBytes]
    | cons b bs =>
      simp only [compareBytes]
      split
      · rename_i he
        simp [he, ih]
      · rename_i he
        simp [he]

/-- 現在の列だけを走査する。アクセスした節点・辺を列へ残す。 -/
def lookup (phase : Phase) {α : Type} : List α → Nat → Work (Option α)
  | [], _ => ⟨none,[.work phase .node]⟩
  | x::_, 0 => ⟨some x,[.work phase .node,.work phase .element]⟩
  | _::xs, i+1 =>
    let rest := lookup phase xs i
    ⟨rest.value,[.work phase .node,.work phase .edge] ++ rest.actions⟩

theorem lookup_eq (phase : Phase) {α : Type} (xs : List α) (i : Nat) :
    (lookup phase xs i).value = xs[i]? := by
  induction xs generalizing i with
  | nil => simp [lookup]
  | cons x xs ih => cases i <;> simp [lookup, ih]

/-- ホストのポインタ幅によらない、検査済みの現在の列の番号。 -/
def currentId (bound index : Nat) : Option (Fin bound) :=
  if h : index < bound then some ⟨index,h⟩ else none

theorem currentId_sound {bound index : Nat} {i : Fin bound}
    (h : currentId bound index = some i) : i.val = index ∧ index < bound := by
  unfold currentId at h
  split at h
  · cases h; exact ⟨rfl,‹index < bound›⟩
  · cases h

/-- 数学 Int の入力を幅・下端・上端の順に検査する例。失敗した後の比較を記録しない。 -/
def readCoefficient (bits : Nat) (n : Int) : Work (Option Int) :=
  if 0 < bits then
    if -(2^(bits-1) : Int) ≤ n then
      if n < (2^(bits-1) : Int) then
        ⟨some n,List.replicate 3 (.work .normalize .compareWord)⟩
      else ⟨none,List.replicate 3 (.work .normalize .compareWord)⟩
    else ⟨none,List.replicate 2 (.work .normalize .compareWord)⟩
  else ⟨none,[.work .normalize .compareWord]⟩

theorem readCoefficient_eq (bits : Nat) (n : Int) :
    (readCoefficient bits n).value = CoefficientModel.save bits n := by
  by_cases hb : 0 < bits <;>
    by_cases hl : -(2^(bits-1) : Int) ≤ n <;>
      by_cases hu : n < (2^(bits-1) : Int) <;>
        simp [readCoefficient, CoefficientModel.save, CoefficientRepresented,hb,hl,hu]

/-- 入力を順に検査した後にだけ加算し、結果を保存する例。保存済み i128 の操作数を定めない。 -/
def addCoefficients (bits : Nat) (a b : Int) : Work (Option Int) :=
  let left := readCoefficient bits a
  match left.value with
  | none => left
  | some _ =>
    let right := readCoefficient bits b
    match right.value with
    | none => ⟨none,left.actions ++ right.actions⟩
    | some _ =>
      let result := readCoefficient bits (a+b)
      ⟨result.value,left.actions ++ right.actions ++ [.work .normalize .add] ++ result.actions⟩

theorem addCoefficients_eq (bits : Nat) (a b : Int) :
    (addCoefficients bits a b).value = CoefficientModel.binary bits .add a b := by
  cases ha : (readCoefficient bits a).value with
  | none =>
    have hn : ¬ CoefficientRepresented bits a := by
      simpa [CoefficientModel.save] using (readCoefficient_eq bits a).symm.trans ha
    simp [addCoefficients,ha,CoefficientModel.binary,hn]
  | some a' =>
    have hp := (CoefficientModel.save_some.mp ((readCoefficient_eq bits a).symm.trans ha)).2
    cases hb : (readCoefficient bits b).value with
    | none =>
      have hn : ¬ CoefficientRepresented bits b := by
        simpa [CoefficientModel.save] using (readCoefficient_eq bits b).symm.trans hb
      simp [addCoefficients,ha,hb,CoefficientModel.binary,hn]
    | some b' =>
      have hq := (CoefficientModel.save_some.mp ((readCoefficient_eq bits b).symm.trans hb)).2
      simp [addCoefficients,ha,hb,CoefficientModel.binary,hp,hq,readCoefficient_eq,
        CoefficientModel.Binary.eval]

/-- 逐次検査する加算の例を係数列へ適用し、各出力要素の破棄を予約する。 -/
def merge (bits : Nat) : List Int → List Int → Work (Except ProofStop (List Int))
  | [], [] => ⟨.ok [],[.work .normalize .node]⟩
  | a::as, b::bs =>
    let addition := addCoefficients bits a b
    let head := [.work .normalize .node,.work .normalize .element,.work .normalize .element] ++ addition.actions
    match addition.value with
    | none => ⟨.error .coefficientRepresentation,head⟩
    | some c =>
      let rest := merge bits as bs
      ⟨rest.value.map (c::·),head ++ [.create .body,.work .normalize .edge,
        .work .normalize .edge] ++ rest.actions⟩
  | _,_ => ⟨.error .malformed,[.work .normalize .node]⟩

theorem merge_eq {bits : Nat} {as bs cs : List Int}
    (h : (merge bits as bs).value = .ok cs) :
    as.length = bs.length ∧ cs = List.zipWith (·+·) as bs ∧
      ∀ c ∈ cs, CoefficientRepresented bits c := by
  induction as generalizing bs cs with
  | nil =>
    cases bs with
    | nil =>
      cases h
      exact ⟨rfl,rfl,by simp⟩
    | cons b bs => cases h
  | cons a as ih =>
    cases bs with
    | nil => cases h
    | cons b bs =>
      simp only [merge] at h
      split at h
      · cases h
      · rename_i c hc
        cases hr : (merge bits as bs).value with
        | error reason => simp [hr, Except.map] at h
        | ok rest =>
          simp only [hr, Except.map, Except.ok.injEq] at h
          subst cs
          obtain ⟨hl, he, hm⟩ := ih hr
          have hc' := CoefficientModel.binary_some ((addCoefficients_eq bits a b) ▸ hc)
          refine ⟨by simp [hl],by simp [he,hc'.1,CoefficientModel.Binary.eval],?_⟩
          intro x hx
          rcases List.mem_cons.mp hx with rfl | hx
          · exact hc'.2.1
          · exact hm x hx

/-- clone は各要素の読取り・生成・辺へ分け、暗黙の全体コピーをタグ一つにしない。 -/
def cloneElements (phase : Phase) (count : Nat) : List Action :=
  match count with
  | 0 => [.work phase .node]
  | n+1 => [.work phase .element,.create .body,.work phase .edge] ++ cloneElements phase n

/-- rollback・共有 handle・所有本体は、生成時のそれぞれの予約を使う。 -/
def rollback (tickets : List Ticket) : List Action := tickets.map Action.destroy

theorem rollback_all (s : StepState) :
    runActions s (rollback s.pending) =
      .ok {s with used := s.used+s.reserved, pending := []} := by
  obtain ⟨limit,used,pending,next⟩ := s
  induction pending generalizing used with
  | nil => simp [rollback, runActions, StepState.reserved]
  | cons t ts ih =>
    simp only [rollback, List.map_cons, runActions, stepAction, List.mem_cons_self, ↓reduceIte,
      List.erase_cons_head]
    have h := ih (used+1)
    simpa [rollback, StepState.reserved, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using h

theorem rollback_within_limit {s : StepState} (hs : s.Valid) :
    ∃ final, runActions s (rollback s.pending) = .ok final ∧ final.Valid ∧
      final.reserved = 0 ∧ final.used = s.used+s.reserved := by
  refine ⟨_,rollback_all s,runActions_valid hs (rollback_all s),rfl,rfl⟩

theorem work_used {α : Type} {w : Work α} {s s' : StepState}
    (h : runActions s w.actions = .ok s') : s'.used = s.used+w.actions.length := runActions_used h

end Benitoite.Release.Refinement.StepAccounting
