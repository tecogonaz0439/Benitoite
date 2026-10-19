import Benitoite.Surface.BuilderSyntax
import Benitoite.Release.Subst

/-!
# 専用操作のコアへの展開

引数の評価後にセルを読み、純粋な合成が成功した後だけ書き換える。
対応する規則は設計書 01-12「構築器の専用操作と脱糖」である。
-/
namespace Benitoite.Surface
open Benitoite.Release

/-- 通常引数は評価済みである。合成中に利用者の式を再評価しない。 -/
def builderCombine (op : BuilderOp) (r : BuilderRefs) (old arg : Val) : Comp :=
  match op, r with
  | .append, .string _ add _ _ => .app add.toVal [old, arg]
  | .appendAll, .string _ add join _ =>
      .letIn (.app join.toVal [arg, .const (.string "")])
        (.app add.toVal [old.rename (· + 1), .var 0])
  | .append, .list _ _ append _ _ => .app append.toVal [old, arg]
  | .appendAll, .list _ _ _ cat _ => .app cat.toVal [old, arg]
  | .append, .bytes _ _ fromList cat _ =>
      .letIn (.app fromList.toVal [.list [arg]])
        (.app cat.toVal [old.rename (· + 1), .var 0])
  | .appendAll, .bytes _ _ _ cat _ => .app cat.toVal [old, arg]
  | _, _ => .ret old

/-- 通常引数の let の下で呼ぶ。i はその let の個数だけ移動済みである。 -/
def builderFinish (op : BuilderOp) (i : Nat) (r : BuilderRefs) (args : List Val) : Comp :=
  match op, args with
  | .copy, [] => .app r.cells.getRef.toVal [.var i]
  | .length, [] => .letIn (.app r.cells.getRef.toVal [.var i])
      (.app r.lengthRef.toVal [.var 0])
  | .append, [arg] | .appendAll, [arg] =>
      .letIn (.app r.cells.getRef.toVal [.var i])
        (.letIn (builderCombine op r (.var 0) (arg.rename (· + 1)))
          (.app r.cells.setRef.toVal [.var (i + 2), .var 0]))
  | _, _ => .ret (.const .unit)

/-- 空の不変値を作り、既存の Reference.new で局所セルを確保する。 -/
def builderInit : BuilderRefs → Comp
  | .string .. => .ret (.const (.string ""))
  | .list .. => .ret (.list [])
  | .bytes _ empty .. => .app empty.toVal []

/-- 内部の一時束縛は初期値だけで、後続の局所番号を増やさない。 -/
def builderNew (r : BuilderRefs) : Comp :=
  .letIn (builderInit r) (.app r.cells.newRef.toVal [.var 0])

end Benitoite.Surface
