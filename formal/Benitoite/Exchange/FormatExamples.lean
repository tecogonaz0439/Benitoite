import Benitoite.Exchange.Convert

/-! 交換時の省略と明示0を区別する例（設計書 01-12「文字列補間」、07-04「証明する性質」）。
脱糖後の定数列だけでは観測できない、表層JSONの書き戻しを確認する。 -/
namespace Benitoite.Exchange.FormatExamples
open Lean

private def roundtrip (precision : Json) : Bool := Id.run do
  let spec := Json.mkObj [("kind", toJson "f"), ("align", toJson "default"),
    ("sign", toJson "default"), ("alternate", toJson false), ("zero", toJson false),
    ("width", Json.null), ("precision", precision)]
  let raw := Json.mkObj [("formatted", Json.mkObj [
    ("ty", toJson (Ty.base "Float")), ("spec", spec)])]
  match (fromJson? raw : Except String InterpPart) with
  | .ok p => return toJson p == raw && (p.toSurface).isOk
  | .error _ => return false

#guard roundtrip Json.null
#guard roundtrip (toJson (0 : Nat))
end Benitoite.Exchange.FormatExamples
