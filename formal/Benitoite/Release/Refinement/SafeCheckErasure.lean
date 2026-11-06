import Benitoite.Release.Refinement.CheckErasureExamples

/-! # ラムダの外の成功した検査の消去

値の構文には入らず、計算・腕・節の本体を辿る。自由変数や具体化に依存する呼出しは保守的に保持する
（設計書 01-12「確かめる性質」）。
-/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open CheckErasure RefinementCheck
attribute [local instance] Classical.propDecidable

/-- 消去する閉じた呼出しと結果は、捕捉・値と局所参照の置換・型と行と範囲の具体化で変わらない。 -/
structure Stable (m n : Comp) : Prop where
  view : ∀ cap, (Closure.mk cap m).view = m ∧ (Closure.mk cap n).view = n
  values : ∀ ν ρ, m.subst ν ρ = m ∧ n.subst ν ρ = n
  types : ∀ c ts es, m.substTyAt c ts es = m ∧ n.substTyAt c ts es = n
  ranges : ∀ ρ, m.mapRangesN ρ = m ∧ n.mapRangesN ρ = n

/-- 部分型の証明で代用せず、閉じた評価が成功した安定な呼出しだけを消す。 -/
structure Site (t u : Ty) (v : Val) : Prop where
  expectedWF : u.WF 0 0 0
  normalSource : t.norm = t
  normalExpected : u.norm = u
  core : t.core = u.core
  accepts : RefinementCheck.accepts v u = true
  stable : Stable (call t u v) (.ret (ok u v))

mutual
  /-- 値の中のラムダ・閉包を保持した計算の書換え。 -/
  inductive Code : Comp → Comp → Prop
    | same (m) : Code m m
    | check {t u v} : Site t u v → Code (call t u v) (.ret (ok u v))
    | builder {k m n} : Code m n → Code (.builderLet k m) (.builderLet k n)
    | letIn {m m' n n'} : Code m m' → Code n n' → Code (.letIn m n) (.letIn m' n')
    | ite {v m m' n n'} : Code m m' → Code n n' → Code (.ite v m n) (.ite v m' n')
    | matchC {v as bs} : Arms as bs → Code (.match v as) (.match v bs)
    | lazyC {m n} : Code m n → Code (.lazyC m) (.lazyC n)
    | use {v m n} : Code m n → Code (.use v m) (.use v n)
    | handle {m n cs ds} : Code m n → Clauses cs ds → Code (.handle m cs) (.handle n ds)
  inductive Arms : List Arm → List Arm → Prop
    | nil : Arms [] []
    | plain {alts m n as bs} : Code m n → Arms as bs →
        Arms (.mk alts none m :: as) (.mk alts none n :: bs)
    | guard {alts g h m n as bs} : Code g h → Code m n → Arms as bs →
        Arms (.mk alts (some g) m :: as) (.mk alts (some h) n :: bs)
  inductive Clauses : List Clause → List Clause → Prop
    | nil : Clauses [] []
    | op {o a nt m n cs ds} : Code m n → Clauses cs ds →
        Clauses (.mk o a nt m :: cs) (.mk o a nt n :: ds)
    | fail {e m n cs ds} : Code m n → Clauses cs ds →
        Clauses (.fail e m :: cs) (.fail e n :: ds)
end

mutual
  /-- 計算の子だけを辿る。引数の値に含まれるラムダの本体には入らない。 -/
  def erase (m : Comp) : Comp :=
    match m with
    | .app (.prim name [t,u] [] []) [v] =>
      if name = PublicNames.checkName ∧ Site t u v then .ret (ok u v) else m
    | .builderLet k body => .builderLet k (erase body)
    | .letIn m n => .letIn (erase m) (erase n)
    | .ite v m n => .ite v (erase m) (erase n)
    | .match v as => .match v (eraseArms as)
    | .lazyC m => .lazyC (erase m)
    | .use v m => .use v (erase m)
    | .handle m cs => .handle (erase m) (eraseClauses cs)
    | m => m
  def eraseArms : List Arm → List Arm
    | [] => []
    | .mk alts none body :: as => .mk alts none (erase body) :: eraseArms as
    | .mk alts (some g) body :: as => .mk alts (some (erase g)) (erase body) :: eraseArms as
  def eraseClauses : List Clause → List Clause
    | [] => []
    | .mk o a nt m :: cs => .mk o a nt (erase m) :: eraseClauses cs
    | .fail e m :: cs => .fail e (erase m) :: eraseClauses cs
end

/-- 署名と型の宣言を保ち、トップレベルの定義の本体だけを書き換える。 -/
def eraseProgram (P : Program) : Program :=
  { P with defs := fun f => (P.defs f).map (fun d => { d with body := erase d.body }) }

