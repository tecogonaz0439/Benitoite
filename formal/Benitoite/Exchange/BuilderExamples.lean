import Benitoite.Exchange.Convert
import Benitoite.Exchange.Version

/-!
# 専用構築器の交換境界の例

版13の表層と専用コアを独立したJSONで照合し、旧版と旧refsの読み替えを拒否する。
対応する契約は設計書 01-12「構築器の局所宣言と捕捉」、07-04「証明する性質」である。
独立corpusの全件の検査とは別に、読者自身の境界を既定ビルドで確認する。
-/
namespace Benitoite.Exchange.BuilderExamples
open Lean

private def decode (text : String) : Except String Block := do
  decodeBlock (← Json.parse text)

/-- 通常の引数のletを挟んだ専用番号を、手書きのコアと比較する。 -/
private def lower : Except String Json := do
  let block ← decode "{\"builderBind\":{\"kind\":\"string\",\"rest\":{\"seq\":{\"expr\":{\"builderOp\":{\"op\":\"append\",\"index\":0,\"args\":[{\"literal\":{\"value\":{\"string\":{\"value\":\"x\"}}}}],\"kind\":\"string\"}},\"rest\":{\"last\":{\"expr\":{\"builderOp\":{\"op\":\"copy\",\"index\":0,\"args\":[],\"kind\":\"string\"}}}}}}}}"
  let surface ← block.toSurface []
  let core := Benitoite.Surface.desugarBlock (fun _ _ => none) .other surface
  return encodeComp (← fromComp [] (fun _ => 0) core)

private def expected : Except String Json := Json.parse
  "{\"builderLet\":{\"kind\":\"string\",\"body\":{\"letIn\":{\"bound\":{\"letIn\":{\"bound\":{\"ret\":{\"value\":{\"const\":{\"value\":{\"string\":{\"value\":\"x\"}}}}}},\"body\":{\"builderOp\":{\"kind\":\"string\",\"op\":\"append\",\"ref\":{\"bound\":{\"index\":1}},\"args\":[{\"var\":{\"index\":0}}]}}}},\"body\":{\"builderOp\":{\"kind\":\"string\",\"op\":\"copy\",\"ref\":{\"bound\":{\"index\":1}},\"args\":[]}}}}}}"

#guard match lower, expected with
  | .ok actual, .ok wanted => actual == wanted
  | _, _ => false

private def versioned (version : Nat) (payload : Json) : Json :=
  Json.mkObj [("version", toJson version), ("payload", payload)]
private def oldBuilder : Json := Json.mkObj [("builderBind", Json.mkObj [])]
private def legacyRefs : Json := Json.mkObj [("unknown", Json.mkObj [("refs", Json.null)])]

-- 版12は旧builderの詳細を補完せず、再生成の理由を返す。
#guard match exchangeJson "corpus" (versioned 12 oldBuilder) with
  | .error reason => reason == "builder syntax requires exchange version 13; regenerate with version 13"
  | .ok _ => false
#guard (exchangeJson "corpus" (versioned 12 (Json.mkObj []))).isOk
#guard (exchangeJson "corpus" (versioned 13 oldBuilder)).isOk
#guard !(exchangeJson "corpus" (versioned 11 oldBuilder)).isOk
#guard !(exchangeJson "corpus" (versioned 13 legacyRefs)).isOk
#guard !(exchangeJson "stdlib" (versioned 5 oldBuilder)).isOk
#guard [8, 9, 10, 11, 12, 13].map sidecarVersion == [2, 3, 3, 4, 4, 5]

-- 新版は参照先を受け取らず、種類の欠落・余分な欄も拒否する。
#guard !(decode "{\"builderBind\":{\"kind\":\"string\",\"refs\":{},\"rest\":\"empty\"}}").isOk
#guard !(decode "{\"last\":{\"expr\":{\"builderOp\":{\"op\":\"copy\",\"index\":0,\"args\":[]}}}}").isOk
#guard !(decode "{\"builderBind\":{\"kind\":{\"list\":{\"element\":\"String\",\"extra\":0}},\"rest\":\"empty\"}}").isOk

end Benitoite.Exchange.BuilderExamples
