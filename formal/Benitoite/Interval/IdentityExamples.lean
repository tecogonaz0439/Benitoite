import Benitoite.Interval.BudgetTraversal

/-!
# 本体と元の出現の識別の独立例

根・捕捉境界・親の番号・元 AST への多対一の対応と、予算停止の接続を確認する。
（設計書 01-12「区間解析の本体の識別と元の出現の対応」）。
-/
namespace Benitoite.Interval
open Benitoite.Surface Benitoite.Release

private def integer : Ty := .base .integer
private def definition := "Example.identities"
private def root := bodyRootKey definition

-- 直接の負号付きリテラルは一式、通常の負号と return は子を持つ。
-- 引数の契約位置 [1,0] でソース順のキーを並べ替えると、この期待は壊れる。
private def operations : Block :=
  .discard (.negInt ⟨7, by decide⟩)
    (.discard (.neg integer (.local 0))
      (.last (.returnE integer (.call (.funName "Example.call" [] [])
        [some "second", some "first"] [1, 0] (.cons (.local 1) (.cons (.local 2) .nil))))))

example :
    (numbered root (bodyRoot operations)).map (fun (key, source) =>
      (key.surfacePreorder, match source with
        | .block _ => "block" | .negInt _ => "negativeLiteral"
        | .neg _ _ => "negation" | .returnE _ _ => "return"
        | .call _ _ _ _ => "call" | .funName _ _ _ => "callee"
        | .local _ => "local" | _ => "other")) =
      [(0, "block"), (1, "negativeLiteral"), (2, "negation"), (3, "local"),
       (4, "return"), (5, "call"), (6, "callee"), (7, "local"), (8, "local")] := by rfl

-- 空本体も根を持ち、同じ番号0でもモジュールが異なればキーは異なる。
example :
    (numbered (bodyRootKey "A.same") (bodyRoot .empty)).map Prod.fst = [⟨"A.same", 0⟩] ∧
    bodyRootKey "A.same" ≠ bodyRootKey "B.same" ∧ QualifiedDefinition definition ∧
    ¬ QualifiedDefinition "Example.identities%body:1:0" := by
  unfold QualifiedDefinition
  decide

-- 境界内の境界、空の節、同じ handler の二つの節を含む。
-- 合成した根を親へ挿入すると、後続の境界と内容の番号がずれる。
private def boundaries : Block :=
  .discard (.lam [] [] integer Eff.empty
    (.last (.lazyE (.last (.constE integer (.local 0))))))
    (.discard (.handleE (.last .unit)
      (.cons (.user "Example.first") 0 0 .empty
        (.cons (.user "Example.second") 0 0 (.last (.local 1)) .nil)))
      (.last (.handleFail integer (.base .unit) (.last .unit) (.last (.local 2)))))

private def manifest := bodyManifest definition boundaries

example : manifest.map (fun entry =>
    (entry.definition, entry.kind, entry.parentStart, surfaceSize (bodyRoot entry.body))) =
    [("Example.identities%body:1:0", .lambda, 2, 4),
     ("Example.identities%body:2:0", .lazy, 3, 3),
     ("Example.identities%body:5:0", .handler, 7, 1),
     ("Example.identities%body:5:1", .handler, 7, 2),
     ("Example.identities%body:8:0", .failure, 10, 2)] := by rfl

example : manifest.map (fun entry =>
    (entry.root.surfacePreorder, entry.parentKey 0, entry.parentKey 1, entry.parentKey 2)) =
    [(0, none, some ⟨definition, 2⟩, some ⟨definition, 3⟩),
     (0, none, some ⟨definition, 3⟩, some ⟨definition, 4⟩),
     (0, none, none, none),
     (0, none, some ⟨definition, 7⟩, none), (0, none, some ⟨definition, 10⟩, none)] := by rfl

-- Nat の組は試験用の (NodeId, UTF-8開始, UTF-8終了) であり、交換入力には加えない。
-- 合成した call/callee は同じ元演算に対応する。合成した根は対応未定義とする。
private def sourceOrigin (key : OperationKey) : Option (Nat × Nat × Nat) :=
  if key.definition = definition then
    match key.surfacePreorder with
    | 1 => some (10, 20, 22)
    | 2 => some (11, 24, 26)
    | 4 => some (13, 28, 40)
    | 5 | 6 => some (14, 35, 40)
    | _ => none
  else none

private def selectedKeys : List OperationKey :=
  [⟨definition, 1⟩, ⟨definition, 2⟩, ⟨definition, 4⟩, ⟨definition, 5⟩, ⟨definition, 6⟩]

