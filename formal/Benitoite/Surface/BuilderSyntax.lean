import Benitoite.Release.Syntax

/-!
# 構築器の構文データ

表層の式・宣言に依存せず、構築器の種類の表を保持する。
対応する定義は設計書 01-12「構築器の分類と環境の対応」である。
-/
namespace Benitoite.Surface
open Benitoite.Release


/-- Γ の先頭にそろえた分類表。範囲外には構築器がない。 -/
abbrev BuilderCtx := List (Option BuilderKind)

/-- 範囲外も含め、その番号に構築器があるかを読む。 -/
def BuilderCtx.kindAt (Δ : BuilderCtx) (i : Nat) : Option BuilderKind := (Δ[i]?).join

end Benitoite.Surface
