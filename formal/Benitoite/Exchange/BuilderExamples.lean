import Benitoite.Exchange.Convert
import Benitoite.Exchange.Version

/-!
# 専用構築器の交換境界の例

表層と専用コアの具体形を独立したJSONで照合し、旧版と参照先の欄の読み替えを拒否する。
対応する契約は設計書 01-12「構築器の局所宣言と捕捉」、07-04「道具と置き場所」である。
独立corpusの全件の検査とは別に、読者自身の境界を既定ビルドで確認する。
-/
namespace Benitoite.Exchange.BuilderExamples
open Lean

private def decode (text : String) : Except String Block := do
  decodeBlock (← Json.parse text)

private def source : Benitoite.Release.Refinement.Surface.Block :=
  .builderBind .string (.seq (.builderOp .append 0 (.cons (.literal (.string "x")) .nil) .string)
    (.last (.builderOp .copy 0 .nil .string)))

private def core : Benitoite.Release.Refinement.Comp :=
  .builderLet .string (.letIn
    (.letIn (.ret (.const (.string "x"))) (.builderOp .string .append (.bound 1) [.var 0]))
    (.builderOp .string .copy (.bound 1) []))

/-- 引数の評価の let の下でも、専用の番号は同じセルを指す。 -/
example : Benitoite.Release.Refinement.Surface.desugarBlock (fun _ _ => none) .other source = core := rfl

private def parsedSource : Except String Bool := do
  let block ← decode "{\"builderBind\":{\"kind\":\"string\",\"rest\":{\"seq\":{\"expr\":{\"builderOp\":{\"op\":\"append\",\"index\":0,\"args\":[{\"literal\":{\"value\":{\"string\":{\"value\":\"x\"}}}}],\"kind\":\"string\"}},\"rest\":{\"last\":{\"expr\":{\"builderOp\":{\"op\":\"copy\",\"index\":0,\"args\":[],\"kind\":\"string\"}}}}}}}}"
  let surface ← block.toSurface []
  return match surface with
    | .builderBind .string (.seq (.builderOp .append 0 (.cons (.literal (.string "x")) .nil) .string)
        (.last (.builderOp .copy 0 .nil .string))) => true
    | _ => false

private def lower : Except String Json := do
  return encodeComp (← fromComp [] (fun _ => 0) core)

#guard parsedSource.toOption == some true

private def expected : Except String Json := Json.parse
  "{\"builderLet\":{\"kind\":\"string\",\"body\":{\"letIn\":{\"bound\":{\"letIn\":{\"bound\":{\"ret\":{\"value\":{\"const\":{\"value\":{\"string\":{\"value\":\"x\"}}}}}},\"body\":{\"builderOp\":{\"kind\":\"string\",\"op\":\"append\",\"ref\":{\"bound\":{\"index\":1}},\"args\":[{\"var\":{\"index\":0}}]}}}},\"body\":{\"builderOp\":{\"kind\":\"string\",\"op\":\"copy\",\"ref\":{\"bound\":{\"index\":1}},\"args\":[]}}}}}}"

#guard match lower, expected with
  | .ok actual, .ok wanted => actual == wanted
  | _, _ => false

private def versioned (version : Nat) : Json :=
  Json.mkObj [("version", toJson version), ("operators", Json.arr #[]), ("inputs", Json.arr #[])]

#guard (exchangeJson "corpus" (versioned 16)).isOk
#guard !(exchangeJson "corpus" (versioned 15)).isOk
#guard sidecarVersion == 8

-- 新版は参照先を受け取らず、種類の欠落・余分な欄も拒否する。
#guard !(decode "{\"builderBind\":{\"kind\":\"string\",\"refs\":{},\"rest\":\"empty\"}}").isOk
#guard !(decode "{\"last\":{\"expr\":{\"builderOp\":{\"op\":\"copy\",\"index\":0,\"args\":[]}}}}").isOk
#guard !(decode "{\"builderBind\":{\"kind\":{\"list\":{\"element\":\"String\",\"extra\":0}},\"rest\":\"empty\"}}").isOk

end Benitoite.Exchange.BuilderExamples
