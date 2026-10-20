import Benitoite.Surface.CheckProgramSound
import Benitoite.Surface.Lemmas.BuilderNoCapture
import Benitoite.Release.Examples

/-! 専用操作の検査の正負。内部の非空分類表から検査し、公開の空表での拒否と区別する。
対応する契約は設計書 01-12「構築器の専用操作と脱糖」である。 -/
namespace Benitoite.Surface.BuilderExamples
open Benitoite.Release Check CheckTools

private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string
private def signature (kind : PrimKind) (ns : List String) (ps : List Ty) (ret : Ty)
    (eff : Eff := Eff.empty) (ts : List TParam := []) : PrimSig :=
  ⟨ts, 0, ns, ps, ret, eff, fun _ _ => True, kind, none⟩
private def entries : List (String × PrimSig) :=
  [("new", signature .refNew ["value"] [.tvar 0] (.reference (.tvar 0)) (Eff.single stateEff) [{}]),
   ("get", signature .refGet ["reference"] [.reference (.tvar 0)] (.tvar 0) (Eff.single stateEff) [{}]),
   ("set", signature .refSet ["reference", "value"] [.reference (.tvar 0), .tvar 0] (.base .unit) (Eff.single stateEff) [{}]),
   ("add", signature .pure ["left", "right"] [strTy, strTy] strTy),
   ("join", signature .pure ["xs", "separator"] [.list strTy, strTy] strTy),
   ("append", signature .pure ["xs", "x"] [.list intTy, intTy] (.list intTy)),
   ("listCat", signature .pure ["xs", "ys"] [.list intTy, .list intTy] (.list intTy)),
   ("listLen", signature .pure ["xs"] [.list intTy] intTy),
   ("empty", signature .pure [] [] .bytes),
   ("fromList", signature .pure ["bs"] [.list (.base .byte)] .bytes),
   ("bytesCat", signature .pure ["a", "b"] [.bytes, .bytes] .bytes),
   ("bytesLen", signature .pure ["b"] [.bytes] intTy)]
private def decls : Declarations :=
  { funs := fun f => if f == "strLen" then
      some ⟨[], 0, ["s"], [strTy], intTy, Eff.empty, []⟩ else none,
    cons := fun _ => none }
private def input : Input :=
  { D := decls,
    B := { Release.Examples.builtins with sig := fun n => (entries.find? (·.1 == n)).map (·.2) },
    satDec := fun _ _ _ => true, admitsDec := fun _ _ _ => true,
    opPrim := fun _ _ => none, ctors := fun _ => [], atoms := [] }
private def kinds : List BuilderKind := [.string, .list intTy, .bytes]
private def ops : List BuilderOp := [.copy, .length, .append, .appendAll]
private def args : BuilderOp → Exprs
  | .copy | .length => .nil
  | _ => .cons (.local 0) .nil
private def run (r : BuilderKind) (o : BuilderOp) (mode : ResumeMode) : Result Inferred :=
  (checkExprR input mode [none, some r] []
    [some ((o.params r).headD (.base .unit)), none] none .other []
    (.builderOp o 1 (args o) r)).run' {}
private def got (r : BuilderKind) (o : BuilderOp) (mode : ResumeMode) : Bool :=
  match run r o mode with
  | .error _ => false
  | .ok (t, e) => tyEq input.atoms t (o.result r) && effEq input.atoms e Eff.empty

-- State を支持に含めず、三種類・全操作を strict/relaxed の両方で検査する。
example : kinds.all (fun r => ops.all (fun o => [ResumeMode.strict, .relaxed].all (got r o))) = true := by decide

-- 構築器の位置を通常の local として読めない。
example : (checkExprR input .strict [none, some .string] [] [some strTy, none] none .other []
    (.local 1)).run' {} = .error ⟨[], "local is missing or hidden"⟩ := by rfl

-- 種類と List の要素型の取り違えを、局所分類と照合して拒否する。
example : (checkExprR input .strict [some .bytes] [] [none] none .other []
    (.builderOp .copy 0 .nil .string)).run' {} =
    .error ⟨[], "invalid local builder kind"⟩ := by rfl
example : (checkExprR input .strict [some (.list intTy)] [] [none] none .other []
    (.builderOp .copy 0 .nil (.list strTy))).run' {} =
    .error ⟨[], "invalid local builder kind"⟩ := by rfl

