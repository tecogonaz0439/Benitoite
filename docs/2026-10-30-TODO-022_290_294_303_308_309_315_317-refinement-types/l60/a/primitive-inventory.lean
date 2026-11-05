import Lean
import Benitoite
open Lean Elab Command Term Meta
open Benitoite.Release.Refinement
private unsafe def findProvider (name : String) (providers : Array String) : TermElabM (Array Nat) := do
  let mut found := #[]
  for i in [:providers.size] do
    let stx ← ofExcept (Parser.runParserCategory (← getEnv) `term
      ("(" ++ providers[i]! ++ ").sig " ++ (toJson name).compress))
    let e ← elabTerm stx none
    synthesizeSyntheticMVarsNoPostponing
    let e ← whnf (← instantiateMVars e)
    if e.isAppOf ``Option.some then found := found.push i
  return found
private def providers : Array String := #["StandardHeadTail.builtins","StandardCollectionRefinedBodies.builtins","StandardScalarResponse.table ModelTargets.builtins","StandardByteStringResponse.table ModelTargets.builtins","StandardCharacterResponse.table ModelTargets.builtins","StandardStringOrdinaryResponse.table ModelTargets.builtins","StandardBytesOrdinaryResponse.table ModelTargets.builtins","StandardBytesResponse.table ModelTargets.builtins","StandardListRemainingResponse.table ModelTargets.builtins","StandardListResponse.table ModelTargets.builtins","StandardNumericRemainingResponse.table ModelTargets.builtins","StandardIntegerAPI.table ModelTargets.builtins","StandardIntegerTextResponse.table ModelTargets.builtins","StandardConversionResponse.table ModelTargets.builtins","StandardArithmeticResponse.table ModelTargets.builtins","StandardDecimalResponse.table ModelTargets.builtins","StandardFloatMathResponse.table ModelTargets.builtins","StandardIntegerResponse.minMaxTable ModelTargets.builtins","StandardOperatorResponse.table ModelTargets.builtins","StandardOrderResponse.table ModelTargets.builtins","StandardStructuralEqualityResponse.table ModelTargets.builtins","StandardActualListBodies.builtins","StandardCollectionModel.builtins","ModelTargets.builtins","ModelHttp.builtins","Model.builtins"]

run_cmd do
  let found ← liftTermElabM (findProvider "%Byte.greater" providers)
  logInfo m!"PROVIDER %Byte.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Byte.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Byte.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Byte.less" providers)
  logInfo m!"PROVIDER %Byte.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Byte.lessOrEqual" providers)
  logInfo m!"PROVIDER %Byte.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Character.greater" providers)
  logInfo m!"PROVIDER %Character.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Character.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Character.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Character.less" providers)
  logInfo m!"PROVIDER %Character.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Character.lessOrEqual" providers)
  logInfo m!"PROVIDER %Character.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.add" providers)
  logInfo m!"PROVIDER %Decimal.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.divide" providers)
  logInfo m!"PROVIDER %Decimal.divide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.greater" providers)
  logInfo m!"PROVIDER %Decimal.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Decimal.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.less" providers)
  logInfo m!"PROVIDER %Decimal.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.lessOrEqual" providers)
  logInfo m!"PROVIDER %Decimal.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.multiply" providers)
  logInfo m!"PROVIDER %Decimal.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.negate" providers)
  logInfo m!"PROVIDER %Decimal.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Decimal.subtract" providers)
  logInfo m!"PROVIDER %Decimal.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.add" providers)
  logInfo m!"PROVIDER %Float.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.divide" providers)
  logInfo m!"PROVIDER %Float.divide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.greater" providers)
  logInfo m!"PROVIDER %Float.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Float.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.less" providers)
  logInfo m!"PROVIDER %Float.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.lessOrEqual" providers)
  logInfo m!"PROVIDER %Float.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.multiply" providers)
  logInfo m!"PROVIDER %Float.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.negate" providers)
  logInfo m!"PROVIDER %Float.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float.subtract" providers)
  logInfo m!"PROVIDER %Float.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.add" providers)
  logInfo m!"PROVIDER %Float32.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.divide" providers)
  logInfo m!"PROVIDER %Float32.divide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.greater" providers)
  logInfo m!"PROVIDER %Float32.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Float32.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.less" providers)
  logInfo m!"PROVIDER %Float32.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.lessOrEqual" providers)
  logInfo m!"PROVIDER %Float32.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.multiply" providers)
  logInfo m!"PROVIDER %Float32.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.negate" providers)
  logInfo m!"PROVIDER %Float32.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Float32.subtract" providers)
  logInfo m!"PROVIDER %Float32.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.add" providers)
  logInfo m!"PROVIDER %Integer.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.div" providers)
  logInfo m!"PROVIDER %Integer.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.greater" providers)
  logInfo m!"PROVIDER %Integer.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Integer.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.less" providers)
  logInfo m!"PROVIDER %Integer.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.lessOrEqual" providers)
  logInfo m!"PROVIDER %Integer.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.mod" providers)
  logInfo m!"PROVIDER %Integer.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.multiply" providers)
  logInfo m!"PROVIDER %Integer.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.negate" providers)
  logInfo m!"PROVIDER %Integer.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer.subtract" providers)
  logInfo m!"PROVIDER %Integer.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.add" providers)
  logInfo m!"PROVIDER %Integer16.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.div" providers)
  logInfo m!"PROVIDER %Integer16.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.greater" providers)
  logInfo m!"PROVIDER %Integer16.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Integer16.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.less" providers)
  logInfo m!"PROVIDER %Integer16.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.lessOrEqual" providers)
  logInfo m!"PROVIDER %Integer16.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.mod" providers)
  logInfo m!"PROVIDER %Integer16.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.multiply" providers)
  logInfo m!"PROVIDER %Integer16.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.negate" providers)
  logInfo m!"PROVIDER %Integer16.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer16.subtract" providers)
  logInfo m!"PROVIDER %Integer16.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.add" providers)
  logInfo m!"PROVIDER %Integer32.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.div" providers)
  logInfo m!"PROVIDER %Integer32.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.greater" providers)
  logInfo m!"PROVIDER %Integer32.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Integer32.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.less" providers)
  logInfo m!"PROVIDER %Integer32.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.lessOrEqual" providers)
  logInfo m!"PROVIDER %Integer32.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.mod" providers)
  logInfo m!"PROVIDER %Integer32.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.multiply" providers)
  logInfo m!"PROVIDER %Integer32.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.negate" providers)
  logInfo m!"PROVIDER %Integer32.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer32.subtract" providers)
  logInfo m!"PROVIDER %Integer32.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.add" providers)
  logInfo m!"PROVIDER %Integer8.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.div" providers)
  logInfo m!"PROVIDER %Integer8.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.greater" providers)
  logInfo m!"PROVIDER %Integer8.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.greaterOrEqual" providers)
  logInfo m!"PROVIDER %Integer8.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.less" providers)
  logInfo m!"PROVIDER %Integer8.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.lessOrEqual" providers)
  logInfo m!"PROVIDER %Integer8.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.mod" providers)
  logInfo m!"PROVIDER %Integer8.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.multiply" providers)
  logInfo m!"PROVIDER %Integer8.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.negate" providers)
  logInfo m!"PROVIDER %Integer8.negate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Integer8.subtract" providers)
  logInfo m!"PROVIDER %Integer8.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%Map.replaceValues" providers)
  logInfo m!"PROVIDER %Map.replaceValues {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%String.add" providers)
  logInfo m!"PROVIDER %String.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%String.greater" providers)
  logInfo m!"PROVIDER %String.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%String.greaterOrEqual" providers)
  logInfo m!"PROVIDER %String.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%String.less" providers)
  logInfo m!"PROVIDER %String.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%String.lessOrEqual" providers)
  logInfo m!"PROVIDER %String.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.add" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.div" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.greater" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.greaterOrEqual" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.less" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.lessOrEqual" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.mod" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.multiply" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger16.subtract" providers)
  logInfo m!"PROVIDER %UnsignedInteger16.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.add" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.div" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.greater" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.greaterOrEqual" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.less" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.lessOrEqual" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.mod" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.multiply" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger32.subtract" providers)
  logInfo m!"PROVIDER %UnsignedInteger32.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.add" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.div" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.div {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.greater" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.greater {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.greaterOrEqual" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.greaterOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.less" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.less {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.lessOrEqual" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.lessOrEqual {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.mod" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.mod {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.multiply" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.multiply {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%UnsignedInteger64.subtract" providers)
  logInfo m!"PROVIDER %UnsignedInteger64.subtract {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%eq" providers)
  logInfo m!"PROVIDER %eq {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "%ne" providers)
  logInfo m!"PROVIDER %ne {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.bitwiseAnd" providers)
  logInfo m!"PROVIDER Byte.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER Byte.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.bitwiseNot" providers)
  logInfo m!"PROVIDER Byte.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.bitwiseOr" providers)
  logInfo m!"PROVIDER Byte.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.fromInteger" providers)
  logInfo m!"PROVIDER Byte.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.shiftLeft" providers)
  logInfo m!"PROVIDER Byte.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.shiftRight" providers)
  logInfo m!"PROVIDER Byte.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.toInteger" providers)
  logInfo m!"PROVIDER Byte.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Byte.toString" providers)
  logInfo m!"PROVIDER Byte.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.concatenate" providers)
  logInfo m!"PROVIDER Bytes.concatenate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.empty" providers)
  logInfo m!"PROVIDER Bytes.empty {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.fromBinary" providers)
  logInfo m!"PROVIDER Bytes.fromBinary {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.fromHex" providers)
  logInfo m!"PROVIDER Bytes.fromHex {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.fromIntegers" providers)
  logInfo m!"PROVIDER Bytes.fromIntegers {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.fromList" providers)
  logInfo m!"PROVIDER Bytes.fromList {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.fromSigned" providers)
  logInfo m!"PROVIDER Bytes.fromSigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.fromUnsigned" providers)
  logInfo m!"PROVIDER Bytes.fromUnsigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.get" providers)
  logInfo m!"PROVIDER Bytes.get {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.length" providers)
  logInfo m!"PROVIDER Bytes.length {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.readSigned" providers)
  logInfo m!"PROVIDER Bytes.readSigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.readUnsigned" providers)
  logInfo m!"PROVIDER Bytes.readUnsigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.slice" providers)
  logInfo m!"PROVIDER Bytes.slice {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.toBinary" providers)
  logInfo m!"PROVIDER Bytes.toBinary {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.toHex" providers)
  logInfo m!"PROVIDER Bytes.toHex {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Bytes.toList" providers)
  logInfo m!"PROVIDER Bytes.toList {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.fromInteger" providers)
  logInfo m!"PROVIDER Character.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isASCIIDigit" providers)
  logInfo m!"PROVIDER Character.isASCIIDigit {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isASCIIWhitespace" providers)
  logInfo m!"PROVIDER Character.isASCIIWhitespace {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isAlphabetic" providers)
  logInfo m!"PROVIDER Character.isAlphabetic {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isLowercase" providers)
  logInfo m!"PROVIDER Character.isLowercase {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isNumeric" providers)
  logInfo m!"PROVIDER Character.isNumeric {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isUppercase" providers)
  logInfo m!"PROVIDER Character.isUppercase {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.isWhitespace" providers)
  logInfo m!"PROVIDER Character.isWhitespace {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.toInteger" providers)
  logInfo m!"PROVIDER Character.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.toLowercase" providers)
  logInfo m!"PROVIDER Character.toLowercase {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.toString" providers)
  logInfo m!"PROVIDER Character.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Character.toUppercase" providers)
  logInfo m!"PROVIDER Character.toUppercase {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.absolute" providers)
  logInfo m!"PROVIDER Decimal.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.fromFloat" providers)
  logInfo m!"PROVIDER Decimal.fromFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.fromInteger" providers)
  logInfo m!"PROVIDER Decimal.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.parse" providers)
  logInfo m!"PROVIDER Decimal.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.round" providers)
  logInfo m!"PROVIDER Decimal.round {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.toFloat" providers)
  logInfo m!"PROVIDER Decimal.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.toString" providers)
  logInfo m!"PROVIDER Decimal.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Decimal.truncate" providers)
  logInfo m!"PROVIDER Decimal.truncate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Example.pathBases" providers)
  logInfo m!"PROVIDER Example.pathBases {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.appendBytesIn" providers)
  logInfo m!"PROVIDER File.appendBytesIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.appendTextIn" providers)
  logInfo m!"PROVIDER File.appendTextIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.readBytesIn" providers)
  logInfo m!"PROVIDER File.readBytesIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.readText" providers)
  logInfo m!"PROVIDER File.readText {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.readTextIn" providers)
  logInfo m!"PROVIDER File.readTextIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.writeBytesIn" providers)
  logInfo m!"PROVIDER File.writeBytesIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "File.writeTextIn" providers)
  logInfo m!"PROVIDER File.writeTextIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.absolute" providers)
  logInfo m!"PROVIDER Float.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.ceiling" providers)
  logInfo m!"PROVIDER Float.ceiling {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.floor" providers)
  logInfo m!"PROVIDER Float.floor {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.isNaN" providers)
  logInfo m!"PROVIDER Float.isNaN {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.parse" providers)
  logInfo m!"PROVIDER Float.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.round" providers)
  logInfo m!"PROVIDER Float.round {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.squareRoot" providers)
  logInfo m!"PROVIDER Float.squareRoot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.toString" providers)
  logInfo m!"PROVIDER Float.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float.truncate" providers)
  logInfo m!"PROVIDER Float.truncate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.absolute" providers)
  logInfo m!"PROVIDER Float32.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.ceiling" providers)
  logInfo m!"PROVIDER Float32.ceiling {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.floor" providers)
  logInfo m!"PROVIDER Float32.floor {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.fromFloat" providers)
  logInfo m!"PROVIDER Float32.fromFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.isInfinite" providers)
  logInfo m!"PROVIDER Float32.isInfinite {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.isNaN" providers)
  logInfo m!"PROVIDER Float32.isNaN {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.parse" providers)
  logInfo m!"PROVIDER Float32.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.round" providers)
  logInfo m!"PROVIDER Float32.round {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.squareRoot" providers)
  logInfo m!"PROVIDER Float32.squareRoot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.toFloat" providers)
  logInfo m!"PROVIDER Float32.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.toString" providers)
  logInfo m!"PROVIDER Float32.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Float32.truncate" providers)
  logInfo m!"PROVIDER Float32.truncate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Http.checkRequestIn" providers)
  logInfo m!"PROVIDER Http.checkRequestIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Http.requestInValue" providers)
  logInfo m!"PROVIDER Http.requestInValue {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Http.sendIn" providers)
  logInfo m!"PROVIDER Http.sendIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Http.widenRequestIn" providers)
  logInfo m!"PROVIDER Http.widenRequestIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.absolute" providers)
  logInfo m!"PROVIDER Integer.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.bitwiseAnd" providers)
  logInfo m!"PROVIDER Integer.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER Integer.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.bitwiseNot" providers)
  logInfo m!"PROVIDER Integer.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.bitwiseOr" providers)
  logInfo m!"PROVIDER Integer.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.floorDivide" providers)
  logInfo m!"PROVIDER Integer.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.floorModulo" providers)
  logInfo m!"PROVIDER Integer.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.maximum" providers)
  logInfo m!"PROVIDER Integer.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.minimum" providers)
  logInfo m!"PROVIDER Integer.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.parse" providers)
  logInfo m!"PROVIDER Integer.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.shiftLeft" providers)
  logInfo m!"PROVIDER Integer.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.shiftRight" providers)
  logInfo m!"PROVIDER Integer.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.shiftRightUnsigned" providers)
  logInfo m!"PROVIDER Integer.shiftRightUnsigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.toFloat" providers)
  logInfo m!"PROVIDER Integer.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer.toString" providers)
  logInfo m!"PROVIDER Integer.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.absolute" providers)
  logInfo m!"PROVIDER Integer16.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.bitwiseAnd" providers)
  logInfo m!"PROVIDER Integer16.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER Integer16.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.bitwiseNot" providers)
  logInfo m!"PROVIDER Integer16.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.bitwiseOr" providers)
  logInfo m!"PROVIDER Integer16.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.floorDivide" providers)
  logInfo m!"PROVIDER Integer16.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.floorModulo" providers)
  logInfo m!"PROVIDER Integer16.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.fromInteger" providers)
  logInfo m!"PROVIDER Integer16.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.maximum" providers)
  logInfo m!"PROVIDER Integer16.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.minimum" providers)
  logInfo m!"PROVIDER Integer16.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.parse" providers)
  logInfo m!"PROVIDER Integer16.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.shiftLeft" providers)
  logInfo m!"PROVIDER Integer16.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.shiftRight" providers)
  logInfo m!"PROVIDER Integer16.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.shiftRightUnsigned" providers)
  logInfo m!"PROVIDER Integer16.shiftRightUnsigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.toFloat" providers)
  logInfo m!"PROVIDER Integer16.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.toInteger" providers)
  logInfo m!"PROVIDER Integer16.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer16.toString" providers)
  logInfo m!"PROVIDER Integer16.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.absolute" providers)
  logInfo m!"PROVIDER Integer32.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.bitwiseAnd" providers)
  logInfo m!"PROVIDER Integer32.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER Integer32.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.bitwiseNot" providers)
  logInfo m!"PROVIDER Integer32.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.bitwiseOr" providers)
  logInfo m!"PROVIDER Integer32.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.floorDivide" providers)
  logInfo m!"PROVIDER Integer32.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.floorModulo" providers)
  logInfo m!"PROVIDER Integer32.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.fromInteger" providers)
  logInfo m!"PROVIDER Integer32.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.maximum" providers)
  logInfo m!"PROVIDER Integer32.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.minimum" providers)
  logInfo m!"PROVIDER Integer32.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.parse" providers)
  logInfo m!"PROVIDER Integer32.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.shiftLeft" providers)
  logInfo m!"PROVIDER Integer32.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.shiftRight" providers)
  logInfo m!"PROVIDER Integer32.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.shiftRightUnsigned" providers)
  logInfo m!"PROVIDER Integer32.shiftRightUnsigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.toFloat" providers)
  logInfo m!"PROVIDER Integer32.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.toInteger" providers)
  logInfo m!"PROVIDER Integer32.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer32.toString" providers)
  logInfo m!"PROVIDER Integer32.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.absolute" providers)
  logInfo m!"PROVIDER Integer8.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.bitwiseAnd" providers)
  logInfo m!"PROVIDER Integer8.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER Integer8.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.bitwiseNot" providers)
  logInfo m!"PROVIDER Integer8.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.bitwiseOr" providers)
  logInfo m!"PROVIDER Integer8.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.floorDivide" providers)
  logInfo m!"PROVIDER Integer8.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.floorModulo" providers)
  logInfo m!"PROVIDER Integer8.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.fromInteger" providers)
  logInfo m!"PROVIDER Integer8.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.maximum" providers)
  logInfo m!"PROVIDER Integer8.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.minimum" providers)
  logInfo m!"PROVIDER Integer8.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.parse" providers)
  logInfo m!"PROVIDER Integer8.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.shiftLeft" providers)
  logInfo m!"PROVIDER Integer8.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.shiftRight" providers)
  logInfo m!"PROVIDER Integer8.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.shiftRightUnsigned" providers)
  logInfo m!"PROVIDER Integer8.shiftRightUnsigned {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.toFloat" providers)
  logInfo m!"PROVIDER Integer8.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.toInteger" providers)
  logInfo m!"PROVIDER Integer8.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Integer8.toString" providers)
  logInfo m!"PROVIDER Integer8.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.append" providers)
  logInfo m!"PROVIDER List.append {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.concatenate" providers)
  logInfo m!"PROVIDER List.concatenate {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.contains" providers)
  logInfo m!"PROVIDER List.contains {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.drop" providers)
  logInfo m!"PROVIDER List.drop {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.get" providers)
  logInfo m!"PROVIDER List.get {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.head" providers)
  logInfo m!"PROVIDER List.head {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.isEmpty" providers)
  logInfo m!"PROVIDER List.isEmpty {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.length" providers)
  logInfo m!"PROVIDER List.length {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.prepend" providers)
  logInfo m!"PROVIDER List.prepend {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.range" providers)
  logInfo m!"PROVIDER List.range {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.reverse" providers)
  logInfo m!"PROVIDER List.reverse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.sort" providers)
  logInfo m!"PROVIDER List.sort {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.tail" providers)
  logInfo m!"PROVIDER List.tail {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "List.take" providers)
  logInfo m!"PROVIDER List.take {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.contains" providers)
  logInfo m!"PROVIDER Map.contains {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.empty" providers)
  logInfo m!"PROVIDER Map.empty {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.fromList" providers)
  logInfo m!"PROVIDER Map.fromList {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.get" providers)
  logInfo m!"PROVIDER Map.get {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.keys" providers)
  logInfo m!"PROVIDER Map.keys {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.remove" providers)
  logInfo m!"PROVIDER Map.remove {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.set" providers)
  logInfo m!"PROVIDER Map.set {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.size" providers)
  logInfo m!"PROVIDER Map.size {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.toList" providers)
  logInfo m!"PROVIDER Map.toList {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Map.values" providers)
  logInfo m!"PROVIDER Map.values {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Reference.get" providers)
  logInfo m!"PROVIDER Reference.get {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Reference.set" providers)
  logInfo m!"PROVIDER Reference.set {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Scope.checkPathIn" providers)
  logInfo m!"PROVIDER Scope.checkPathIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Scope.pathInValue" providers)
  logInfo m!"PROVIDER Scope.pathInValue {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Scope.widenPathIn" providers)
  logInfo m!"PROVIDER Scope.widenPathIn {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.add" providers)
  logInfo m!"PROVIDER Set.add {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.contains" providers)
  logInfo m!"PROVIDER Set.contains {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.difference" providers)
  logInfo m!"PROVIDER Set.difference {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.empty" providers)
  logInfo m!"PROVIDER Set.empty {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.fromList" providers)
  logInfo m!"PROVIDER Set.fromList {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.intersection" providers)
  logInfo m!"PROVIDER Set.intersection {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.remove" providers)
  logInfo m!"PROVIDER Set.remove {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.size" providers)
  logInfo m!"PROVIDER Set.size {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.toList" providers)
  logInfo m!"PROVIDER Set.toList {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "Set.union" providers)
  logInfo m!"PROVIDER Set.union {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.byteIndexOf" providers)
  logInfo m!"PROVIDER String.byteIndexOf {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.byteLength" providers)
  logInfo m!"PROVIDER String.byteLength {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.byteSlice" providers)
  logInfo m!"PROVIDER String.byteSlice {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.characterAt" providers)
  logInfo m!"PROVIDER String.characterAt {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.characterCount" providers)
  logInfo m!"PROVIDER String.characterCount {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.characterSlice" providers)
  logInfo m!"PROVIDER String.characterSlice {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.characters" providers)
  logInfo m!"PROVIDER String.characters {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.contains" providers)
  logInfo m!"PROVIDER String.contains {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.displayWidth" providers)
  logInfo m!"PROVIDER String.displayWidth {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.displayWidthCJK" providers)
  logInfo m!"PROVIDER String.displayWidthCJK {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.displayWidthPadEnd" providers)
  logInfo m!"PROVIDER String.displayWidthPadEnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.displayWidthPadEndCJK" providers)
  logInfo m!"PROVIDER String.displayWidthPadEndCJK {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.displayWidthPadStart" providers)
  logInfo m!"PROVIDER String.displayWidthPadStart {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.displayWidthPadStartCJK" providers)
  logInfo m!"PROVIDER String.displayWidthPadStartCJK {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.endsWith" providers)
  logInfo m!"PROVIDER String.endsWith {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.fromCharacters" providers)
  logInfo m!"PROVIDER String.fromCharacters {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.fromUTF8" providers)
  logInfo m!"PROVIDER String.fromUTF8 {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.isEmpty" providers)
  logInfo m!"PROVIDER String.isEmpty {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.join" providers)
  logInfo m!"PROVIDER String.join {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.lines" providers)
  logInfo m!"PROVIDER String.lines {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.repeat" providers)
  logInfo m!"PROVIDER String.repeat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.replace" providers)
  logInfo m!"PROVIDER String.replace {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.split" providers)
  logInfo m!"PROVIDER String.split {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.startsWith" providers)
  logInfo m!"PROVIDER String.startsWith {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.toLowercase" providers)
  logInfo m!"PROVIDER String.toLowercase {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.toUTF8" providers)
  logInfo m!"PROVIDER String.toUTF8 {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.toUppercase" providers)
  logInfo m!"PROVIDER String.toUppercase {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "String.trim" providers)
  logInfo m!"PROVIDER String.trim {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.absolute" providers)
  logInfo m!"PROVIDER UnsignedInteger16.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.bitwiseAnd" providers)
  logInfo m!"PROVIDER UnsignedInteger16.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER UnsignedInteger16.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.bitwiseNot" providers)
  logInfo m!"PROVIDER UnsignedInteger16.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.bitwiseOr" providers)
  logInfo m!"PROVIDER UnsignedInteger16.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.floorDivide" providers)
  logInfo m!"PROVIDER UnsignedInteger16.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.floorModulo" providers)
  logInfo m!"PROVIDER UnsignedInteger16.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.fromInteger" providers)
  logInfo m!"PROVIDER UnsignedInteger16.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.maximum" providers)
  logInfo m!"PROVIDER UnsignedInteger16.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.minimum" providers)
  logInfo m!"PROVIDER UnsignedInteger16.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.parse" providers)
  logInfo m!"PROVIDER UnsignedInteger16.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.shiftLeft" providers)
  logInfo m!"PROVIDER UnsignedInteger16.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.shiftRight" providers)
  logInfo m!"PROVIDER UnsignedInteger16.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.toFloat" providers)
  logInfo m!"PROVIDER UnsignedInteger16.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.toInteger" providers)
  logInfo m!"PROVIDER UnsignedInteger16.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger16.toString" providers)
  logInfo m!"PROVIDER UnsignedInteger16.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.absolute" providers)
  logInfo m!"PROVIDER UnsignedInteger32.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.bitwiseAnd" providers)
  logInfo m!"PROVIDER UnsignedInteger32.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER UnsignedInteger32.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.bitwiseNot" providers)
  logInfo m!"PROVIDER UnsignedInteger32.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.bitwiseOr" providers)
  logInfo m!"PROVIDER UnsignedInteger32.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.floorDivide" providers)
  logInfo m!"PROVIDER UnsignedInteger32.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.floorModulo" providers)
  logInfo m!"PROVIDER UnsignedInteger32.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.fromInteger" providers)
  logInfo m!"PROVIDER UnsignedInteger32.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.maximum" providers)
  logInfo m!"PROVIDER UnsignedInteger32.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.minimum" providers)
  logInfo m!"PROVIDER UnsignedInteger32.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.parse" providers)
  logInfo m!"PROVIDER UnsignedInteger32.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.shiftLeft" providers)
  logInfo m!"PROVIDER UnsignedInteger32.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.shiftRight" providers)
  logInfo m!"PROVIDER UnsignedInteger32.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.toFloat" providers)
  logInfo m!"PROVIDER UnsignedInteger32.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.toInteger" providers)
  logInfo m!"PROVIDER UnsignedInteger32.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger32.toString" providers)
  logInfo m!"PROVIDER UnsignedInteger32.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.absolute" providers)
  logInfo m!"PROVIDER UnsignedInteger64.absolute {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.bitwiseAnd" providers)
  logInfo m!"PROVIDER UnsignedInteger64.bitwiseAnd {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.bitwiseExclusiveOr" providers)
  logInfo m!"PROVIDER UnsignedInteger64.bitwiseExclusiveOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.bitwiseNot" providers)
  logInfo m!"PROVIDER UnsignedInteger64.bitwiseNot {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.bitwiseOr" providers)
  logInfo m!"PROVIDER UnsignedInteger64.bitwiseOr {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.floorDivide" providers)
  logInfo m!"PROVIDER UnsignedInteger64.floorDivide {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.floorModulo" providers)
  logInfo m!"PROVIDER UnsignedInteger64.floorModulo {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.fromDecimal" providers)
  logInfo m!"PROVIDER UnsignedInteger64.fromDecimal {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.fromInteger" providers)
  logInfo m!"PROVIDER UnsignedInteger64.fromInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.maximum" providers)
  logInfo m!"PROVIDER UnsignedInteger64.maximum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.minimum" providers)
  logInfo m!"PROVIDER UnsignedInteger64.minimum {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.parse" providers)
  logInfo m!"PROVIDER UnsignedInteger64.parse {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.shiftLeft" providers)
  logInfo m!"PROVIDER UnsignedInteger64.shiftLeft {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.shiftRight" providers)
  logInfo m!"PROVIDER UnsignedInteger64.shiftRight {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.toDecimal" providers)
  logInfo m!"PROVIDER UnsignedInteger64.toDecimal {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.toFloat" providers)
  logInfo m!"PROVIDER UnsignedInteger64.toFloat {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.toInteger" providers)
  logInfo m!"PROVIDER UnsignedInteger64.toInteger {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "UnsignedInteger64.toString" providers)
  logInfo m!"PROVIDER UnsignedInteger64.toString {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "exit" providers)
  logInfo m!"PROVIDER exit {Json.compress (toJson found)}"
run_cmd do
  let found ← liftTermElabM (findProvider "print" providers)
  logInfo m!"PROVIDER print {Json.compress (toJson found)}"

open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let names := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if names.isEmpty then break
    for n in names do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      let deps ← Lean.collectAxioms n
      logInfo m!"'{n}' depends on axioms: [{String.intercalate ", " (deps.toList.map Name.toString)}]"
