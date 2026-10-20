import Benitoite.Surface.Lemmas.BuilderCapture

/-!
# コアの捕捉と番号の付け替え

構築器のセルを使う通常の計算と、外側のセルを保持できないクロージャを分ける。
設計書 01-12「構築器の局所文脈と旧構文の意味」に対応する。
-/
namespace Benitoite.Surface
open Benitoite.Release

/-- 新たに束縛した番号はそのまま、外側の番号だけを付け替える。 -/
theorem liftReads_rename {p q ξ} (h : ∀ i, p i → q (ξ i)) (n : Nat) :
    ∀ i, liftReads n p i → liftReads n q (upRen n ξ i) := by
  intro i hi
  unfold liftReads at *
  by_cases hn : i < n
  · exact Or.inl (by simp [upRen, hn])
  · exact Or.inr (by simpa [upRen, hn] using h (i - n) (hi.resolve_left hn))

mutual
  theorem Val.Reads.rename {p q ξ} (v : Val) (h : Val.Reads p v)
      (hr : ∀ i, p i → q (ξ i)) : Val.Reads q (v.rename ξ) := by
    cases v <;> simp only [Val.Reads, Val.rename] at h ⊢
    case var i => exact hr i h
    case lam ns ps body => exact Comp.Reads.rename body h (liftReads_rename hr _)
    case con c ts vs => exact Vals.Reads.rename vs h hr
    case dict c ts vs => exact Vals.Reads.rename vs h hr
    case list vs => exact Vals.Reads.rename vs h hr
    case setV vs => exact Vals.Reads.rename vs h hr
    case mapV ks vs => exact ⟨Vals.Reads.rename ks h.1 hr, Vals.Reads.rename vs h.2 hr⟩
    case super v s => exact Val.Reads.rename v h hr
  theorem Vals.Reads.rename {p q ξ} (vs : List Val) (h : Vals.Reads p vs)
      (hr : ∀ i, p i → q (ξ i)) : Vals.Reads q (Val.renameList ξ vs) := by
    cases vs <;> simp only [Vals.Reads, Val.renameList] at h ⊢
    case cons v vs => exact ⟨Val.Reads.rename v h.1 hr, Vals.Reads.rename vs h.2 hr⟩
  theorem Comp.Reads.rename {p q ξ} (m : Comp) (h : Comp.Reads p m)
      (hr : ∀ i, p i → q (ξ i)) : Comp.Reads q (m.rename ξ) := by
    cases m <;> simp only [Comp.Reads, Comp.rename] at h ⊢
    case builderLet k body => exact Comp.Reads.rename body h (liftReads_rename hr 1)
    case builderOp k op r vs =>
        refine ⟨?_, Vals.Reads.rename vs h.2 hr⟩
        cases r with
        | bound i => exact hr i h.1
        | loc _ => trivial
    case ret v => exact Val.Reads.rename v h hr
    case escape v => exact Val.Reads.rename v h hr
    case letIn m n => exact ⟨Comp.Reads.rename m h.1 hr, Comp.Reads.rename n h.2 (liftReads_rename hr 1)⟩
    case app f vs => exact ⟨Val.Reads.rename f h.1 hr, Vals.Reads.rename vs h.2 hr⟩
    case meth f m ts es vs => exact ⟨Val.Reads.rename f h.1 hr, Vals.Reads.rename vs h.2 hr⟩
    case ite v m n => exact ⟨Val.Reads.rename v h.1 hr, Comp.Reads.rename m h.2.1 hr, Comp.Reads.rename n h.2.2 hr⟩
    case «match» v arms => exact ⟨Val.Reads.rename v h.1 hr, Arms.Reads.rename arms h.2 hr⟩
    case lazyC m => exact Comp.Reads.rename m h hr
    case use v m => exact ⟨Val.Reads.rename v h.1 hr, Comp.Reads.rename m h.2 hr⟩
    case handle m cs => exact ⟨Comp.Reads.rename m h.1 hr, Clauses.Reads.rename cs h.2 hr⟩
    case resume k v => exact ⟨Val.Reads.rename k h.1 hr, Val.Reads.rename v h.2 hr⟩
  theorem Arms.Reads.rename {p q ξ} (arms : List Arm) (h : Arms.Reads p arms)
      (hr : ∀ i, p i → q (ξ i)) : Arms.Reads q (Arm.renameList ξ arms) := by
    cases arms with
    | nil => simp only [Arms.Reads, Arm.renameList]
    | cons a rest =>
        cases a with
        | mk alts g body =>
            cases g <;> simp only [Arms.Reads, Arm.renameList] at h ⊢
            case none => exact ⟨by simp, Comp.Reads.rename body h.2.1 (liftReads_rename hr _), Arms.Reads.rename rest h.2.2 hr⟩
            case some g => exact ⟨fun m hm => by cases hm; exact Comp.Reads.rename g (h.1 g rfl) (liftReads_rename hr _),
                Comp.Reads.rename body h.2.1 (liftReads_rename hr _), Arms.Reads.rename rest h.2.2 hr⟩
  theorem Clauses.Reads.rename {p q ξ} (cs : List Release.Clause) (h : Clauses.Reads p cs)
      (hr : ∀ i, p i → q (ξ i)) : Clauses.Reads q (Release.Clause.renameList ξ cs) := by
    cases cs with
    | nil => simp only [Clauses.Reads, Release.Clause.renameList]
    | cons c rest =>
        cases c <;> simp only [Clauses.Reads, Release.Clause.renameList] at h ⊢
        case mk o n nt body => exact ⟨Comp.Reads.rename body h.1 (liftReads_rename hr _), Clauses.Reads.rename rest h.2 hr⟩
        case fail e body => exact ⟨Comp.Reads.rename body h.1 (liftReads_rename hr _), Clauses.Reads.rename rest h.2 hr⟩
