import Benitoite.Release.Typing

/-! 組み込みの制約とデータ型の要約の計算（設計書 01-06「等値の型」
「鍵の型（初回リリース版）」「組み込みの制約（初回リリース版）」）。
宣言の型引数を展開せず、有限の要約の表を同時に更新する。 -/
namespace Benitoite.Release

/-- 要約に必要な宣言だけを持つ。構成子の名前は要約に影響しない。 -/
structure BuiltinDataDecl where
  name : DataName
  ntys : Nat
  ctors : List (List Ty)

/-- always は等値でない型（鍵の要約では Float）を無条件に含むこと。
無条件に含む場合は依存を吸収し、それ以外は昇順で重複のない集合を持つ。 -/
structure BoundSummary where
  always : Bool := false
  dependsOn : List Nat := []
  deriving BEq, DecidableEq

/-- 型引数の個数を判定にも使うため、要約と同じ表に保持する。 -/
structure BuiltinDataSummary where
  name : DataName
  ntys : Nat
  eq : BoundSummary
  key : BoundSummary
  deriving BEq, DecidableEq

/-- 名前は一つの入力の宣言の表の中で参照する。 -/
abbrev SummaryTable := List BuiltinDataSummary

private def insertDep (i : Nat) : List Nat → List Nat
  | [] => [i]
  | j :: js => if i < j then i :: j :: js else if i == j then j :: js
      else j :: insertDep i js

/-- 「無条件に含む」を吸収元として条件を合わせる。 -/
def BoundSummary.merge (a b : BoundSummary) : BoundSummary :=
  if a.always || b.always then ⟨true, []⟩
  else ⟨false, b.dependsOn.foldl (fun ds i => insertDep i ds) a.dependsOn⟩

mutual
  /-- 宣言の引数の型が含む条件。key は Float の要約を選ぶ。
  関数・中身を見せない型・型パラメータの適用の中は辿らない（typeck/decls.rs）。 -/
  def summarizeTy (S : SummaryTable) (key : Bool) : Ty → BoundSummary
    | .base .float => ⟨key, []⟩
    | .base _ | .bytes => ⟨false, []⟩
    | .tvar i => ⟨false, [i]⟩
    | .list t | .set t => summarizeTy S key t
    | .map k v => (summarizeTy S key k).merge (summarizeTy S key v)
    | .data d ts =>
        match S.find? (fun s => s.name == d) with
        | none => ⟨false, []⟩
        | some d =>
            let s := if key then d.key else d.eq
            if s.always then ⟨true, []⟩
            else summarizeArgs S key (some s.dependsOn) 0 ts
    | .fn _ _ _ | .opaque _ | .reference _ | .lazy _ | .tapp _ _
      | .cont _ _ _ | .dict _ _ | .ctor _ => ⟨!key, []⟩

  /-- 番号を数えながら依存する型引数を辿る。none は全引数を選ぶ。
  リストの要素に直接再帰し、カーネルで評価できる構造的な再帰を保つ。 -/
  def summarizeArgs (S : SummaryTable) (key : Bool) (deps : Option (List Nat))
      (k : Nat) : List Ty → BoundSummary
    | [] => ⟨false, []⟩
    | t :: ts =>
        let rest := summarizeArgs S key deps (k + 1) ts
        if deps.isNone || (deps.getD []).contains k then (summarizeTy S key t).merge rest
        else rest
end

/-- すべての宣言を同じ古い表から更新する（01-06 の手順 2）。 -/
def summaryStep (ds : List BuiltinDataDecl) (S : SummaryTable) : SummaryTable :=
  ds.map fun d =>
    let args := d.ctors.flatten
    ⟨d.name, d.ntys, summarizeArgs S false none 0 args, summarizeArgs S true none 0 args⟩

/-- 二種類の要約の各依存と always が増える回数を上から抑える燃料。 -/
def summaryFuel (ds : List BuiltinDataDecl) : Nat :=
  2 * (ds.foldl (fun n d => n + d.ntys + 1) 0) + 1

private def iterateSummaries (ds : List BuiltinDataDecl) : Nat → SummaryTable → SummaryTable
  | 0, S => S
  | n + 1, S =>
      let next := summaryStep ds S
      if next == S then S else iterateSummaries ds n next

/-- 空の要約から不動点を計算する（01-06 の手順 1〜3）。 -/
def dataSummaries (ds : List BuiltinDataDecl) : SummaryTable :=
  iterateSummaries ds (summaryFuel ds) (ds.map fun d => ⟨d.name, d.ntys, ⟨false, []⟩, ⟨false, []⟩⟩)