-- 操作の通常引数にも型の包含を要求し、子の元の経路を報告する。
example : (checkExprR input .strict [some .string] [] [none] none .other []
    (.builderOp .append 0 (.cons (.literal (.integer ⟨1, by decide⟩)) .nil) .string)).run' {} =
    .error ⟨[0, 0], "type is not included in the expected type"⟩ := by rfl

-- 公開入口では Γ に十分な場所があっても Δ は空である。
example : (checkExpr input .strict [] [none] none .other []
    (.builderOp .copy 0 .nil .string)) =
    .error ⟨[], "invalid local builder kind"⟩ := by rfl

-- 引数自身の追記を一度終えてから外側の専用操作を行う。読む順序の退行は最終の内容で検出する。
private def append (arg : Expr) : Expr := .builderOp .append 0 (.cons arg .nil) .string
private def nestedAppend : Expr := append
  (.ite (.literal (.boolean true))
    (.seq (append (.literal (.string "x"))) (.last (.literal (.string "suffix"))))
    (.last (.literal (.string "unused"))))
private def runtimeBuiltins (fail : Bool) : Builtins :=
  { input.B with delta := fun n _ _ vs => match n, vs with
      | "add", [.const (.string a), .const (.string b)] =>
          if fail then some (.err "TooLarge") else some (.val (.const (.string (a ++ b))))
      | _, _ => none }
private noncomputable def storedAfter (e : Expr) (fail : Bool) : Option (Bool × String) :=
  let body := (desugarExpr (fun _ _ => none) .other e).subst builderValueSubst (builderLocalSubst 0)
  let state := (Release.run Release.Examples.program (runtimeBuiltins fail)
    Release.Examples.oracle Release.Examples.rel Release.Examples.fresh 80
    (.run body [] (Store.empty.set 0 (.builder (.string "old")))) []).1
  let read := fun (failed : Bool) (store : Store) => match store 0 with
    | some (.builder (.string text)) => some (failed, text)
    | _ => none
  match state with
  | .run (.ret (.const .unit)) [] store => read false store
  | .error ["TooLarge"] [] store => read true store
  | _ => none
example : storedAfter nestedAppend false = some (false, "oldxsuffix") := by decide
-- 通常引数の計算が失敗したときは、専用セルを更新しない。
-- 旧合成の組み込みは専用操作では呼ばないため、失敗する呼び出しを通常引数に置く。
example : storedAfter (append (.call (.primName "add" [] []) [none, none] [0, 1]
    (.cons (.literal (.string "")) (.cons (.literal (.string "x")) .nil)))) true = some (true, "old") := by decide

-- 宣言だけで終わる場合も、三種類とも Unit と空の効果を返す。
private def checkedBlock (b : Block) : Result Inferred :=
  checkBlock input .strict [] [] none .other [] b
example : kinds.all (fun r => match checkedBlock (.builderBind r .empty) with
    | .ok (t, e) => tyEq input.atoms t (.base .unit) && effEq input.atoms e Eff.empty
    | _ => false) = true := by decide

-- 通常の Reference.get を引数で呼べば、構築器が純粋でも State は残る。
private def stateInput : Input := { input with atoms := [.name stateEff] }
private def referenceArg : Expr := .call (.primName "get" [strTy] []) [none] [0]
  (.cons (.local 1) .nil)
example : (match checkBlock stateInput .strict [] [some (.reference strTy)] none .other []
    (.builderBind .string (.last (.builderOp .append 0 (.cons referenceArg .nil) .string))) with
    | .ok (t, ε) => tyEq stateInput.atoms t (.base .unit) && effEq stateInput.atoms ε (Eff.single stateEff)
    | .error _ => false) = true := by decide

private def copyAt (i : Nat) : Expr := .builderOp .copy i .nil .string
private def appendAt (i : Nat) (s : String) : Expr :=
  .builderOp .append i (.cons (.literal (.string s)) .nil) .string
private def declared (body : Block) : Block := .builderBind .string body
/-- 空の効果を宣言した通常関数を、構築器の本体も含めて全プログラム検査へ渡す。 -/
private def pureMaterials : CheckTables.Materials :=
  { defs := [("main",
      { tparams := [], neffs := 0, names := [], params := [],
        ret := strTy, eff := Eff.empty,
        body := declared (.seq (appendAt 0 "pure") (.last (.returnE strTy (copyAt 0)))) })],
    conFields := [], accessors := [], data := [], ops := [], effects := [],
    classes := [], impls := [], trustedFuns := [], trustedImpls := [] }

