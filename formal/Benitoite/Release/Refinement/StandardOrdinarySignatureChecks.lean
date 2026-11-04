import Benitoite.Release.Refinement.StandardNumericRemainingResponse
import Benitoite.Release.Refinement.StandardBytesOrdinaryResponse
import Benitoite.Release.Refinement.StandardStringOrdinaryResponse

/-! # 元ソースから抽出した純粋署名の独立な照合 -/
namespace Benitoite.Release.Refinement.StandardOrdinarySignatureChecks
noncomputable section
-- Byte.toString
example : (StandardByteStringResponse.signature) =
 ⟨[],0,["b"],[(.base .byte)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.toString
example : (StandardCharacterResponse.API.signature .toString) =
 ⟨[],0,["c"],[(.base .character)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isASCIIDigit
example : (StandardCharacterResponse.API.signature .isASCIIDigit) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isASCIIWhitespace
example : (StandardCharacterResponse.API.signature .isASCIIWhitespace) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isAlphabetic
example : (StandardCharacterResponse.API.signature .isAlphabetic) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isNumeric
example : (StandardCharacterResponse.API.signature .isNumeric) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isWhitespace
example : (StandardCharacterResponse.API.signature .isWhitespace) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isUppercase
example : (StandardCharacterResponse.API.signature .isUppercase) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.isLowercase
example : (StandardCharacterResponse.API.signature .isLowercase) =
 ⟨[],0,["c"],[(.base .character)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.toUppercase
example : (StandardCharacterResponse.API.signature .toUppercase) =
 ⟨[],0,["c"],[(.base .character)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Character.toLowercase
example : (StandardCharacterResponse.API.signature .toLowercase) =
 ⟨[],0,["c"],[(.base .character)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.toString
example : (StandardNumericRemainingResponse.API.signature .Float_toString) =
 ⟨[],0,["x"],[(.base .float)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.parse
example : (StandardNumericRemainingResponse.API.signature .Float_parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .float)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.truncate
example : (StandardFloatMathResponse.signature false .truncate) =
 ⟨[],0,["x"],[(.base .float)],(.data "Option" [(.base .integer)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.absolute
example : (StandardFloatMathResponse.signature false .absolute) =
 ⟨[],0,["x"],[(.base .float)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.floor
example : (StandardFloatMathResponse.signature false .floor) =
 ⟨[],0,["x"],[(.base .float)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.ceiling
example : (StandardFloatMathResponse.signature false .ceiling) =
 ⟨[],0,["x"],[(.base .float)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.round
example : (StandardFloatMathResponse.signature false .round) =
 ⟨[],0,["x"],[(.base .float)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float.squareRoot
example : (StandardFloatMathResponse.signature false .squareRoot) =
 ⟨[],0,["x"],[(.base .float)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.fromFloat
example : (StandardNumericRemainingResponse.API.signature .Float32_fromFloat) =
 ⟨[],0,["n"],[(.base .float)],(.data "Option" [(.base .float32)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.toFloat
example : (StandardNumericRemainingResponse.API.signature .Float32_toFloat) =
 ⟨[],0,["n"],[(.base .float32)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.parse
example : (StandardNumericRemainingResponse.API.signature .Float32_parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .float32)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.toString
example : (StandardNumericRemainingResponse.API.signature .Float32_toString) =
 ⟨[],0,["n"],[(.base .float32)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.truncate
example : (StandardFloatMathResponse.signature true .truncate) =
 ⟨[],0,["n"],[(.base .float32)],(.data "Option" [(.base .integer)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.absolute
example : (StandardFloatMathResponse.signature true .absolute) =
 ⟨[],0,["n"],[(.base .float32)],(.base .float32),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.floor
example : (StandardFloatMathResponse.signature true .floor) =
 ⟨[],0,["n"],[(.base .float32)],(.base .float32),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.ceiling
example : (StandardFloatMathResponse.signature true .ceiling) =
 ⟨[],0,["n"],[(.base .float32)],(.base .float32),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.round
example : (StandardFloatMathResponse.signature true .round) =
 ⟨[],0,["n"],[(.base .float32)],(.base .float32),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Float32.squareRoot
example : (StandardFloatMathResponse.signature true .squareRoot) =
 ⟨[],0,["n"],[(.base .float32)],(.base .float32),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Decimal.toFloat
example : (StandardNumericRemainingResponse.API.signature .Decimal_toFloat) =
 ⟨[],0,["x"],[(.base .decimal)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Decimal.fromFloat
example : (StandardNumericRemainingResponse.API.signature .Decimal_fromFloat) =
 ⟨[],0,["x"],[(.base .float)],(.data "Option" [(.base .decimal)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Decimal.toString
example : (StandardNumericRemainingResponse.API.signature .Decimal_toString) =
 ⟨[],0,["x"],[(.base .decimal)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Decimal.parse
example : (StandardNumericRemainingResponse.API.signature .Decimal_parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .decimal)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer.toString
example : (StandardIntegerTextResponse.signature .integer64 .toString) =
 ⟨[],0,["n"],[(.base .integer)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer.parse
example : (StandardIntegerTextResponse.signature .integer64 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .integer)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer.toFloat
example : (StandardIntegerTextResponse.signature .integer64 .toFloat) =
 ⟨[],0,["n"],[(.base .integer)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer8.parse
example : (StandardIntegerTextResponse.signature .integer8 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .integer8)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer8.toString
example : (StandardIntegerTextResponse.signature .integer8 .toString) =
 ⟨[],0,["n"],[(.base .integer8)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer8.toFloat
example : (StandardIntegerTextResponse.signature .integer8 .toFloat) =
 ⟨[],0,["n"],[(.base .integer8)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer16.parse
example : (StandardIntegerTextResponse.signature .integer16 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .integer16)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer16.toString
example : (StandardIntegerTextResponse.signature .integer16 .toString) =
 ⟨[],0,["n"],[(.base .integer16)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer16.toFloat
example : (StandardIntegerTextResponse.signature .integer16 .toFloat) =
 ⟨[],0,["n"],[(.base .integer16)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer32.parse
example : (StandardIntegerTextResponse.signature .integer32 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .integer32)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer32.toString
example : (StandardIntegerTextResponse.signature .integer32 .toString) =
 ⟨[],0,["n"],[(.base .integer32)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Integer32.toFloat
example : (StandardIntegerTextResponse.signature .integer32 .toFloat) =
 ⟨[],0,["n"],[(.base .integer32)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger16.parse
example : (StandardIntegerTextResponse.signature .unsignedInteger16 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .unsignedInteger16)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger16.toString
example : (StandardIntegerTextResponse.signature .unsignedInteger16 .toString) =
 ⟨[],0,["n"],[(.base .unsignedInteger16)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger16.toFloat
example : (StandardIntegerTextResponse.signature .unsignedInteger16 .toFloat) =
 ⟨[],0,["n"],[(.base .unsignedInteger16)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger32.parse
example : (StandardIntegerTextResponse.signature .unsignedInteger32 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .unsignedInteger32)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger32.toString
example : (StandardIntegerTextResponse.signature .unsignedInteger32 .toString) =
 ⟨[],0,["n"],[(.base .unsignedInteger32)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger32.toFloat
example : (StandardIntegerTextResponse.signature .unsignedInteger32 .toFloat) =
 ⟨[],0,["n"],[(.base .unsignedInteger32)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger64.parse
example : (StandardIntegerTextResponse.signature .unsignedInteger64 .parse) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [(.base .unsignedInteger64)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger64.toString
example : (StandardIntegerTextResponse.signature .unsignedInteger64 .toString) =
 ⟨[],0,["n"],[(.base .unsignedInteger64)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- UnsignedInteger64.toFloat
example : (StandardIntegerTextResponse.signature .unsignedInteger64 .toFloat) =
 ⟨[],0,["n"],[(.base .unsignedInteger64)],(.base .float),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.byteSlice
example : (StandardStringOrdinaryResponse.API.signature .byteSlice) =
 ⟨[],0,["s","start","stop"],[(.base .string),(.base .integer),(.base .integer)],(.data "Option" [(.base .string)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.characterAt
example : (StandardStringOrdinaryResponse.API.signature .characterAt) =
 ⟨[],0,["s","i"],[(.base .string),(.base .integer)],(.data "Option" [(.base .character)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.characterSlice
example : (StandardStringOrdinaryResponse.API.signature .characterSlice) =
 ⟨[],0,["s","start","stop"],[(.base .string),(.base .integer),(.base .integer)],(.data "Option" [(.base .string)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.isEmpty
example : (StandardStringOrdinaryResponse.API.signature .isEmpty) =
 ⟨[],0,["s"],[(.base .string)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.contains
example : (StandardStringOrdinaryResponse.API.signature .contains) =
 ⟨[],0,["s","part"],[(.base .string),(.base .string)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.startsWith
example : (StandardStringOrdinaryResponse.API.signature .startsWith) =
 ⟨[],0,["s","prefix"],[(.base .string),(.base .string)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.endsWith
example : (StandardStringOrdinaryResponse.API.signature .endsWith) =
 ⟨[],0,["s","suffix"],[(.base .string),(.base .string)],(.base .boolean),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.byteIndexOf
example : (StandardStringOrdinaryResponse.API.signature .byteIndexOf) =
 ⟨[],0,["s","part"],[(.base .string),(.base .string)],(.data "Option" [(.base .integer)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.split
example : (StandardStringOrdinaryResponse.API.signature .split) =
 ⟨[],0,["s","separator"],[(.base .string),(.base .string)],(.list (.base .string)),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.lines
example : (StandardStringOrdinaryResponse.API.signature .lines) =
 ⟨[],0,["s"],[(.base .string)],(.list (.base .string)),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.join
example : (StandardStringOrdinaryResponse.API.signature .join) =
 ⟨[],0,["xs","separator"],[(.list (.base .string)),(.base .string)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.trim
example : (StandardStringOrdinaryResponse.API.signature .trim) =
 ⟨[],0,["s"],[(.base .string)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.replace
example : (StandardStringOrdinaryResponse.API.signature .replace) =
 ⟨[],0,["s","old","new"],[(.base .string),(.base .string),(.base .string)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.repeat
example : (StandardStringOrdinaryResponse.API.signature .repeat) =
 ⟨[],0,["s","n"],[(.base .string),(.base .integer)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.characters
example : (StandardStringOrdinaryResponse.API.signature .characters) =
 ⟨[],0,["s"],[(.base .string)],(.list (.base .character)),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.fromCharacters
example : (StandardStringOrdinaryResponse.API.signature .fromCharacters) =
 ⟨[],0,["cs"],[(.list (.base .character))],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.toUppercase
example : (StandardStringOrdinaryResponse.API.signature .toUppercase) =
 ⟨[],0,["s"],[(.base .string)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.toLowercase
example : (StandardStringOrdinaryResponse.API.signature .toLowercase) =
 ⟨[],0,["s"],[(.base .string)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.toUTF8
example : (StandardStringOrdinaryResponse.API.signature .toUTF8) =
 ⟨[],0,["s"],[(.base .string)],.bytes,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.fromUTF8
example : (StandardStringOrdinaryResponse.API.signature .fromUTF8) =
 ⟨[],0,["b"],[.bytes],(.data "Option" [(.base .string)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.displayWidth
example : (StandardStringOrdinaryResponse.API.signature .displayWidth) =
 ⟨[],0,["s"],[(.base .string)],(.base .integer),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.displayWidthCJK
example : (StandardStringOrdinaryResponse.API.signature .displayWidthCJK) =
 ⟨[],0,["s"],[(.base .string)],(.base .integer),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.displayWidthPadStart
example : (StandardStringOrdinaryResponse.API.signature .displayWidthPadStart) =
 ⟨[],0,["s","width"],[(.base .string),(.base .integer)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.displayWidthPadEnd
example : (StandardStringOrdinaryResponse.API.signature .displayWidthPadEnd) =
 ⟨[],0,["s","width"],[(.base .string),(.base .integer)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.displayWidthPadStartCJK
example : (StandardStringOrdinaryResponse.API.signature .displayWidthPadStartCJK) =
 ⟨[],0,["s","width"],[(.base .string),(.base .integer)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- String.displayWidthPadEndCJK
example : (StandardStringOrdinaryResponse.API.signature .displayWidthPadEndCJK) =
 ⟨[],0,["s","width"],[(.base .string),(.base .integer)],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.empty
example : (StandardBytesOrdinaryResponse.API.signature .empty) =
 ⟨[],0,[],[],.bytes,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.fromIntegers
example : (StandardBytesOrdinaryResponse.API.signature .fromIntegers) =
 ⟨[],0,["ns"],[(.list (.base .integer))],(.data "Option" [.bytes]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.fromHex
example : (StandardBytesOrdinaryResponse.API.signature .fromHex) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [.bytes]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.fromBinary
example : (StandardBytesOrdinaryResponse.API.signature .fromBinary) =
 ⟨[],0,["s"],[(.base .string)],(.data "Option" [.bytes]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.toHex
example : (StandardBytesOrdinaryResponse.API.signature .toHex) =
 ⟨[],0,["b"],[.bytes],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.toBinary
example : (StandardBytesOrdinaryResponse.API.signature .toBinary) =
 ⟨[],0,["b"],[.bytes],(.base .string),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.get
example : (StandardBytesOrdinaryResponse.API.signature .get) =
 ⟨[],0,["b","i"],[.bytes,(.base .integer)],(.data "Option" [(.base .byte)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.slice
example : (StandardBytesOrdinaryResponse.API.signature .slice) =
 ⟨[],0,["b","start","stop"],[.bytes,(.base .integer),(.base .integer)],(.data "Option" [.bytes]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.concatenate
example : (StandardBytesOrdinaryResponse.API.signature .concatenate) =
 ⟨[],0,["a","b"],[.bytes,.bytes],.bytes,Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.readUnsigned
example : (StandardBytesOrdinaryResponse.API.signature .readUnsigned) =
 ⟨[],0,["b","offset","count","order"],[.bytes,(.base .integer),(.base .integer),(.data "ByteOrder" [])],(.data "Option" [(.base .integer)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.readSigned
example : (StandardBytesOrdinaryResponse.API.signature .readSigned) =
 ⟨[],0,["b","offset","count","order"],[.bytes,(.base .integer),(.base .integer),(.data "ByteOrder" [])],(.data "Option" [(.base .integer)]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.fromUnsigned
example : (StandardBytesOrdinaryResponse.API.signature .fromUnsigned) =
 ⟨[],0,["n","count","order"],[(.base .integer),(.base .integer),(.data "ByteOrder" [])],(.data "Option" [.bytes]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
-- Bytes.fromSigned
example : (StandardBytesOrdinaryResponse.API.signature .fromSigned) =
 ⟨[],0,["n","count","order"],[(.base .integer),(.base .integer),(.data "ByteOrder" [])],(.data "Option" [.bytes]),Eff.empty,
  (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩ := rfl
end
end Benitoite.Release.Refinement.StandardOrdinarySignatureChecks

