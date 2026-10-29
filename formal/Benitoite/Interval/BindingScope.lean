/-!
# 局所環境の束縛番号の土台

区間解析の局所記録（`Interval.RangeState`）と Scope の成功の局所解析（`Scope.Inference`）が共有する
束縛番号の土台である。定義は `Interval.RangeState` にあったものを変えずに移した。区間解析の評価関係に
依存しないので、Scope の局所解析は区間解析の評価関係を import せずにこの土台を使える
（設計書 01-12「区間解析の同じ成功値の直接射影」）。
-/
namespace Benitoite.Interval

/-- Rust の BindingId との対応に使う、現在の局所環境の束縛番号の土台。 -/
structure BindingScope where
  positions : List Nat
  nextId : Nat
  deriving DecidableEq, Repr

/-- de Bruijn の位置に対応する、現在の局所環境の束縛番号を読む。 -/
def BindingScope.idAt (scope : BindingScope) (index : Nat) : Option Nat :=
  scope.positions[index]?

/-- 通常・パターン・専用束縛は位置を作り、ワイルドカードはこの操作を呼ばない。 -/
def BindingScope.fresh (scope : BindingScope) : BindingScope :=
  ⟨scope.nextId :: scope.positions, scope.nextId + 1⟩

/-- 新しい値の番号は旧位置の番号を上書きしない。
Range の成功値も通常束縛と同じ番号の割り当てを使う。 -/
theorem BindingScope.fresh_idAt (scope : BindingScope) :
    scope.fresh.idAt 0 = some scope.nextId ∧
      ∀ index, scope.fresh.idAt (index + 1) = scope.idAt index := by
  exact ⟨rfl, fun _ => rfl⟩

/-- 既存の全番号が nextId 未満なら、新しい番号は既存番号と異なる。 -/
theorem BindingScope.fresh_distinct (scope : BindingScope)
    (valid : ∀ id ∈ scope.positions, id < scope.nextId) :
    scope.nextId ∉ scope.positions := by
  intro member
  have := valid _ member
  omega

/-- 新しい番号を追加した後も、次番号が現在の全番号より大きい条件が保たれる。 -/
theorem BindingScope.fresh_valid (scope : BindingScope)
    (valid : ∀ id ∈ scope.positions, id < scope.nextId) :
    ∀ id ∈ scope.fresh.positions, id < scope.fresh.nextId := by
  intro id member
  simp only [BindingScope.fresh, List.mem_cons] at member
  rcases member with same | old
  · subst id; exact Nat.lt_succ_self _
  · exact Nat.lt_trans (valid _ old) (Nat.lt_succ_self _)

end Benitoite.Interval