theorem pure_program_checked : CheckTables.checkProgram
    (pureMaterials.input input.B input.satDec input.admitsDec input.opPrim [])
    pureMaterials pureMaterials.names = .ok () := by rfl

/-- 通常引数と discard が増やす共有番号を、独立した期待コアで照合する。 -/
theorem dedicated_lowering :
    desugarBlock (fun _ _ => none) .other
      (declared (.seq (appendAt 0 "x") (.last (copyAt 0)))) =
    .builderLet .string
      (.letIn (.letIn (.ret (.const (.string "x")))
        (.builderOp .string .append (.bound 1) [.var 0]))
        (.builderOp .string .copy (.bound 1) [])) := by rfl

private def hiddenBuilder (r : Result α) : Bool := match r with
  | .error e => e.reason == "invalid local builder kind"
  | _ => false

-- 捕捉の各境界に外側のセルを渡した場合は拒否する。同じ失敗を理由も含めて検査する。
private def captureBoundaries : List Expr :=
  [.lam [] [] strTy (Eff.single stateEff) (.last (.returnE strTy (copyAt 0))),
   .lazyE (.last (copyAt 0)),
   .partialCall (.primName "add" [] []) ["left", "right"]
     (.expr (some "left") 0 (copyAt 0) (.hole (some "right") 1 strTy .nil)) strTy (Eff.single stateEff),
   .partialCall (.ite (.literal (.boolean true))
      (.seq (appendAt 0 "x") (.last (.primName "add" [] []))) (.last (.primName "add" [] [])))
     ["left", "right"] (.hole (some "left") 0 strTy (.hole (some "right") 1 strTy .nil))
     strTy (Eff.single stateEff)]
example : captureBoundaries.all (fun e => hiddenBuilder (checkedBlock (declared (.last e)))) = true := by decide
example : checkedBlock (declared (.last (.lam [] [] strTy (Eff.single stateEff) (.last (.returnE strTy (copyAt 0)))))) =
    .error ⟨[0, 0, 0, 0, 0], "invalid local builder kind"⟩ := by rfl

-- 専用名そのものの return と、タスクへ渡す関数の本体からの操作は拒否する。
example : checkBlock input .strict [] [] (some strTy) .tail []
    (declared (.last (.returnE strTy (.local 0)))) =
    .error ⟨[0, 0, 0], "local is missing or hidden"⟩ := by rfl
private def taskDecl : FunDecl := ⟨[], 0, ["f"], [.fn [] [] strTy (Eff.single stateEff)], .base .unit, Eff.empty, []⟩
private def taskInput : Input := { input with D := { decls with
    funs := fun f => if f == "task" then (some taskDecl) else decls.funs f } }
example : hiddenBuilder (checkBlock taskInput .strict [] [] none .other []
    (declared (.last (.call (.funName "task" [] []) [some "f"] [0]
      (.cons (.lam [] [] strTy (Eff.single stateEff) (.last (.returnE strTy (copyAt 0)))) .nil))))) = true := by decide

-- copy を先に通常値へ束縛すれば、その値をラムダと部分適用に捕捉できる。
private def snapshotLambda : Block := declared
  (.bind .bind strTy (copyAt 0) (.last (.lam [] [] strTy Eff.empty (.last (.returnE strTy (.local 0))))))
private def snapshotPartial : Block := declared
  (.bind .bind strTy (copyAt 0) (.last (.partialCall (.primName "add" [] []) ["left", "right"]
    (.expr (some "left") 0 (.local 0) (.hole (some "right") 1 strTy .nil)) strTy Eff.empty)))
example : [snapshotLambda, snapshotPartial].all (fun b => (checkedBlock b).isOk) = true := by decide

-- 宣言の内容の型は本体へ入る前に範囲を検査する。
example : checkedBlock (.builderBind (.list (.tvar 0)) .empty) =
    .error ⟨[], "invalid builder content type"⟩ := by rfl

private noncomputable def returnedText (body : Block) : Option String :=
  match (Release.run Release.Examples.program (runtimeBuiltins false)
      Release.Examples.oracle Release.Examples.rel Release.Examples.fresh 180
      (.run (desugarBlock (fun _ _ => none) .other body) [] Store.empty) []).1 with
  | .run (.ret (.const (.string s))) [] _ => some s
  | _ => none