mutual
  theorem erase_code (m : Comp) : Code m (erase m) := by
    cases m with
    | builderLet k m => exact .builder (erase_code m)
    | letIn m n => exact .letIn (erase_code m) (erase_code n)
    | ite v m n => exact .ite (erase_code m) (erase_code n)
    | «match» v as => exact .matchC (erase_arms as)
    | lazyC m => exact .lazyC (erase_code m)
    | use v m => exact .use (erase_code m)
    | handle m cs => exact .handle (erase_code m) (erase_clauses cs)
    | app f vs =>
      unfold erase
      split
      · next name t u v heq =>
        obtain ⟨rfl,rfl⟩ := Comp.app.inj heq
        split
        · next h => rw [h.1]; exact .check h.2
        · exact .same _
      all_goals first | contradiction | exact .same _
    | _ => exact .same _
  theorem erase_arms (as : List Arm) : Arms as (eraseArms as) := by
    cases as with
    | nil => exact .nil
    | cons a as =>
      cases a with
      | mk alts guard body =>
        cases guard with
        | none => exact .plain (erase_code body) (erase_arms as)
        | some g => exact .guard (erase_code g) (erase_code body) (erase_arms as)
  theorem erase_clauses (cs : List Clause) : Clauses cs (eraseClauses cs) := by
    cases cs with
    | nil => exact .nil
    | cons c cs =>
      cases c with
      | mk o a nt m => exact .op (erase_code m) (erase_clauses cs)
      | fail e m => exact .fail (erase_code m) (erase_clauses cs)
end

mutual
  theorem Code.subst {m n} (h : Code m n) (ν : Nat → Val) (ρ : Nat → LocalRef) :
      Code (m.subst ν ρ) (n.subst ν ρ) := by
    cases h with
    | same m => exact .same _
    | check h => rw [(h.stable.values ν ρ).1,(h.stable.values ν ρ).2]; exact .check h
    | builder h => exact .builder (h.subst _ _)
    | letIn h g => exact .letIn (h.subst _ _) (g.subst _ _)
    | ite h g => exact .ite (h.subst _ _) (g.subst _ _)
    | matchC h => exact .matchC (h.subst _ _)
    | lazyC h => exact .lazyC (h.subst _ _)
    | use h => exact .use (h.subst _ _)
    | handle h g => exact .handle (h.subst _ _) (g.subst _ _)
  theorem Arms.subst {as bs} (h : Arms as bs) (ν : Nat → Val) (ρ : Nat → LocalRef) :
      Arms (Arm.substList ν as ρ) (Arm.substList ν bs ρ) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (h.subst _ _) (g.subst _ _)
    | guard h g k => exact .guard (h.subst _ _) (g.subst _ _) (k.subst _ _)
  theorem Clauses.subst {cs ds} (h : Clauses cs ds) (ν : Nat → Val) (ρ : Nat → LocalRef) :
      Clauses (Clause.substList ν cs ρ) (Clause.substList ν ds ρ) := by
    cases h with
    | nil => exact .nil
    | op h g => exact .op (h.subst _ _) (g.subst _ _)
    | fail h g => exact .fail (h.subst _ _) (g.subst _ _)
end

mutual
  theorem Code.substTy {m n} (h : Code m n) (c : Nat) (ts : List Ty) (es : List Eff) :
      Code (m.substTyAt c ts es) (n.substTyAt c ts es) := by
    cases h with
    | same m => exact .same _
    | check h => rw [(h.stable.types c ts es).1,(h.stable.types c ts es).2]; exact .check h
    | builder h => exact .builder (h.substTy _ _ _)
    | letIn h g => exact .letIn (h.substTy _ _ _) (g.substTy _ _ _)
    | ite h g => exact .ite (h.substTy _ _ _) (g.substTy _ _ _)
    | matchC h => exact .matchC (h.substTy _ _ _)
    | lazyC h => exact .lazyC (h.substTy _ _ _)
    | use h => exact .use (h.substTy _ _ _)
    | handle h g => exact .handle (h.substTy _ _ _) (g.substTy _ _ _)
  theorem Arms.substTy {as bs} (h : Arms as bs) (c : Nat) (ts : List Ty) (es : List Eff) :
      Arms (Arm.substTyAtList c ts es as) (Arm.substTyAtList c ts es bs) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (h.substTy _ _ _) (g.substTy _ _ _)
    | guard h g k => exact .guard (h.substTy _ _ _) (g.substTy _ _ _) (k.substTy _ _ _)
  theorem Clauses.substTy {cs ds} (h : Clauses cs ds) (c : Nat) (ts : List Ty) (es : List Eff) :
      Clauses (Clause.substTyAtList c ts es cs) (Clause.substTyAtList c ts es ds) := by
    cases h with
    | nil => exact .nil
    | op h g => exact .op (h.substTy _ _ _) (g.substTy _ _ _)
    | fail h g => exact .fail (h.substTy _ _ _) (g.substTy _ _ _)
