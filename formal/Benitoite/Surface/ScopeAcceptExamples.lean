import Benitoite.Surface.ScopeAccept
import Benitoite.Surface.ScopeLowerExamples
import Benitoite.Surface.Check
import Benitoite.Surface.PrimRange

/-!
# 必須の判定の受理・拒否の理由・範囲付きの組み込みの名前の小例（L40.4）

`Surface.ScopeAccept` の受理の判定と、表層の検査器と型付けが範囲付きの項目を呼ぶ形を、小さな入力で確かめる（設計書
01-12「Scope の必須の判定の受理と拒否の理由」）。出現の解決・文字列の解析器・表はこの例のためのものである。
-/

namespace Benitoite.Surface.ScopeAcceptExamples

open Benitoite.Release
open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept
open Benitoite.Surface.ScopeLowerExamples (dataTree boundary defn at_ wide scope0 unitTy str)
open Scope.Domain (Range)

def reasonOf {α : Type} : Except α Unit → Option α
  | .ok () => none
  | .error e => some e

/-- `/data/a/**`、`/**`、`/database/**`。 -/
def dataA : Range := .path (.tree ["data", "a"])
def rootTree : Range := .path (.tree [])
def database : Range := .path (.tree ["database"])

/-! ## 範囲の受理 -/

-- 既知の `/data/**` を覆う契約は受理し、覆わない狭い契約は notCovered で拒否する。
#guard reasonOf (acceptRange (.known dataTree) dataTree) == none
#guard reasonOf (acceptRange (.known dataTree) rootTree) == none
#guard reasonOf (acceptRange (.known dataA) dataTree) == none
#guard reasonOf (acceptRange (.known dataTree) dataA) == some .notCovered
#guard reasonOf (acceptRange (.known dataTree) database) == some .notCovered
-- 未知・予算の超過の位置は Top の契約だけを受理する。
#guard reasonOf (acceptRange .unknown dataTree) == some .unknownSource
#guard reasonOf (acceptRange .exceeded dataTree) == some .budgetExceeded
#guard reasonOf (acceptRange .unknown .top) == none
-- Top を覆うのは Top だけである（`/**` も Top を覆わない）。
#guard reasonOf (acceptRange (.known .top) rootTree) == some .notCovered
#guard reasonOf (acceptRange (.known .top) .top) == none

/-! ## 原子の受理（効果の上限） -/

def ep (lo hi : Nat) (h1 : lo < 65536 := by decide) (h2 : hi < 65536 := by decide) : Range :=
  .endpoint ⟨.name (.exact ["api", "example", "com"]), ⟨⟨lo, h1⟩, ⟨hi, h2⟩⟩⟩

def connect (r : Range) : Atom := .name "Http.Connect" (.fixed r)
def writeAt (r : Range) : Atom := .name "File.Write" (.fixed r)

-- 一原子に覆われる原子は受理する。構造上の包含（同じ原子）は必ず受理する。
#guard reasonOf (acceptAtom [writeAt dataTree] (.known dataA) (writeAt dataA)) == none
#guard reasonOf (acceptAtom [writeAt dataTree] (.known dataTree) (writeAt dataTree)) == none
-- 和でだけ覆える原子は atomicCoverOnly（`0..9` を `0..4` と `5..9` の二原子では判定しない）。
#guard reasonOf (acceptAtom [connect (ep 0 4), connect (ep 5 9)] (.known (ep 0 9)) (connect (ep 0 9))) ==
  some .atomicCoverOnly
#guard reasonOf (acceptAtom [connect (ep 0 4)] (.known (ep 0 9)) (connect (ep 0 9))) == some .notCovered
-- 旧の Top の原子は、範囲付きの上限（`/**` を含む）に覆われない。由来により理由が分かれる。
#guard reasonOf (acceptAtom [writeAt rootTree] (.known .top) (.nameTop "File.Write")) == some .notCovered
#guard reasonOf (acceptAtom [writeAt rootTree] .unknown (.nameTop "File.Write")) == some .unknownSource
#guard reasonOf (acceptAtom [writeAt rootTree] .exceeded (.nameTop "File.Write")) == some .budgetExceeded
#guard reasonOf (acceptAtom [.nameTop "File.Write"] .unknown (.nameTop "File.Write")) == none

/-! ## 本体の受理（必須の判定の結果を型の制約へ渡す） -/

/-- 番号 1・2 の出現を `Scope.checkPathIn` へ解決する。 -/
def resolve (key : Key) : Option Resolved :=
  if key = at_ 1 ∨ key = at_ 2 ∨ key = at_ 9 then some ⟨.standard, checkPathName⟩ else none

