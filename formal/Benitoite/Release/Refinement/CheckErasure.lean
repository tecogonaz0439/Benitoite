import Benitoite.Release.Refinement.RefinementCheckResponse
import Benitoite.Release.Refinement.MainStatements

/-! # 閉じた評価で成功した検査の消去 -/
namespace Benitoite.Release.Refinement.CheckErasure
open RefinementCheck
noncomputable section

/-- 実引数は評価済みの値一つであり、評価する計算を複製しない。 -/
def call (t u : Ty) (v : Val) : Comp :=
  .app (.prim PublicNames.checkName [t,u] [] []) [v]

/-- 空の捕捉で値と型が変わらず、正規形の型引数と全篩の閉じた評価の成功を確認した呼出しだけを置き換える。 -/
def erase (m : Comp) : Comp := by
  classical
  exact match m with
  | .app (.prim name [t,u] [] []) [v] =>
    if name = PublicNames.checkName ∧
        (Closure.pure (.app (.prim name [t,u] [] []) [v])).view =
          .app (.prim name [t,u] [] []) [v] ∧ t.norm = t ∧ u.norm = u ∧
        t.core = u.core ∧ accepts v u = true then .ret (ok u v)
    else .app (.prim name [t,u] [] []) [v]
  | m => m

/-- 篩の含意や部分型の証明書は、消去の前提として読まない。 -/
theorem erase_check {t u v} (hv : (Closure.pure (call t u v)).view = call t u v)
    (nt : t.norm = t) (nu : u.norm = u)
    (hc : t.core = u.core) (ha : accepts v u = true) :
    erase (call t u v) = .ret (ok u v) := by
  simp only [call] at hv
  simp [erase,call,nt,nu,hc,ha,hv]

/-- 偽と評価不能を含む不成功の入力は、元の呼出しを保つ。 -/
theorem erase_rejected {t u v} (ha : accepts v u = false) :
    erase (call t u v) = call t u v := by simp [erase,call,ha]

/-- 一つでも偽又は評価不能の外側の篩があれば、呼出しは残る。 -/
theorem erase_refined_rejected {t a p v sort term}
    (hs : a.sort? = some sort) (ht : v.toTerm? = some term)
    (he : (p.open term).evalClosed = some false ∨ (p.open term).evalClosed = none) :
    erase (call t (.refined a p) v) = call t (.refined a p) v := by
  apply erase_rejected
  rw [accepts_refined hs ht]
  rcases he with he | he <;> simp [Pred.closedTrue,he]

/-- 同じ値・継続・ストアのまま、事象のない一段だけを省く。 -/
theorem erased_step {P B σ q k μ t u v render}
    (hq : q.view = call t u v)
    (hs : B.sig PublicNames.checkName = some signature)
    (hd : B.delta PublicNames.checkName [t,u] [] [] [v] =
      delta render PublicNames.checkName [t,u] [] [] [v])
    (hv : (Closure.pure (call t u v)).view = call t u v)
    (nt : t.norm = t) (nu : u.norm = u)
    (hc : t.core = u.core) (ha : accepts v u = true) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (erase (call t u v))) k μ) := by
  rw [erase_check hv nt nu hc ha]
  apply Step.E_Prim (rs := []) hq hs rfl
  simpa [Ty.normTys,nt,nu,delta,run_ok hc ha] using hd

/-- 入力契約から元の呼出しを、篩付きの Result と空の効果で型付ける。 -/
theorem call_typed {P B Ψ t u v R Δ}
    (hs : B.sig PublicNames.checkName = some signature)
    (args : BuiltinArgs P B Ψ PublicNames.checkName signature [t,u] [] [] [v]
      (result u) Eff.empty) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (call t u v) (result u) Eff.empty Δ := by
  exact .C_DependentApp
    (.V_Prim hs args.ranges (by simp [signature,NamesWF]) args.admissible args.signature)
    args.arguments

/-- 成功・拒否のどちらも、消去の前後で篩付きの結果型と効果が同じである。 -/
theorem erase_typed {P B Ψ t u v R Δ} (hp : Declarations P) (render : Ty → String)
    (hs : B.sig PublicNames.checkName = some signature)
    (args : BuiltinArgs P B Ψ PublicNames.checkName signature [t,u] [] [] [v]
      (result u) Eff.empty) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (call t u v) (result u) Eff.empty Δ ∧
    HasTypeCQ P B Ψ Qempty [] [] [] R (erase (call t u v)) (result u) Eff.empty Δ := by
  have before := call_typed (R := R) (Δ := Δ) hs args
  refine ⟨before,?_⟩
  by_cases h : (Closure.pure (call t u v)).view = call t u v ∧ t.norm = t ∧ u.norm = u ∧ t.core = u.core ∧ accepts v u = true
  · rw [erase_check h.1 h.2.1 h.2.2.1 h.2.2.2.1 h.2.2.2.2]
    obtain ⟨out,hd,typed,_,_⟩ := response hp render args
    have ho : out = .val (ok u v) := by
      simpa [delta,run_ok h.2.2.2.1 h.2.2.2.2] using hd.symm
    subst out
    exact .C_Return typed.1
  · simp only [call] at h
    simpa [erase,call,h] using before

