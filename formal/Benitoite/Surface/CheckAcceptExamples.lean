import Benitoite.Surface.CheckAccept
import Benitoite.Surface.ScopeAcceptExamples

/-!
# 型検査器の入口への受理の組み込みと、被覆による検査器の受理の小例（L50.2）

`Surface.CheckAccept` の入口と全体の受理の述語、`Check.acceptEffCover`（効果の上限の被覆による受理）を、小さな
プログラムで確かめる（設計書 07-04「必須の判定の受理の組み込み」）。文字列の解析器と表はこの例のためのもので
ある（`ScopeLowerExamples.boundary`）。
-/

namespace Benitoite.Surface.CheckAcceptExamples

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Benitoite.Surface.CheckAccept
open Benitoite.Surface.CheckTables
open Benitoite.Surface.ScopeLowerExamples (dataTree boundary wide unitTy str)
open Benitoite.Surface.ScopeAcceptExamples (dataA checkP writeAt pathIn)
open Scope.Domain (Range)

/-- 例の受理の入力。規則は `ScopeLowerExamples.boundary` の六項目（`/data/**` だけを解析する）。 -/
def acceptInput (L : Limits := wide) : AcceptInput := ⟨"Ok", boundary.rules.lookup, L, fun i m => i ++ "." ++ m⟩

def checkTy (r : Range) : Release.Ty := TargetTable.resultTy (pathIn r) TargetTable.scopeErrorTy

/-- `let r = Scope.checkPathIn(pattern: pat, path: raw); ()`（呼び出しは番号 0）。 -/
def bodyCheck (pat : Expr) (rs : List Range) : Block := .bind .bind (checkTy (rs.headD .top)) (checkP pat rs) (.last .unit)

def defOf (body : Block) (eff : Eff := Eff.empty) (params : List Release.Ty := [.base .string]) (names := ["raw"])
    (ret : Release.Ty := unitTy) : Def :=
  { tparams := [], neffs := 0, names, params, ret, eff, body }

def materials (body : Block) (eff : Eff := Eff.empty) (params : List Release.Ty := [.base .string])
    (names := ["raw"]) (ret : Release.Ty := unitTy) : Materials :=
  { defs := [("main.store", defOf body eff params names ret)], conFields := [], accessors := [], data := [], ops := [],
    effects := [], classes := [], impls := [], trustedFuns := [], trustedImpls := [] }

def reasonOf : Except EntryError Unit → Option (Option (Nat × CoverFailure))
  | .ok () => none
  | .error (.typing _) => some none
  | .error (.cover k f) => some (some (k.surfacePreorder, f))

def atoms : List Atom :=
  [.nameTop "State", .name "File.Write" (.rvar 0), .name "File.Read" (.rvar 0), .name "Http.Connect" (.rvar 0),
    writeAt dataTree, writeAt dataA]

def q : Check.Input := { ScopeAcceptExamples.input with atoms }

def entry (body : Block) (L : Limits := wide) (eff : Eff := Eff.empty) (params : List Release.Ty := [.base .string])
    (names := ["raw"]) (ret : Release.Ty := unitTy) : Option (Option (Nat × CoverFailure)) :=
  let m := materials body eff params names ret
  reasonOf (checkProgramAccepted { q with D := m.declarations } (acceptInput L) m m.names)

/-! ## 出現の解決 -/

-- 組み込みの名前を頭に持つ直接の呼び出し（番号 0）を標準の `Scope.checkPathIn` に解決し、ほかの番号は解決しない。
#guard primResolve (bodyKey "main.store") (bodyCheck (str "/data/**") [dataTree]) ⟨"main.store", 0⟩ ==
  some ⟨.standard, checkPathName⟩
#guard primResolve (bodyKey "main.store") (bodyCheck (str "/data/**") [dataTree]) ⟨"main.store", 1⟩ == none

/-! ## 入口（型付けの検査と受理） -/

