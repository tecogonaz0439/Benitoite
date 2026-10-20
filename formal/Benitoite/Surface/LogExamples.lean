import Benitoite.Surface.CheckProgramSound

/-!
# Logの通常の操作とハンドラの適用例

有限の標準宣言と組み込み表を既存の公開checkerへ渡す。位置は展開済みの通常レコードであり、
新しい効果消去規則や仮定を置かない（設計書 01-12「Logの通常宣言とハンドラの具体例」）。
-/
namespace Benitoite.Surface.LogExamples
open Benitoite.Release Check CheckTools CheckTables

private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string
private def unitTy : Ty := .base .unit
private def boolTy : Ty := .base .boolean
private def levelTy : Ty := .data "Log.Level" []
private def valueTy : Ty := .data "Log.Value" []
private def attributeTy : Ty := .data "Log.Attribute" []
private def locationTy : Ty := .data "SourceLocation.Location" []
private def recordTy : Ty := .data "Log.Record" []
private def atoms : List Atom := [.name "Log", .name "Console.Write"]

private def enumData (name : String) (cs : List String) : DataMaterial :=
  ⟨name, 0, cs.map fun c => (c, ⟨name, 0, []⟩)⟩
private def recordData (name : String) (ps : List Ty) : DataMaterial :=
  ⟨name, 0, [(name, ⟨name, 0, ps⟩)]⟩

/-- 通常のdata/record宣言。名前は解決済みであり、hereの原始操作はない。 -/
def materials : Materials :=
  { defs := [], classes := [], impls := [], trustedFuns := [], trustedImpls := [],
    ops := [], effects := [], accessors := [],
    conFields := [("Log.Attribute", ["key", "value"]),
      ("SourceLocation.Location", ["file", "line", "column"]),
      ("Log.Record", ["level", "message", "attributes", "location"])],
    data := [enumData "Log.Level" ["Log.Debug", "Log.Info", "Log.Warn", "Log.Error"],
      ⟨"Log.Value", 0,
        [("Log.Text", ⟨"Log.Value", 0, [strTy]⟩),
         ("Log.Boolean", ⟨"Log.Value", 0, [boolTy]⟩),
         ("Log.Integer", ⟨"Log.Value", 0, [intTy]⟩),
         ("Log.UnsignedInteger", ⟨"Log.Value", 0, [.base .unsignedInteger64]⟩),
         ("Log.Float", ⟨"Log.Value", 0, [.base .float]⟩)]⟩,
      recordData "Log.Attribute" [strTy, valueTy],
      recordData "SourceLocation.Location" [strTy, intTy, intTy],
      recordData "Log.Record" [levelTy, strTy, .list attributeTy, locationTy]] }

private def operation (eff : String) (ns : List String) (ps : List Ty) (ret : Ty) :
    PrimMaterial :=
  ⟨[], ns, 0, ps, ret, Eff.single eff, .io, some eff⟩

/-- Logは既存の名前付き組み込み効果として、二つの操作を持つ。 -/
def raw : List (PrimName × PrimMaterial) :=
  [("Log.emit", operation "Log" ["record"] [recordTy] unitTy),
   ("Log.enabled", operation "Log" ["level"] [levelTy] boolTy),
   ("Console.writeError", operation "Console.Write" ["text"] [strTy] unitTy)]

def builtinMaterial : BuiltinMaterial :=
  ⟨[("Log", ["Log.emit", "Log.enabled"]), ("Console.Write", ["Console.writeError"])],
    [], "Reference.get", "Reference.set"⟩
private def entries : List PrimEntry := primEntries [] raw
private def input : Input := materials.input (builtins [] entries builtinMaterial)
  (satB []) (admitsDec [] entries) (fun _ _ => none) atoms

private def one (e : Expr) : Exprs := .cons e .nil
private def text (s : String) : Expr := .literal (.string s)
private def integer (n : Integer64Literal) : Expr := .literal (.integer n)
private def info : Expr := .nullCon "Log.Info" []

/-- 呼び出し側で展開した位置を、通常のレコードのフィールドとして渡す。 -/
def location : Expr := .record "SourceLocation.Location" [] [0, 1, 2]
  (.cons (text "example.bnt") (.cons (integer ⟨7, by decide⟩) (one (integer ⟨3, by decide⟩))))