def table : ScopeTable Release.Val := standardTable resolve boundary.rules.lookup

/-- 範囲の列を持つ `Scope.checkPathIn(pattern: pat, path: raw)`（組み込みの名前の頭）。 -/
def checkP (pat : Expr) (rs : List Range) : Expr :=
  .call (.primName checkPathName [] [] rs) [some "pattern", some "path"] [0, 1] (.cons pat (.cons (.local 0) .nil))

def accept (L : Limits) (body : Block) : Option (Key × CoverFailure) :=
  reasonOf (acceptBody "Ok" table L (at_ 1) scope0 body)

/-- `let r = Scope.checkPathIn(pattern: pat, path: raw)`（番号 1）。 -/
def bodyLet (pat : Expr) (rs : List Range) : Block := .bind .bind unitTy (checkP pat rs) (.last .unit)

-- リテラルのパターンの検査は、規則の添字 `/data/**` を覆う範囲の列だけを受理する。
#guard accept wide (bodyLet (str "/data/**") [dataTree]) == none
#guard accept wide (bodyLet (str "/data/**") [.top]) == none
#guard accept wide (bodyLet (str "/data/**") [rootTree]) == none
#guard accept wide (bodyLet (str "/data/**") [dataA]) == some (at_ 1, .notCovered)
-- 局所の文字列のパターンは由来を認定できないので、狭い範囲の列は unknownSource で拒否する。
#guard accept wide (bodyLet (.local 0) [dataTree]) == some (at_ 1, .unknownSource)
#guard accept wide (bodyLet (.local 0) [.top]) == none
-- 予算を超えた解析では、Top になった位置の理由は budgetExceeded である（上限 0 で最初の一段から止まる）。
#guard accept ⟨⟨0, 0⟩, ⟨0, 0⟩⟩ (bodyLet (.local 0) [dataTree]) == some (at_ 1, .budgetExceeded)
-- 解析が辿らない式（リストの要素）の中の呼び出し（番号 2）には記録がなく、外側の文（番号 1）の記録を使わない。
-- 事実を持たない状態で選ぶので、リテラルのパターンは既知、局所のパターンは未知になる。
def bodyNested (pat : Expr) (rs : List Range) : Block := .last (.list unitTy (.cons (checkP pat rs) .nil))
#guard ((analyzeBody "Ok" table wide (at_ 1) scope0 (bodyNested (str "/data/**") [dataTree])).2.map
  (·.1.surfacePreorder)) == [1]
#guard accept wide (bodyNested (str "/data/**") [dataTree]) == none
#guard accept wide (bodyNested (.local 0) [dataTree]) == some (at_ 2, .unknownSource)

/-! ## `Http.checkRequestIn` のポートの区間の受理 -/

/-- 番号 1 の出現を `Http.checkRequestIn` へ解決する。 -/
def resolveHttp (key : Key) : Option Resolved :=
  if key = at_ 1 then some ⟨.standard, checkRequestName⟩ else none

def tableHttp : ScopeTable Release.Val := standardTable resolveHttp boundary.rules.lookup

/-- `let r = Http.checkRequestIn[rs](hostPattern: "api.example.com", minimumPort: lo, maximumPort: hi, request: req)`
（番号 1）。 -/
def bodyRequest (lo hi : Nat) (rs : List Range) (h1 : lo ≤ 9223372036854775807 := by decide)
    (h2 : hi ≤ 9223372036854775807 := by decide) : Block :=
  .bind .bind unitTy
    (.call (.primName checkRequestName [] [] rs) [some "hostPattern", some "minimumPort", some "maximumPort", some "request"]
      [0, 1, 2, 3] (.cons (str "api.example.com") (.cons (ScopeLowerExamples.int lo h1)
        (.cons (ScopeLowerExamples.int hi h2) (.cons (.local 0) .nil)))))
    (.last .unit)

def acceptHttp (body : Block) : Option (Key × CoverFailure) :=
  reasonOf (acceptBody "Ok" tableHttp wide (at_ 1) scope0 body)