end

mutual
  theorem Code.mapRanges {m n} (h : Code m n) (ρ : Nat → RangeIx) :
      Code (m.mapRangesN ρ) (n.mapRangesN ρ) := by
    cases h with
    | same m => exact .same _
    | check h => rw [(h.stable.ranges ρ).1,(h.stable.ranges ρ).2]; exact .check h
    | builder h => exact .builder (h.mapRanges _)
    | letIn h g => exact .letIn (h.mapRanges _) (g.mapRanges _)
    | ite h g => exact .ite (h.mapRanges _) (g.mapRanges _)
    | matchC h => exact .matchC (h.mapRanges _)
    | lazyC h => exact .lazyC (h.mapRanges _)
    | use h => exact .use (h.mapRanges _)
    | handle h g => exact .handle (h.mapRanges _) (g.mapRanges _)
  theorem Arms.mapRanges {as bs} (h : Arms as bs) (ρ : Nat → RangeIx) :
      Arms (Arm.mapRangesListN ρ as) (Arm.mapRangesListN ρ bs) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (h.mapRanges _) (g.mapRanges _)
    | guard h g k => exact .guard (h.mapRanges _) (g.mapRanges _) (k.mapRanges _)
  theorem Clauses.mapRanges {cs ds} (h : Clauses cs ds) (ρ : Nat → RangeIx) :
      Clauses (Clause.mapRangesListN ρ cs) (Clause.mapRangesListN ρ ds) := by
    cases h with
    | nil => exact .nil
    | op h g => exact .op (h.mapRanges _) (g.mapRanges _)
    | fail h g => exact .fail (h.mapRanges _) (g.mapRanges _)
end

/-- 任意の適格な範囲引数で具体化しても、コードの対応を保つ。 -/
theorem Code.instR {m n} (h : Code m n) (rs : List RangeExpr) : Code (m.instR rs) (n.instR rs) := by
  cases rs with
  | nil => exact h
  | cons r rs => exact h.mapRanges _

/-- 捕捉した値は同じまま保持する。成功した呼出しの後の return では view の一致で捕捉の違いを吸収する。 -/
inductive ClosureRel : Closure → Closure → Prop
  | code {cap m n} : Code m n → ClosureRel (.mk cap m) (.mk cap n)
  | returned {cap cap' v} : (∀ c, closeVal c v = v) →
      ClosureRel (.mk cap (.ret v)) (.mk cap' (.ret v))

inductive FrameRel : Frame → Frame → Prop
  | letF {q q'} : ClosureRel q q' → FrameRel (.letF q) (.letF q')
  | mark : FrameRel .mark .mark
  | update (l) : FrameRel (.update l) (.update l)
  | release (v) : FrameRel (.release v) (.release v)
  | drop (l) : FrameRel (.drop l) (.drop l)
  | handleF {cap cs ds} : Clauses cs ds → FrameRel (.handleF cap cs) (.handleF cap ds)
  | guardF {v cap as bs next q q'} : Arms as bs → ClosureRel q q' →
      FrameRel (.guardF v cap as next q) (.guardF v cap bs next q')

inductive ContRel : Cont → Cont → Prop
  | nil : ContRel [] []
  | cons {f g k l} : FrameRel f g → ContRel k l → ContRel (f :: k) (g :: l)

inductive CellRel : Cell → Cell → Prop
  | builder (c) : CellRel (.builder c) (.builder c)
  | value (v) : CellRel (.val v) (.val v)
  | done (v) : CellRel (.done v) (.done v)
  | used : CellRel .used .used
  | thunk {q q'} : ClosureRel q q' → CellRel (.thunk q) (.thunk q')
  | cont {k k'} : ContRel k k' → CellRel (.cont k) (.cont k')

def StoreRel (μ μ' : Store) : Prop := ∀ l, Option.Rel CellRel (μ l) (μ' l)

inductive StateRel : State → State → Prop
  | run {q q' k k' μ μ'} : ClosureRel q q' → ContRel k k' → StoreRel μ μ' →
      StateRel (.run q k μ) (.run q' k' μ')
  | matchRun {v cap as bs next k k' μ μ'} : Arms as bs → ContRel k k' → StoreRel μ μ' →
      StateRel (.matchRun v cap as next k μ) (.matchRun v cap bs next k' μ')
  | error {rs k k' μ μ'} : ContRel k k' → StoreRel μ μ' → StateRel (.error rs k μ) (.error rs k' μ')
  | exit {n rs k k' μ μ'} : ContRel k k' → StoreRel μ μ' → StateRel (.exit n rs k μ) (.exit n rs k' μ')

end
end Benitoite.Release.Refinement.SafeCheckErasure