/-- 燃料が尽きた結果も、もう一度更新して収束を検査する。 -/
def summariesConverged (ds : List BuiltinDataDecl) (S : SummaryTable) : Bool :=
  summaryStep ds S == S

mutual
  /-- 等値・鍵の判定。データ型の鍵の判定は等値の条件も検査する（ir/check.rs）。 -/
  def satisfiesB (S : SummaryTable) (C : List TParam) (key : Bool) : Ty → Bool
    | .base .float => !key
    | .base _ | .bytes => true
    | .tvar i => match C[i]? with
        | none => false
        | some p => p.key || (!key && p.equality)
    | .list t | .set t => satisfiesB S C key t
    | .map k v => satisfiesB S C key k && satisfiesB S C key v
    | .data d ts =>
        match S.find? (fun s => s.name == d) with
        | none => false
        | some s => ts.length == s.ntys && !s.eq.always &&
            s.eq.dependsOn.all (· < ts.length) && satArgs S C false s.eq.dependsOn 0 ts &&
            (!key || (!s.key.always && s.key.dependsOn.all (· < ts.length) &&
              satArgs S C true s.key.dependsOn 0 ts))
    | .fn _ _ _ | .opaque _ | .reference _ | .lazy _ | .cont _ _ _
      | .dict _ _ | .ctor _ | .tapp _ _ => false

  /-- 欠けた依存の位置は呼び出し元で拒否し、ここでは要素に直接再帰する。 -/
  def satArgs (S : SummaryTable) (C : List TParam) (key : Bool) (deps : List Nat)
      (k : Nat) : List Ty → Bool
    | [] => true
    | t :: ts => (!deps.contains k || satisfiesB S C key t) && satArgs S C key deps (k + 1) ts
end

/-- SatAll は制約のない位置も検査するので、その位置は型によらず受け入れる。 -/
def satB (S : SummaryTable) (C : List TParam) (t : Ty) (p : TParam) : Bool :=
  if p.key then satisfiesB S C true t
  else if p.equality then satisfiesB S C false t else true

/-- ordered は Release.TParam に含まれず、prim の admits だけで検査する。 -/
structure BuiltinConstraint where
  equality : Bool := false
  key : Bool := false
  ordered : Bool := false

/-- 順序の比較の閉じた型の集まり TySet::ORD。型パラメータは通さない。 -/
def orderedB : Ty → Bool
  | .base .integer | .base .float | .base .string | .base .character
    | .base .byte | .base .decimal => true
  | _ => false

/-- 個数と各位置の組み込みの制約を検査する。C は tvar の番号の順（内側から）。 -/
def admitsB (S : SummaryTable) (cs : List BuiltinConstraint) (C : List TParam) : List Ty → Bool :=
  match cs with
  | [] => fun ts => ts.isEmpty
  | p :: ps => fun ts => match ts with
      | [] => false
      | t :: ts => satB S C t ⟨p.equality, p.key⟩ && (!p.ordered || orderedB t) && admitsB S ps C ts

/-! 小さな宣言の表で仕様上の境界を確かめる。 -/
private def eqC : TParam := ⟨true, false⟩
private def keyC : TParam := ⟨false, true⟩
private def sampleDecls : List BuiltinDataDecl := [
  ⟨"Option", 1, [[], [.tvar 0]]⟩,
  ⟨"Nest", 1, [[.tvar 0], [.data "Nest" [.list (.tvar 0)]]]⟩,
  ⟨"A", 2, [[.data "B" [.tvar 1, .tvar 0]]]⟩,
  ⟨"B", 2, [[.tvar 0], [.data "A" [.tvar 1, .tvar 0]]]⟩,
  ⟨"R", 1, [[.tvar 0], [.opaque "IOError"]]⟩,
  ⟨"F", 0, [[.data "G" []]]⟩,
  ⟨"G", 0, [[.base .float], [.data "F" []]]⟩]
private def sampleS : SummaryTable := dataSummaries sampleDecls

example : satB [] [] (.base .integer) eqC = true ∧
    satB [] [] (.base .string) eqC = true ∧
    satB [] [] (.fn [] (.base .unit) Eff.empty) eqC = false := by decide
example : satB [] [] (.fn [] (.base .unit) Eff.empty) ⟨false, false⟩ = true ∧
    satB [] [] (.tvar 10) ⟨false, false⟩ = true := by decide
example : satB [] [] (.base .float) eqC = true ∧
    satB [] [] (.base .float) keyC = false ∧
    satB [] [] (.list (.base .integer)) keyC = true := by decide
