import Benitoite.Release.Refinement.StandardActualListBodies

/-! # 標準ソースの原署名と具体の純粋応答表の対応 -/
namespace Benitoite.Release.Refinement.StandardSignatureExamples

-- Byte.fromInteger: public function fromInteger(n: Integer) -> Option[Byte]
example : (StandardScalarResponse.API.signature .byteFrom) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .byte)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteFrom = "Byte.fromInteger" := ⟨rfl,rfl⟩

-- Byte.toInteger: public function toInteger(b: Byte) -> Integer
example : (StandardScalarResponse.API.signature .byteTo) = (⟨[],0,["b"],[(.base .byte)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteTo = "Byte.toInteger" := ⟨rfl,rfl⟩

-- Byte.bitwiseAnd: public function bitwiseAnd(a: Byte, b: Byte) -> Byte
example : (StandardScalarResponse.API.signature .byteAnd) = (⟨[],0,["a","b"],[(.base .byte),(.base .byte)],(.base .byte),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteAnd = "Byte.bitwiseAnd" := ⟨rfl,rfl⟩

-- Byte.bitwiseOr: public function bitwiseOr(a: Byte, b: Byte) -> Byte
example : (StandardScalarResponse.API.signature .byteOr) = (⟨[],0,["a","b"],[(.base .byte),(.base .byte)],(.base .byte),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteOr = "Byte.bitwiseOr" := ⟨rfl,rfl⟩

-- Byte.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: Byte, b: Byte) -> Byte
example : (StandardScalarResponse.API.signature .byteXor) = (⟨[],0,["a","b"],[(.base .byte),(.base .byte)],(.base .byte),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteXor = "Byte.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- Byte.bitwiseNot: public function bitwiseNot(a: Byte) -> Byte
example : (StandardScalarResponse.API.signature .byteNot) = (⟨[],0,["a"],[(.base .byte)],(.base .byte),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteNot = "Byte.bitwiseNot" := ⟨rfl,rfl⟩

-- Byte.shiftLeft: public function shiftLeft(a: Byte, n: Integer) -> Byte
example : (StandardScalarResponse.API.signature .byteLeft) = (⟨[],0,["a","n"],[(.base .byte),(.base .integer)],(.base .byte),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteLeft = "Byte.shiftLeft" := ⟨rfl,rfl⟩

-- Byte.shiftRight: public function shiftRight(a: Byte, n: Integer) -> Byte
example : (StandardScalarResponse.API.signature .byteRight) = (⟨[],0,["a","n"],[(.base .byte),(.base .integer)],(.base .byte),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .byteRight = "Byte.shiftRight" := ⟨rfl,rfl⟩

-- Character.toInteger: public function toInteger(c: Character) -> Integer
example : (StandardScalarResponse.API.signature .characterTo) = (⟨[],0,["c"],[(.base .character)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .characterTo = "Character.toInteger" := ⟨rfl,rfl⟩

-- Character.fromInteger: public function fromInteger(n: Integer) -> Option[Character]
example : (StandardScalarResponse.API.signature .characterFrom) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .character)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .characterFrom = "Character.fromInteger" := ⟨rfl,rfl⟩

-- Float.isNaN: public function isNaN(x: Float) -> Boolean
example : (StandardScalarResponse.API.signature .floatNaN) = (⟨[],0,["x"],[(.base .float)],(.base .boolean),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .floatNaN = "Float.isNaN" := ⟨rfl,rfl⟩

-- Float32.isNaN: public function isNaN(n: Float32) -> Boolean
example : (StandardScalarResponse.API.signature .float32NaN) = (⟨[],0,["n"],[(.base .float32)],(.base .boolean),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .float32NaN = "Float32.isNaN" := ⟨rfl,rfl⟩

-- Float32.isInfinite: public function isInfinite(n: Float32) -> Boolean
example : (StandardScalarResponse.API.signature .float32Infinite) = (⟨[],0,["n"],[(.base .float32)],(.base .boolean),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardScalarResponse.API.name .float32Infinite = "Float32.isInfinite" := ⟨rfl,rfl⟩

-- Decimal.round: public function round(x: Decimal, places: Integer, mode: RoundingMode) -> Decimal
example : (StandardDecimalResponse.API.signature .round) = (⟨[],0,["x","places","mode"],[(.base .decimal),(.base .integer),(.data "RoundingMode" [])],(.base .decimal),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardDecimalResponse.API.name .round = "Decimal.round" := ⟨rfl,rfl⟩

-- Decimal.absolute: public function absolute(x: Decimal) -> Decimal
example : (StandardDecimalResponse.API.signature .absolute) = (⟨[],0,["x"],[(.base .decimal)],(.base .decimal),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardDecimalResponse.API.name .absolute = "Decimal.absolute" := ⟨rfl,rfl⟩

-- Decimal.fromInteger: public function fromInteger(n: Integer) -> Decimal
example : (StandardDecimalResponse.API.signature .fromInteger) = (⟨[],0,["n"],[(.base .integer)],(.base .decimal),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardDecimalResponse.API.name .fromInteger = "Decimal.fromInteger" := ⟨rfl,rfl⟩

-- Decimal.truncate: public function truncate(x: Decimal) -> Option[Integer]
example : (StandardDecimalResponse.API.signature .truncate) = (⟨[],0,["x"],[(.base .decimal)],(.data "Option" [(.base .integer)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardDecimalResponse.API.name .truncate = "Decimal.truncate" := ⟨rfl,rfl⟩

-- String.byteLength: public function byteLength(s: String) -> Integer
example : (StandardBytesResponse.API.signature .stringBytes) = (⟨[],0,["s"],[(.base .string)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardBytesResponse.API.name .stringBytes = "String.byteLength" := ⟨rfl,rfl⟩

-- String.characterCount: public function characterCount(s: String) -> Integer
example : (StandardBytesResponse.API.signature .stringCharacters) = (⟨[],0,["s"],[(.base .string)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardBytesResponse.API.name .stringCharacters = "String.characterCount" := ⟨rfl,rfl⟩

-- Bytes.fromList: public function fromList(bs: List[Byte]) -> Bytes
example : (StandardBytesResponse.API.signature .bytesFromList) = (⟨[],0,["bs"],[(.list (.base .byte))],.bytes,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardBytesResponse.API.name .bytesFromList = "Bytes.fromList" := ⟨rfl,rfl⟩

-- Bytes.toList: public function toList(b: Bytes) -> List[Byte]
example : (StandardBytesResponse.API.signature .bytesToList) = (⟨[],0,["b"],[.bytes],(.list (.base .byte)),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardBytesResponse.API.name .bytesToList = "Bytes.toList" := ⟨rfl,rfl⟩

-- Bytes.length: public function length(b: Bytes) -> Integer
example : (StandardBytesResponse.API.signature .bytesLength) = (⟨[],0,["b"],[.bytes],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardBytesResponse.API.name .bytesLength = "Bytes.length" := ⟨rfl,rfl⟩

-- List.length: public function length[T](xs: List[T]) -> Integer
example : (StandardListResponse.API.signature .length) = (⟨[TypeCtx.valueParam],0,["xs"],[(.list (.tvar 0))],(.base .integer),Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardListResponse.API.name .length = "List.length" := ⟨rfl,rfl⟩

-- List.isEmpty: public function isEmpty[T](xs: List[T]) -> Boolean
example : (StandardListResponse.API.signature .isEmpty) = (⟨[TypeCtx.valueParam],0,["xs"],[(.list (.tvar 0))],(.base .boolean),Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardListResponse.API.name .isEmpty = "List.isEmpty" := ⟨rfl,rfl⟩

-- List.prepend: public function prepend[T](xs: List[T], x: T) -> List[T]
example : (StandardListResponse.API.signature .prepend) = (⟨[TypeCtx.valueParam],0,["xs","x"],[(.list (.tvar 0)),(.tvar 0)],(.list (.tvar 0)),Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardListResponse.API.name .prepend = "List.prepend" := ⟨rfl,rfl⟩

-- List.append: public function append[T](xs: List[T], x: T) -> List[T]
example : (StandardListResponse.API.signature .append) = (⟨[TypeCtx.valueParam],0,["xs","x"],[(.list (.tvar 0)),(.tvar 0)],(.list (.tvar 0)),Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardListResponse.API.name .append = "List.append" := ⟨rfl,rfl⟩

-- List.concatenate: public function concatenate[T](xs: List[T], ys: List[T]) -> List[T]
example : (StandardListResponse.API.signature .concatenate) = (⟨[TypeCtx.valueParam],0,["xs","ys"],[(.list (.tvar 0)),(.list (.tvar 0))],(.list (.tvar 0)),Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardListResponse.API.name .concatenate = "List.concatenate" := ⟨rfl,rfl⟩

-- List.reverse: public function reverse[T](xs: List[T]) -> List[T]
example : (StandardListResponse.API.signature .reverse) = (⟨[TypeCtx.valueParam],0,["xs"],[(.list (.tvar 0))],(.list (.tvar 0)),Eff.empty,(fun _ ts => ts.length = 1),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardListResponse.API.name .reverse = "List.reverse" := ⟨rfl,rfl⟩

-- Map.empty: public function empty[K: key, V]() -> Map[K, V]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .empty) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,[],[],(.map (.tvar 0) (.tvar 1)),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .empty = "Map.empty" := ⟨rfl,rfl⟩

-- Map.fromList: public function fromList[K: key, V](pairs: List[Pair[K, V]]) -> Map[K, V]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .fromList) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["pairs"],[(.list (.data "Pair" [(.tvar 0),(.tvar 1)]))],(.map (.tvar 0) (.tvar 1)),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .fromList = "Map.fromList" := ⟨rfl,rfl⟩

-- Map.toList: public function toList[K: key, V](m: Map[K, V]) -> List[Pair[K, V]]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .toList) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m"],[(.map (.tvar 0) (.tvar 1))],(.list (.data "Pair" [(.tvar 0),(.tvar 1)])),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .toList = "Map.toList" := ⟨rfl,rfl⟩

-- Map.get: public function get[K: key, V](m: Map[K, V], k: K) -> Option[V]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .get) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m","k"],[(.map (.tvar 0) (.tvar 1)),(.tvar 0)],(.data "Option" [(.tvar 1)]),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .get = "Map.get" := ⟨rfl,rfl⟩

-- Map.set: public function set[K: key, V](m: Map[K, V], k: K, value: V) -> Map[K, V]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .set) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m","k","value"],[(.map (.tvar 0) (.tvar 1)),(.tvar 0),(.tvar 1)],(.map (.tvar 0) (.tvar 1)),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .set = "Map.set" := ⟨rfl,rfl⟩

-- Map.remove: public function remove[K: key, V](m: Map[K, V], k: K) -> Map[K, V]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .remove) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m","k"],[(.map (.tvar 0) (.tvar 1)),(.tvar 0)],(.map (.tvar 0) (.tvar 1)),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .remove = "Map.remove" := ⟨rfl,rfl⟩

-- Map.contains: public function contains[K: key, V](m: Map[K, V], k: K) -> Boolean
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .contains) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m","k"],[(.map (.tvar 0) (.tvar 1)),(.tvar 0)],(.base .boolean),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .contains = "Map.contains" := ⟨rfl,rfl⟩

-- Map.size: public function size[K: key, V](m: Map[K, V]) -> Integer
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .size) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m"],[(.map (.tvar 0) (.tvar 1))],(.base .integer),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .size = "Map.size" := ⟨rfl,rfl⟩

-- Map.keys: public function keys[K: key, V](m: Map[K, V]) -> List[K]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .keys) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m"],[(.map (.tvar 0) (.tvar 1))],(.list (.tvar 0)),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .keys = "Map.keys" := ⟨rfl,rfl⟩

-- Map.values: public function values[K: key, V](m: Map[K, V]) -> List[V]
example (B : Builtins) : (StandardCollections.MapAPI.signature B.sat .values) = (⟨[⟨TParam.keyC,.value⟩,TypeCtx.valueParam],0,["m"],[(.map (.tvar 0) (.tvar 1))],(.list (.tvar 1)),Eff.empty,(fun C ts => ts.length = 2 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC,{}][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.MapAPI.name .values = "Map.values" := ⟨rfl,rfl⟩

-- Set.empty: public function empty[T: key]() -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .empty) = (⟨[⟨TParam.keyC,.value⟩],0,[],[],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .empty = "Set.empty" := ⟨rfl,rfl⟩

-- Set.fromList: public function fromList[T: key](xs: List[T]) -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .fromList) = (⟨[⟨TParam.keyC,.value⟩],0,["xs"],[(.list (.tvar 0))],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .fromList = "Set.fromList" := ⟨rfl,rfl⟩

-- Set.toList: public function toList[T: key](s: Set[T]) -> List[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .toList) = (⟨[⟨TParam.keyC,.value⟩],0,["s"],[(.set (.tvar 0))],(.list (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .toList = "Set.toList" := ⟨rfl,rfl⟩

-- Set.contains: public function contains[T: key](s: Set[T], x: T) -> Boolean
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .contains) = (⟨[⟨TParam.keyC,.value⟩],0,["s","x"],[(.set (.tvar 0)),(.tvar 0)],(.base .boolean),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .contains = "Set.contains" := ⟨rfl,rfl⟩

-- Set.add: public function add[T: key](s: Set[T], x: T) -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .add) = (⟨[⟨TParam.keyC,.value⟩],0,["s","x"],[(.set (.tvar 0)),(.tvar 0)],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .add = "Set.add" := ⟨rfl,rfl⟩

-- Set.remove: public function remove[T: key](s: Set[T], x: T) -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .remove) = (⟨[⟨TParam.keyC,.value⟩],0,["s","x"],[(.set (.tvar 0)),(.tvar 0)],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .remove = "Set.remove" := ⟨rfl,rfl⟩

-- Set.size: public function size[T: key](s: Set[T]) -> Integer
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .size) = (⟨[⟨TParam.keyC,.value⟩],0,["s"],[(.set (.tvar 0))],(.base .integer),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .size = "Set.size" := ⟨rfl,rfl⟩

-- Set.union: public function union[T: key](a: Set[T], b: Set[T]) -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .union) = (⟨[⟨TParam.keyC,.value⟩],0,["a","b"],[(.set (.tvar 0)),(.set (.tvar 0))],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .union = "Set.union" := ⟨rfl,rfl⟩

-- Set.intersection: public function intersection[T: key](a: Set[T], b: Set[T]) -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .intersection) = (⟨[⟨TParam.keyC,.value⟩],0,["a","b"],[(.set (.tvar 0)),(.set (.tvar 0))],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .intersection = "Set.intersection" := ⟨rfl,rfl⟩

-- Set.difference: public function difference[T: key](a: Set[T], b: Set[T]) -> Set[T]
example (B : Builtins) : (StandardCollections.SetAPI.signature B.sat .difference) = (⟨[⟨TParam.keyC,.value⟩],0,["a","b"],[(.set (.tvar 0)),(.set (.tvar 0))],(.set (.tvar 0)),Eff.empty,(fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam), ts[i]? = some t → [TParam.keyC][i]? = some p → B.sat C t p),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardCollections.SetAPI.name .difference = "Set.difference" := ⟨rfl,rfl⟩

-- Integer.floorDivide: public function floorDivide(a: Integer, b: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .floorDivide) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .floorDivide = "Integer.floorDivide" := ⟨rfl,rfl⟩

-- Integer.floorModulo: public function floorModulo(a: Integer, b: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .floorModulo) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .floorModulo = "Integer.floorModulo" := ⟨rfl,rfl⟩

-- Integer.absolute: public function absolute(n: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .absolute) = (⟨[],0,["n"],[(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .absolute = "Integer.absolute" := ⟨rfl,rfl⟩

-- Integer.minimum: public function minimum(a: Integer, b: Integer) -> Integer
example : (StandardIntegerResponse.minMaxSig .integer64) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer64 false = "Integer.minimum" := ⟨rfl,rfl⟩

-- Integer.maximum: public function maximum(a: Integer, b: Integer) -> Integer
example : (StandardIntegerResponse.minMaxSig .integer64) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer64 true = "Integer.maximum" := ⟨rfl,rfl⟩

-- Integer.bitwiseAnd: public function bitwiseAnd(a: Integer, b: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .bitwiseAnd = "Integer.bitwiseAnd" := ⟨rfl,rfl⟩

-- Integer.bitwiseOr: public function bitwiseOr(a: Integer, b: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .bitwiseOr = "Integer.bitwiseOr" := ⟨rfl,rfl⟩

-- Integer.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: Integer, b: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .bitwiseExclusiveOr = "Integer.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- Integer.bitwiseNot: public function bitwiseNot(a: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .bitwiseNot) = (⟨[],0,["a"],[(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .bitwiseNot = "Integer.bitwiseNot" := ⟨rfl,rfl⟩

-- Integer.shiftLeft: public function shiftLeft(a: Integer, n: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .shiftLeft) = (⟨[],0,["a","n"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .shiftLeft = "Integer.shiftLeft" := ⟨rfl,rfl⟩

-- Integer.shiftRight: public function shiftRight(a: Integer, n: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .shiftRight) = (⟨[],0,["a","n"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .shiftRight = "Integer.shiftRight" := ⟨rfl,rfl⟩

-- Integer.shiftRightUnsigned: public function shiftRightUnsigned(a: Integer, n: Integer) -> Integer
example : (StandardIntegerAPI.API.signature .integer64 .shiftRightUnsigned) = (⟨[],0,["a","n"],[(.base .integer),(.base .integer)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer64 .shiftRightUnsigned = "Integer.shiftRightUnsigned" := ⟨rfl,rfl⟩

-- Integer8.fromInteger: public function fromInteger(n: Integer) -> Option[Integer8]
example : (StandardConversionResponse.signature .integer8 true) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .integer8)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .integer8 true = "Integer8.fromInteger" := ⟨rfl,rfl⟩

-- Integer8.toInteger: public function toInteger(n: Integer8) -> Integer
example : (StandardConversionResponse.signature .integer8 false) = (⟨[],0,["n"],[(.base .integer8)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .integer8 false = "Integer8.toInteger" := ⟨rfl,rfl⟩

-- Integer8.absolute: public function absolute(n: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .absolute) = (⟨[],0,["n"],[(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .absolute = "Integer8.absolute" := ⟨rfl,rfl⟩

-- Integer8.minimum: public function minimum(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerResponse.minMaxSig .integer8) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer8 false = "Integer8.minimum" := ⟨rfl,rfl⟩

-- Integer8.maximum: public function maximum(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerResponse.minMaxSig .integer8) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer8 true = "Integer8.maximum" := ⟨rfl,rfl⟩

-- Integer8.floorDivide: public function floorDivide(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .floorDivide) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .floorDivide = "Integer8.floorDivide" := ⟨rfl,rfl⟩

-- Integer8.floorModulo: public function floorModulo(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .floorModulo) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .floorModulo = "Integer8.floorModulo" := ⟨rfl,rfl⟩

-- Integer8.bitwiseAnd: public function bitwiseAnd(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .bitwiseAnd = "Integer8.bitwiseAnd" := ⟨rfl,rfl⟩

-- Integer8.bitwiseOr: public function bitwiseOr(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .bitwiseOr = "Integer8.bitwiseOr" := ⟨rfl,rfl⟩

-- Integer8.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: Integer8, b: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .integer8),(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .bitwiseExclusiveOr = "Integer8.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- Integer8.bitwiseNot: public function bitwiseNot(a: Integer8) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .bitwiseNot) = (⟨[],0,["a"],[(.base .integer8)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .bitwiseNot = "Integer8.bitwiseNot" := ⟨rfl,rfl⟩

-- Integer8.shiftLeft: public function shiftLeft(a: Integer8, n: Integer) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .shiftLeft) = (⟨[],0,["a","n"],[(.base .integer8),(.base .integer)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .shiftLeft = "Integer8.shiftLeft" := ⟨rfl,rfl⟩

-- Integer8.shiftRight: public function shiftRight(a: Integer8, n: Integer) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .shiftRight) = (⟨[],0,["a","n"],[(.base .integer8),(.base .integer)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .shiftRight = "Integer8.shiftRight" := ⟨rfl,rfl⟩

-- Integer8.shiftRightUnsigned: public function shiftRightUnsigned(a: Integer8, n: Integer) -> Integer8
example : (StandardIntegerAPI.API.signature .integer8 .shiftRightUnsigned) = (⟨[],0,["a","n"],[(.base .integer8),(.base .integer)],(.base .integer8),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer8 .shiftRightUnsigned = "Integer8.shiftRightUnsigned" := ⟨rfl,rfl⟩

-- Integer16.fromInteger: public function fromInteger(n: Integer) -> Option[Integer16]
example : (StandardConversionResponse.signature .integer16 true) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .integer16)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .integer16 true = "Integer16.fromInteger" := ⟨rfl,rfl⟩

-- Integer16.toInteger: public function toInteger(n: Integer16) -> Integer
example : (StandardConversionResponse.signature .integer16 false) = (⟨[],0,["n"],[(.base .integer16)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .integer16 false = "Integer16.toInteger" := ⟨rfl,rfl⟩

-- Integer16.absolute: public function absolute(n: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .absolute) = (⟨[],0,["n"],[(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .absolute = "Integer16.absolute" := ⟨rfl,rfl⟩

-- Integer16.minimum: public function minimum(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerResponse.minMaxSig .integer16) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer16 false = "Integer16.minimum" := ⟨rfl,rfl⟩

-- Integer16.maximum: public function maximum(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerResponse.minMaxSig .integer16) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer16 true = "Integer16.maximum" := ⟨rfl,rfl⟩

-- Integer16.floorDivide: public function floorDivide(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .floorDivide) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .floorDivide = "Integer16.floorDivide" := ⟨rfl,rfl⟩

-- Integer16.floorModulo: public function floorModulo(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .floorModulo) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .floorModulo = "Integer16.floorModulo" := ⟨rfl,rfl⟩

-- Integer16.bitwiseAnd: public function bitwiseAnd(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .bitwiseAnd = "Integer16.bitwiseAnd" := ⟨rfl,rfl⟩

-- Integer16.bitwiseOr: public function bitwiseOr(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .bitwiseOr = "Integer16.bitwiseOr" := ⟨rfl,rfl⟩

-- Integer16.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: Integer16, b: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .integer16),(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .bitwiseExclusiveOr = "Integer16.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- Integer16.bitwiseNot: public function bitwiseNot(a: Integer16) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .bitwiseNot) = (⟨[],0,["a"],[(.base .integer16)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .bitwiseNot = "Integer16.bitwiseNot" := ⟨rfl,rfl⟩

-- Integer16.shiftLeft: public function shiftLeft(a: Integer16, n: Integer) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .shiftLeft) = (⟨[],0,["a","n"],[(.base .integer16),(.base .integer)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .shiftLeft = "Integer16.shiftLeft" := ⟨rfl,rfl⟩

-- Integer16.shiftRight: public function shiftRight(a: Integer16, n: Integer) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .shiftRight) = (⟨[],0,["a","n"],[(.base .integer16),(.base .integer)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .shiftRight = "Integer16.shiftRight" := ⟨rfl,rfl⟩

-- Integer16.shiftRightUnsigned: public function shiftRightUnsigned(a: Integer16, n: Integer) -> Integer16
example : (StandardIntegerAPI.API.signature .integer16 .shiftRightUnsigned) = (⟨[],0,["a","n"],[(.base .integer16),(.base .integer)],(.base .integer16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer16 .shiftRightUnsigned = "Integer16.shiftRightUnsigned" := ⟨rfl,rfl⟩

-- Integer32.fromInteger: public function fromInteger(n: Integer) -> Option[Integer32]
example : (StandardConversionResponse.signature .integer32 true) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .integer32)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .integer32 true = "Integer32.fromInteger" := ⟨rfl,rfl⟩

-- Integer32.toInteger: public function toInteger(n: Integer32) -> Integer
example : (StandardConversionResponse.signature .integer32 false) = (⟨[],0,["n"],[(.base .integer32)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .integer32 false = "Integer32.toInteger" := ⟨rfl,rfl⟩

-- Integer32.absolute: public function absolute(n: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .absolute) = (⟨[],0,["n"],[(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .absolute = "Integer32.absolute" := ⟨rfl,rfl⟩

-- Integer32.minimum: public function minimum(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerResponse.minMaxSig .integer32) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer32 false = "Integer32.minimum" := ⟨rfl,rfl⟩

-- Integer32.maximum: public function maximum(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerResponse.minMaxSig .integer32) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .integer32 true = "Integer32.maximum" := ⟨rfl,rfl⟩

-- Integer32.floorDivide: public function floorDivide(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .floorDivide) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .floorDivide = "Integer32.floorDivide" := ⟨rfl,rfl⟩

-- Integer32.floorModulo: public function floorModulo(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .floorModulo) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .floorModulo = "Integer32.floorModulo" := ⟨rfl,rfl⟩

-- Integer32.bitwiseAnd: public function bitwiseAnd(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .bitwiseAnd = "Integer32.bitwiseAnd" := ⟨rfl,rfl⟩

-- Integer32.bitwiseOr: public function bitwiseOr(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .bitwiseOr = "Integer32.bitwiseOr" := ⟨rfl,rfl⟩

-- Integer32.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: Integer32, b: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .integer32),(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .bitwiseExclusiveOr = "Integer32.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- Integer32.bitwiseNot: public function bitwiseNot(a: Integer32) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .bitwiseNot) = (⟨[],0,["a"],[(.base .integer32)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .bitwiseNot = "Integer32.bitwiseNot" := ⟨rfl,rfl⟩

-- Integer32.shiftLeft: public function shiftLeft(a: Integer32, n: Integer) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .shiftLeft) = (⟨[],0,["a","n"],[(.base .integer32),(.base .integer)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .shiftLeft = "Integer32.shiftLeft" := ⟨rfl,rfl⟩

-- Integer32.shiftRight: public function shiftRight(a: Integer32, n: Integer) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .shiftRight) = (⟨[],0,["a","n"],[(.base .integer32),(.base .integer)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .shiftRight = "Integer32.shiftRight" := ⟨rfl,rfl⟩

-- Integer32.shiftRightUnsigned: public function shiftRightUnsigned(a: Integer32, n: Integer) -> Integer32
example : (StandardIntegerAPI.API.signature .integer32 .shiftRightUnsigned) = (⟨[],0,["a","n"],[(.base .integer32),(.base .integer)],(.base .integer32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .integer32 .shiftRightUnsigned = "Integer32.shiftRightUnsigned" := ⟨rfl,rfl⟩

-- UnsignedInteger16.fromInteger: public function fromInteger(n: Integer) -> Option[UnsignedInteger16]
example : (StandardConversionResponse.signature .unsignedInteger16 true) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .unsignedInteger16)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .unsignedInteger16 true = "UnsignedInteger16.fromInteger" := ⟨rfl,rfl⟩

-- UnsignedInteger16.toInteger: public function toInteger(n: UnsignedInteger16) -> Integer
example : (StandardConversionResponse.signature .unsignedInteger16 false) = (⟨[],0,["n"],[(.base .unsignedInteger16)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .unsignedInteger16 false = "UnsignedInteger16.toInteger" := ⟨rfl,rfl⟩

-- UnsignedInteger16.absolute: public function absolute(n: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .absolute) = (⟨[],0,["n"],[(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .absolute = "UnsignedInteger16.absolute" := ⟨rfl,rfl⟩

-- UnsignedInteger16.minimum: public function minimum(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerResponse.minMaxSig .unsignedInteger16) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .unsignedInteger16 false = "UnsignedInteger16.minimum" := ⟨rfl,rfl⟩

-- UnsignedInteger16.maximum: public function maximum(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerResponse.minMaxSig .unsignedInteger16) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .unsignedInteger16 true = "UnsignedInteger16.maximum" := ⟨rfl,rfl⟩

-- UnsignedInteger16.floorDivide: public function floorDivide(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .floorDivide) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .floorDivide = "UnsignedInteger16.floorDivide" := ⟨rfl,rfl⟩

-- UnsignedInteger16.floorModulo: public function floorModulo(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .floorModulo) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .floorModulo = "UnsignedInteger16.floorModulo" := ⟨rfl,rfl⟩

-- UnsignedInteger16.bitwiseAnd: public function bitwiseAnd(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .bitwiseAnd = "UnsignedInteger16.bitwiseAnd" := ⟨rfl,rfl⟩

-- UnsignedInteger16.bitwiseOr: public function bitwiseOr(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .bitwiseOr = "UnsignedInteger16.bitwiseOr" := ⟨rfl,rfl⟩

-- UnsignedInteger16.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .bitwiseExclusiveOr = "UnsignedInteger16.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- UnsignedInteger16.bitwiseNot: public function bitwiseNot(a: UnsignedInteger16) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .bitwiseNot) = (⟨[],0,["a"],[(.base .unsignedInteger16)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .bitwiseNot = "UnsignedInteger16.bitwiseNot" := ⟨rfl,rfl⟩

-- UnsignedInteger16.shiftLeft: public function shiftLeft(a: UnsignedInteger16, n: Integer) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .shiftLeft) = (⟨[],0,["a","n"],[(.base .unsignedInteger16),(.base .integer)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .shiftLeft = "UnsignedInteger16.shiftLeft" := ⟨rfl,rfl⟩

-- UnsignedInteger16.shiftRight: public function shiftRight(a: UnsignedInteger16, n: Integer) -> UnsignedInteger16
example : (StandardIntegerAPI.API.signature .unsignedInteger16 .shiftRight) = (⟨[],0,["a","n"],[(.base .unsignedInteger16),(.base .integer)],(.base .unsignedInteger16),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger16 .shiftRight = "UnsignedInteger16.shiftRight" := ⟨rfl,rfl⟩

-- UnsignedInteger32.fromInteger: public function fromInteger(n: Integer) -> Option[UnsignedInteger32]
example : (StandardConversionResponse.signature .unsignedInteger32 true) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .unsignedInteger32)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .unsignedInteger32 true = "UnsignedInteger32.fromInteger" := ⟨rfl,rfl⟩

-- UnsignedInteger32.toInteger: public function toInteger(n: UnsignedInteger32) -> Integer
example : (StandardConversionResponse.signature .unsignedInteger32 false) = (⟨[],0,["n"],[(.base .unsignedInteger32)],(.base .integer),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .unsignedInteger32 false = "UnsignedInteger32.toInteger" := ⟨rfl,rfl⟩

-- UnsignedInteger32.absolute: public function absolute(n: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .absolute) = (⟨[],0,["n"],[(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .absolute = "UnsignedInteger32.absolute" := ⟨rfl,rfl⟩

-- UnsignedInteger32.minimum: public function minimum(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerResponse.minMaxSig .unsignedInteger32) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .unsignedInteger32 false = "UnsignedInteger32.minimum" := ⟨rfl,rfl⟩

-- UnsignedInteger32.maximum: public function maximum(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerResponse.minMaxSig .unsignedInteger32) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .unsignedInteger32 true = "UnsignedInteger32.maximum" := ⟨rfl,rfl⟩

-- UnsignedInteger32.floorDivide: public function floorDivide(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .floorDivide) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .floorDivide = "UnsignedInteger32.floorDivide" := ⟨rfl,rfl⟩

-- UnsignedInteger32.floorModulo: public function floorModulo(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .floorModulo) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .floorModulo = "UnsignedInteger32.floorModulo" := ⟨rfl,rfl⟩

-- UnsignedInteger32.bitwiseAnd: public function bitwiseAnd(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .bitwiseAnd = "UnsignedInteger32.bitwiseAnd" := ⟨rfl,rfl⟩

-- UnsignedInteger32.bitwiseOr: public function bitwiseOr(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .bitwiseOr = "UnsignedInteger32.bitwiseOr" := ⟨rfl,rfl⟩

-- UnsignedInteger32.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .bitwiseExclusiveOr = "UnsignedInteger32.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- UnsignedInteger32.bitwiseNot: public function bitwiseNot(a: UnsignedInteger32) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .bitwiseNot) = (⟨[],0,["a"],[(.base .unsignedInteger32)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .bitwiseNot = "UnsignedInteger32.bitwiseNot" := ⟨rfl,rfl⟩

-- UnsignedInteger32.shiftLeft: public function shiftLeft(a: UnsignedInteger32, n: Integer) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .shiftLeft) = (⟨[],0,["a","n"],[(.base .unsignedInteger32),(.base .integer)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .shiftLeft = "UnsignedInteger32.shiftLeft" := ⟨rfl,rfl⟩

-- UnsignedInteger32.shiftRight: public function shiftRight(a: UnsignedInteger32, n: Integer) -> UnsignedInteger32
example : (StandardIntegerAPI.API.signature .unsignedInteger32 .shiftRight) = (⟨[],0,["a","n"],[(.base .unsignedInteger32),(.base .integer)],(.base .unsignedInteger32),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger32 .shiftRight = "UnsignedInteger32.shiftRight" := ⟨rfl,rfl⟩

-- UnsignedInteger64.fromInteger: public function fromInteger(n: Integer) -> Option[UnsignedInteger64]
example : (StandardConversionResponse.signature .unsignedInteger64 true) = (⟨[],0,["n"],[(.base .integer)],(.data "Option" [(.base .unsignedInteger64)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .unsignedInteger64 true = "UnsignedInteger64.fromInteger" := ⟨rfl,rfl⟩

-- UnsignedInteger64.toInteger: public function toInteger(n: UnsignedInteger64) -> Option[Integer]
example : (StandardConversionResponse.signature .unsignedInteger64 false) = (⟨[],0,["n"],[(.base .unsignedInteger64)],(.data "Option" [(.base .integer)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardConversionResponse.name .unsignedInteger64 false = "UnsignedInteger64.toInteger" := ⟨rfl,rfl⟩

-- UnsignedInteger64.toDecimal: public function toDecimal(n: UnsignedInteger64) -> Decimal
example : (StandardDecimalResponse.API.signature .toDecimal) = (⟨[],0,["n"],[(.base .unsignedInteger64)],(.base .decimal),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardDecimalResponse.API.name .toDecimal = "UnsignedInteger64.toDecimal" := ⟨rfl,rfl⟩

-- UnsignedInteger64.fromDecimal: public function fromDecimal(x: Decimal) -> Option[UnsignedInteger64]
example : (StandardDecimalResponse.API.signature .fromDecimal) = (⟨[],0,["x"],[(.base .decimal)],(.data "Option" [(.base .unsignedInteger64)]),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardDecimalResponse.API.name .fromDecimal = "UnsignedInteger64.fromDecimal" := ⟨rfl,rfl⟩

-- UnsignedInteger64.absolute: public function absolute(n: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .absolute) = (⟨[],0,["n"],[(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .absolute = "UnsignedInteger64.absolute" := ⟨rfl,rfl⟩

-- UnsignedInteger64.minimum: public function minimum(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerResponse.minMaxSig .unsignedInteger64) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .unsignedInteger64 false = "UnsignedInteger64.minimum" := ⟨rfl,rfl⟩

-- UnsignedInteger64.maximum: public function maximum(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerResponse.minMaxSig .unsignedInteger64) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerResponse.minMaxName .unsignedInteger64 true = "UnsignedInteger64.maximum" := ⟨rfl,rfl⟩

-- UnsignedInteger64.floorDivide: public function floorDivide(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .floorDivide) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .floorDivide = "UnsignedInteger64.floorDivide" := ⟨rfl,rfl⟩

-- UnsignedInteger64.floorModulo: public function floorModulo(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .floorModulo) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .floorModulo = "UnsignedInteger64.floorModulo" := ⟨rfl,rfl⟩

-- UnsignedInteger64.bitwiseAnd: public function bitwiseAnd(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .bitwiseAnd) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .bitwiseAnd = "UnsignedInteger64.bitwiseAnd" := ⟨rfl,rfl⟩

-- UnsignedInteger64.bitwiseOr: public function bitwiseOr(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .bitwiseOr) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .bitwiseOr = "UnsignedInteger64.bitwiseOr" := ⟨rfl,rfl⟩

-- UnsignedInteger64.bitwiseExclusiveOr: public function bitwiseExclusiveOr(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .bitwiseExclusiveOr) = (⟨[],0,["a","b"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .bitwiseExclusiveOr = "UnsignedInteger64.bitwiseExclusiveOr" := ⟨rfl,rfl⟩

-- UnsignedInteger64.bitwiseNot: public function bitwiseNot(a: UnsignedInteger64) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .bitwiseNot) = (⟨[],0,["a"],[(.base .unsignedInteger64)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .bitwiseNot = "UnsignedInteger64.bitwiseNot" := ⟨rfl,rfl⟩

-- UnsignedInteger64.shiftLeft: public function shiftLeft(a: UnsignedInteger64, n: Integer) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .shiftLeft) = (⟨[],0,["a","n"],[(.base .unsignedInteger64),(.base .integer)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .shiftLeft = "UnsignedInteger64.shiftLeft" := ⟨rfl,rfl⟩

-- UnsignedInteger64.shiftRight: public function shiftRight(a: UnsignedInteger64, n: Integer) -> UnsignedInteger64
example : (StandardIntegerAPI.API.signature .unsignedInteger64 .shiftRight) = (⟨[],0,["a","n"],[(.base .unsignedInteger64),(.base .integer)],(.base .unsignedInteger64),Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardIntegerAPI.API.name .unsignedInteger64 .shiftRight = "UnsignedInteger64.shiftRight" := ⟨rfl,rfl⟩

end Benitoite.Release.Refinement.StandardSignatureExamples
