import Benitoite.Exchange.Version

/-!
# 交換の観測・拒否の理由・範囲の入力の検査の小例（L50.2）

`Exchange/Observe.lean` の読み書きと判定、`Version.lean` の範囲の入力の検査（`validateRangeInput`）を、小さな入力で
確かめる（設計書 07-04「交換の形式の版」）。具体の確かめは `#guard`（コンパイルした判定の評価）で行う。
-/

namespace Benitoite.Exchange.ObserveExamples
open Lean Benitoite.Exchange Benitoite.Scope.Domain Benitoite.Scope.Signature
open Benitoite.Surface.ScopeAccept (CoverFailure)

def dataA : Target := .path ["data", "a.txt"]
def apiHost : HostTarget := .name ["api", "example", "com"]
def lanHost : HostTarget := .ip (IPAddr.v4 0xC0A80114)
def ep : Target := .endpoint ⟨apiHost, ⟨443, by decide⟩⟩
def lanEp : Target := .endpoint ⟨lanHost, ⟨443, by decide⟩⟩

-- 対象と観測の往復（種類別）。
#guard (decodeObservation (encodeObservation [dataA, .host apiHost, ep, lanEp])).toOption == some [dataA, .host apiHost, ep, lanEp]
#guard (decodeTarget (Json.mkObj [("path", Json.arr #["data"]), ("extra", Json.null)])).isOk
#guard !(decodeObservation (Json.arr #[Json.mkObj [("path", Json.arr #["data"]), ("extra", Json.null)]])).isOk
#guard !(decodeTarget (Json.mkObj [("file", Json.arr #["data"])])).isOk
-- 範囲外のポートと幅を超えるアドレスは誤りにする。
#guard !(decodeTarget (Json.mkObj [("endpoint", Json.mkObj [("host", encodeHostTarget apiHost), ("port", toJson 65536)])])).isOk

-- 拒否の理由の四つの名前（DET-05）と往復。
#guard [CoverFailure.notCovered, .atomicCoverOnly, .unknownSource, .budgetExceeded].map encodeCoverFailure ==
  [.str "notCovered", .str "atomicCoverOnly", .str "unknownSource", .str "budgetExceeded"]
#guard [CoverFailure.notCovered, .atomicCoverOnly, .unknownSource, .budgetExceeded].all fun f =>
  (decodeCoverFailure (encodeCoverFailure f)).toOption == some f
#guard !(decodeCoverFailure (.str "covered")).isOk

/-! ## 観測の許可 -/

def dataTree : Range := .path (.tree ["data"])
def apiEp : Range := .endpoint ⟨.name (.exact ["api", "example", "com"]), ⟨⟨443, by decide⟩, ⟨443, by decide⟩⟩⟩
def kinds : String → Option Kind
  | "File.Write" => some .path
  | "Http.Connect" => some .endpoint
  | _ => none
def upper : List Benitoite.Release.Atom :=
  [.name "File.Write" (.fixed dataTree), .name "Http.Connect" (.fixed apiEp)]

-- 範囲の原子は、その範囲に属する対象の観測だけを許す。Top の原子は種類の全対象を許す。
#guard observationAllowed kinds upper "File.Write" [dataA]
#guard !observationAllowed kinds upper "File.Write" [.path ["etc", "passwd"]]
#guard observationAllowed kinds upper "Http.Connect" [ep]
#guard !observationAllowed kinds upper "Http.Connect" [lanEp]
#guard observationAllowed kinds [.name "File.Write" (.fixed .top)] "File.Write" [.path ["etc", "passwd"]]
-- 種類の違う対象と、対象を持たない名前の観測は許さない。範囲の変数の原子は対象を許さない。
#guard !observationAllowed kinds upper "File.Write" [ep]
#guard observationAllowed kinds upper "Console" []
#guard !observationAllowed kinds upper "Console" [dataA]
#guard !observationAllowed kinds [.name "File.Write" (.rvar 0)] "File.Write" [dataA]

/-! ## 範囲の入力の検査 -/

def lan24 : Range := .host (.ip (.cidr (CIDR.v4 0xC0A80100 24)))
def lan32 : Range := .host (.ip (.cidr (CIDR.v4 0xC0A80114 32)))
def hostBits : Range := .host (.ip (.cidr (CIDR.v4 0xC0A80114 24)))