example : satB [] [] (.map (.base .string) (.base .float)) eqC = true ∧
    satB [] [] (.map (.base .string) (.base .float)) keyC = false ∧
    satB [] [] (.map (.fn [] (.base .unit) Eff.empty) (.base .integer)) eqC = false := by decide
example : satB [] [keyC, eqC, ⟨false, false⟩] (.tvar 0) eqC = true ∧
    satB [] [keyC, eqC] (.tvar 0) keyC = true ∧
    satB [] [keyC, eqC] (.tvar 1) eqC = true ∧
    satB [] [keyC, eqC] (.tvar 1) keyC = false ∧
    satB [] [keyC, eqC, ⟨false, false⟩] (.tvar 2) eqC = false ∧
    satB [] [] (.tvar 0) eqC = false := by decide
example : summariesConverged sampleDecls sampleS = true ∧
    sampleS = [
      ⟨"Option", 1, ⟨false, [0]⟩, ⟨false, [0]⟩⟩,
      ⟨"Nest", 1, ⟨false, [0]⟩, ⟨false, [0]⟩⟩,
      ⟨"A", 2, ⟨false, [1]⟩, ⟨false, [1]⟩⟩,
      ⟨"B", 2, ⟨false, [0]⟩, ⟨false, [0]⟩⟩,
      ⟨"R", 1, ⟨true, []⟩, ⟨false, [0]⟩⟩,
      ⟨"F", 0, ⟨false, []⟩, ⟨true, []⟩⟩,
      ⟨"G", 0, ⟨false, []⟩, ⟨true, []⟩⟩] := by decide
example : satB sampleS [] (.data "Option" [.base .integer]) keyC = true ∧
    satB sampleS [] (.data "Option" [.base .float]) eqC = true ∧
    satB sampleS [] (.data "Option" [.base .float]) keyC = false ∧
    satB sampleS [] (.data "Option" []) eqC = false ∧
    satB sampleS [] (.data "missing" []) eqC = false ∧
    satB sampleS [] (.data "R" [.base .integer]) keyC = false := by decide
example : satB [⟨"Bad", 1, ⟨false, [1]⟩, ⟨false, []⟩⟩] []
    (.data "Bad" [.base .integer]) eqC = false := by decide
example : dataSummaries [⟨"Pair", 2, [[.tvar 1, .tvar 0, .tvar 1]]⟩] =
    [⟨"Pair", 2, ⟨false, [0, 1]⟩, ⟨false, [0, 1]⟩⟩] := by decide
example : dataSummaries [
    ⟨"H", 0, [[.data "I" []]]⟩,
    ⟨"I", 0, [[.data "H" []], [.opaque "IOError"]]⟩] =
    [⟨"H", 0, ⟨true, []⟩, ⟨false, []⟩⟩,
     ⟨"I", 0, ⟨true, []⟩, ⟨false, []⟩⟩] := by decide
-- 関数などの中の Float と型パラメータは、要約の依存や鍵の条件に加えない。
example : dataSummaries [⟨"Hidden", 1, [[
    .fn [.tvar 0] (.base .float) Eff.empty, .reference (.base .float),
    .lazy (.tvar 0), .tapp 0 [.base .float]]]⟩] =
    [⟨"Hidden", 1, ⟨true, []⟩, ⟨false, []⟩⟩] := by decide
example : [Ty.opaque "IOError", .reference (.base .integer), .lazy (.base .integer),
    .cont (.base .integer) (.base .integer) Eff.empty, .dict "Eq" (.base .integer),
    .ctor .list, .tapp 0 [.base .integer]].all (fun t => !satB [] [] t eqC) = true ∧
    satB [] [] .bytes keyC = true ∧ satB [] [] (.set (.base .integer)) keyC = true := by decide
example : [Ty.base .integer, .base .float, .base .string, .base .character,
    .base .byte, .base .decimal].all orderedB = true := by decide
example : admitsB [] [⟨false, false, true⟩] [] [.base .decimal] = true ∧
    admitsB [] [⟨false, false, true⟩] [] [.base .boolean] = false ∧
    admitsB [] [⟨false, false, true⟩] [] [.base .unit] = false ∧
    admitsB [] [⟨false, false, true⟩] [keyC] [.tvar 0] = false ∧
    admitsB [] [⟨false, true, false⟩] [keyC] [.tvar 0] = true ∧
    admitsB [] [⟨false, true, false⟩] [] [] = false ∧
    admitsB [] [] [] [.base .integer] = false := by decide

end Benitoite.Release
