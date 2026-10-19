import Benitoite.Release.Syntax

/-!
# 構築器の構文データ

表層の式・宣言に依存せず、種類と参照先を保持する。
対応する定義は設計書 01-12「構築器の分類と環境の対応」である。
-/
namespace Benitoite.Surface
open Benitoite.Release

/-- 構築器は通常の型とは別に分類する。 -/
inductive BuilderKind where
  | string | list (element : Ty) | bytes

/-- 専用操作の四分類。 -/
inductive BuilderOp where
  | append | appendAll | copy | length
  deriving DecidableEq

/-- 構築器から取り出す通常の不変値の型。 -/
def BuilderKind.contents : BuilderKind → Ty
  | .string => .base .string
  | .list t => .list t
  | .bytes => .bytes

/-- 脱糖後に専用名の位置を埋めるセルの型。 -/
def BuilderKind.cell (k : BuilderKind) : Ty := .reference k.contents

/-- Γ の先頭にそろえた分類表。範囲外には構築器がない。 -/
abbrev BuilderCtx := List (Option BuilderKind)

/-- 範囲外も含め、その番号に構築器があるかを読む。 -/
def BuilderCtx.kindAt (Δ : BuilderCtx) (i : Nat) : Option BuilderKind := (Δ[i]?).join

/-- 行引数は空に固定し、具体化する型引数は構文に保持する。 -/
structure BuilderPrimRef where
  name : PrimName
  types : List Ty

/-- 純粋な標準関数は組み込みと通常関数の両方を参照できる。 -/
inductive BuilderPureRef where
  | prim (ref : BuilderPrimRef)
  | funRef (name : FunName) (types : List Ty)

/-- 行引数を持たないコアの組み込み参照。 -/
def BuilderPrimRef.toVal (r : BuilderPrimRef) : Val := .prim r.name r.types []
/-- 純粋な参照をコアの通常の値へ移す。 -/
def BuilderPureRef.toVal : BuilderPureRef → Val
  | .prim r => r.toVal
  | .funRef f ts => .fnRef f ts []

/-- new の存在も参照先の条件として検査し、組み込みの仮定へ足さない。 -/
structure BuilderCellRefs where
  newRef : BuilderPrimRef
  getRef : BuilderPrimRef
  setRef : BuilderPrimRef

/-- 種類ごとの脱糖で必要な参照先だけを保持する。 -/
inductive BuilderRefs where
  | string (cell : BuilderCellRefs) (add join length : BuilderPureRef)
  | list (element : Ty) (cell : BuilderCellRefs) (append concatenate length : BuilderPureRef)
  | bytes (cell : BuilderCellRefs) (empty fromList concatenate length : BuilderPureRef)

/-- 参照先の組が属する構築器の種類。 -/
def BuilderRefs.kind : BuilderRefs → BuilderKind
  | .string .. => .string
  | .list t .. => .list t
  | .bytes .. => .bytes

/-- 三種類に共通するセルの参照先。 -/
def BuilderRefs.cells : BuilderRefs → BuilderCellRefs
  | .string c .. | .list _ c .. | .bytes c .. => c

/-- 種類に対応する長さの関数。 -/
def BuilderRefs.lengthRef : BuilderRefs → BuilderPureRef
  | .string _ _ _ l | .list _ _ _ _ l | .bytes _ _ _ _ l => l

/-- 長さの参照先のラベルは既存の標準ソースに合わせる。 -/
def BuilderKind.lengthNames : BuilderKind → List String
  | .string => ["s"]
  | .list _ => ["xs"]
  | .bytes => ["b"]

/-- 一回の追記で受け取る通常値。 -/
def BuilderKind.item : BuilderKind → Ty
  | .string => .base .string
  | .list t => t
  | .bytes => .base .byte

/-- 専用操作の通常引数の契約。セルはこの列へ含めない。 -/
def BuilderOp.params (op : BuilderOp) (k : BuilderKind) : List Ty :=
  match op with
  | .copy | .length => []
  | .append => [k.item]
  | .appendAll => [match k with | .string => .list (.base .string) | _ => k.contents]

/-- 専用操作の結果も通常の Release.Ty である。 -/
def BuilderOp.result (op : BuilderOp) (k : BuilderKind) : Ty :=
  match op with
  | .copy => k.contents
  | .length => .base .integer
  | .append | .appendAll => .base .unit

/-- 型引数を持つ参照先を漏れなく辿る共通の述語。 -/
def BuilderRefs.ForRefs (p : Val → Prop) (r : BuilderRefs) : Prop :=
  (p r.cells.newRef.toVal ∧ p r.cells.getRef.toVal ∧ p r.cells.setRef.toVal) ∧
  match r with
  | .string _ a j l => p a.toVal ∧ p j.toVal ∧ p l.toVal
  | .list _ _ a c l => p a.toVal ∧ p c.toVal ∧ p l.toVal
  | .bytes _ e f c l => p e.toVal ∧ p f.toVal ∧ p c.toVal ∧ p l.toVal

end Benitoite.Surface
