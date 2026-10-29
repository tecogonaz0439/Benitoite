import Benitoite.Release.ShapeOk
import Benitoite.Release.Model
import Benitoite.Scope.RangeCover

/-!
# 範囲付きの組み込みの関数の表の項目（L20.7）

決定の判断 8 と L00.08 の一括の問いの問 22（DET-03）・問 23（DET-04）の表の項目を、本番の署名 `PrimSig` で置く
（plan-l10-l50 の注「表の項目」）。七つの IO（`File.readTextIn`・`readBytesIn`・`writeTextIn`・`appendTextIn`・
`writeBytesIn`・`appendBytesIn`・`Http.sendIn`）、検査（`Scope.checkPathIn`・`Http.checkRequestIn`）、射影
（`Scope.pathInValue`・`Http.requestInValue`）、拡大（`Scope.widenPathIn`・`Http.widenRequestIn`）の 13 項目である。
範囲の変数の個数は問 22 の表の右の列、七つの IO の形は単一の対象（`File.*In` は `single path 0`、`Http.sendIn` は
`single endpoint 0`）、効果は `L[rvar 0]` である。

表のデータ（問 11）: `effKind` は `File.Read`・`File.Write` が path、`Http.Connect` が endpoint。`valKind` は
`Scope.PathIn` が path、`Http.RequestIn` が endpoint。`admitsR` は、検査・射影・IO が一つの範囲を、拡大が入力の範囲
R と戻りの範囲 S の組で S が R を覆うものを許す（種類の一致は `RangeAdmissible` の `FitsKind` が確かめる）。範囲付きの
値型は資源の型にしない（`isResource = false`）。表のデータの正しさは信頼の対象であり、Rust の表との照合は R30・K10 が
行う（設計書 07-04「形式化で仮定するもの」）。

δ と応答の関係（実装）は表の引数とし、本モジュールは項目の形の性質（`sig_scoped`・`io_op` の欄）だけを示す。
δ と応答の関係を与えて全ての欄を満たす実例は `Release/ModelTargets.lean` にある。

誤り型の構成子（問 23）: `Http.RequestCheckError` は `InvalidUrl(message: String)` と `Scope(error: Scope.ScopeError)`
の二つである（`requestCheckErrorCons`）。結果の型 `Result` の構成子の宣言はプログラムの側にある（`Release.Program.cons`）。

`Http.RequestIn` の値は検査した要求を保持する（決定の判断 7）。値の形は検査済みの要求の値
`Val.checkedRequest t req`（実効の endpoint の対象 t と、`Http.ClientRequest` のレコードの閉じた値 req）であり、表の
データ `valContent` は `Http.RequestIn` の値が保持する要求の型を `Http.ClientRequest` のレコードの型 `clientRequestTy`
とする（L40.3b・L40.3c）。`Http.checkRequestIn`・
`Http.requestInValue`・`Http.sendIn` の δ と応答を与えて全ての欄を満たす実例は `Release/ModelHttp.lean` にある。
-/

namespace Benitoite.Release.TargetTable

open Benitoite.Release
open Scope.Domain (Range Kind)

/-- `Scope.PathIn[rvar i]`。 -/
def pathIn (i : Nat) : Ty := .opaque "Scope.PathIn" (.rvar i)

/-- `Http.RequestIn[rvar i]`（H,P は一つの endpoint の範囲）。 -/
def requestIn (i : Nat) : Ty := .opaque "Http.RequestIn" (.rvar i)

/-- 結果の型 `Result[A, E]`。 -/
def resultTy (a e : Ty) : Ty := .data "Result" [a, e]

def ioErrorTy : Ty := .opaqueTop "IOError"
def networkErrorTy : Ty := .opaqueTop "NetworkError"
def scopeErrorTy : Ty := .opaqueTop "Scope.ScopeError"
def responseTy : Ty := .opaqueTop "Http.Response"
def clientRequestTy : Ty := .data "Http.ClientRequest" []
def requestCheckErrorTy : Ty := .data "Http.RequestCheckError" []

/-- `Http.RequestCheckError` の構成子（問 23 の DET-04）。 -/
def requestCheckErrorCons : ConName → Option ConDecl
  | "Http.RequestCheckError.InvalidUrl" => some ⟨"Http.RequestCheckError", 0, [.base .string]⟩
  | "Http.RequestCheckError.Scope" => some ⟨"Http.RequestCheckError", 0, [scopeErrorTy]⟩
  | _ => none