private def snapshotStable : Block := declared
  (.bind .bind strTy (copyAt 0) (.seq (appendAt 1 "later") (.last (.local 0))))
private def branchAppend : Block := declared
  (.seq (.ite (.literal (.boolean true)) (.last (appendAt 0 "yes")) (.last (appendAt 0 "no")))
    (.last (copyAt 0)))
example : returnedText snapshotStable = some "" := by decide
example : returnedText branchAppend = some "yes" := by decide
example : [snapshotStable, branchAppend].all (fun b => (checkedBlock b).isOk) = true := by decide

-- handle の本体は同じセルを使う。節で新しく作ったセルを越えて resume しても、
-- 保存した継続は本体のセルを保持する。
private def handleInput : Input := { input with
  D := { decls with
    ops := Release.Examples.program.ops,
    effects := Release.Examples.program.effects },
  atoms := [.name stateEff, .name "Ask"] }
private def suspendedBody : Block := declared
  (.seq (appendAt 0 "before")
    (.discard (.call (.opName "ask" []) [] [] .nil)
      (.seq (appendAt 0 "after") (.last (copyAt 0)))))
private def resumed : Block := .last (.handleE suspendedBody
  (.cons (.user "ask") 0 0
    (declared (.seq (appendAt 0 "inside") (.last (.resume 1 (.literal (.integer ⟨7, by decide⟩)))))) .nil))
example : (checkBlock handleInput .strict [] [] none .other [] resumed).isOk = true := by decide
example : returnedText resumed = some "beforeafter" := by decide

-- 外側のセルを節で使うことは、resume の可否とは別に拒否する。
private def badClause : Block := declared (.last (.handleE
  (.last (.call (.opName "ask" []) [] [] .nil))
  (.cons (.user "ask") 0 0 (.seq (appendAt 1 "bad") (.last (.resume 0 (.literal (.integer ⟨7, by decide⟩))))) .nil)))
example : hiddenBuilder (checkBlock handleInput .strict [] [] none .other [] badClause) = true := by decide

-- 構成子の部分適用でも、固定式の専用操作を空表で拒否する。
private def pairInput : Input := { input with D := { decls with
    cons := fun c => if c == "Pair" then some ⟨"Pair", 0, [strTy, strTy]⟩ else none } }
private def partialPair (e : Expr) : Expr :=
  .partialCon "Pair" [] (.expr none 0 e (.hole none 1 strTy .nil))
example : hiddenBuilder (checkBlock pairInput .strict [] [] none .other []
    (declared (.last (partialPair (copyAt 0))))) = true := by decide
example : (checkBlock pairInput .strict [] [] none .other []
    (declared (.bind .bind strTy (copyAt 0) (.last (partialPair (.local 0)))))).isOk = true := by decide

-- 二つのセルの間に通常値を挟んでも、先にコピーした内容は後の追記に変わらない。
private def multiple : Block := declared (.seq (appendAt 0 "first")
  (.bind .bind strTy (copyAt 0) (declared (.seq (appendAt 0 "second")
    (.seq (appendAt 2 "changed") (.last (.local 1)))))))
example : (checkedBlock multiple).isOk = true := by decide
example : returnedText multiple = some "first" := by decide

-- Fail 節から外側の専用位置を読むことも拒否し、節自身の宣言は受理する。
private def badFailClause : Block := declared (.last (.handleFail strTy strTy
  (.last (.literal (.string "ok"))) (.last (copyAt 2))))
private def localFailClause : Block := .last (.handleFail strTy strTy
  (.last (.literal (.string "ok"))) (declared (.last (copyAt 0))))
example : hiddenBuilder (checkedBlock badFailClause) = true := by decide
example : (checkedBlock localFailClause).isOk = true := by decide

-- コアの述語は、通常の計算でのセル利用を許し、全生成境界の自由参照を検出する。
-- 入口の空Δではなく、すでにある外側の0番のセルを除外して確かめる。
example : Comp.Captures (fun i => i ≠ 0) (desugarExpr (fun _ _ => none) .other (copyAt 0)) := by
  simp [copyAt, builderFinish, desugarExpr, desugarExprs, boundVars, sequence, letChain,
    Comp.Captures, Vals.Captures]