private def logAttribute : Expr := .record "Log.Attribute" [] [0, 1]
  (.cons (text "count") (one (.conCall "Log.Integer" [] (one (integer ⟨3, by decide⟩)))))
def record : Expr := .record "Log.Record" [] [0, 1, 2, 3]
  (.cons info (.cons (text "done") (.cons (.list attributeTy (one logAttribute)) (one location))))

private def call1 (name arg : String) (value : Expr) : Expr :=
  .call (.primName name [] []) [some arg] [0] (one value)
def emit : Expr := call1 "Log.emit" "record" record
def enabled : Expr := call1 "Log.enabled" "level" info
private def send (value : Expr) : Expr := call1 "Log.emit" "record" value
private def query (value : Expr) : Expr := call1 "Log.enabled" "level" value
private def write : Expr := call1 "Console.writeError" "text" (text "done")

private def clauses (forward output : Bool) : Clauses :=
  .cons (.prim "Log.emit") 1 0
    (if forward then .seq (send (.local 1)) (.last (.resume 0 .unit))
     else if output then .seq write (.last (.resume 0 .unit))
     else .last (.resume 0 .unit))
    (.cons (.prim "Log.enabled") 1 0
      (if forward then .last (.resume 0 (query (.local 1)))
       else .last (.resume 0 (.literal (.boolean false)))) .nil)

def handled (body : Expr) (forward : Bool := false) (output : Bool := false) : Expr :=
  .handleE (.last body) (clauses forward output)

private def result (e : Expr) (t : Ty) (eff : Eff) : Result Bool :=
  (checkExpr input .strict [] [] none .other [] e).map fun (a, ε) =>
    tyEq atoms a t && effEq atoms ε eff

theorem emit_checked : result emit unitTy (Eff.single "Log") = .ok true := by rfl
theorem enabled_checked : result enabled boolTy (Eff.single "Log") = .ok true := by rfl
theorem handled_checked :
    result (handled emit) unitTy Eff.empty = .ok true ∧
    result (handled enabled) boolTy Eff.empty = .ok true := by constructor <;> rfl
theorem forwarded_checked :
    result (handled emit true) unitTy (Eff.single "Log") = .ok true ∧
    result (handled enabled true) boolTy (Eff.single "Log") = .ok true := by
  constructor <;> rfl
theorem console_remains_checked :
    result (handled emit false true) unitTy (Eff.single "Console.Write") = .ok true := by rfl

/-- 不完全な節の列だけではLogを消せない。 -/
theorem incomplete_handler_retains_log :
    result (.handleE (.last emit)
      (.cons (.prim "Log.emit") 1 0 (.last (.resume 0 .unit)) .nil))
      unitTy (Eff.single "Log") = .ok true := by rfl

private def entryDef (e : Expr) (ret : Ty) (eff : Eff) : Def :=
  { tparams := [], neffs := 0, names := [], params := [], ret, eff,
    body := .last (.returnE unitTy e) }

/-- 同じ宣言表で、純粋・送り直し・Console出力の通常関数をまとめて検査する。 -/
def programMaterials : Materials :=
  { materials with defs :=
    [("emit", entryDef emit unitTy (Eff.single "Log")),
     ("enabled", entryDef enabled boolTy (Eff.single "Log")),
     ("silent", entryDef (handled emit) unitTy Eff.empty),
     ("forward", entryDef (handled emit true) unitTy (Eff.single "Log")),
     ("console", entryDef (handled emit false true) unitTy (Eff.single "Console.Write"))] }

set_option maxHeartbeats 800000 in
theorem program_checked :
    checkProgram { input with D := programMaterials.declarations }
      programMaterials programMaterials.names = .ok () := by rfl

/-- 操作を処理した後のConsole.Writeを、純粋な関数の宣言で隠せない。 -/
theorem console_pure_rejected :
    checkDef input [] (entryDef (handled emit false true) unitTy Eff.empty) =
      .error ⟨[0], "effect exceeds the allowed effect"⟩ := by rfl

end Benitoite.Surface.LogExamples