/-- 単一の対象の形の IO の項目。効果は `l[rvar 0]`、範囲の変数は種類 k の一つ、引数の位置 0 が対象の位置である。 -/
def ioIn (names : List String) (params : List Ty) (ret : Ty) (l : EffName) (k : Kind) : PrimSig where
  tparams := []
  neffs := 0
  names := names
  params := params
  ret := ret
  eff := Eff.singleAt l (.rvar 0)
  admits := fun _ ts => ts = []
  kind := .io
  opEff := some l
  rkinds := [k]
  shape := .single k 0

/-- 純粋な項目（検査・射影・拡大）。 -/
def pureIn (names : List String) (params : List Ty) (ret : Ty) (ks : List Kind) : PrimSig where
  tparams := []
  neffs := 0
  names := names
  params := params
  ret := ret
  eff := Eff.empty
  admits := fun _ ts => ts = []
  kind := .pure
  opEff := none
  rkinds := ks

def readTextIn : PrimSig := ioIn ["path"] [pathIn 0] (resultTy (.base .string) ioErrorTy) "File.Read" .path
def readBytesIn : PrimSig := ioIn ["path"] [pathIn 0] (resultTy .bytes ioErrorTy) "File.Read" .path
def writeTextIn : PrimSig :=
  ioIn ["path", "text"] [pathIn 0, .base .string] (resultTy (.base .unit) ioErrorTy) "File.Write" .path
def appendTextIn : PrimSig :=
  ioIn ["path", "text"] [pathIn 0, .base .string] (resultTy (.base .unit) ioErrorTy) "File.Write" .path
def writeBytesIn : PrimSig :=
  ioIn ["path", "content"] [pathIn 0, .bytes] (resultTy (.base .unit) ioErrorTy) "File.Write" .path
def appendBytesIn : PrimSig :=
  ioIn ["path", "content"] [pathIn 0, .bytes] (resultTy (.base .unit) ioErrorTy) "File.Write" .path
def sendIn : PrimSig :=
  ioIn ["request"] [requestIn 0] (resultTy responseTy networkErrorTy) "Http.Connect" .endpoint
def checkPathIn : PrimSig :=
  pureIn ["pattern", "path"] [.base .string, .base .string] (resultTy (pathIn 0) scopeErrorTy) [.path]
def checkRequestIn : PrimSig :=
  pureIn ["hostPattern", "minimumPort", "maximumPort", "request"]
    [.base .string, .base .integer, .base .integer, clientRequestTy] (resultTy (requestIn 0) requestCheckErrorTy)
    [.endpoint]
def pathInValue : PrimSig := pureIn ["path"] [pathIn 0] (.base .string) [.path]
def requestInValue : PrimSig := pureIn ["request"] [requestIn 0] clientRequestTy [.endpoint]
def widenPathIn : PrimSig := pureIn ["path"] [pathIn 0] (pathIn 1) [.path, .path]
def widenRequestIn : PrimSig := pureIn ["request"] [requestIn 0] (requestIn 1) [.endpoint, .endpoint]

/-- 13 項目と、可変のセルの二項目（`Reference.get`・`Reference.set`。`Model` と同じ）。 -/
def entries : List (PrimName × PrimSig) :=
  [("Reference.get", Model.refGetSig), ("Reference.set", Model.refSetSig),
   ("File.readTextIn", readTextIn), ("File.readBytesIn", readBytesIn),
   ("File.writeTextIn", writeTextIn), ("File.appendTextIn", appendTextIn),
   ("File.writeBytesIn", writeBytesIn), ("File.appendBytesIn", appendBytesIn),
   ("Http.sendIn", sendIn), ("Scope.checkPathIn", checkPathIn), ("Http.checkRequestIn", checkRequestIn),
   ("Scope.pathInValue", pathInValue), ("Http.requestInValue", requestInValue),
   ("Scope.widenPathIn", widenPathIn), ("Http.widenRequestIn", widenRequestIn)]

/-- エフェクトの名前の対象の種類（表のデータ）。 -/
def effKind : EffName → Option Kind
  | "File.Read" => some .path
  | "File.Write" => some .path
  | "Http.Connect" => some .endpoint
  | _ => none

/-- 範囲付きの値型の名前の対象の種類（表のデータ）。 -/
def valKind : OpaqueName → Option Kind
  | "Scope.PathIn" => some .path
  | "Http.RequestIn" => some .endpoint
  | _ => none

/-- 範囲付きの値型の名前の値が保持する要求の型（表のデータ）。 -/
def valContent : OpaqueName → Option Ty
  | "Http.RequestIn" => some clientRequestTy
  | _ => none

