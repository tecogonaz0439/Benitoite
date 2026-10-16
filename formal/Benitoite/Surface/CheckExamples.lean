import Benitoite.Surface.CheckProgramSound
import Benitoite.Release.Examples

/-! 検査全体の公開入口と、実名付きの材料から型付けへの接続の評価例。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check.Examples
open Benitoite.Release Benitoite.Surface.CheckTools

private def intTy : Ty := .base .integer
private def unitTy : Ty := .base .unit
private def eInt (n : Nat) : Expr := .literal (.integer n)
private def eTrue : Expr := .literal (.boolean true)
private def eFalse : Expr := .literal (.boolean false)
private def atoms : List Atom :=
  [.name "State", .name "Console.Write", .name "A", .name "B"]
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
example : got (run (.ifOnly eFalse (.lastDiscard (eInt 1)))) unitTy = true := by decide

-- return の末尾と非末尾、および遅延境界での遮蔽。
example : got (run (.returnE unitTy (eInt 1)) [] (some intTy) .tail) intTy = true := by decide
example : got (run (.returnE unitTy (eInt 1)) [] (some intTy)) unitTy = true := by decide
example : run (.returnE unitTy (eInt 1)) = .error ⟨[], "return is outside a function"⟩ := by rfl
example : got (run (.lazyE (.last (eInt 1)))) (.lazy intTy) = true := by decide
example : run (.lazyE (.last (.returnE intTy (eInt 1)))) [] (some intTy) =
    .error ⟨[0, 0], "return is outside a function"⟩ := by rfl

-- 一覧・パターン・ガードを通した型と、失敗する要素のソース位置。
example : got (run (.list intTy (.cons (eInt 1) (.cons (eInt 2) .nil)))) (.list intTy) = true := by decide
example : run (.list intTy (.cons (eInt 1) (.cons eFalse .nil))) =
    .error ⟨[0, 1], "type is not included in the expected type"⟩ := by rfl
example : got (run (.matchE intTy eTrue
    (.cons [⟨.wild, []⟩] (some eTrue) (.last (eInt 1))
      (.single .wild (.last (eInt 2)) .nil)))) intTy = true := by decide
example : run (.matchE intTy eTrue (.single (.boolean true) (.last (eInt 1)) .nil)) =
    .error ⟨[], "match is not exhaustive"⟩ := by rfl

-- 位置を入れ替えたレコードの構築・更新。独立した引数の誤りの位置も保つ。
private def pointDecls : Declarations :=
  { emptyDecls with
    cons := fun c => if c == "Point" then some ⟨"Point", 0, [intTy, intTy]⟩ else none,
    conFields := fun c => if c == "Point" then some ["x", "y"] else none }
private def pointInput : Input :=
  { input pointDecls with ctors := fun n => if n == "Point" then ["Point"] else [] }
example : got (checkExpr pointInput .strict [] [] none .other []
    (.record "Point" [] [1, 0] (.cons (eInt 3) (.cons (eInt 2) .nil)))) (.data "Point" []) = true := by decide
example : got (checkExpr pointInput .strict [] [some (.data "Point" [])] none .other []
    (.recordUpdate "Point" [] 2 [0] (.local 0) (.cons (eInt 7) .nil))) (.data "Point" []) = true := by decide
example : checkExpr pointInput .strict [] [] none .other []
    (.record "Point" [] [1, 0] (.cons (eInt 3) (.cons eFalse .nil))) =
    .error ⟨[0, 1], "type is not included in the expected type"⟩ := by rfl

-- 同じ宣言でもソース照合には外部の view が作用し、内部の更新には作用しない。
private def pointViewInput (view : CoverageView) : Input :=
  { pointInput with D := pointDecls.withView view }
private def pointPat : Pattern := .record "Point" 2 [0, 1] [.var, .var]
private def pointMatch (catchAll : Bool) : Expr :=
  .matchE intTy (.local 0) (.single pointPat (.last (eInt 1))
    (if catchAll then .single .wild (.last (eInt 2)) .nil else .nil))