-- 規則の添字 `/data/**` を覆う範囲の列は、型付けと受理の両方を通る。
#guard entry (bodyCheck (str "/data/**") [dataTree]) == none
#guard entry (bodyCheck (str "/data/**") [.top]) == none
-- 型付けは通るが、狭い契約 `/data/a/**` は規則の添字を覆わないので、入口は notCovered で拒否する。
#guard entry (bodyCheck (str "/data/**") [dataA]) == some (some (0, .notCovered))
-- 引数の文字列のパターンは由来を認定できず、狭い契約は unknownSource で拒否する。
#guard entry (bodyCheck (.local 0) [dataTree]) == some (some (0, .unknownSource))
#guard entry (bodyCheck (.local 0) [.top]) == none
-- 予算の上限 0 では、狭い契約は budgetExceeded で拒否する。
#guard entry (bodyCheck (.local 0) [dataTree]) (L := ⟨⟨0, 0⟩, ⟨0, 0⟩⟩) == some (some (0, .budgetExceeded))
-- 型付けの誤り（束縛の型の注釈が結果の型と違う）は受理より先に報告する。
#guard entry (.bind .bind unitTy (checkP (str "/data/**") [dataTree]) (.last .unit)) == some none

-- 規則のない受理の入力（旧の像）では、入口は型付けの検査と同じ結果を返す。
example : checkProgramAccepted { q with D := (materials (bodyCheck (str "/data/**") [dataA])).declarations }
    AcceptInput.noRules (materials (bodyCheck (str "/data/**") [dataA]))
    (materials (bodyCheck (str "/data/**") [dataA])).names = .ok () ↔
    checkProgram { q with D := (materials (bodyCheck (str "/data/**") [dataA])).declarations }
      (materials (bodyCheck (str "/data/**") [dataA])) (materials (bodyCheck (str "/data/**") [dataA])).names = .ok () :=
  checkProgramAccepted_noRules (fun _ => rfl)

/-! ## 検査器の効果の上限の被覆による受理 -/

def writeRet : Release.Ty := TargetTable.resultTy unitTy TargetTable.ioErrorTy

/-- `File.writeTextIn[/data/a/**](path: p, text: "x")`。引数 p は `Scope.PathIn[/data/a/**]`。 -/
def writeNarrow : Block :=
  .last (.returnE writeRet (.call (.primName "File.writeTextIn" [] [] [dataA]) [some "path", some "text"] [0, 1]
    (.cons (.local 0) (.cons (str "x") .nil))))

def writeEff (r : Range) : Eff := Eff.ofAtoms (· == writeAt r)

-- 上限 `File.Write[/data/**]` の関数の本体が `/data/a/**` へ書く（被覆だけで包含する）。検査器は受理する。
#guard entry writeNarrow (eff := writeEff dataTree) (params := [pathIn dataA]) (names := ["p"]) (ret := writeRet) == none
-- 上限と同じ原子は受理し、覆わない上限（`/data/a/**` は `/data/**` を覆わない）は拒否する。
#guard entry writeNarrow (eff := writeEff dataA) (params := [pathIn dataA]) (names := ["p"]) (ret := writeRet) == none
#guard (Check.acceptEffCover q [] (writeEff dataA) (writeEff dataTree)).isOk == false
#guard (Check.acceptEffCover q [] (writeEff dataTree) (writeEff dataA)).isOk
-- 構造上の包含で受理する `acceptEff` は、被覆だけの包含を受理しない（handle の保護本体などに使う）。
#guard (Check.acceptEff q [] (writeEff dataTree) (writeEff dataA)).isOk == false
-- Top を覆うのは Top だけである（`/data/**` の上限は Top の原子を覆わない）。
#guard (Check.acceptEffCover { q with atoms := q.atoms ++ [.nameTop "File.Write"] } [] (writeEff dataTree)
  (Eff.single "File.Write")).isOk == false

/-! ## `handle` の保護本体の効果と節の添字（L50.4、RV-L50 中3）