/-- 範囲の具体化の制約（表のデータ）。拡大は戻りの範囲 S が入力の範囲 R を覆う組だけを許す。 -/
def admitsR : PrimName → List Range → Prop
  | "Scope.widenPathIn", rs => ∃ r s, rs = [r, s] ∧ s.Covers r
  | "Http.widenRequestIn", rs => ∃ r s, rs = [r, s] ∧ s.Covers r
  | b, rs => (b = "File.readTextIn" ∨ b = "File.readBytesIn" ∨ b = "File.writeTextIn" ∨ b = "File.appendTextIn" ∨
      b = "File.writeBytesIn" ∨ b = "File.appendBytesIn" ∨ b = "Http.sendIn" ∨ b = "Scope.checkPathIn" ∨
      b = "Http.checkRequestIn" ∨ b = "Scope.pathInValue" ∨ b = "Http.requestInValue") ∧ rs.length = 1

/-- 項目の表。δ と応答の関係は引数とする。 -/
def builtins (delta : PrimName → List Ty → List Eff → List Range → List Val → Option Outcome)
    (ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop) :
    Builtins where
  sig := fun b => entries.lookup b
  delta := delta
  ioResponse := ioResponse
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := fun l =>
    if l = stateEff then some []
    else if l = "File.Read" then some ["File.readTextIn", "File.readBytesIn"]
    else if l = "File.Write" then some ["File.writeTextIn", "File.appendTextIn", "File.writeBytesIn", "File.appendBytesIn"]
    else if l = "Http.Connect" then some ["Http.sendIn"]
    else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
  effKind := effKind
  valKind := valKind
  admitsR := admitsR
  valContent := valContent

variable {delta : PrimName → List Ty → List Eff → List Range → List Val → Option Outcome}
  {ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop}

theorem lookup_mem : ∀ {l : List (PrimName × PrimSig)} {b : PrimName} {s : PrimSig}, l.lookup b = some s → (b, s) ∈ l
  | [], _, _, h => by simp at h
  | (b', s') :: l, b, s, h => by
      simp only [List.lookup] at h
      split at h
      · next he =>
          cases h
          simp only [beq_iff_eq] at he
          subst he
          exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (lookup_mem h)

theorem sig_mem {b : PrimName} {s : PrimSig} (h : (builtins delta ioResponse).sig b = some s) : (b, s) ∈ entries :=
  lookup_mem h

theorem ioIn_scoped {names : List String} {params : List Ty} {ret : Ty} {l : EffName} {k : Kind}
    (hn : NamesWF names params) (hp : Ty.VarsInList 1 0 (· < 0) params) (hr1 : Ty.VarsIn 1 0 (· < 0) ret)
    (hr : Ty.VarsIn 0 0 (· < 0) ret)
    (hpos : ∀ p ∈ params, (∃ o ix, p = .opaque o ix) ∨ Ty.VarsIn 0 0 (· < 0) p) :
    (ioIn names params ret l k).Scoped := by
  refine ⟨hn, hp, hr1, ?_, hpos, fun _ _ => hr⟩
  refine ⟨fun i h => by simp at h, trivial, fun x hx => ?_⟩
  simp only [beq_iff_eq] at hx
  subst hx
  simp [Scope.Signature.Ix.WF, PrimSig.nranges, ioIn]

/-- 単一の対象の形の項目の形の検査。 -/
theorem ioIn_shapeOk {B : Builtins} {b : PrimName} {names : List String} {params : List Ty} {ret : Ty}
    {l : EffName} {k : Kind} {bs : List PrimName} {o : OpaqueName} (hbs : B.effects l = some bs) (hb : b ∈ bs)
    (hek : B.effKind l = some k) (hp : params[0]? = some (.opaque o (.rvar 0))) (hvk : B.valKind o = some k) :
    B.ShapeOk b (ioIn names params ret l k) :=
  ⟨l, bs, rfl, rfl, hbs, hb, hek, rfl, rfl, o, hp, hvk⟩

theorem pureIn_scoped {names : List String} {params : List Ty} {ret : Ty} {ks : List Kind}
    (hn : NamesWF names params) (hp : Ty.VarsInList ks.length 0 (· < 0) params)
    (hr : Ty.VarsIn ks.length 0 (· < 0) ret)
    (hpos : ∀ p ∈ params, (∃ o ix, p = .opaque o ix) ∨ Ty.VarsIn 0 0 (· < 0) p) :
    (pureIn names params ret ks).Scoped :=
  ⟨hn, hp, hr, ⟨fun i h => by simp at h, trivial, fun x hx => by simp at hx⟩,
    hpos, fun l hl => by simp [pureIn] at hl⟩