example : ([closedView, fun d => d == "Point"] : List CoverageView).map (fun view =>
    [ (checkExpr (pointViewInput view) .strict [] [some (.data "Point" [])]
        none .other [] (pointMatch false)).map (fun r => got (.ok r) intTy),
      (checkExpr (pointViewInput view) .strict [] [some (.data "Point" [])]
        none .other [] (pointMatch true)).map (fun r => got (.ok r) intTy),
      (checkExpr (pointViewInput view) .strict [] [some (.data "Point" [])]
        none .other [] (.recordUpdate "Point" [] 2 [0] (.local 0) (.cons (eInt 7) .nil))).map
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
        (.matchE intTy (.local 0) (.single (.con none "Some" [.var]) (.last (eInt 1))
          (.single (.con none "None" []) (.last (eInt 2)) .nil)))).map
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
private def errorTy : Ty := .opaque "Failure"
private def resultTy : Ty := .data "Result" [intTy, errorTy]
private def optionTy : Ty := .data "Option" [intTy]
private def dieAtoms : List Atom := [.name "Process.Exit", .name "A"]
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
example : dieRun { dieInput with atoms := [.name "A"] } optionEnv (optionDie) =
    .error ⟨[], "Process.Exit effect is outside atoms"⟩ := by rfl

-- 純粋性の失敗は説明自身の位置。return と resume は説明の遮蔽した境界で拒否する。
private def impureMessage : Expr := .call (.local 1) [] [] .nil
example : dieRun (dieInput)
    (optionEnv ++ [some (.fn [] [] strTy (Eff.single "A"))])
    (optionDie (some impureMessage)) =
    .error ⟨[1], "effect exceeds the allowed effect"⟩ := by rfl
example : dieRun (dieInput) optionEnv (optionDie (some (eInt 0))) =
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
  .handleE (.last (.call (.opName "A.id" []) [some "value"] [0] (.cons (eInt 7) .nil)))
    (.cons (.user "A.id") 1 0 (.last (.resume 0 (.local 1))) .nil)
example : got (checkExpr opInput .strict [] [] none .other [] handled) intTy = true := by decide
example : checkExpr opInput .strict [] [] none .other []
    (.handleE (.last (eInt 1)) (.cons (.user "A.id") 0 0 (.last (eInt 2)) .nil)) =
    .error ⟨[1], "handler operation arity mismatch"⟩ := by rfl

-- リソースの State と、純粋な補間・直接の連結関数の契約。
example : got (checkExpr (input) .strict [] [some (.opaque "File")] none .other []
    (.withE "File" (.local 0) (.last (eInt 1)))) intTy (Eff.single "State") = true := by decide
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
    (.listSpread intTy (.primName "concat" [] []) (.cons (eInt 1) .nil)
      (.list intTy (.cons (eInt 2) .nil)) (.cons (eInt 3) .nil))) (.list intTy) = true := by decide
example : got (checkExpr collectionInput .strict [] [] none .other []
    (.interpolation [.text "n=", .converted intTy] (.cons (eInt 7) .nil)
      (.cons (.primName "toString" [] []) .nil))) (.base .string) = true := by decide

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
      [some "right", some "left"] [1, 0] (.cons (eInt 2) (.cons (eInt 1) .nil)))).map
    (fun (t, ε) => tyEq [] t intTy && effEq [] ε emptyEff) = .ok true := by rfl

-- 全実装の実名の保証は、検査と有限の一覧の成功から得る。
example : ∀ n id, CheckTables.lookup (materials.impls.map fun (n,i) => (n,i.input)) n = some id →
    id.ContractsMatch materials.declarations := by
  exact CheckTables.checkProgram_contracts (by decide)
    (show CheckTables.checkProgram programInput materials materials.names = .ok () from rfl)

-- die を持つ全プログラムも実際の実装辞書を検査する。実装メソッドの実名は緩めない。
private def dieMainBody : Block :=
  .lastDiscard (.tryResultDie intTy "Ok" "Err" (.impl "FailureShow" [] []) "meth:9" "prim:8"
    (.conCall "Err" [intTy, intTy] (.cons (eInt 1) .nil))
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

end Benitoite.Surface.Check.Examples
