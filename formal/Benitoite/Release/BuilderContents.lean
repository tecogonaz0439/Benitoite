import Benitoite.Release.Typing
import Benitoite.Release.LocalRef

/-!
# 専用セルの内容と論理上限

通常の値と区別したまま、種類・長さ・要素の型を検査する。
設計書 01-12「構築器の専用セルの内容と上限」に対応する。
-/
namespace Benitoite.Release

/-- 内容が属する種類。List の要素型もセルに保存する。 -/
def BuilderContents.kind : BuilderContents → BuilderKind
  | .string _ => .string
  | .list a _ => .list a
  | .bytes _ => .bytes

/-- 上限と length の両方に用いる尺度。String は UTF-8 のバイト数である。 -/
def BuilderContents.size : BuilderContents → Nat
  | .string s => s.utf8ByteSize
  | .list _ vs => vs.length
  | .bytes bs => bs.length

/-- 種類に固有の論理上限。 -/
def BuilderKind.limit : BuilderKind → Nat
  | .string | .bytes => maxBuilderBytes
  | .list _ => maxBuilderListLen

/-- new が置く空の内容。 -/
def BuilderKind.empty : BuilderKind → BuilderContents
  | .string => .string ""
  | .list a => .list a []
  | .bytes => .bytes []

/-- copy はセルの場所を返さず、操作時の不変内容を通常値として返す。 -/
def BuilderContents.snapshot : BuilderContents → Val
  | .string s => .const (.string s)
  | .list _ vs => .list vs
  | .bytes bs => .bytesV bs

/-- Byte の抽象表現にも、専用セル内では実際の値域を要求する。 -/
def BuilderContents.ValidBytes : BuilderContents → Prop
  | .bytes bs => ∀ b ∈ bs, b < 256
  | _ => True

/-- 専用セルの内容の型付け。通常の値へ専用場所を注入しない。 -/
def BuilderCellOk (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : BuilderKind) (c : BuilderContents) : Prop :=
  c.kind = k ∧ c.size ≤ k.limit ∧ c.ValidBytes ∧
    match c with
    | .list a vs => Ty.WF 0 a ∧ HasTypeEach P B Ψ [] [] vs a
    | _ => True

theorem BuilderKind.limit_le_max64 (k : BuilderKind) : (k.limit : Int) ≤ max64 := by
  cases k with
  | string | bytes => exact maxBuilderBytes_le_max64
  | list _ => exact maxBuilderListLen_le_max64

/-- 上限から有界 Integer を構成する。長さを切り詰めたり剰余にしたりしない。 -/
def BuilderContents.lengthValue (c : BuilderContents) (h : c.size ≤ c.kind.limit) : Integer64Value :=
  ⟨(c.size : Int), by
    have hu := c.kind.limit_le_max64
    have hn : (c.size : Int) ≤ (c.kind.limit : Int) := Int.ofNat_le.mpr h
    constructor
    · have : (0 : Int) ≤ (c.size : Int) := Int.natCast_nonneg _
      simp only [min64]; omega
    · omega⟩

@[simp] theorem BuilderContents.lengthValue_toInt (c : BuilderContents) (h) :
    (c.lengthValue h).toInt = (c.size : Int) := rfl

theorem BuilderCellOk.empty {P B Ψ k} (hw : match k with | .list a => Ty.WF 0 a | _ => True) :
    BuilderCellOk P B Ψ k k.empty := by
  cases k <;> simp [BuilderCellOk, BuilderKind.empty, BuilderContents.kind,
    BuilderContents.size, BuilderContents.ValidBytes, BuilderKind.limit,
    maxBuilderBytes, maxBuilderListLen] at *
  exact ⟨hw, .nil⟩

theorem BuilderCellOk.length_bound {P B Ψ k c} (h : BuilderCellOk P B Ψ k c) :
    c.size ≤ c.kind.limit := by rw [h.1]; exact h.2.1

/-- copy の結果はセルの種類に対応する通常の型を持つ。 -/
theorem BuilderCellOk.snapshot_typed {P B Ψ k c} (h : BuilderCellOk P B Ψ k c) :
    HasTypeV P B Ψ [] [] c.snapshot k.contents := by
  rcases h with ⟨rfl, _, _, ht⟩
  cases c with
  | string _ => exact .V_Const
  | list a vs => exact .V_List ht.2 ht.1
  | bytes _ => exact .V_Bytes

/-- 論理上限に収まる長さには、既存の Integer の型が付く。 -/
theorem BuilderCellOk.length_typed {P B Ψ k c} (h : BuilderCellOk P B Ψ k c) :
    HasTypeV P B Ψ [] [] (.const (.integer (c.lengthValue h.length_bound))) (.base .integer) :=
  .V_Const

end Benitoite.Release