/-- 表の全ての項目は `PrimSig.Scoped`（`sig_scoped` の欄の内容）を満たす。 -/
theorem entries_scoped : ∀ e ∈ entries, e.2.Scoped := by
  intro e he
  simp only [entries, List.mem_cons, List.not_mem_nil, or_false] at he
  rcases he with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  · exact (Model.assumptions Model.emptyProgram).sig_scoped "Reference.get" _ (by simp [Model.builtins])
  · exact (Model.assumptions Model.emptyProgram).sig_scoped "Reference.set" _ (by simp [Model.builtins])
  all_goals first
    | (apply ioIn_scoped <;>
        simp [NamesWF, pathIn, requestIn, resultTy, ioErrorTy, networkErrorTy, responseTy, Ty.VarsInList, Ty.VarsIn,
          Scope.Signature.Ix.WF])
    | (apply pureIn_scoped <;>
        simp [NamesWF, pathIn, requestIn, resultTy, scopeErrorTy, requestCheckErrorTy, clientRequestTy, Ty.VarsInList,
          Ty.VarsIn, Scope.Signature.Ix.WF])

theorem sig_scoped {b : PrimName} {s : PrimSig} (h : (builtins delta ioResponse).sig b = some s) : s.Scoped :=
  entries_scoped (b, s) (sig_mem h)

/-- 七つの IO の項目は形の検査を通る（`io_op` の欄の内容）。可変のセルと純粋な項目は IO を行わない。 -/
theorem io_op {b : PrimName} {s : PrimSig} (h : (builtins delta ioResponse).sig b = some s)
    (hk : s.kind = .io ∨ s.kind = .exit) : (builtins delta ioResponse).ShapeOk b s := by
  have hm := sig_mem h
  simp only [entries, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hm
  rcases hm with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ |
      ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
    first
    | (exfalso; simp [Model.refGetSig, Model.refSetSig, pureIn, checkPathIn, checkRequestIn, pathInValue,
        requestInValue, widenPathIn, widenRequestIn] at hk)
    | (refine ioIn_shapeOk (by simp [builtins, stateEff]; rfl) ?_ rfl rfl rfl; simp)

/-- 範囲付きの値型は資源の型ではない（`release_exists` の量化を旧と同じに保つ。L20.4 の申し送り 8）。 -/
theorem not_resource (o : OpaqueName) : (builtins delta ioResponse).isResource o = false := rfl

/-- 表のデータの値。 -/
example : effKind "File.Read" = some .path ∧ effKind "File.Write" = some .path ∧
    effKind "Http.Connect" = some .endpoint ∧ effKind "Console.Write" = none := ⟨rfl, rfl, rfl, rfl⟩
example : valKind "Scope.PathIn" = some .path ∧ valKind "Http.RequestIn" = some .endpoint ∧
    valKind "IOError" = none := ⟨rfl, rfl, rfl⟩
example : valContent "Http.RequestIn" = some clientRequestTy ∧ valContent "Scope.PathIn" = none :=
  ⟨rfl, rfl⟩

/-- 拡大の項目の具体化: 戻りの範囲が入力の範囲を覆う組だけを許す。 -/
example : admitsR "Scope.widenPathIn" [.path (.tree ["data", "x"]), .path (.tree ["data"])] :=
  ⟨_, _, rfl, by decide⟩
example : ¬ admitsR "Scope.widenPathIn" [.path (.tree ["data"]), .path (.tree ["data", "x"])] := by
  rintro ⟨r, s, h, hc⟩
  simp only [List.cons.injEq, and_true] at h
  obtain ⟨rfl, rfl⟩ := h
  revert hc; decide

/-- 単一の対象の形の項目を一つの範囲で具体化すると、引数の対象の位置と効果の原子が同じ範囲になる（入力の添字と効果の
一致）。 -/
example (R : Range) : (writeTextIn.inst [R]).eff = Eff.singleAt "File.Write" (.fixed R) ∧
    (writeTextIn.inst [R]).params = [.opaque "Scope.PathIn" (.fixed R), .base .string] := by
  refine ⟨?_, rfl⟩
  rw [PrimSig.inst_eff]
  simp [writeTextIn, ioIn, Scope.Signature.Ix.inst]

end Benitoite.Release.TargetTable