example : ∀ e ∈ captureBoundaries,
    ¬ Comp.Captures (fun i => i ≠ 0) (desugarExpr (fun _ _ => none) .other e) := by
  simp [captureBoundaries, copyAt, appendAt, builderFinish, desugarExpr,
    desugarBlock, desugarExprs, desugarHoleArgs, sequence, letChain, callArgs, sequenceArgs, argEvals, argValues, directCallee,
    Comp.Captures, Val.Captures, Comp.Reads, LocalRef.Reads, Val.Reads, Vals.Reads,
    Comp.rename, Val.rename, Val.renameList, LocalRef.rename, HoleArgs.holeTypes, liftReads, upRen, recordFields,
    boundVars]

-- 先行copyの通常値は捕捉できる。隣の専用位置を除外しても、値の番号は残る。
example : Comp.Captures (fun i => i ≠ 1)
    (desugarExpr (fun _ _ => none) .other
      (.lam [] [] strTy Eff.empty (.last (.returnE strTy (.local 0))))) := by
  simp [desugarExpr, desugarBlock, Comp.Captures, Val.Captures, Comp.Reads, Val.Reads, liftReads]

-- Fail節では継続の予約とエラーの二位置を除いた後に、外側のセル番号を調べる。
example : ¬ Comp.Captures (fun i => i ≠ 0)
    (desugarExpr (fun _ _ => none) .other
      (.handleFail strTy strTy (.last (.literal (.string "ok"))) (.last (copyAt 2)))) := by
  simp [copyAt, builderFinish, desugarExpr, desugarExprs, desugarBlock, boundVars, sequence, letChain,
    Comp.Captures, Val.Captures, Clauses.Reads, Comp.Reads, LocalRef.Reads, Vals.Reads,
    liftReads]


-- block 内で作った構築器の不変な copy だけを通常の値として返せる。
example : checkExpr input .strict [] [] none .other []
    (.block (declared (.seq (appendAt 0 "x") (.last (copyAt 0))))) =
    .ok (strTy, Eff.empty) := by rfl
example : checkExpr input .strict [] [] none .other []
    (.block (declared (.last (.local 0)))) =
    .error ⟨[0, 0, 0], "local is missing or hidden"⟩ := by rfl
example : captureBoundaries.all (fun e => hiddenBuilder
    (checkedBlock (declared (.last (.block (.last e)))))) = true := by decide
-- 外側の構築器は同じ分類表で操作し、その追記は block の後にも残る。
private def blockAppend : Block := declared
  (.seq (.block (.seq (appendAt 0 "block") (.last .unit))) (.last (copyAt 0)))
example : checkedBlock blockAppend = .ok (strTy, Eff.empty) := by rfl
example : returnedText blockAppend = some "block" := by decide
-- 通常の Reference の State は block の出口でも残る。
example : (checkExpr { input with atoms := [.name stateEff] } .strict []
    [some (.reference strTy)] none .other []
    (.block (.last (.call (.primName "get" [strTy] []) [none] [0] (.cons (.local 0) .nil))))).map
      (fun (t,e) => tyEq [.name stateEff] t strTy && effEq [.name stateEff] e (Eff.single stateEff)) =
    .ok true := by rfl

private def pickBody : Block :=
  .bind .bind intTy
    (.block (.seq (.ifOnly (.local 0) (.last (.returnE (.base .unit) (.literal (.integer ⟨7, by decide⟩)))))
      (.last (.literal (.integer ⟨9, by decide⟩)))))
    (.last (.returnE intTy (.local 0)))
private noncomputable def pick (flag : Bool) : Option Int :=
  let call := Comp.app (.lam ["flag"] [.base .boolean]
    (desugarBlock (fun _ _ => none) .tail pickBody)) [.const (.boolean flag)]
  match (Release.run Release.Examples.program (runtimeBuiltins false)
      Release.Examples.oracle Release.Examples.rel Release.Examples.fresh 40
      (.run call [] Store.empty) []).1 with
  | .run (.ret (.const (.integer n))) [] _ => some n.toInt
  | _ => none
-- block を関数に置き換える脱糖では、囲む関数への早期 return を保存できない。
example : [pick true, pick false] = [some 7, some 9] := by decide
example : checkExpr input .strict [] [] none .other []
    (.lam ["flag"] [.base .boolean] intTy Eff.empty pickBody) =
    .ok (.fn ["flag"] [.base .boolean] intTy Eff.empty, Eff.empty) := by rfl

end Benitoite.Surface.BuilderExamples