-- 対応する元演算を独立に指定し、単なる some の有無だけで受け入れない。
example : SourceCorrespondence (fun key => key ∈ selectedKeys) sourceOrigin
    (fun key location =>
      (key = ⟨definition, 1⟩ ∧ location = (10, 20, 22)) ∨
      (key = ⟨definition, 2⟩ ∧ location = (11, 24, 26)) ∨
      (key = ⟨definition, 4⟩ ∧ location = (13, 28, 40)) ∨
      (key ∈ [⟨definition, 5⟩, ⟨definition, 6⟩] ∧ location = (14, 35, 40))) := by
  intro key selected
  simp only [selectedKeys, List.mem_cons, List.not_mem_nil, or_false] at selected
  rcases selected with rfl | rfl | rfl | rfl | rfl
  all_goals refine ⟨_, rfl, ?_⟩; decide

example : ¬ SourceCorrespondence (fun key => key = root) sourceOrigin
    (fun _ _ => True) := sourceCorrespondence_missing (by decide) rfl

example : sourceOrigin ⟨definition, 5⟩ = sourceOrigin ⟨definition, 6⟩ := rfl

open BudgetAnalysis Budget
private def emptyEnv := AbstractEnv.ofLocals []
private def budgetSource := bodyRoot (.last (.lazyE (.last (.local 0))))
private def identities (ctx : Context) := ctx.identitiesRev.reverse.map Prod.fst
private def numberedOnly (limits : Limits) :=
  skipExpr 30 budgetSource limits { next := root }
private def stopReason : Except Halt Unit → Option Halt
  | .ok _ => none
  | .error reason => some reason

-- 未対応の lazy の子も番号付けする。上限ちょうどでは完走し、一回不足なら
-- 接頭辞だけを残す。拒否した番号を飛ばして後続へ進まない。
example :
    let exact := numberedOnly ⟨⟨5, 100⟩, ⟨100, 100⟩⟩
    let stopped := numberedOnly ⟨⟨4, 100⟩, ⟨100, 100⟩⟩
    stopReason exact.1 = none ∧ identities exact.2 = [⟨definition, 0⟩, ⟨definition, 1⟩, ⟨definition, 2⟩] ∧
    exact.2.next = ⟨definition, 3⟩ ∧ exact.2.budget.body.operations = 5 ∧
    stopReason stopped.1 = some (.budget (.unidentified ⟨.body, .operations⟩)) ∧
    identities stopped.2 = [⟨definition, 0⟩, ⟨definition, 1⟩] ∧
    stopped.2.next = ⟨definition, 2⟩ ∧ stopped.2.budget.body.operations = 4 := by
  decide +kernel

-- 解析と番号だけの走査が同じキーを得ること、全体超過と保持超過も確認する。
#guard
    let analyzed := analyzeExpr {} {} 30 emptyEnv root budgetSource
    let numbered := numberedOnly {}
    let whole := numberedOnly ⟨⟨100, 100⟩, ⟨4, 100⟩⟩
    let items := numberedOnly ⟨⟨100, 0⟩, ⟨100, 100⟩⟩
    identities analyzed.context = [⟨definition, 0⟩, ⟨definition, 1⟩, ⟨definition, 2⟩] ∧
    identities numbered.2 = identities analyzed.context ∧
    stopReason whole.1 = some (.budget (.unidentified ⟨.whole, .operations⟩)) ∧
    identities whole.2 = [⟨definition, 0⟩, ⟨definition, 1⟩] ∧
    stopReason items.1 = some (.budget (.unidentified ⟨.body, .items⟩)) ∧
    identities items.2 = [] ∧ items.2.next = root

-- 同じ構文でも区間環境によって到達する枝と結果が異なる。
-- 未到達の枝も走査するため、警告の有無から番号を詰める退行を検出できる。
private def branchSource : Expr := bodyRoot (.last (.ite
  (.binary .lt integer (.local 0) (.literal (.integer ⟨0, by decide⟩)))
  (.last (.binary .intDiv integer (.literal (.integer ⟨1, by decide⟩))
    (.literal (.integer ⟨0, by decide⟩))))
  (.last (.literal (.integer ⟨2, by decide⟩)))))

#guard
    let negative := analyzeExpr {} {} 64
      (AbstractEnv.ofLocals [.integer (normalize (-1) (-1))]) root branchSource
    let positive := analyzeExpr {} {} 64
      (AbstractEnv.ofLocals [.integer (normalize 1 1)]) root branchSource
    let skipped := skipExpr 64 branchSource {} { next := root }
    identities negative.context =
      [⟨definition, 0⟩, ⟨definition, 1⟩, ⟨definition, 2⟩, ⟨definition, 3⟩,
       ⟨definition, 4⟩, ⟨definition, 5⟩, ⟨definition, 6⟩, ⟨definition, 7⟩,
       ⟨definition, 8⟩] ∧
    identities positive.context = identities negative.context ∧
    identities skipped.2 = identities negative.context ∧
    negative.approx.integer = top ∧ positive.approx.integer = normalize 2 2 ∧
    negative.approx.warnings.map (fun w => (w.key, w.cause)) =
      [(⟨definition, 5⟩, .zeroDivisor)] ∧ positive.approx.warnings = []

end Benitoite.Interval
