import Benitoite.Surface.CheckProgramSound
import Benitoite.Release.Examples
import Benitoite.Surface.PrimRange

/-! 検査全体の公開入口と、実名付きの材料から型付けへの接続の評価例。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check.Examples
open Benitoite.Release Benitoite.Surface.CheckTools

private def intTy : Ty := .base .integer
private def unitTy : Ty := .base .unit
private def eInt (n : Integer64Literal) : Expr := .literal (.integer n)
private def eTrue : Expr := .literal (.boolean true)
private def eFalse : Expr := .literal (.boolean false)
private def atoms : List Atom :=
  [.nameTop "State", .nameTop "Console.Write", .nameTop "A", .nameTop "B"]
private def emptyDecls : Declarations := { funs := fun _ => none, cons := fun _ => none }
private def input (D : Declarations := emptyDecls) : Input :=
  { D, B := Release.Examples.builtins, satDec := fun _ _ _ => true,
    admitsDec := fun _ _ _ => true, opPrim := fun _ _ => none,
    ctors := fun _ => [], atoms }
private def run (e : Expr) (Γ : List (Option Ty) := [])
    (R : Option Ty := none) (p : Position := .other) : Result Inferred :=
  checkExpr (input) .strict [] Γ R p [] e
private def got (x : Result Inferred) (a : Ty) (ε : Eff := emptyEff) : Bool :=
  match x with
  | .error _ => false
  | .ok (b, ε') => tyEq atoms a b && effEq atoms ε ε'

-- ラムダの型の名前と、条件分岐による外側のエフェクトの結び。
private def fn (eff : Eff) : Expr :=
  .lam ["value"] [intTy] intTy eff (.last (.returnE unitTy (.local 0)))
example : got (run (.ite eTrue (.last (fn (Eff.single "A"))) (.last (fn (Eff.single "B")))))
    (.fn ["value"] [intTy] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide
example : got (run (.elseIf eFalse (.last (fn (Eff.single "A")))
    (.ite eTrue (.last (fn (Eff.single "B"))) (.last (fn emptyEff)))))
    (.fn ["value"] [intTy] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide
example : got (run (.ifOnly eFalse (.lastDiscard (eInt ⟨1, by decide⟩)))) unitTy = true := by decide

-- return の末尾と非末尾、および遅延境界での遮蔽。
example : got (run (.returnE unitTy (eInt ⟨1, by decide⟩)) [] (some intTy) .tail) intTy = true := by decide
example : got (run (.returnE unitTy (eInt ⟨1, by decide⟩)) [] (some intTy)) unitTy = true := by decide
example : run (.returnE unitTy (eInt ⟨1, by decide⟩)) = .error ⟨[], "return is outside a function"⟩ := by rfl
example : got (run (.lazyE (.last (eInt ⟨1, by decide⟩)))) (.lazy intTy) = true := by decide
example : run (.lazyE (.last (.returnE intTy (eInt ⟨1, by decide⟩)))) [] (some intTy) =
    .error ⟨[0, 0], "return is outside a function"⟩ := by rfl

-- 一覧・パターン・ガードを通した型と、失敗する要素のソース位置。
example : got (run (.list intTy (.cons (eInt ⟨1, by decide⟩) (.cons (eInt ⟨2, by decide⟩) .nil)))) (.list intTy) = true := by decide
example : run (.list intTy (.cons (eInt ⟨1, by decide⟩) (.cons eFalse .nil))) =
    .error ⟨[0, 1], "type is not included in the expected type"⟩ := by rfl
example : got (run (.matchE intTy eTrue
    (.cons [⟨.wild, []⟩] (some eTrue) (.last (eInt ⟨1, by decide⟩))
      (.single .wild (.last (eInt ⟨2, by decide⟩)) .nil)))) intTy = true := by decide
example : run (.matchE intTy eTrue (.single (.boolean true) (.last (eInt ⟨1, by decide⟩)) .nil)) =
    .error ⟨[], "match is not exhaustive"⟩ := by rfl

-- 位置を入れ替えたレコードの構築・更新。独立した引数の誤りの位置も保つ。
private def pointDecls : Declarations :=
  { emptyDecls with
    cons := fun c => if c == "Point" then some ⟨"Point", 0, [intTy, intTy]⟩ else none,
    conFields := fun c => if c == "Point" then some ["x", "y"] else none }
private def pointInput : Input :=
  { input pointDecls with ctors := fun n => if n == "Point" then ["Point"] else [] }
example : got (checkExpr pointInput .strict [] [] none .other []
    (.record "Point" [] [1, 0] (.cons (eInt ⟨3, by decide⟩) (.cons (eInt ⟨2, by decide⟩) .nil)))) (.data "Point" []) = true := by decide
example : got (checkExpr pointInput .strict [] [some (.data "Point" [])] none .other []
    (.recordUpdate "Point" [] 2 [0] (.local 0) (.cons (eInt ⟨7, by decide⟩) .nil))) (.data "Point" []) = true := by decide
example : checkExpr pointInput .strict [] [] none .other []
    (.record "Point" [] [1, 0] (.cons (eInt ⟨3, by decide⟩) (.cons eFalse .nil))) =
    .error ⟨[0, 1], "type is not included in the expected type"⟩ := by rfl

-- 同じ宣言でもソース照合には外部の view が作用し、内部の更新には作用しない。
private def pointViewInput (view : CoverageView) : Input :=
  { pointInput with D := pointDecls.withView view }
private def pointPat : Pattern := .record "Point" 2 [0, 1] [.var, .var]
private def pointMatch (catchAll : Bool) : Expr :=
  .matchE intTy (.local 0) (.single pointPat (.last (eInt ⟨1, by decide⟩))
    (if catchAll then .single .wild (.last (eInt ⟨2, by decide⟩)) .nil else .nil))

example : ([closedView, fun d => d == "Point"] : List CoverageView).map (fun view =>
    [ (checkExpr (pointViewInput view) .strict [] [some (.data "Point" [])]
        none .other [] (pointMatch false)).map (fun r => got (.ok r) intTy),
      (checkExpr (pointViewInput view) .strict [] [some (.data "Point" [])]
        none .other [] (pointMatch true)).map (fun r => got (.ok r) intTy),
      (checkExpr (pointViewInput view) .strict [] [some (.data "Point" [])]
        none .other [] (.recordUpdate "Point" [] 2 [0] (.local 0) (.cons (eInt ⟨7, by decide⟩) .nil))).map
        (fun r => got (.ok r) (.data "Point" [])) ]) =
    [[.ok true, .ok true, .ok true],
      [.error ⟨[], "match is not exhaustive"⟩, .ok true, .ok true]] := by rfl

-- 最後の束縛と続きを持つ束縛の両方が、bind/shadow とも同じ view を読む。
example : ([closedView, fun d => d == "Point"] : List CoverageView).map (fun view =>
    [BindKind.bind, .shadow].map (fun k =>
      [Block.lastPat k pointPat (.data "Point" []) (.local 0),
       .bindPat k pointPat (.data "Point" []) (.local 0) (.lastDiscard (.local 0))].map
        (fun b => (checkBlock (pointViewInput view) .strict [] [some (.data "Point" [])]
          none .other [] b).map (fun r => got (.ok r) unitTy)))) =
    [[[.ok true, .ok true], [.ok true, .ok true]],
     [[.error ⟨[], "binding pattern is not exhaustive"⟩, .error ⟨[], "binding pattern is not exhaustive"⟩],
      [.error ⟨[], "binding pattern is not exhaustive"⟩, .error ⟨[], "binding pattern is not exhaustive"⟩]]] := by rfl

-- try の合成照合も外部の view で包括分岐を要求しない。ソースの全列挙は拒否する。
private def tryDecls : Declarations :=
  { emptyDecls with cons := fun c => match c with
      | "Ok" => some ⟨"Result", 2, [.tvar 0]⟩
      | "Err" => some ⟨"Result", 2, [.tvar 1]⟩
      | "Some" => some ⟨"Option", 1, [.tvar 0]⟩
      | "None" => some ⟨"Option", 1, []⟩
      | _ => none }
private def tryInput (view : CoverageView) : Input :=
  { input (tryDecls.withView view) with ctors := fun d => match d with
      | "Result" => ["Ok", "Err"] | "Option" => ["Some", "None"] | _ => [] }

example : ([closedView, fun _ => true] : List CoverageView).map (fun view =>
    [ (checkExpr (tryInput view) .strict [] [some (.data "Result" [intTy, unitTy])]
        (some (.data "Result" [unitTy, unitTy])) .other []
        (.tryResult [unitTy, unitTy] "Ok" "Err" (.local 0))).map (fun r => got (.ok r) intTy),
      (checkExpr (tryInput view) .strict [] [some (.data "Option" [intTy])]
        (some (.data "Option" [unitTy])) .other []
        (.tryOption [unitTy] "Some" "None" (.local 0))).map (fun r => got (.ok r) intTy),
      (checkExpr (tryInput view) .strict [] [some (.data "Option" [intTy])] none .other []
        (.matchE intTy (.local 0) (.single (.con none "Some" [.var]) (.last (eInt ⟨1, by decide⟩))
          (.single (.con none "None" []) (.last (eInt ⟨2, by decide⟩)) .nil)))).map
            (fun r => got (.ok r) intTy) ]) =
    [[.ok true, .ok true, .ok true], [.ok true, .ok true, .error ⟨[], "match is not exhaustive"⟩]] := by rfl

-- 宣言のない die は構成子の探索で拒否する。裸の try の上の表は維持する。
example : ([none, some (.literal (.string ""))] : List (Option Expr)).map (fun message =>
    [run (.tryResultDie intTy "Ok" "Err" (.local 1) "show" "Process.exit" (.local 0) message),
     run (.tryOptionDie intTy "Some" "None" "Process.exit" (.local 0) message)] |>.map
       (fun result => result.map (fun _ => true))) =
    [[.error ⟨[], "unknown Result success constructor"⟩, .error ⟨[], "unknown Option success constructor"⟩],
     [.error ⟨[], "unknown Result success constructor"⟩, .error ⟨[], "unknown Option success constructor"⟩]] := by rfl

section DieChecks

private def strTy : Ty := .base .string
private def errorTy : Ty := .opaqueTop "Failure"
private def resultTy : Ty := .data "Result" [intTy, errorTy]
private def optionTy : Ty := .data "Option" [intTy]
private def dieAtoms : List Atom := [.nameTop "Process.Exit", .nameTop "A"]
private def showSig : MethSig :=
  { tparams := [], neffs := 0, names := ["x"], params := [.tvar 0], ret := strTy, eff := emptyEff }
private def exitSig : PrimSig :=
  { tparams := [{}], neffs := 0, names := ["code"], params := [intTy], ret := .tvar 0,
    eff := Eff.single "Process.Exit", kind := .exit, opEff := some "Process.Exit",
    admits := fun _ ts => ts.length = 1 }
private def dieInput (ms : MethSig := showSig) (sg : PrimSig := exitSig) : Input :=
  { tryInput closedView with
    atoms := dieAtoms,
    D := { tryDecls with classes := fun cl => if cl == "class:7" then some {
      supers := [], methods := fun m => if m == "meth:9" then some ms else none } else none },
    B := { Release.Examples.builtins with
      sig := fun b => if b == "prim:8" then some sg else none } }
private def resultEnv : List (Option Ty) :=
  [some resultTy, some (.dict "class:7" errorTy), some strTy,
    some (.fn [] [] resultTy (Eff.single "A"))]
private def optionEnv : List (Option Ty) := [some optionTy]
private def resultDie (message : Option Expr := none) : Expr :=
  .tryResultDie intTy "Ok" "Err" (.local 1) "meth:9" "prim:8" (.local 0) message
private def optionDie (message : Option Expr := none) : Expr :=
  .tryOptionDie intTy "Some" "None" "prim:8" (.local 0) message
private def dieRun (q : Input) (env : List (Option Ty)) (e : Expr)
    (r : Option Ty := none) (p : Position := .other) : Result Inferred :=
  checkExpr q .strict [] env r p [] e
private def dieGot (r : Result Inferred) (eff : Eff := Eff.single "Process.Exit") : Result Bool :=
  r.map fun (t, ε) => tyEq dieAtoms t intTy && effEq dieAtoms ε eff

-- 同じ表で任意の R・位置・任意の説明を検査する。Option は辞書を持たない。
example : ([none, some unitTy, some intTy, some resultTy] : List (Option Ty)).map (fun r =>
    [Position.other, .tail].map (fun p =>
      [none, some (.literal (.string ""))].map (fun message =>
        [dieGot (dieRun (dieInput) resultEnv (resultDie message) r p),
         dieGot (dieRun (dieInput) optionEnv (optionDie message) r p)]))) =
    List.replicate 4 (List.replicate 2 (List.replicate 2 [.ok true, .ok true])) := by rfl

-- 入力の効果は失わず、説明は元の局所番号を読み、内側の lambda は自分の return を持つ。
example : dieGot (dieRun (dieInput) resultEnv
    (.tryResultDie intTy "Ok" "Err" (.local 1) "meth:9" "prim:8"
      (.call (.local 3) [] [] .nil) (some (.local 2))))
    (Eff.union (Eff.single "A") (Eff.single "Process.Exit")) = .ok true := by rfl
example : dieGot (dieRun (dieInput) optionEnv (optionDie (some
    (.call (.lam [] [] strTy emptyEff (.last (.returnE unitTy (.literal (.string "message")))))
      [] [] .nil)))) = .ok true := by rfl

-- 一条件だけを変えたメソッドの契約を、すべて同じ拒否位置で検査する。
example : ([{ showSig with tparams := [{}] }, { showSig with neffs := 1 },
    { showSig with names := ["other"] }, { showSig with params := [intTy] },
    { showSig with ret := intTy }, { showSig with eff := Eff.single "A" }] : List MethSig).map
    (fun ms => dieRun (dieInput ms) resultEnv (resultDie)) =
    List.replicate 6 (.error ⟨[2], "invalid die display method contract"⟩) := by rfl
example : dieRun (dieInput) [some resultTy, some (.dict "class:7" unitTy)] (resultDie) =
    .error ⟨[2], "die dictionary target type mismatch"⟩ := by rfl
example : dieRun (dieInput) [some resultTy, some intTy] (resultDie) =
    .error ⟨[2], "expected a dictionary type"⟩ := by rfl
example : dieRun (dieInput) [some resultTy, some (.dict "OtherClass" errorTy)] (resultDie) =
    .error ⟨[2], "unknown die dictionary class"⟩ := by rfl
example : dieRun (dieInput) resultEnv
    (.tryResultDie intTy "Ok" "Err" (.local 1) "otherMethod" "prim:8" (.local 0) none) =
    .error ⟨[2], "unknown die display method"⟩ := by rfl

-- exit の種類・所属・型引数の数・契約名・具体化した型・効果・admits を個別に壊す。
example : ([{ exitSig with kind := .io }, { exitSig with opEff := none },
    { exitSig with tparams := [] }, { exitSig with neffs := 1 },
    { exitSig with names := [] }] : List PrimSig).map (fun sg =>
      dieRun (dieInput showSig sg) optionEnv (optionDie)) =
    List.replicate 5 (.error ⟨[], "invalid die exit primitive"⟩) := by rfl
example : ([{ exitSig with names := ["other"] }, { exitSig with params := [strTy] },
    { exitSig with ret := strTy }, { exitSig with eff := emptyEff }] : List PrimSig).map (fun sg =>
      dieRun (dieInput showSig sg) optionEnv (optionDie)) =
    List.replicate 4 (.error ⟨[], "die exit type mismatch"⟩) := by rfl
example : dieRun { dieInput with admitsDec := fun _ _ _ => false } optionEnv (optionDie) =
    .error ⟨[], "die exit type arguments are not admitted"⟩ := by rfl
example : dieRun { dieInput with atoms := [.nameTop "A"] } optionEnv (optionDie) =
    .error ⟨[], "Process.Exit effect is outside atoms"⟩ := by rfl

-- 純粋性の失敗は説明自身の位置。return と resume は説明の遮蔽した境界で拒否する。
private def impureMessage : Expr := .call (.local 1) [] [] .nil
example : dieRun (dieInput)
    (optionEnv ++ [some (.fn [] [] strTy (Eff.single "A"))])
    (optionDie (some impureMessage)) =
    .error ⟨[1], "effect exceeds the allowed effect"⟩ := by rfl
example : dieRun (dieInput) optionEnv (optionDie (some (eInt ⟨0, by decide⟩))) =
    .error ⟨[1], "type is not included in the expected type"⟩ := by rfl
example : dieRun (dieInput) optionEnv
    (optionDie (some (.returnE strTy (.literal (.string "escape"))))) (some strTy) =
    .error ⟨[1], "return is outside a function"⟩ := by rfl
example : dieRun (dieInput) (optionEnv ++ [some (.cont strTy strTy emptyEff)])
    (optionDie (some (.resume 1 (.literal (.string "resume"))))) =
    .error ⟨[1], "continuation is missing or hidden"⟩ := by rfl

-- 入力の種類・成功型・構成子・網羅性は、辞書や説明の検査に達する前に独立に拒否する。
example : dieRun (dieInput) [some (.data "Option" [strTy])] (optionDie) =
    .error ⟨[0], "Option die input type mismatch"⟩ := by rfl
example : dieRun (dieInput) [some intTy] (optionDie) =
    .error ⟨[0], "try input is not an Option"⟩ := by rfl
example : dieRun (dieInput) resultEnv
    (.tryResultDie intTy "Ok" "Ok" (.local 1) "meth:9" "prim:8" (.local 0) none) =
    .error ⟨[], "invalid Result constructors"⟩ := by rfl
private def extraOptionInput : Input :=
  { dieInput with
    D := { (dieInput).D with cons := fun c =>
      if c == "OtherNone" then some ⟨"Option", 1, []⟩ else (dieInput).D.cons c },
    ctors := fun d => if d == "Option" then ["Some", "None", "OtherNone"] else (dieInput).ctors d }
example : dieRun extraOptionInput optionEnv (optionDie) =
    .error ⟨[], "Option try is not exhaustive"⟩ := by rfl

end DieChecks

-- 名前を持つ利用者の操作。節のローカルな継続と、外側の型を接続する。
private def opDecls : Declarations :=
  { emptyDecls with
    ops := fun o => if o == "A.id" then some {
      eff := "A", tparams := [], names := ["value"], params := [intTy], ret := intTy } else none
    effects := fun e => if e == "A" then some ["A.id"] else none }
private def opInput : Input := { input opDecls with ctors := fun _ => [] }
private def handled : Expr :=
  .handleE (.last (.call (.opName "A.id" []) [some "value"] [0] (.cons (eInt ⟨7, by decide⟩) .nil)))
    (.cons (.user "A.id") 1 0 (.last (.resume 0 (.local 1))) .nil)
example : got (checkExpr opInput .strict [] [] none .other [] handled) intTy = true := by decide

-- 節で初めて現れる効果は反復で集計し、確定後も純粋な注釈を許さない。
private def effectfulClauseHandle : Expr :=
  .handleE (.last (eInt ⟨1, by decide⟩))
    (.cons (.user "A.id") 1 0
      (.seq (.call (.local 2) [some "value"] [0] (.cons (eInt ⟨7, by decide⟩) .nil))
        (.last (.resume 0 (.local 1)))) .nil)
private def clauseEffectEnv : List (Option Ty) :=
  [some (.fn ["value"] [intTy] unitTy (Eff.single "B"))]
example : got (checkExpr opInput .strict [] clauseEffectEnv none .other []
    effectfulClauseHandle) intTy (Eff.single "B") = true := by decide
example : checkExpr opInput .strict [] clauseEffectEnv none .other []
    (.lam [] [] intTy emptyEff (.last (.returnE unitTy effectfulClauseHandle))) =
    .error ⟨[0], "effect exceeds the allowed effect"⟩ := by rfl

example : checkExpr opInput .strict [] [] none .other []
    (.handleE (.last (eInt ⟨1, by decide⟩)) (.cons (.user "A.id") 0 0 (.last (eInt ⟨2, by decide⟩)) .nil)) =
    .error ⟨[1], "handler operation arity mismatch"⟩ := by rfl

-- 操作の辞書は公開引数に含めず、節では同じ制約番号を局所の型で読み直す。
private def renderDecl : OpDecl :=
  { eff := "A", tparams := [{}], names := ["%dict1", "value"],
    params := [.dict "Show" (.tvar 0), .tvar 0], ret := .base .string,
    dictParams := [("Show", 0)] }
private def renderInput : Input :=
  { opInput with D := { opDecls with
      ops := fun o => if o == "render" then some renderDecl else none
      effects := fun e => if e == "A" then some ["render"] else none
      classes := fun c => if c == "Show" then some {
        supers := [], methods := fun m => if m == "show" then some {
          tparams := [], neffs := 0, names := ["value"], params := [.tvar 0],
          ret := .base .string, eff := emptyEff } else none } else none } }
private def renderCall (t : Ty) (d : DictEv := .local 0) : Expr :=
  .call (.opDicts "render" [t] [d] ["value"] [t]) [some "value"] [0]
    (.cons (.local 1) .nil)
private def renderClause (d : DictEv) : Block :=
  .last (.resume 0 (.call (.methName d "show" [] [] [] ["value"] [.tvar 0])
    [some "value"] [0] (.cons (.local 1) .nil)))
private def renderHandle (t : Ty) (d : DictEv) (count : Nat := 1) : Expr :=
  .handleE (.last (renderCall t))
    (.cons (.user "render") 1 1 (renderClause d) .nil count)
private def renderEnv (t : Ty) : List (Option Ty) := [some (.dict "Show" t), some t]

-- Integer と String を同じ多相の節で扱い、外側の辞書0と節の辞書0を区別する。
example : ([intTy, .base .string] : List Ty).map (fun t =>
    got (checkExpr renderInput .strict [] (renderEnv t) none .other []
      (renderHandle t (.clause ⟨2, 1, 1⟩ 0))) (.base .string)) = [true, true] := by decide


-- 外側の同名クラスの辞書を、節のrigid型の辞書へ流用できない。
example : checkExpr renderInput .strict [] (renderEnv intTy) none .other []
    (renderHandle intTy (.local 3)) =
    .error ⟨[1, 0, 0, 0, 0], "method parameter annotation mismatch"⟩ := by rfl

-- 所属する節の環境がなければ、同じクラスの外側の辞書があっても根拠を拒否する。
example : checkDict renderInput [] (renderEnv intTy) [] (.clause ⟨2, 1, 1⟩ 0) =
    .error ⟨[], "clause dictionary scope mismatch"⟩ := by rfl

-- 未使用の辞書も束縛数に含め、継続を常に0番に保つ。
example : got (checkExpr renderInput .strict [] (renderEnv intTy) none .other []
    (.handleE (.last (renderCall intTy))
      (.cons (.user "render") 1 1 (.last (.resume 0 (.literal (.string "unused")))) .nil 1)))
    (.base .string) = true := by decide
example : checkExpr renderInput .strict [] (renderEnv intTy) none .other []
    (renderHandle intTy (.clause ⟨2, 1, 1⟩ 0) 0) =
    .error ⟨[1], "handler operation arity mismatch"⟩ := by rfl

-- 辞書のクラスと公開引数の名前・個数は、それぞれの契約を独立に検査する。
example : checkExpr renderInput .strict [] [some (.dict "Other" intTy), some intTy]
    none .other [] (renderCall intTy) =
    .error ⟨[0, 0, 0], "dictionary type mismatch"⟩ := by rfl
example : checkExpr renderInput .strict [] (renderEnv intTy) none .other []
    (.call (.opDicts "render" [intTy] [.local 0] ["value"] [intTy])
      [some "%dict1", some "value"] [0, 1] (.cons (.local 0) (.cons (.local 1) .nil))) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : checkExpr renderInput .strict [] (renderEnv intTy) none .other []
    (.opName "render" [intTy]) =
    .error ⟨[], "operation needs dictionaries"⟩ := by rfl

-- 脱糖から実行まで、同じ節へ二種類の辞書を渡して表示結果を観測する。
private def renderBuiltins : Builtins :=
  { Release.Examples.builtins with
    sig := fun b => if b == "intToString" then some {
      tparams := [], neffs := 0, names := ["value"], params := [intTy], ret := .base .string,
      eff := emptyEff, kind := .pure, opEff := none, admits := fun _ _ => True } else none
    delta := fun b _ _ _ vs => match b, vs with
      | "intToString", [.const (.integer n)] => some (.val (.const (.string (toString n.toInt))))
      | _, _ => none }
private def renderImpl (t : Ty) (body : Comp) : Release.ImplDecl :=
  { tparams := [], dictParams := [], cls := "Show", target := t,
    supers := fun _ => none, methods := fun m => if m == "show" then some body else none }
private def renderProgram : Release.Program :=
  { Release.Examples.program with
    ops := renderInput.D.ops, effects := renderInput.D.effects, classes := renderInput.D.classes,
    impls := fun i => match i with
      | "ShowInt" => some (renderImpl intTy (.app (.prim "intToString" [] [] []) [.var 0]))
      | "ShowString" => some (renderImpl (.base .string) (.ret (.var 0)))
      | _ => none }
private noncomputable def renderResult (t : Ty) (impl : ImplName) (value : Val) : Option String :=
  let body := (desugarExpr (fun _ _ => none) .other
    (renderHandle t (.clause ⟨2, 1, 1⟩ 0))).instantiate [value, .dict impl [] []]
  match (Release.run renderProgram renderBuiltins Release.Examples.oracle Release.Examples.rel
    Release.Examples.fresh 60 (.run body [] Store.empty) []).1 with
  | .run (.ret (.const (.string s))) [] _ => some s
  | _ => none
example : [renderResult intTy "ShowInt" (.const (.integer ⟨7, by decide⟩)),
    renderResult (.base .string) "ShowString" (.const (.string "text"))] =
    [some "7", some "text"] := by decide

namespace OperationValues

private def renderValue (t : Ty) (d : DictEv := .local 0) : Expr :=
  .opDicts "render" [t] [d] ["value"] [t]

-- 作成は純粋、呼び出しは A。値の束縛・穴・パイプにも同じ公開型を使う。
private def renderForms (t : Ty) : List Expr :=
  [renderCall t,
   .call (.paren (renderValue t)) [some "value"] [0] (.cons (.local 1) .nil),
   .call (.partialCall (renderValue t) ["value"] (.hole none 0 t .nil)
     (.base .string) (Eff.single "A")) [none] [0] (.cons (.local 1) .nil),
   .pipe (.local 1) (renderValue t),
   .pipe (.local 1) (.call (renderValue t) [] [] .nil),
   .handleE (.bind .bind (.fn ["value"] [t] (.base .string) (Eff.single "A")) (renderValue t)
     (.last (.call (.local 0) [some "value"] [0] (.cons (.local 2) .nil))))
     (.cons (.user "render") 1 1 (renderClause (.clause ⟨2, 1, 1⟩ 0)) .nil 1)]

example : ([intTy, .base .string] : List Ty).map (fun t =>
    got (checkExpr renderInput .strict [] (renderEnv t) none .other [] (renderValue t))
      (.fn ["value"] [t] (.base .string) (Eff.single "A"))) = [true, true] := by decide

example : ([intTy, .base .string] : List Ty).map (fun t =>
    (renderForms t).map fun e => got
      (checkExpr renderInput .strict [] (renderEnv t) none .other [] e)
      (.base .string) (if e matches .handleE .. then emptyEff else Eff.single "A")) =
    [[true, true, true, true, true, true], [true, true, true, true, true, true]] := by decide

-- 操作値を純粋な関数だと扱う注釈は拒否する。作成時の純粋性と潜在効果を混同しない。
example : checkExpr renderInput .strict [] (renderEnv intTy) none .other []
    (.partialCall (renderValue intTy) ["value"] (.hole none 0 intTy .nil)
      (.base .string) emptyEff) =
    .error ⟨[], "effect exceeds the allowed effect"⟩ := by rfl

private def runRender (e : Expr) (impl : ImplName) (value : Val) : Comp :=
  (desugarExpr (fun _ _ => none) .other e).instantiate [value, .dict impl [] []]

private noncomputable def renderFormResult (impl : ImplName) (value : Val)
    (e : Expr) : Option String :=
  let body := match e with
    | .handleE .. => e
    | _ => .handleE (.last e)
        (.cons (.user "render") 1 1 (renderClause (.clause ⟨2, 1, 1⟩ 0)) .nil 1)
  match (Release.run renderProgram renderBuiltins Release.Examples.oracle Release.Examples.rel
    Release.Examples.fresh 150 (.run (runRender body impl value) [] Store.empty) []).1 with
  | .run (.ret (.const (.string s))) [] _ => some s
  | _ => none

example : [(renderForms intTy).map (renderFormResult "ShowInt" (.const (.integer ⟨7, by decide⟩))),
    (renderForms (.base .string)).map
      (renderFormResult "ShowString" (.const (.string "text")))] =
    [[some "7", some "7", some "7", some "7", some "7", some "7"],
     [some "text", some "text", some "text", some "text", some "text", some "text"]] := by decide

end OperationValues

namespace OperationDictionaries

private def strTy : Ty := .base .string
private def pairDecl : OpDecl :=
  { eff := "A", tparams := [{}], names := ["%dict1", "%dict2", "first", "second"],
    params := [.dict "Show" (.tvar 0), .dict "Tag" (.tvar 0), .tvar 0, .tvar 0],
    ret := strTy, dictParams := [("Show", 0), ("Tag", 0)] }
private def tagSig : MethSig :=
  { tparams := [], neffs := 0, names := ["value"], params := [.tvar 0],
    ret := strTy, eff := emptyEff }
private def declarations : Declarations :=
  { renderInput.D with
    ops := fun o => if o == "pair" then some pairDecl else none
    effects := fun e => if e == "A" then some ["pair"] else none
    classes := fun c => match c with
      | "Fancy" => some { supers := ["Show"], methods := fun _ => none }
      | "Tag" => some { supers := [], methods := fun m => if m == "tag" then some tagSig else none }
      | _ => renderInput.D.classes c }
private def builtins : Builtins :=
  { renderBuiltins with
    sig := fun b => match b with
      | "first" | "second" => some (Release.Examples.sig [] [] [] intTy
          (Eff.single "B") .io (some "B"))
      | "append" => some (Release.Examples.sig [] ["left", "right"] [strTy, strTy]
          strTy emptyEff .pure)
      | "tagInt" => some (Release.Examples.sig [] ["value"] [intTy] strTy emptyEff .pure)
      | _ => renderBuiltins.sig b
    delta := fun b ts es rs vs => match b, vs with
      | "append", [.const (.string a), .const (.string b)] => some (.val (.const (.string (a ++ b))))
      | "tagInt", [.const (.integer n)] => some (.val (.const (.string ("tag" ++ toString n.toInt))))
      | _, _ => renderBuiltins.delta b ts es rs vs
    ioResponse := fun b ts es vs out obs => match b, vs with
      | "first", [] => out = .val (.const (.integer ⟨7, by decide⟩)) ∧ obs = []
      | "second", [] => out = .val (.const (.integer ⟨9, by decide⟩)) ∧ obs = []
      | _, _ => renderBuiltins.ioResponse b ts es vs out obs
    effects := fun e => if e == "B" then some ["first", "second"] else renderBuiltins.effects e }
private def q : Input := { renderInput with D := declarations, B := builtins }
private def env : List (Option Ty) :=
  [some (.dict "Fancy" intTy), some (.dict "Tag" intTy)]
private def pairHead (ds : List DictEv := [.super (.local 0) "Show", .local 1]) : Expr :=
  .opDicts "pair" [intTy] ds ["first", "second"] [intTy, intTy]
private def readArg (name : String) : Expr := .call (.primName name [] [] []) [] [] .nil
private def pairArgs : Exprs := .cons (readArg "second") (.cons (readArg "first") .nil)
private def directCall : Expr := .call (pairHead) [some "second", some "first"] [1, 0] pairArgs
private def partialPair : Expr :=
  .partialCall (pairHead) ["first", "second"]
    (.expr (some "second") 1 (readArg "second") (.hole (some "first") 0 intTy .nil))
    strTy (unionEff atoms (Eff.single "A") (Eff.single "B"))

-- 宣言順と逆に書いた引数、値化した頭、穴、パイプを同じ契約へ接続する。
private def calls : List Expr :=
  [directCall,
   .call (.paren (pairHead)) [some "second", some "first"] [1, 0] pairArgs,
   .call (.partialCall (pairHead) ["first", "second"]
     (.hole (some "second") 1 intTy (.hole (some "first") 0 intTy .nil))
     strTy (Eff.single "A")) [some "second", some "first"] [0, 1] pairArgs,
   .pipe (readArg "first")
     (.call (pairHead) [some "second"] [1] (.cons (readArg "second") .nil)),
   .call partialPair [some "first"] [0] (.cons (readArg "first") .nil)]

private def showValue (d : DictEv) (v : Expr) (method : String := "show") : Expr :=
  .call (.methName d method [] [] [] ["value"] [.tvar 0]) [some "value"] [0] (.cons v .nil)

-- 辞書も値も、内側の一引数ラムダから参照する。継続はラムダの外でだけ使う。
private def pairClause (depth : Nat := 1) (swapped : Bool := false) : Block :=
  .last (.resume 0 (.call
    (.lam ["unused"] [unitTy] strTy emptyEff
      (.last (.returnE unitTy (.call (.primName "append" [] [] []) [some "left", some "right"] [0, 1]
        (.cons (showValue (.clause ⟨2, 2, 2⟩ (if swapped then 1 else 0) depth) (.local 3))
          (.cons (showValue (.clause ⟨2, 2, 2⟩ 1 depth) (.local 2) "tag") .nil))))))
    [none] [0] (.cons .unit .nil)))
private def handledPair (e : Expr) (depth : Nat := 1) (swapped : Bool := false) : Expr :=
  .handleE (.last e) (.cons (.user "pair") 2 1 (pairClause depth swapped) .nil 2)

example : calls.map (fun e => got (checkExpr q .strict [] env none .other [] e)
    strTy (Eff.union (Eff.single "A") (Eff.single "B"))) =
    [true, true, true, true, true] := by decide
example : calls.map (fun e => got (checkExpr q .strict [] env none .other [] (handledPair e))
    strTy (Eff.single "B")) = [true, true, true, true, true] := by decide
example : got (checkExpr q .strict [] env none .other [] partialPair)
    (.fn ["first"] [intTy] strTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide

-- 辞書の順序と上位クラスの根拠を独立に拒否する。
example : checkExpr q .strict [] env none .other []
    (pairHead [.local 1, .super (.local 0) "Show"]) =
    .error ⟨[0, 0], "dictionary type mismatch"⟩ := by rfl
example : checkExpr q .strict [] env none .other []
    (pairHead [.super (.local 0) "Missing", .local 1]) =
    .error ⟨[0, 0], "class is not a superclass"⟩ := by rfl

-- 内側ラムダでのdepthを省くと所属を拒否し、同じ枠の別クラスを使うとメソッドを拒否する。
example : checkExpr q .strict [] env none .other [] (handledPair directCall 0) =
    .error ⟨[1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], "clause dictionary scope mismatch"⟩ := by rfl
example : checkExpr q .strict [] env none .other [] (handledPair directCall 1 true) =
    .error ⟨[1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0], "unknown method"⟩ := by rfl

private def program : Release.Program :=
  { renderProgram with
    ops := declarations.ops, effects := declarations.effects,
    classes := declarations.classes,
    impls := fun i => match i with
      | "FancyInt" => some {
          tparams := [], dictParams := [], cls := "Fancy", target := intTy,
          supers := fun s => if s == "Show" then some (.dict "ShowInt" [] []) else none,
          methods := fun _ => none }
      | "TagInt" => some {
          tparams := [], dictParams := [], cls := "Tag", target := intTy,
          supers := fun _ => none,
          methods := fun m => if m == "tag" then some (.app (.prim "tagInt" [] [] []) [.var 0]) else none }
      | _ => renderProgram.impls i }
private def oracle : Oracle
  | "first", _, _, _ => (.val (.const (.integer ⟨7, by decide⟩)), [])
  | "second", _, _, _ => (.val (.const (.integer ⟨9, by decide⟩)), [])
  | b, ts, es, vs => Release.Examples.oracle b ts es vs

-- 表示結果は辞書・値の配置を、事象列はソース順と一度だけの評価を観測する。
private noncomputable def result (e : Expr) : Option String × List PrimName :=
  let body := (desugarExpr (fun _ _ => none) .other (handledPair e)).instantiate
    [.dict "TagInt" [] [], .dict "FancyInt" [] []]
  let (s, events) := Release.run program builtins oracle Release.Examples.rel
    Release.Examples.fresh 250 (.run body [] Store.empty) []
  let value := match s with
    | .run (.ret (.const (.string text))) [] _ => some text
    | _ => none
  (value, events.filterMap fun ev => match ev with | .io b _ _ _ => some b | _ => none)

example : calls.map result =
    [(some "7tag9", ["second", "first"]), (some "7tag9", ["second", "first"]),
     (some "7tag9", ["second", "first"]), (some "7tag9", ["first", "second"]),
     (some "7tag9", ["first", "second"])] := by decide

-- 節へ受け取った上位クラスの辞書も、内側ラムダで所属を保ったまま射影する。
private def fancyDecl : OpDecl :=
  { renderDecl with params := [.dict "Fancy" (.tvar 0), .tvar 0], dictParams := [("Fancy", 0)] }
private def fancyInput : Input :=
  { q with atoms := .nameTop "R" :: q.atoms, D := { declarations with
      ops := fun o => match o with
        | "fancy" => some fancyDecl
        | "render" => some { renderDecl with eff := "R" }
        | _ => none
      effects := fun e => match e with
        | "A" => some ["fancy"] | "R" => some ["render"] | _ => none } }
private def fancyBody (d : DictEv) (forward : Bool) : Expr :=
  if forward then
    -- 内側ラムダで受け取った辞書を操作値へ捕え、局所束縛の後で呼ぶ。
    .handleE (.bind .bind (.fn ["value"] [.tvar 0] strTy (Eff.single "R"))
      (.opDicts "render" [.tvar 0] [.super d "Show"] ["value"] [.tvar 0])
      (.last (.call (.local 0) [some "value"] [0] (.cons (.local 3) .nil))))
      (.cons (.user "render") 1 1 (renderClause (.clause ⟨6, 1, 1⟩ 0)) .nil 1)
  else showValue (.super d "Show") (.local 2)
private def fancyHandle (d : DictEv := .clause ⟨2, 1, 1⟩ 0 1) (forward : Bool := false) : Expr :=
  .handleE (.last (.pipe (eInt ⟨7, by decide⟩) (.opDicts "fancy" [intTy] [.local 0] ["value"] [intTy])))
    (.cons (.user "fancy") 1 1
      (.last (.resume 0 (.call
        (.lam ["unused"] [unitTy] strTy emptyEff
          (.last (.returnE unitTy (fancyBody d forward))))
        [none] [0] (.cons .unit .nil)))) .nil 1)

example : [false, true].map (fun forward => got
    (checkExpr fancyInput .strict [] env none .other []
      (fancyHandle (.clause ⟨2, 1, 1⟩ 0 1) forward)) strTy) = [true, true] := by decide
example : checkExpr fancyInput .strict [] env none .other [] (fancyHandle (.local 4)) =
    .error ⟨[1, 0, 0, 0, 0, 0, 0, 0, 0], "method parameter annotation mismatch"⟩ := by rfl

private noncomputable def fancyResult (forward : Bool) : Option String :=
  let p := { program with ops := fancyInput.D.ops, effects := fancyInput.D.effects }
  let body := (desugarExpr (fun _ _ => none) .other
    (fancyHandle (.clause ⟨2, 1, 1⟩ 0 1) forward)).instantiate
    [.dict "TagInt" [] [], .dict "FancyInt" [] []]
  match (Release.run p builtins oracle Release.Examples.rel Release.Examples.fresh
    150 (.run body [] Store.empty) []).1 with
  | .run (.ret (.const (.string s))) [] _ => some s
  | _ => none

example : [false, true].map fancyResult = [some "7", some "7"] := by decide

end OperationDictionaries

-- リソースの State と、純粋な補間・直接の連結関数の契約。
example : got (checkExpr (input) .strict [] [some (.opaqueTop "File")] none .other []
    (.withE "File" (.local 0) (.last (eInt ⟨1, by decide⟩)))) intTy (Eff.single "State") = true := by decide
private def collectionBuiltins : Builtins :=
  { Release.Examples.builtins with sig := fun b => match b with
      | "concat" => some (Release.Examples.sig [] ["xs", "ys"] [.list intTy, .list intTy]
          (.list intTy) emptyEff .pure)
      | "toString" => some (Release.Examples.sig [] ["n"] [intTy] (.base .string) emptyEff .pure)
      | "addString" => some (Release.Examples.sig [] ["left", "right"] [.base .string, .base .string]
          (.base .string) emptyEff .pure)
      | _ => Release.Examples.builtins.sig b }
private def collectionInput : Input :=
  { (input) with
    B := collectionBuiltins,
    opPrim := CheckTables.makeOpPrim (fun op _ => match op with
      | .binary .add => some "addString" | _ => none) }
example : got (checkExpr collectionInput .strict [] [] none .other []
    (.listSpread intTy (.primName "concat" [] [] []) (.cons (eInt ⟨1, by decide⟩) .nil)
      (.list intTy (.cons (eInt ⟨2, by decide⟩) .nil)) (.cons (eInt ⟨3, by decide⟩) .nil))) (.list intTy) = true := by decide
example : got (checkExpr collectionInput .strict [] [] none .other []
    (.interpolation [.text "n=", .converted intTy] (.cons (eInt ⟨7, by decide⟩) .nil)
      (.cons (.primName "toString" [] [] []) .nil))) (.base .string) = true := by decide

namespace FormattedInterpolation

private def spec : FormatSpec := { kind := .s, align := .right, width := some 8 }
private def formatSig : PrimSig :=
  Release.Examples.sig [] ["value", "kind", "align", "sign", "alternate", "zero", "width", "precision"]
    [.base .string, intTy, intTy, intTy, .base .boolean, .base .boolean, intTy, intTy]
    (.base .string) Eff.empty .pure
private def formatInput : Input :=
  { collectionInput with B := { collectionBuiltins with
      sig := fun b => if b == "%Format.String" then some formatSig else collectionBuiltins.sig b } }
private def value : Expr := .literal (.string "x")
private def formatted : Expr := .interpolation [.formatted (.base .string) spec]
  (.cons value .nil) (.cons (.primName "%Format.String" [] [] []) .nil)

-- Stringも固定シグネチャの整形を通り、型判断と検査器がともに受理する。
example : HasType emptyDecls formatInput.B formatInput.opPrim [] [] none .other
    formatted (.base .string) Eff.empty := by
  have hempty : Eff.substAt 0 [] [] Eff.empty = Eff.empty := Eff.substAt_ofAtoms 0 [] _
  apply HasType.E_Interpolation
  · exact ⟨⟨by decide, by decide⟩, trivial⟩
  · exact .cons .E_Literal .nil
  · apply HasTypes.cons (ε := Eff.empty) (εs := Eff.empty) ?_ .nil
    have hhead : HasType emptyDecls formatInput.B formatInput.opPrim [] [] none .other
        (.primName "%Format.String" [] [] [])
        (fnTy formatSig.names formatSig.params formatSig.ret formatSig.eff [] []) Eff.empty := by
      apply HasTypeQ.E_PrimNil (s := formatSig) rfl rfl
        (PrimSig.inst_nil_of_canonical (by simp [formatSig, Release.Examples.sig, Ty.Canonical, Ty.norm])
          (by simp [formatSig, Release.Examples.sig, Eff.fails, Eff.empty]))
      · simp [NamesWF, formatSig, Release.Examples.sig]
      · rfl
      · rfl
      · rfl
      · apply PrimitiveAdmissible.of_noRows (by
          simp [PrimSig.Scoped, NamesWF, formatSig, Release.Examples.sig, Ty.VarsInList,
            Ty.VarsIn, Eff.VarsIn, Eff.empty, PrimSig.ntys, intTy]) rfl rfl rfl
        simp
      · rw [fnTy_eq, show formatSig.eff = Eff.empty from rfl, hempty]
        simp [formatSig, Release.Examples.sig, Ty.subst, Ty.substAt,
          Eff.empty, Eff.fails, SingleTy, SingleTys, SingleEff, SingleFail, intTy]
    rw [fnTy_eq, show formatSig.eff = Eff.empty from rfl, hempty] at hhead
    simpa [formatSig, Release.Examples.sig, Ty.subst, Ty.substAt,
      Eff.empty, FormatSpec.converterType, FormatSpec.parameterNames, FormatSpec.constantTypes, intTy]
      using hhead
  · exact ⟨⟨_, rfl⟩, trivial⟩
  · intro h; simp [InterpPart.count] at h

example : checkExpr formatInput .strict [] [] none .other [] formatted =
    .ok (.base .string, emptyEff) := by rfl

-- 脱糖の期待値は符号化の関数を使わずに記す。省略精度は-1のままである。
example : desugarExpr formatInput.opPrim .other formatted =
    .letIn (.ret (.const (.string "x")))
      (.letIn (.app (.prim "%Format.String" [] [] [])
        [.var 0, .const (.integer ⟨7, by decide⟩), .const (.integer ⟨2, by decide⟩),
         .const (.integer ⟨0, by decide⟩), .const (.boolean false), .const (.boolean false),
         .const (.integer ⟨8, by decide⟩), .const (.integer ⟨-1, by decide⟩)])
        (.ret (.var 0))) := by rfl

-- 全式の評価、書式付きと書式なしの変換、連結の順序と、各束縛下の番号を確認する。
example : desugarExpr formatInput.opPrim .other
    (.interpolation [.formatted (.base .string) spec, .converted intTy, .stringExpr]
      (.cons (.local 0) (.cons (.local 1) (.cons (.local 2) .nil)))
      (.cons (.primName "%Format.String" [] [] []) (.cons (.primName "toString" [] [] []) .nil))) =
    .letIn (.ret (.var 0))
      (.letIn (.ret (.var 2))
        (.letIn (.ret (.var 4))
          (.letIn (.app (.prim "%Format.String" [] [] [])
            [.var 2, .const (.integer ⟨7, by decide⟩), .const (.integer ⟨2, by decide⟩),
             .const (.integer ⟨0, by decide⟩), .const (.boolean false), .const (.boolean false),
             .const (.integer ⟨8, by decide⟩), .const (.integer ⟨-1, by decide⟩)])
            (.letIn (.app (.prim "toString" [] [] []) [.var 2])
              (.letIn (.app (.prim "addString" [] [] []) [.var 1, .var 0])
                (.app (.prim "addString" [] [] []) [.var 0, .var 3])))))) := by rfl

-- 型別の値は局所変数から読み、判定器へ実際の固定シグネチャを渡す。
-- 期待する受理集合をSupportedTypeやconverterTypeから生成しない。
-- 名前の照合は交換の境界が担う。この小例では同じ名前に型別の署名を与え、表層検査だけを確かめる。
private def typedInput (t : Ty) (s : PrimSig := formatSig) : Input :=
  let sg : PrimSig := { s with params := t :: s.params.tail }
  { formatInput with B := { formatInput.B with sig := fun b =>
      if b == "%Format.String" then Option.some sg else formatInput.B.sig b } }
private def single (t : Ty) (s : FormatSpec) (head : Expr := .primName "%Format.String" [] [] []) : Expr :=
  .interpolation [.formatted t s] (.cons (.local 0) .nil) (.cons head .nil)
private def accepted : List (Ty × FormatSpec) :=
  [(.base .integer, { kind := .d }), (.base .integer8, { kind := .b, alternate := true }),
   (.base .integer16, { kind := .o }), (.base .integer32, { kind := .x }),
   (.base .byte, { kind := .upperX, zero := true, width := some 8 }),
   (.base .unsignedInteger16, { kind := .d }), (.base .unsignedInteger32, { kind := .b }),
   (.base .unsignedInteger64, { kind := .x, sign := .plus }),
   (.base .float, { kind := .f, precision := some 0 }),
   (.base .float32, { kind := .f, precision := some 28 }),
   (.base .decimal, { kind := .f }), (.base .string, { kind := .s }),
   (.base .character, { kind := .c }), (.base .boolean, { width := some 1 })]
example : [ResumeMode.strict, .relaxed].all (fun mode => accepted.all (fun (t, s) =>
    got (checkExpr (typedInput t) mode [] [some t] none .other [] (single t s))
      (.base .string))) = true := by decide

-- 型不適合と不正指定は、頭や式の検査より前に同じ公開境界で拒否する。
private def rejected : List (Ty × FormatSpec) :=
  [(intTy, {}), (intTy, { kind := .f }), (.base .float, { kind := .d }),
   (.base .character, { kind := .s }), (.base .string, { kind := .c }),
   (.base .boolean, { sign := .plus }), (.base .string, { zero := true, width := some 8 }),
   (.list intTy, { width := some 8 }),
   (intTy, { width := some 0 }), (intTy, { width := some 65536 }),
   (.base .float, { kind := .f, precision := some 29 }),
   (intTy, { kind := .d, precision := some 0 }),
   (intTy, { align := .right }), (intTy, { zero := true }),
   (intTy, { zero := true, align := .right, width := some 8 }),
   (intTy, { kind := .d, alternate := true })]
example : rejected.all (fun (t, s) =>
    match checkExpr (typedInput t) .strict [] [some t] none .other [] (single t s) with
    | .error ⟨[], "interpolation type is not allowed"⟩ => true
    | _ => false) = true := by decide

-- 型が合っても局所変数経由の頭は直接の頭ではない。
example : checkExpr formatInput .strict [] [some (.base .string),
    some (.fn ["value", "kind", "align", "sign", "alternate", "zero", "width", "precision"]
      [.base .string, intTy, intTy, intTy, .base .boolean, .base .boolean, intTy, intTy]
      (.base .string) emptyEff)] none .other []
    (single (.base .string) spec (.local 1)) =
    .error ⟨[1], "interpolation converter is not a direct callee"⟩ := by rfl

-- 直接の頭でも呼び出しの契約が非純粋なら拒否する。
example : checkExpr (typedInput (.base .string) { formatSig with eff := Eff.single "A" })
    .strict [] [some (.base .string)] none .other [] (single (.base .string) spec) =
    .error ⟨[1, 0], "type is not included in the expected type"⟩ := by rfl

-- 頭を得る式の効果も空でなければならないが、補間される値の効果は残す。
private def printed : Expr := .call (.primName "print" [] [] []) [none] [0]
  (.cons (eInt ⟨1, by decide⟩) .nil)
example : checkExpr formatInput .strict [] [some (.base .string)] none .other []
    (single (.base .string) spec
      (.block (.seq printed (.last (.primName "%Format.String" [] [] []))))) =
    .error ⟨[1], "effect exceeds the allowed effect"⟩ := by rfl
example : got (checkExpr formatInput .strict [] [] none .other []
    (.interpolation [.formatted (.base .string) spec]
      (.cons (.block (.seq printed (.last value))) .nil)
      (.cons (.primName "%Format.String" [] [] []) .nil)))
    (.base .string) (Eff.single "Console.Write") = true := by decide

-- 引数名・七定数型・結果型も固定シグネチャの一部である。
example : [ { formatSig with names := ["v", "kind", "align", "sign", "alternate", "zero", "width", "precision"] },
    { formatSig with params := [.base .string, .base .boolean, intTy, intTy,
        .base .boolean, .base .boolean, intTy, intTy] },
    { formatSig with ret := intTy } ].all (fun s =>
      match checkExpr (typedInput (.base .string) s) .strict [] [some (.base .string)]
          none .other [] (single (.base .string) spec) with
      | .error ⟨[1, 0], "type is not included in the expected type"⟩ => true
      | _ => false) = true := by decide

-- 式と頭は各一つ必要で、余分なものも受理しない。
example : [(.nil, .cons (.primName "%Format.String" [] [] []) .nil),
    (.cons value (.cons value .nil), .cons (.primName "%Format.String" [] [] []) .nil)].all
    (fun (es, fs) => match checkExpr formatInput .strict [] [] none .other []
        (.interpolation [.formatted (.base .string) spec] es fs) with
      | .error ⟨[0], "argument count mismatch"⟩ => true
      | _ => false) = true := by decide
example : [Exprs.nil, .cons (.primName "%Format.String" [] [] [])
    (.cons (.primName "%Format.String" [] [] []) .nil)].all (fun fs =>
      match checkExpr formatInput .strict [] [] none .other []
          (.interpolation [.formatted (.base .string) spec] (.cons value .nil) fs) with
      | .error ⟨[1], "argument count mismatch"⟩ => true
      | _ => false) = true := by decide

-- 書式付きと書式なしを混ぜても、連結には純粋なString加算を要求する。
private def mixed : Expr := .interpolation
  [.text "[", .formatted (.base .string) spec, .converted intTy, .stringExpr]
  (.cons value (.cons (eInt ⟨7, by decide⟩) (.cons value .nil)))
  (.cons (.primName "%Format.String" [] [] []) (.cons (.primName "toString" [] [] []) .nil))
example : got (checkExpr formatInput .strict [] [] none .other [] mixed) (.base .string) =
    true := by decide
example : checkExpr { formatInput with opPrim := fun _ _ => none }
    .strict [] [] none .other [] mixed =
    .error ⟨[], "interpolation string addition is invalid"⟩ := by rfl

end FormattedInterpolation

-- 実名を保持したクラス・上位辞書・実装と、全プログラムの検査。
private def methodSig : MethSig :=
  { tparams := [], neffs := 0, names := ["left", "right"], params := [intTy, intTy],
    ret := intTy, eff := emptyEff }
private def methodBody : Block := .last (.returnE intTy (.local 1))
private def mainDef : Def :=
  { tparams := [], neffs := 0, names := [], params := [], ret := unitTy,
    eff := emptyEff, body := .last .unit }
private def materials : CheckTables.Materials :=
  { defs := [("main", mainDef)], conFields := [], accessors := [], data := [], ops := [], effects := [],
    classes := [("Choose", ⟨["Base"], [("choose", methodSig)]⟩), ("Base", ⟨[], []⟩)],
    impls := [("ChooseInt", ⟨⟨[], [], "Choose", intTy⟩, [("Base", .impl "BaseInt" [] [])],
      [("choose", ⟨["left", "right"], methodBody⟩)]⟩),
      ("BaseInt", ⟨⟨[], [], "Base", intTy⟩, [], []⟩)],
    trustedFuns := [], trustedImpls := [] }
private def builtinMaterial : CheckTables.BuiltinMaterial := ⟨[], [], "get", "set"⟩
private def selectOp : Operator → Ty → Option PrimName := fun _ _ => none
private def programInput : Input :=
  materials.input (CheckTables.builtins [] [] builtinMaterial) (satB [])
    (CheckTables.admitsDec [] []) (CheckTables.makeOpPrim selectOp) []

example : CheckTables.checkProgram programInput materials materials.names = .ok () := by rfl
example : (checkDict programInput [] [] [] (.super (.impl "ChooseInt" [] []) "Base")).map
    (fun t => tyEq [] t (.dict "Base" intTy)) = .ok true := by rfl
example : (checkExpr programInput .strict [] [] none .other []
    (.call (.methName (.impl "ChooseInt" [] []) "choose" [] [] [] ["left", "right"] [intTy, intTy])
      [some "right", some "left"] [1, 0] (.cons (eInt ⟨2, by decide⟩) (.cons (eInt ⟨1, by decide⟩) .nil)))).map
    (fun (t, ε) => tyEq [] t intTy && effEq [] ε emptyEff) = .ok true := by rfl

-- 全実装の実名の保証は、検査と有限の一覧の成功から得る。
example : ∀ n id, CheckTables.lookup (materials.impls.map fun (n,i) => (n,i.input)) n = some id →
    id.ContractsMatch materials.declarations := by
  exact CheckTables.checkProgram_contracts (by decide)
    (show CheckTables.checkProgram programInput materials materials.names = .ok () from rfl)

-- die を持つ全プログラムも実際の実装辞書を検査する。実装メソッドの実名は緩めない。
private def dieMainBody : Block :=
  .lastDiscard (.tryResultDie intTy "Ok" "Err" (.impl "FailureShow" [] []) "meth:9" "prim:8"
    (.conCall "Err" [intTy, intTy] (.cons (eInt ⟨1, by decide⟩) .nil))
    (some (.literal (.string "message"))))
private def dieMaterials (badNames : Bool := false) : CheckTables.Materials :=
  { materials with
    defs := [("main", { mainDef with eff := Eff.single "Process.Exit", body := dieMainBody })],
    data := [⟨"Result", 2, [("Ok", ⟨"Result", 2, [.tvar 0]⟩),
      ("Err", ⟨"Result", 2, [.tvar 1]⟩)]⟩],
    classes := materials.classes ++ [("class:7", ⟨[], [("meth:9", showSig)]⟩)],
    impls := materials.impls ++ [("FailureShow", ⟨⟨[], [], "class:7", intTy⟩, [],
      [("meth:9", ⟨[if badNames then "other" else "x"],
        .last (.returnE unitTy (.literal (.string "failure")))⟩)]⟩)] }
private def dieRaw : List (PrimName × CheckTables.PrimMaterial) :=
  [("prim:8", ⟨[{}], ["code"], 0, [intTy], .tvar 0, Eff.single "Process.Exit", .exit,
    some "Process.Exit"⟩)]
private def dieBuiltinMaterial : CheckTables.BuiltinMaterial :=
  { builtinMaterial with effects := [("Process.Exit", ["prim:8"])] }
private def dieProgramInput (badNames : Bool := false) : Input :=
  let entries := CheckTables.primEntries [] dieRaw
  (dieMaterials badNames).input (CheckTables.builtins [] entries dieBuiltinMaterial) (satB [])
    (CheckTables.admitsDec [] entries) (CheckTables.makeOpPrim selectOp) dieAtoms

example : CheckTables.checkProgram (dieProgramInput) (dieMaterials) (dieMaterials).names =
    .ok () := by rfl
example : checkDef (dieProgramInput) [] { mainDef with body := dieMainBody } =
    .error ⟨[0], "effect exceeds the allowed effect"⟩ := by rfl
example : CheckTables.checkProgram (dieProgramInput true) (dieMaterials true) (dieMaterials true).names =
    .error ⟨[1, 2, 0, 1], "implementation method parameter names mismatch"⟩ := by rfl
example : ∀ n id,
    CheckTables.lookup ((dieMaterials).impls.map fun (n,i) => (n,i.input)) n = some id →
      id.ContractsMatch (dieMaterials).declarations := by
  exact CheckTables.checkProgram_contracts (by decide)
    (show CheckTables.checkProgram (dieProgramInput) (dieMaterials) (dieMaterials).names = .ok () from rfl)

-- 同じ Point の作者と外部の本体を、一つのプログラムで別々の指定から検査する。
private def pointDef (catchAll : Bool) : Def :=
  { mainDef with
    names := ["point"], params := [.data "Point" []],
    body := .lastDiscard (pointMatch catchAll) }
private def pointMaterials (external functionCatch methodCatch : Bool) : CheckTables.Materials :=
  { materials with
    functionViews := fun f d => external && f == "external" && d == "Point",
    methodViews := fun i m d => external && i == "PointMethods" && m == "external" && d == "Point",
    defs := [("author", pointDef false), ("external", pointDef functionCatch)],
    conFields := [("Point", ["x", "y"])],
    data := [⟨"Point", 0, [("Point", ⟨"Point", 0, [intTy, intTy]⟩)]⟩],
    classes := [("Inspect", ⟨[], [("author", pointSig), ("external", pointSig)]⟩)],
    impls := [("PointMethods", ⟨⟨[], [], "Inspect", .data "Point" []⟩, [],
      [("author", ⟨["point"], (pointDef false).body⟩),
       ("external", ⟨["point"], (pointDef methodCatch).body⟩)]⟩)] }
where
  pointSig : MethSig :=
    { tparams := [], neffs := 0, names := ["point"], params := [.data "Point" []],
      ret := unitTy, eff := emptyEff }

private def checkPointProgram (external functionCatch methodCatch : Bool) : Result Unit :=
  let m := pointMaterials external functionCatch methodCatch
  CheckTables.checkProgram
    (m.input (CheckTables.builtins [] [] builtinMaterial) (satB [])
      (CheckTables.admitsDec [] []) (CheckTables.makeOpPrim selectOp) []) m m.names

example : [checkPointProgram false false false, checkPointProgram true true true,
    checkPointProgram true false true, checkPointProgram true true false] =
    [.ok (), .ok (), .error ⟨[0, 1, 0, 0], "match is not exhaustive"⟩,
      .error ⟨[1, 0, 0, 1, 0], "match is not exhaustive"⟩] := by rfl

-- 一般のFailを持つ型も、使わない入力を含めて一律には拒否しない。
private def nestedFailTy : Ty :=
  .list (.fn [] [] unitTy (.mk (fun _ => false) [intTy]))
private def nestedLegacyTy : Ty := .list (.fn [] [] unitTy Eff.empty)

example : run .unit [some nestedFailTy] =
    .ok (unitTy, emptyEff) := rfl
example : run .unit [some nestedLegacyTy] = .ok (unitTy, emptyEff) := rfl
example : run (.returnE nestedFailTy .unit) [] (some unitTy) .tail =
    .ok (unitTy, emptyEff) := rfl
example : checkEach input .strict [] [] none [] .nil nestedFailTy =
    .ok emptyEff := rfl

-- 未参照の有限の宣言も、一般のFailを理由に拒否しない。
example :
    let m : CheckTables.Materials := { pointMaterials false false false with
      trustedFuns := [("unused", {
        tparams := [], neffs := 0, names := [], params := [], ret := nestedFailTy, eff := Eff.empty })] }
    CheckTables.checkProgram
      (m.input (CheckTables.builtins [] [] builtinMaterial) (satB [])
        (CheckTables.admitsDec [] []) (CheckTables.makeOpPrim selectOp) []) m m.names =
      .ok () := rfl

-- 入力だけでなく、結果の型と実際に呼び出した潜在効果も一般のFailを保つ。
private def intFail : Eff := .mk (fun _ => false) [intTy]
private def failFn : Ty := .fn [] [] unitTy intFail
example : run (.local 0) [some nestedFailTy] = .ok (nestedFailTy, emptyEff) := rfl
example : run (.call (.local 0) [] [] .nil) [some failFn] = .ok (unitTy, intFail) := rfl

-- 同じ正規形の型を受理し、重複したFailを持つ注釈は書き換えずに拒否する。
example : checkEach input .strict [] [some failFn] none [] (.cons (.local 0) .nil) failFn =
    .ok emptyEff := rfl
example : checkEach input .strict [] [some failFn] none [] (.cons (.local 0) .nil)
    (.fn [] [] unitTy (.mk (fun _ => false) [intTy, intTy])) =
    .error ⟨[0], "type is not included in the expected type"⟩ := rfl

-- 節の内側のFail[α₁]を外側のFail[α₀]へ戻し、両モードで同じ包含を検査する。
private def polyClauseInput : Input :=
  { input with D := { emptyDecls with ops := fun _ => some {
      eff := "A", tparams := [{}], names := [], params := [], ret := unitTy } } }
private def outerFail : Eff := .mk (fun _ => false) [.tvar 0]
private def polyClause : Clauses :=
  .cons (.user "A.poly") 0 1 (.last (.call (.local 1) [] [] .nil)) .nil
example (mode : ResumeMode) :
    checkClauses polyClauseInput mode [{}] [some (.fn [] [] unitTy outerFail)] none [] Eff.empty
      polyClause unitTy outerFail = .ok outerFail := by
  cases mode <;> apply congrArg Except.ok
  all_goals apply Eff.ext_test
  all_goals first | (intro a; cases a <;> rfl) | rfl


-- 宣言から本体へ渡す Q と、通常の行多相の区別を公開入口で検査する。
private def noFailRow : Eff := .mk (· == .rho 0) []
private def explicitFailureRow : Eff := .mk (· == .rho 0) [intTy]
private def failureString : Eff := .mk (fun _ => false) [.base .string]
private def noFailSignature (marked : Bool) : FunDecl :=
  { tparams := [], neffs := 1, names := ["action"],
    params := [.fn [] [] unitTy (if marked then explicitFailureRow else noFailRow)],
    ret := unitTy, eff := Eff.empty }
private def noFailInput (marked : Bool) : Input :=
  { input { emptyDecls with funs := fun f => if f == "accept" then some (noFailSignature marked) else none }
    with atoms := [Atom.rho 0] }
private def noFailCaller (marked : Bool) : Def :=
  { toFunDecl := noFailSignature marked, body := .lastDiscard (.funName "accept" [] [noFailRow]) }

/-- 行の印は呼び出しの検査に渡る。通常の行は Fail を具体化できる。 -/
example :
    [(checkExpr (noFailInput true) .strict [] [] none .other []
        (.funName "accept" [] [failureString])).isOk,
     (checkExpr (noFailInput false) .strict [] [] none .other []
        (.funName "accept" [] [failureString])).isOk,
     (checkDef (noFailInput true) [] (noFailCaller true)).isOk,
     (checkExpr ({ noFailInput true with noFailRows := [true] }) .strict [] [] none .other []
        (.funName "accept" [] [noFailRow])).isOk] =
      [false, true, true, false] := by rfl

/-- 署名から得られない行の印を、本体から追加して受理しない。 -/
example : checkDef (noFailInput true) [] (noFailCaller false) =
    .error ⟨[0, 0], "function instantiation violates scope or NoFail"⟩ := by rfl

namespace CharacterCoverage

private def charTy : Ty := .base .character
private def range (lo hi : Nat) : Pattern :=
  .range (.character (Char.ofNat lo)) (.character (Char.ofNat hi))
private def full : Pattern := range 0 0x10FFFF
private def rows (ps : List Pattern) : Arms :=
  match ps with
  | [] => .nil
  | p :: ps => .single p (.last (eInt ⟨1, by decide⟩)) (rows ps)

/-- 公開checkerのmatchとbind/shadowが、文字全域の同じ判定を使う。 -/
example : ([ [full], [range 0 0xD7FF, range 0xE000 0x10FFFF],
    [range 0 96, .character 'a', range 98 0x10FFFF],
    [range 0 96, range 98 0x10FFFF] ] : List (List Pattern)).map
    (fun ps => (run (.matchE intTy (.local 0) (rows ps)) [some charTy]).map
      (fun r => got (.ok r) intTy)) =
    [.ok true, .ok true, .ok true, .error ⟨[], "match is not exhaustive"⟩] := by rfl

example : ([BindKind.bind, .shadow] : List BindKind).map (fun kind =>
    [full, range 1 0x10FFFF].map (fun p =>
      [Block.lastPat kind p charTy (.local 0),
       .bindPat kind p charTy (.local 0) (.lastDiscard (.local 0))].map (fun b =>
        (checkBlock (input) .strict [] [some charTy] none .other [] b).map
          (fun r => got (.ok r) unitTy)))) =
    [[[.ok true, .ok true], [.error ⟨[], "binding pattern is not exhaustive"⟩,
       .error ⟨[], "binding pattern is not exhaustive"⟩]],
     [[.ok true, .ok true], [.error ⟨[], "binding pattern is not exhaustive"⟩,
       .error ⟨[], "binding pattern is not exhaustive"⟩]]] := by rfl

/-- ガードだけでは網羅せず、後のガードなし全域で網羅する。 -/
example : ([Arms.nil, rows [full]] : List Arms).map (fun rest =>
    (run (.matchE intTy (.local 0) (.cons [⟨full, []⟩] (some eTrue)
      (.last (eInt ⟨1, by decide⟩)) rest)) [some charTy]).map (fun r => got (.ok r) intTy)) =
    [.error ⟨[], "match is not exhaustive"⟩, .ok true] := by rfl

private def recordDecls : Declarations :=
  { emptyDecls with
    cons := fun c => if c == "Sample" then some ⟨"Sample", 0, [charTy, .base .boolean]⟩ else none,
    conFields := fun c => if c == "Sample" then some ["letter", "flag"] else none }
private def recordInput (view : CoverageView) : Input :=
  { input (recordDecls.withView view) with ctors := fun d => if d == "Sample" then ["Sample"] else [] }
private def rec (p : Pattern) (b : Bool) : Pattern := .record "Sample" 2 [0, 1] [p, .boolean b]

/-- レコードの二欄の相関と、文字の全域を覆っても残る将来の構成子。 -/
example : ([closedView, fun d => d == "Sample"] : List CoverageView).map (fun view =>
    [[rec full true, rec full false],
     [rec (range 0 96) true, rec (range 97 0x10FFFF) false]].map (fun ps =>
      (checkExpr (recordInput view) .strict [] [some (.data "Sample" [])] none .other []
        (.matchE intTy (.local 0) (rows ps))).map (fun r => got (.ok r) intTy))) =
    [[.ok true, .error ⟨[], "match is not exhaustive"⟩],
     [.error ⟨[], "match is not exhaustive"⟩, .error ⟨[], "match is not exhaustive"⟩]] := by rfl

end CharacterCoverage


-- block は末尾位置と戻り先を保つ。ラムダ末尾の block 内の return も必ず抜ける。
private def blockReturn : Expr := .block (.last (.returnE unitTy (eInt ⟨7, by decide⟩)))
example : [Position.tail, .other].map (fun pos => run blockReturn [] (some intTy) pos) =
    [.ok (intTy, Eff.empty), .ok (unitTy, Eff.empty)] := by rfl
example : run (.lam [] [] intTy Eff.empty (.last blockReturn)) =
    .ok (.fn [] [] intTy Eff.empty, Eff.empty) := by rfl
example : [Expr.block .empty, .block (.lastBind .bind intTy (eInt ⟨1, by decide⟩)),
    .block (.last .unit)].map run = List.replicate 3 (.ok (unitTy, Eff.empty)) := by rfl
-- lazy とガードの R = none を block 内にも伝える。
example : run (.lazyE (.last blockReturn)) =
    .error ⟨[0, 0, 0, 0], "return is outside a function"⟩ := by rfl
example : run (.matchE intTy (eInt ⟨1, by decide⟩)
    (.cons [⟨.wild, []⟩] (some (.block (.last (.returnE unitTy eTrue))))
      (.last (eInt ⟨1, by decide⟩)) .nil)) =
    .error ⟨[1, 0, 0, 0], "return is outside a function"⟩ := by rfl

end Benitoite.Surface.Check.Examples