検査器の `handle` の腕は、保護本体の推論した効果から処理しない原子を除いた効果を `handle` の式の効果に含めてから、
保護本体の効果を構造上の包含で調べる（`Check.acceptEff (union ε handled) εbody`）。処理しない原子はそのまま式の効果へ
移るので、この包含はどの本体でも成り立ち、上限との比較は関数の本体の被覆による受理（`acceptEffCover`）で行われる。 -/

/-- `/data/a.txt` だけの範囲。 -/
def aTxt : Range := .path (.exact ["data", "a.txt"])

def qTxt : Check.Input := { q with atoms := q.atoms ++ [writeAt aTxt] }

def materialsOf (ds : List (String × Def)) : Materials :=
  { defs := ds, conFields := [], accessors := [], data := [], ops := [],
    effects := [], classes := [], impls := [], trustedFuns := [], trustedImpls := [] }

def entryTxt (ds : List (String × Def)) : Option (Option (Nat × CoverFailure)) :=
  let m := materialsOf ds
  reasonOf (checkProgramAccepted { qTxt with D := m.declarations } (acceptInput wide) m m.names)

/-- `File.writeTextIn[/data/a.txt](path: <局所変数 i>, text: "x")`。 -/
def writeTxt (i : Nat) : Expr :=
  .call (.primName "File.writeTextIn" [] [] [aTxt]) [some "path", some "text"] [0, 1] (.cons (.local i) (.cons (str "x") .nil))

/-- 上限 `{File.Write["/data/**"]}` の関数。本体は `File.Write` を処理しない `handle`（節なし）の保護本体で `/data/a.txt`
へ書く。 -/
def handleWrite : Def :=
  defOf (.last (.returnE writeRet (.handleE (.last (writeTxt 0)) .nil))) (writeEff dataTree) [pathIn aTxt] ["p"] writeRet

-- 検査器は受理する（RV-L50 中3 が挙げた形）。保護本体の効果 `{File.Write["/data/a.txt"]}` は `handle` の式の効果に移り、
-- 関数の本体の被覆による受理で上限に含まれる。
#guard entryTxt [("main.store", handleWrite)] == none

/-- 節 `File.writeTextIn(path, text, k) => g(p: path)`（path は節の環境の番号 2）。 -/
def writeClause : Clauses :=
  .cons (.prim "File.writeTextIn") 2 0 (.last (.call (.funName "g" [] []) [some "p"] [0] (.cons (.local 2) .nil))) .nil

/-- 上限 `{File.Write["/data/**"]}` の関数。本体は `File.writeTextIn` を処理する `handle` で、保護本体は `/data/a.txt`
へ書き、節は捕えたパスを `g` へ渡す。 -/
def handleClause : Def :=
  defOf (.last (.returnE writeRet (.handleE (.last (writeTxt 0)) writeClause))) (writeEff dataTree) [pathIn aTxt] ["p"]
    writeRet

/-- `g(p: Scope.PathIn[r]) : Result[Unit, IOError] uses File.Write["/data/**"]`（本体は p へ書く）。 -/
def gWith (r : Range) : Def :=
  defOf (.last (.returnE writeRet (.call (.primName "File.writeTextIn" [] [] [r]) [some "path", some "text"] [0, 1]
    (.cons (.local 0) (.cons (str "x") .nil))))) (writeEff dataTree) [pathIn r] ["p"] writeRet

-- 節の添字は保護本体の推論した効果の規則の値 `/data/a.txt` であり、節の環境のパスは `Scope.PathIn["/data/a.txt"]` を持つ。
-- `g` の引数がその型なら受理し、`Scope.PathIn["/data/**"]` なら型の誤りで拒否する。型付けは保護本体の効果を `B_Sub` の
-- 被覆で `{File.Write["/data/**"]}` に広げて添字 `/data/**` を選べるので、この形では検査器が型付けより狭い（RV-L50 中3 の
-- 差の実体）。
#guard entryTxt [("main.store", handleClause), ("g", gWith aTxt)] == none
#guard entryTxt [("main.store", handleClause), ("g", gWith dataTree)] == some none

end Benitoite.Surface.CheckAcceptExamples