-- 最小が最大より大きいポートの組（`443` と `80`）は整形式の範囲でないので、必須の判定は未知である。狭い契約（`80..443`
-- を含む）は unknownSource で拒否し、Top の契約だけを受理する。
#guard acceptHttp (bodyRequest 443 80 [ep 80 443]) == some (at_ 1, .unknownSource)
#guard acceptHttp (bodyRequest 443 80 [ep 443 443]) == some (at_ 1, .unknownSource)
#guard acceptHttp (bodyRequest 443 80 [.top]) == none
-- 整形式でない範囲を既知にすると、所属する対象がないので `80..443` の契約が覆ってしまう（直した読み取りが避ける形）。
#guard reasonOf (acceptRange (.known (.endpoint ⟨.name (.exact ["api", "example", "com"]),
  ⟨⟨443, by decide⟩, ⟨80, by decide⟩⟩⟩)) (ep 80 443)) == none
-- 等しい組と正しい順の組は既知のままであり、覆う契約を受理し、覆わない契約を notCovered で拒否する。
#guard acceptHttp (bodyRequest 443 443 [ep 443 443]) == none
#guard acceptHttp (bodyRequest 443 443 [ep 80 443]) == none
#guard acceptHttp (bodyRequest 80 443 [ep 80 443]) == none
#guard acceptHttp (bodyRequest 80 443 [ep 443 443]) == some (at_ 1, .notCovered)

/-! ## 検査器が範囲付きの項目を呼ぶ形 -/

/-- 表の項目の範囲の具体化の制約の判定（`TargetTable.admitsR` と同じ。拡大は戻りの範囲が入力の範囲を覆う組）。 -/
def admitsRDec : PrimName → List Range → Bool
  | "Scope.widenPathIn", [r, s] => s.covers? r
  | "Http.widenRequestIn", [r, s] => s.covers? r
  | "Scope.widenPathIn", _ | "Http.widenRequestIn", _ => false
  | b, rs => (b == "File.readTextIn" || b == "File.readBytesIn" || b == "File.writeTextIn" ||
      b == "File.appendTextIn" || b == "File.writeBytesIn" || b == "File.appendBytesIn" || b == "Http.sendIn" ||
      b == "Scope.checkPathIn" || b == "Http.checkRequestIn" || b == "Scope.pathInValue" ||
      b == "Http.requestInValue") && rs.length == 1

def builtins : Builtins := TargetTable.builtins (fun _ _ _ _ _ => none) (fun _ _ _ _ _ _ => False)

def atoms : List Atom :=
  [.nameTop "State", .name "File.Write" (.rvar 0), .name "File.Read" (.rvar 0), .name "Http.Connect" (.rvar 0),
    writeAt dataTree]

def input : Check.Input :=
  { D := { funs := fun _ => none, cons := fun _ => none }, B := builtins, satDec := fun _ _ _ => true,
    admitsDec := fun _ _ _ => true, opPrim := fun _ _ => none, ctors := fun _ => [], atoms, admitsRDec }

def run (e : Expr) : Check.Result Check.Inferred := Check.checkExpr input .strict [] [] none .other [] e

def tyOf (x : Check.Result Check.Inferred) : Option Ty := match x with | .ok (t, _) => some t | .error _ => none
def errOf (x : Check.Result Check.Inferred) : Option String := match x with | .ok _ => none | .error e => some e.reason

def pathIn (r : Range) : Ty := .opaque "Scope.PathIn" (.fixed r)

-- 検査の結果の型は、型検査器が選んだ範囲を持つ。
#guard (tyOf (run (.primName checkPathName [] [] [dataTree]))).map
    (CheckTools.tyEq atoms (.fn ["pattern", "path"] [.base .string, .base .string]
      (TargetTable.resultTy (pathIn dataTree) TargetTable.scopeErrorTy) Eff.empty)) == some true
-- 範囲付きの IO は、引数の対象の位置と効果の原子が同じ範囲になる。
#guard (tyOf (run (.primName "File.writeTextIn" [] [] [dataTree]))).map
    (CheckTools.tyEq atoms (.fn ["path", "text"] [pathIn dataTree, .base .string]
      (TargetTable.resultTy (.base .unit) TargetTable.ioErrorTy) (Eff.ofAtoms (· == writeAt dataTree)))) == some true
-- 具体化の像の原子が候補の集合にないと拒否する（交換の原子の一覧の不足）。
#guard errOf (run (.primName "File.writeTextIn" [] [] [dataA])) == some "primitive range instantiation leaves the atom set"
-- 範囲の変数の数と合わない列、種類の違う範囲、被覆しない拡大は許容されない。
#guard errOf (run (.primName "File.writeTextIn" [] [] [])) == some "primitive range instantiation is not admitted"
#guard errOf (run (.primName "File.writeTextIn" [] [] [ep 0 9])) == some "primitive range instantiation is not admitted"
#guard (tyOf (run (.primName widenPathName [] [] [dataA, dataTree]))).map
    (CheckTools.tyEq atoms (.fn ["path"] [pathIn dataA] (pathIn dataTree) Eff.empty)) == some true
