import Benitoite.Surface.CheckAccept

/-!
R20.3b 中1の五例を、Top の列を付けた Surface.Block として ScopeAccept.acceptBody で確かめる。
Rust の通常の入口の検査は tests/scoped_calls.rs の
unannotated_checks_use_top_when_projection_or_join_requires_it にある。

本台本は Rust の parser・名前解決・型推論との全比較ではない。Surface の型注記と局所位置を手で対応させ、
本番の primResolve・tableFor・Boundary.rules・acceptBody を使う。Lean の境界は文字列の解析器を
引数で受けるため、本例の三つのパターンだけを読む有限の解析器を与える。Rust のパターン解析器との一致は
この台本の検査に含めない。型注記は対応するが、Surface.Check の型付けの検査は実行しない。
-/

namespace Benitoite.R20_3b

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Benitoite.Surface.CheckAccept
open Benitoite.Scope.Domain (Range)

def strTy : Ty := .base .string
def unitTy : Ty := .base .unit
def pathTy : Ty := .opaque "Scope.PathIn" (.fixed .top)
def resultTy : Ty := TargetTable.resultTy pathTy TargetTable.scopeErrorTy
def projectTy : Ty := .fn [] [] strTy Eff.empty

def parsers : Parsers where
  pattern
    | "/data/**" => some (.path (.tree ["data"]))
    | "/data/a" => some (.path (.exact ["data", "a"]))
    | "/data/b" => some (.path (.exact ["data", "b"]))
    | _ => none
  target _ := none

def boundary : Boundary where
  ok := "Ok"
  err := "Error"
  pathTys _ := [pathTy, TargetTable.scopeErrorTy]
  requestTys _ := []
  pathFailure := .const .unit
  requestFailure := .const .unit
  parsers := parsers
  hostPattern _ := none
  endpointOf _ := none
  requestBound := requestLitBound (fun _ => none)
  pathText _ := "/data/a"
  requestValueRun _ _ := none

def limits : Limits := ⟨⟨1000, 1000⟩, ⟨10000, 10000⟩⟩
def input : AcceptInput := ⟨"Ok", boundary.rules.lookup, limits, fun i m => i ++ "." ++ m⟩

def str (s : String) : Expr := .literal (.string s)
def checkP (pattern : String) (path : Nat := 0) : Expr :=
  .call (.primName checkPathName [] [] [.top]) [some "pattern", some "path"] [0, 1]
    (.cons (str pattern) (.cons (.local path) .nil))
def project (path : Nat := 0) : Expr :=
  .call (.primName pathValueName [] [] [.top]) [some "path"] [0] (.cons (.local path) .nil)

def matchOk (result : Nat) (body : Block) : Expr :=
  .matchE strTy (.local result)
    (.cons [⟨.con none "Ok" [.var], [0]⟩] none body
      (.cons [⟨.con none "Error" [.var], [0]⟩] none (.last (str "error")) .nil))

-- sample(path: String): checked の束縛後は checked=0、path=1。
-- Ok の腕では value=0、checked=1、path=2 となる。
def checkedBody (success : Block) : Block :=
  .bind .bind resultTy (checkP "/data/**")
    (.last (.returnE strTy (matchOk 0 success)))

def aliasBody : Block := checkedBody
  (.bind .bind pathTy (.local 0) (.last (project 0)))

def rewrapBody : Block := checkedBody
  (.bind .bind resultTy (.conCall "Ok" [pathTy, TargetTable.scopeErrorTy] (.cons (.local 0) .nil))
    (.last (matchOk 0 (.last (project 0)))))

def captureBody : Block := checkedBody
  (.bind .bind projectTy (.lam [] [] strTy Eff.empty (.last (.returnE strTy (project 0))))
    (.last (.call (.local 0) [] [] .nil)))

-- パイプの右辺は空の引数列を持つ呼び出しであり、acceptOccurrence は acceptCall ... [] と読む。
def pipeBody : Block := checkedBody
  (.last (.pipe (.local 0) (.call (.primName pathValueName [] [] [.top]) [] [] .nil)))

-- sample(flag: Boolean, path: String): 最後の引数から path=0、flag=1。
def joinBody : Block :=
  .bind .bind resultTy
    (.ite (.local 1) (.last (checkP "/data/a")) (.last (checkP "/data/b")))
    (.discard (.local 0) (.last .unit))

def accepted (name : String) (nlocals : Nat) (body : Block) : Bool :=
  match acceptBody "Ok" (tableFor input (bodyKey name) body) limits (bodyKey name) (entryScope nlocals) body with
  | .ok () => true
  | .error _ => false

-- 有限の解析器でも三つのパターンを既知と読み、異なる枝の既定値を区別する。
#guard boundary.rules.checkPath.index [.lit "/data/**", .unknown] == [.path (.tree ["data"])]
#guard boundary.rules.checkPath.index [.lit "/data/a", .unknown] == [.path (.exact ["data", "a"])]
#guard boundary.rules.checkPath.index [.lit "/data/b", .unknown] == [.path (.exact ["data", "b"])]

#guard accepted "sample.alias" 1 aliasBody
#guard accepted "sample.rewrap" 1 rewrapBody
#guard accepted "sample.capture" 1 captureBody
#guard accepted "sample.pipe" 1 pipeBody
#guard accepted "sample.join" 2 joinBody

#eval "accepted: alias, rewrap, capture, pipe, join (5/5)"

end Benitoite.R20_3b
