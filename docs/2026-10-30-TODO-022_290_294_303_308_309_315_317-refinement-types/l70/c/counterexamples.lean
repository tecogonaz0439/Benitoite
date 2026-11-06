import Benitoite.Release.Refinement.StandardModelCompletion

/-! L70 群 C の停止の根拠（results.md の「停止した理由」）。`formal/` から `lake env lean -M 12288 <このファイル>` で検査する。
既定ビルドには含めない。 -/

namespace Benitoite.Release.Refinement
noncomputable section

/-! 反例2: 組込みの操作の節の文脈に、P で宣言のない data 型が入る場合 -/

def cxBase : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

/-- 新しい data 型 `Z` と構成子 `Z.A` を足す。 -/
def cxAddZ : Program := { cxBase with cons := fun c => if c = "Z.A" then some ⟨"Z", 0, []⟩ else none }

theorem cx_extends_Z : Program.Extends cxBase cxAddZ where
  defs _ _ h := h
  cons _ _ h := by simp [cxBase] at h
  ops _ _ h := h
  effects _ _ h := h
  classes _ _ h := h
  impls _ _ h := h
  dataInfo _ _ h := h
  externals := rfl
  consClosed c cd h hd := by
    rcases hd with ⟨c', cd', hc', _⟩ | hi
    · simp [cxBase] at hc'
    · simp [cxBase] at hi
  dataInfoOld _ _ := rfl

/-- P では `Z` に住む値がないので、腕のない照合が網羅する。 -/
theorem cx_base_exhaustive : Exhaustive cxBase (.data "Z" []) [] := by
  intro v hv
  exfalso
  generalize ht : (Ty.data "Z" []).norm = t at hv
  cases hv with
  | con hc => simp [cxBase] at hc
  | @const c => cases c <;> simp_all [Ty.norm, Ty.normTys, Const.type]
  | atError => simp_all [Ty.norm, Ty.normTys, atErrorType]
  | _ => simp_all [Ty.norm, Ty.normTys]

/-- P' では `Z.A` が住むので、腕のない照合は網羅しない。 -/
theorem cx_added_not_exhaustive : ¬ Exhaustive cxAddZ (.data "Z" []) [] := by
  intro h
  have hz : Inhabits cxAddZ (Ty.data "Z" []).norm (.con "Z.A" [] []) := by
    have : (Ty.data "Z" []).norm = .data (⟨"Z", 0, []⟩ : ConDecl).data [] := by
      simp [Ty.norm, Ty.normTys]
    rw [this]
    exact .con (by simp [cxAddZ]) rfl (by simp) .nil
  obtain ⟨p, hp, _⟩ := h _ hz
  simp at hp

/-! 反例1: 組込みの効果のラベルへ利用者の操作を足す場合の `handled` -/

def cxB : Builtins := { StandardModel.baseBuiltins with
  effects := fun l => if l = "L" then some ["op"] else none }

def cxAddOp : Program := { cxBase with
  ops := fun o => if o = "userOp" then some ⟨"L", [], [], [], .base .unit, []⟩ else none
  effects := fun l => if l = "L" then some ["userOp"] else none }

theorem cx_extends_op : Program.Extends cxBase cxAddOp where
  defs _ _ h := h
  cons _ _ h := h
  ops _ _ h := by simp [cxBase] at h
  effects _ _ h := by simp [cxBase] at h
  classes _ _ h := h
  impls _ _ h := h
  dataInfo _ _ h := h
  externals := rfl
  consClosed _ _ h _ := h
  dataInfoOld _ _ := rfl

def cxClauses : List Clause := [.mk (.prim "op") 1 0 (.ret (.const .unit))]

theorem cx_handled_base : (handled cxBase cxB cxClauses).mem (.name "L" (.fixed .top)) := by
  rfl

theorem cx_handled_added : ¬ (handled cxAddOp cxB cxClauses).mem (.name "L" (.fixed .top)) := by
  intro h
  exact absurd h (by decide)

end
end Benitoite.Release.Refinement