#guard errOf (run (.primName widenPathName [] [] [dataTree, dataA])) == some "primitive range instantiation is not admitted"
-- 全て Top の列は表の制約によらず許す（旧の Top の具体化）。
#guard (errOf (run (.primName "File.writeTextIn" [] [] [.top]))) == some "primitive range instantiation leaves the atom set"
#guard (tyOf (run (.primName checkPathName [] [] [.top]))).isSome

/-! ## 型付けと脱糖 -/

/-- 明示拡大の行き先は戻り値の注釈から決まる。 -/
example : widenRanges (pathIn dataA) (pathIn dataTree) = some [dataA, dataTree] := by decide
example : widenRanges (pathIn dataA) (.opaque "Http.RequestIn" (.fixed dataTree)) = none := by decide

/-- 範囲付きの組み込みの名前は、脱糖で同じ範囲の列を持つコアの項になる。 -/
example : desugarExpr (fun _ _ => none) .other (.primName checkPathName [] [] [dataTree]) =
    .ret (.prim checkPathName [] [] [dataTree]) := rfl

/-- `Scope.checkPathIn` を `/data/**` で具体化した名前の型。 -/
theorem checkPathIn_fnTy :
    fnTy (TargetTable.checkPathIn.inst [dataTree]).names (TargetTable.checkPathIn.inst [dataTree]).params
        (TargetTable.checkPathIn.inst [dataTree]).ret (TargetTable.checkPathIn.inst [dataTree]).eff [] [] =
      .fn ["pattern", "path"] [.base .string, .base .string]
        (TargetTable.resultTy (pathIn dataTree) TargetTable.scopeErrorTy) Eff.empty := by
  have hempty : Eff.substAt 0 [] [] Eff.empty = Eff.empty := Eff.substAt_ofAtoms 0 [] _
  have he : Eff.instR [dataTree] Eff.empty = Eff.empty := by
    simp [Eff.instR, Eff.empty]; funext x; rcases x with ⟨l, ix⟩ | i <;> (try cases ix) <;> simp [Eff.instAtoms]
  simp only [fnTy, PrimSig.inst, TargetTable.checkPathIn, TargetTable.pureIn, he]
  simp [Ty.subst, Ty.substAt, Ty.substTysAt, hempty, Ty.instTarget, Ty.instR, Ty.rawInstR, Ty.rawInstRTys,
    TargetTable.resultTy, TargetTable.pathIn, TargetTable.scopeErrorTy, Scope.Signature.Ix.inst, Ty.norm, Ty.normTys,
    pathIn, Ty.opaqueTop]

/-- 表層の型付けは範囲付きの項目を呼べる。`Scope.checkPathIn` を `/data/**` で具体化した名前は、結果の型に
`Scope.PathIn[/data/**]` を持つ関数の型で型付く。 -/
theorem checkPathIn_typed (D : Declarations) (op : OpPrim) :
    HasType D builtins op [] [] none .other (.primName checkPathName [] [] [dataTree])
      (.fn ["pattern", "path"] [.base .string, .base .string]
        (TargetTable.resultTy (pathIn dataTree) TargetTable.scopeErrorTy) Eff.empty) Eff.empty := by
  have hs : builtins.sig checkPathName = some TargetTable.checkPathIn := rfl
  have hsc := TargetTable.sig_scoped hs
  have h := HasTypeQ.E_Prim (D := D) (opPrim := op) (Q := Qempty) (Δ := []) (C := []) (Γ := []) (R := none)
    (p := .other) (ts := []) (es := []) (rs := [dataTree]) hs
    ⟨⟨by decide, by decide, Or.inr ⟨by simp [checkPathName], rfl⟩⟩, by decide⟩
    (by simp [NamesWF, PrimSig.inst, TargetTable.checkPathIn, TargetTable.pureIn]) rfl rfl rfl
    (PrimitiveAdmissible.of_noRows_inst hsc (by decide) rfl rfl rfl (by simp))
    (by rw [checkPathIn_fnTy]; simp [SingleTy, SingleTys, SingleEff, SingleFail, TargetTable.resultTy, pathIn,
      TargetTable.scopeErrorTy, Ty.opaqueTop, Eff.empty, Eff.fails])
  rw [checkPathIn_fnTy] at h
  exact h
end Benitoite.Surface.ScopeAcceptExamples