end

mutual
  /-- 通常の計算でセルを読むことは許し、生成するクロージャでの自由参照を制限する。 -/
  def Val.Captures (p : Nat → Prop) : Val → Prop
    | .lam _ ps body => Comp.Reads (liftReads ps.length p) body
    | .con _ _ vs | .list vs | .setV vs | .dict _ _ vs => Vals.Captures p vs
    | .mapV ks vs => Vals.Captures p ks ∧ Vals.Captures p vs
    | .super v _ => Val.Captures p v
    | .var .. | .const .. | .fnRef .. | .prim .. | .op .. | .raise .. | .loc .. | .bytesV .. => True
  def Vals.Captures (p : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.Captures p v ∧ Vals.Captures p vs
  def Comp.Captures (p : Nat → Prop) : Comp → Prop
    | .builderLet _ body => Comp.Captures (liftReads 1 p) body
    | .builderOp _ _ _ vs => Vals.Captures p vs
    | .ret v | .escape v => Val.Captures p v
    | .letIn m n => Comp.Captures p m ∧ Comp.Captures (liftReads 1 p) n
    | .app f vs | .meth f _ _ _ vs => Val.Captures p f ∧ Vals.Captures p vs
    | .ite v m n => Val.Captures p v ∧ Comp.Captures p m ∧ Comp.Captures p n
    | .match v arms => Val.Captures p v ∧ Arms.Captures p arms
    | .lazyC m => Comp.Reads p m
    | .use v m => Val.Captures p v ∧ Comp.Captures p m
    | .handle m cs => Comp.Captures p m ∧ Clauses.Reads p cs
    | .resume k v => Val.Captures p k ∧ Val.Captures p v
  def Arms.Captures (p : Nat → Prop) : List Arm → Prop
    | [] => True
    | .mk alts g body :: rest =>
        (∀ m, g = some m → Comp.Captures (liftReads (Arm.bindersOf alts) p) m) ∧
        Comp.Captures (liftReads (Arm.bindersOf alts) p) body ∧ Arms.Captures p rest
end

mutual
  theorem Val.Captures.rename {p q ξ} (v : Val) (h : Val.Captures p v)
      (hr : ∀ i, p i → q (ξ i)) : Val.Captures q (v.rename ξ) := by
    cases v <;> simp only [Val.Captures, Val.rename] at h ⊢
    case lam ns ps body => exact Comp.Reads.rename body h (liftReads_rename hr _)
    case con c ts vs => exact Vals.Captures.rename vs h hr
    case dict c ts vs => exact Vals.Captures.rename vs h hr
    case list vs => exact Vals.Captures.rename vs h hr
    case setV vs => exact Vals.Captures.rename vs h hr
    case mapV ks vs => exact ⟨Vals.Captures.rename ks h.1 hr, Vals.Captures.rename vs h.2 hr⟩
    case super v s => exact Val.Captures.rename v h hr
  theorem Vals.Captures.rename {p q ξ} (vs : List Val) (h : Vals.Captures p vs)
      (hr : ∀ i, p i → q (ξ i)) : Vals.Captures q (Val.renameList ξ vs) := by
    cases vs <;> simp only [Vals.Captures, Val.renameList] at h ⊢
    case cons v vs => exact ⟨Val.Captures.rename v h.1 hr, Vals.Captures.rename vs h.2 hr⟩
  theorem Comp.Captures.rename {p q ξ} (m : Comp) (h : Comp.Captures p m)
      (hr : ∀ i, p i → q (ξ i)) : Comp.Captures q (m.rename ξ) := by
    cases m <;> simp only [Comp.Captures, Comp.rename] at h ⊢
    case builderLet k body => exact Comp.Captures.rename body h (liftReads_rename hr 1)
    case builderOp k op r vs => exact Vals.Captures.rename vs h hr
    case ret v => exact Val.Captures.rename v h hr
    case escape v => exact Val.Captures.rename v h hr
    case letIn m n => exact ⟨Comp.Captures.rename m h.1 hr, Comp.Captures.rename n h.2 (liftReads_rename hr 1)⟩
    case app f vs => exact ⟨Val.Captures.rename f h.1 hr, Vals.Captures.rename vs h.2 hr⟩
    case meth f m ts es vs => exact ⟨Val.Captures.rename f h.1 hr, Vals.Captures.rename vs h.2 hr⟩
    case ite v m n => exact ⟨Val.Captures.rename v h.1 hr, Comp.Captures.rename m h.2.1 hr, Comp.Captures.rename n h.2.2 hr⟩
    case «match» v arms => exact ⟨Val.Captures.rename v h.1 hr, Arms.Captures.rename arms h.2 hr⟩
    case lazyC m => exact Comp.Reads.rename m h hr
    case use v m => exact ⟨Val.Captures.rename v h.1 hr, Comp.Captures.rename m h.2 hr⟩
    case handle m cs => exact ⟨Comp.Captures.rename m h.1 hr, Clauses.Reads.rename cs h.2 hr⟩
    case resume k v => exact ⟨Val.Captures.rename k h.1 hr, Val.Captures.rename v h.2 hr⟩
  theorem Arms.Captures.rename {p q ξ} (arms : List Arm) (h : Arms.Captures p arms)
      (hr : ∀ i, p i → q (ξ i)) : Arms.Captures q (Arm.renameList ξ arms) := by
    cases arms with
    | nil => simp only [Arms.Captures, Arm.renameList]
    | cons a rest =>
        cases a with
        | mk alts g body =>
            cases g <;> simp only [Arms.Captures, Arm.renameList] at h ⊢
            case none => exact ⟨by simp, Comp.Captures.rename body h.2.1 (liftReads_rename hr _), Arms.Captures.rename rest h.2.2 hr⟩
            case some g => exact ⟨fun m hm => by cases hm; exact Comp.Captures.rename g (h.1 g rfl) (liftReads_rename hr _),
                Comp.Captures.rename body h.2.1 (liftReads_rename hr _), Arms.Captures.rename rest h.2.2 hr⟩
end

mutual
  theorem Val.Reads.captures {p} (v : Val) (h : Val.Reads p v) : Val.Captures p v := by
    cases v <;> simp only [Val.Reads, Val.Captures] at h ⊢
    case lam ns ps body => exact h
    case con c ts vs => exact Vals.Reads.captures vs h
    case dict c ts vs => exact Vals.Reads.captures vs h
    case list vs => exact Vals.Reads.captures vs h
    case setV vs => exact Vals.Reads.captures vs h
    case mapV ks vs => exact ⟨Vals.Reads.captures ks h.1, Vals.Reads.captures vs h.2⟩
    case super v s => exact Val.Reads.captures v h
  theorem Vals.Reads.captures {p} (vs : List Val) (h : Vals.Reads p vs) : Vals.Captures p vs := by
    cases vs <;> simp only [Vals.Reads, Vals.Captures] at h ⊢
    case cons v vs => exact ⟨Val.Reads.captures v h.1, Vals.Reads.captures vs h.2⟩
  theorem Comp.Reads.captures {p} (m : Comp) (h : Comp.Reads p m) : Comp.Captures p m := by
    cases m <;> simp only [Comp.Reads, Comp.Captures] at h ⊢
    case builderLet k body => exact Comp.Reads.captures body h
    case builderOp k op r vs => exact Vals.Reads.captures vs h.2
    case ret v => exact Val.Reads.captures v h
    case escape v => exact Val.Reads.captures v h
    case letIn m n => exact ⟨Comp.Reads.captures m h.1, Comp.Reads.captures n h.2⟩
    case app f vs => exact ⟨Val.Reads.captures f h.1, Vals.Reads.captures vs h.2⟩
    case meth f m ts es vs => exact ⟨Val.Reads.captures f h.1, Vals.Reads.captures vs h.2⟩
    case ite v m n => exact ⟨Val.Reads.captures v h.1, Comp.Reads.captures m h.2.1, Comp.Reads.captures n h.2.2⟩
    case «match» v arms => exact ⟨Val.Reads.captures v h.1, Arms.Reads.captures arms h.2⟩
    case lazyC m => exact h
    case use v m => exact ⟨Val.Reads.captures v h.1, Comp.Reads.captures m h.2⟩
    case handle m cs => exact ⟨Comp.Reads.captures m h.1, h.2⟩
    case resume k v => exact ⟨Val.Reads.captures k h.1, Val.Reads.captures v h.2⟩
  theorem Arms.Reads.captures {p} (arms : List Arm) (h : Arms.Reads p arms) : Arms.Captures p arms := by
    cases arms with
    | nil => simp only [Arms.Captures]
    | cons a rest =>
        cases a with
        | mk alts g body =>
            simp only [Arms.Reads, Arms.Captures] at h ⊢
            exact ⟨fun m hm => Comp.Reads.captures m (h.1 m hm), Comp.Reads.captures body h.2.1, Arms.Reads.captures rest h.2.2⟩
end

/-- 付け替えをしない場合は、許す外側の番号の集合だけを広げられる。 -/
theorem Comp.Captures.mono {p q m} (h : Comp.Captures p m) (hp : ∀ i, p i → q i) :
    Comp.Captures q m := by
  simpa only [Comp.rename_id] using Comp.Captures.rename (ξ := id) m h hp

/-- d 個の一時変数の下に置いた計算では、元の外側の番号だけをずらす。 -/
theorem Comp.Captures.shift {p m} (h : Comp.Captures p m) (d : Nat) :
    Comp.Captures (liftReads d p) (m.rename (· + d)) :=
  Comp.Captures.rename m h (fun i hi => Or.inr (by simpa using hi))

/-- パターンの局所変数の下へ一時変数を追加しても、外側の捕捉条件を保つ。 -/
theorem Comp.Captures.shiftUnder {p m} (n : Nat) (h : Comp.Captures (liftReads n p) m) :
    Comp.Captures (liftReads n (liftReads 1 p)) (m.rename (upRen n (· + 1))) :=
  Comp.Captures.rename m h (liftReads_rename (fun i hi => Or.inr (by simpa using hi)) n)

end Benitoite.Surface