-- 整形式で正規形の範囲だけを受理する（prefix が最大長の CIDR は完全一致の形に正規化してから書く）。
#guard (checkRangeInput lan24).isOk
#guard !(checkRangeInput lan32).isOk
#guard !(checkRangeInput hostBits).isOk
-- 最小のポートが最大より大きい区間（`443..80`）は整形式でない（`PortRange.WF`）ので拒否する。一点の区間は受理する。
def invertedEp : Range := .endpoint ⟨.name (.exact ["api", "example", "com"]), ⟨⟨443, by decide⟩, ⟨80, by decide⟩⟩⟩
#guard (checkRangeInput apiEp).isOk
#guard !(checkRangeInput invertedEp).isOk
#guard !(checkIxInput 0 (.fixed invertedEp)).isOk
#guard (checkIxInput 0 (.fixed dataTree)).isOk
#guard !(checkIxInput 0 (.rvar 0)).isOk
#guard (checkIxInput 1 (.rvar 0)).isOk
#guard !(checkAdmitsRuleInput 1 (.covers 0 1)).isOk
#guard (checkAdmitsRuleInput 2 (.covers 0 1)).isOk

private def corpusWith (atom : Json) (scope : Json) : Json :=
  Json.mkObj [("version", toJson 15), ("inputs", Json.arr #[Json.mkObj [("eff", Json.arr #[atom]),
    ("scopeAcceptance", scope)]])]

private def scopeOf (r : Range) : Json :=
  Json.mkObj [("patterns", Json.arr #[Json.mkObj [("text", .str "/data/**"), ("range", encodeRange r)]]),
    ("hosts", Json.arr #[]), ("limits", encodeLimits ⟨⟨1, 1⟩, ⟨1, 1⟩⟩)]

-- 新版の corpus は、全ての範囲の位置と必須の判定の入力の範囲を検査し、必須の判定の入力を必須とする。
#guard (exchangeJson "corpus" (corpusWith (toJson (Atom.name "File.Write" (.fixed dataTree))) (scopeOf dataTree))).isOk
#guard !(exchangeJson "corpus" (corpusWith (toJson (Atom.name "File.Write" (.fixed hostBits))) (scopeOf dataTree))).isOk
#guard !(exchangeJson "corpus" (corpusWith (toJson (Atom.name "File.Write" (.fixed dataTree))) (scopeOf lan32))).isOk
#guard !(exchangeJson "corpus" (corpusWith (toJson (Atom.name "File.Write" (.fixed dataTree))) Json.null)).isOk
#guard !(exchangeJson "corpus" (corpusWith (toJson (Atom.name "Http.Connect" (.fixed invertedEp))) (scopeOf dataTree))).isOk
-- 旧版の corpus は必須の判定の入力を置かせず、null（規則のない受理の入力）で読む。
#guard match exchangeJson "corpus" (Json.mkObj [("version", toJson 14), ("inputs", Json.arr #[Json.mkObj []])]) with
  | .ok j => ((j.getObjVal? "inputs").bind (·.getArrVal? 0) |>.bind (·.getObjVal? "scopeAcceptance")).toOption ==
      some Json.null
  | .error _ => false
#guard !(exchangeJson "corpus" (Json.mkObj [("version", toJson 14),
  ("inputs", Json.arr #[Json.mkObj [("scopeAcceptance", scopeOf dataTree)]])])).isOk

-- 必須の判定の入力の欄の余り・重複した綴りは拒否する。
#guard !(fromJson? (Json.mkObj [("patterns", Json.arr #[]), ("hosts", Json.arr #[]),
  ("limits", encodeLimits ⟨⟨1, 1⟩, ⟨1, 1⟩⟩), ("extra", Json.null)]) : Except String ScopeAcceptanceEntry).isOk
#guard !(fromJson? (Json.mkObj [("patterns", Json.arr #[
    Json.mkObj [("text", .str "/a"), ("range", encodeRange dataTree)],
    Json.mkObj [("text", .str "/a"), ("range", encodeRange dataTree)]]), ("hosts", Json.arr #[]),
  ("limits", encodeLimits ⟨⟨1, 1⟩, ⟨1, 1⟩⟩)]) : Except String ScopeAcceptanceEntry).isOk

end Benitoite.Exchange.ObserveExamples