/-- 成功した純粋な行の次状態は一意であり、他の効果・失敗の遷移はない。 -/
theorem step_unique {P B σ q k μ t u v render label dest}
    (hq : q.view = call t u v)
    (hs : B.sig PublicNames.checkName = some signature)
    (hd : B.delta PublicNames.checkName [t,u] [] [] [v] =
      delta render PublicNames.checkName [t,u] [] [] [v])
    (hv : (Closure.pure (call t u v)).view = call t u v)
    (nt : t.norm = t) (nu : u.norm = u)
    (hc : t.core = u.core) (ha : accepts v u = true)
    (h : Step P B σ (.run q k μ) label dest) :
    label = none ∧ dest = .run (Closure.pure (erase (call t u v))) k μ := by
  have hd' : B.delta PublicNames.checkName [t,u] [] [] [v] = some (.val (ok u v)) := by
    simpa [delta,run_ok hc ha] using hd
  rw [erase_check hv nt nu hc ha]
  cases h <;> simp_all [call,signature,closeVal]
  all_goals subst_vars
  all_goals simp_all [Closure.view]

/-- 事象のない段も含めた有限の実行列。リストの順と長さが評価の順と回数を記録する。 -/
def Execution (P : Program) (B : Builtins) (σ : PathEnv) :
    State → List (Option Event) → State → Prop
  | s, [], z => s = z
  | s, label :: labels, z => ∃ dest, Step P B σ s label dest ∧ Execution P B σ dest labels z

/-- 有限の実行列は、事象だけを残した既存の Steps を与える。 -/
theorem Execution.steps {P B σ s labels z} (h : Execution P B σ s labels z) :
    Steps P B σ s (labels.filterMap id) z := by
  induction labels generalizing s with
  | nil => cases h; exact .nil
  | cons label labels ih =>
    obtain ⟨dest,step,rest⟩ := h
    cases label <;> simpa using Steps.cons step (ih rest)

/-- 無限の実行も、各段のラベルと状態を明示した同じ遷移関係で記録する。 -/
def InfiniteExecution (P : Program) (B : Builtins) (σ : PathEnv)
    (s : State) (labels : Nat → Option Event) : Prop :=
  ∃ states : Nat → State, states 0 = s ∧ ∀ n, Step P B σ (states n) (labels n) (states (n+1))

/-- 任意の継続の実行を、事象なしの一段を除いてそのまま保存する。
有限列の残りの順と長さ、無限列、事象列、終端の値・失敗の payload・ストアが一致する。 -/
theorem observations_preserved {P B σ q k μ t u v render}
    (hq : q.view = call t u v)
    (hs : B.sig PublicNames.checkName = some signature)
    (hd : B.delta PublicNames.checkName [t,u] [] [] [v] =
      delta render PublicNames.checkName [t,u] [] [] [v])
    (hv : (Closure.pure (call t u v)).view = call t u v)
    (nt : t.norm = t) (nu : u.norm = u)
    (hc : t.core = u.core) (ha : accepts v u = true) :
    let source := State.run q k μ
    let target := State.run (Closure.pure (erase (call t u v))) k μ
    (∀ labels z, Execution P B σ source (none :: labels) z ↔ Execution P B σ target labels z) ∧
    (∀ events z, z.Final → (Steps P B σ source events z ↔ Steps P B σ target events z)) ∧
    (∀ labels, InfiniteExecution P B σ source (fun n => match n with
        | 0 => none | n+1 => labels n) ↔ InfiniteExecution P B σ target labels) := by
  dsimp only
  have first := erased_step (P := P) (σ := σ) (k := k) (μ := μ) hq hs hd hv nt nu hc ha
  have unique := fun {label dest} => step_unique (P := P) (σ := σ) (k := k) (μ := μ)
    (label := label) (dest := dest) hq hs hd hv nt nu hc ha
  refine ⟨?_,?_,?_⟩
  · intro labels z
    constructor
    · rintro ⟨dest,step,rest⟩
      cases (unique step).2
      exact rest
    · intro rest; exact ⟨_,first,rest⟩
  · intro events z final
    constructor
    · intro run
      cases run with
      | nil =>
        cases k <;> simp_all [State.Final,call]
      | cons step rest =>
        obtain ⟨rfl,rfl⟩ := unique step
        exact rest
    · intro rest
      exact Steps.cons first rest
  · intro labels
    constructor
    · rintro ⟨states,start,steps⟩
      have zero := steps 0
      rw [start] at zero
      have eq := (unique zero).2
      exact ⟨fun n => states (n+1),eq,fun n => steps (n+1)⟩
    · rintro ⟨states,start,steps⟩
      refine ⟨fun n => match n with | 0 => .run q k μ | n+1 => states n,rfl,?_⟩
      intro n
      cases n with
      | zero => simpa only [start] using first
      | succ n => exact steps n

end
end Benitoite.Release.Refinement.CheckErasure
