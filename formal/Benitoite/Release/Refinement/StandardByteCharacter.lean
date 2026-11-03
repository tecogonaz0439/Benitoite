import Benitoite.Release.Refinement.StandardInteger
import Benitoite.Release.Refinement.MeasureContracts

/-! # Byte・Character の明示変換と Bytes の実値 -/
namespace Benitoite.Release.Refinement.StandardScalar
open Benitoite.Interval

/-- u8 への実変換は整数を巡回させず、先に範囲を検査する。 -/
def byteConvert (n : Int) : Option UInt8 :=
  if h : 0 ≤ n ∧ n ≤ 255 then some (UInt8.ofNatLT n.toNat (by change n.toNat < 256; omega)) else none

theorem byteConvert_some (n : Int) (v : UInt8) :
    byteConvert n = some v ↔ (v.toNat : Int) = n := by
  unfold byteConvert
  split
  · rename_i h
    simp only [Option.some.injEq]
    constructor
    · intro eq; cases eq; simp; omega
    · intro eq
      apply UInt8.toNat_inj.mp
      simp; omega
  · rename_i h
    simp only [reduceCtorEq, false_iff]
    have hi := v.toNat_lt
    intro eq
    exact h (by omega)

theorem byteConvert_none (n : Int) :
    byteConvert n = none ↔ n < 0 ∨ 255 < n := by
  unfold byteConvert
  split <;> simp_all <;> omega

def byteOption : Option UInt8 → Val
  | some v => .con "Option.Some" [.base .byte] [.const (.byte v.toNat)]
  | none => .con "Option.None" [.base .byte] []

def byteToInteger (v : UInt8) : Benitoite.Release.Integer64Value :=
  ⟨v.toNat, by have := v.toNat_lt; simp only [Benitoite.Release.min64,Benitoite.Release.max64]; omega⟩

/-- Byte と UnsignedInteger8 は同じ型。後者の本体は前者を呼ぶ。 -/
private def byteDeltaAt (name : PrimName) (ws : List Val) : Option Outcome := do
  match name,ws with
  | "Byte.fromInteger", [.const (.integer n)] => return .val (byteOption (byteConvert n.toInt))
  | "Byte.toInteger", [.const (.byte n)] =>
    if h : n < 256 then return .val (.const (.integer (byteToInteger (UInt8.ofNatLT n h)))) else none
  | "Byte.bitwiseAnd", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return .val (.const (.byte ((UInt8.ofNat a &&& UInt8.ofNat b).toNat))) else none
  | "Byte.bitwiseOr", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return .val (.const (.byte ((UInt8.ofNat a ||| UInt8.ofNat b).toNat))) else none
  | "Byte.bitwiseExclusiveOr", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return .val (.const (.byte ((UInt8.ofNat a ^^^ UInt8.ofNat b).toNat))) else none
  | "Byte.bitwiseNot", [.const (.byte a)] =>
    if a ≤ 255 then return .val (.const (.byte ((~~~UInt8.ofNat a).toNat))) else none
  | "Byte.shiftLeft", [.const (.byte a),.const (.integer n)] =>
    if a ≤ 255 then
      if 0 ≤ n.toInt ∧ n.toInt ≤ 7 then return .val (.const (.byte (((UInt8.ofNat a) <<< UInt8.ofNat n.toInt.toNat).toNat)))
      else return .err "ArgumentOutOfDomain"
    else none
  | "Byte.shiftRight", [.const (.byte a),.const (.integer n)] =>
    if a ≤ 255 then
      if 0 ≤ n.toInt ∧ n.toInt ≤ 7 then return .val (.const (.byte (((UInt8.ofNat a) >>> UInt8.ofNat n.toInt.toNat).toNat)))
      else return .err "ArgumentOutOfDomain"
    else none
  | "%eq", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return integerCompareDelta .eq a b else none
  | "%ne", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return integerCompareDelta .ne a b else none
  | "%Byte.less", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return integerCompareDelta .lt a b else none
  | "%Byte.lessOrEqual", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return integerCompareDelta .le a b else none
  | "%Byte.greater", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return integerCompareDelta .gt a b else none
  | "%Byte.greaterOrEqual", [.const (.byte a),.const (.byte b)] =>
    if a ≤ 255 ∧ b ≤ 255 then return integerCompareDelta .ge a b else none
  | _,_ => none

/-- 共通の型・行・範囲引数の検査を使う部分表。 -/
def byteDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome := scalarDelta .byte byteDeltaAt name ts es rs ws

theorem byte_result (P : Program) (B : Builtins) (Ψ : StoreTy) (v : UInt8) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.byte v.toNat)) (.base .byte) ∧
    (Val.const (.byte v.toNat)).toTerm? = some (.integer v.toNat) ∧
    byteDelta "Byte.toInteger" [] [] [] [.const (.byte v.toNat)] =
      some (.val (.const (.integer (byteToInteger v)))) := by
  have bound : v.toNat ≤ 255 := by have := v.toNat_lt; omega
  refine ⟨.V_Const bound,rfl,?_⟩
  simp [byteDelta,scalarDelta,scalarArguments,byteDeltaAt,v.toNat_lt]

/-- Char の内部の妥当性を、同じ自然数の scalar の範囲へ写す。 -/
theorem character_scalar (c : Char) :
    c.toNat < 0xd800 ∨ (0xdfff < c.toNat ∧ c.toNat < 0x110000) := by
  have h := c.valid
  simpa only [UInt32.isValidChar,UInt32.lt_iff_toNat_lt,Char.toNat] using h

private def characterOfNat (n : Nat) (h : Char.isValidCharNat n) : Char :=
  ⟨UInt32.ofNatLT n (Char.isValidUInt32 n h),Char.isValidChar_of_isValidCharNat n h⟩

private theorem characterOfNat_code (n : Nat) (h : Char.isValidCharNat n) :
    (characterOfNat n h).toNat = n := by simp [characterOfNat,Char.toNat]

/-- fromInteger は surrogate、負数、上端の外を None にする。 -/
def characterConvert (n : Int) : Option Char :=
  if h : 0 ≤ n ∧ Char.isValidCharNat n.toNat then some (characterOfNat n.toNat h.2) else none

theorem characterConvert_some (n : Int) (c : Char) :
    characterConvert n = some c ↔ (c.toNat : Int) = n := by
  unfold characterConvert
  split
  · rename_i h
    simp only [Option.some.injEq]
    constructor
    · intro eq; cases eq; rw [characterOfNat_code]; omega
    · intro eq
      apply Char.toNat_inj.mp
      rw [characterOfNat_code]; omega
  · rename_i h
    simp only [reduceCtorEq, false_iff]
    intro eq
    have scalar := character_scalar c
    exact h (by constructor; omega; simpa only [show n.toNat = c.toNat by omega] using scalar)

theorem characterConvert_none (n : Int) :
    characterConvert n = none ↔ n < 0 ∨ (0xd800 ≤ n ∧ n ≤ 0xdfff) ∨ 0x110000 ≤ n := by
  unfold characterConvert
  split <;> simp_all [Char.isValidCharNat] <;> omega

def characterToInteger (c : Char) : Benitoite.Release.Integer64Value :=
  ⟨c.toNat, by have := character_scalar c; simp only [Benitoite.Release.min64,Benitoite.Release.max64]; omega⟩

def characterCompareDelta (op : Comparison) (a b : Char) : Outcome :=
  .val (.const (.boolean ((Observation.character a).compare op (.character b))))

def characterCompareName : Comparison → PrimName
  | .eq => "%eq" | .ne => "%ne" | .lt => "%Character.less" | .le => "%Character.lessOrEqual"
  | .gt => "%Character.greater" | .ge => "%Character.greaterOrEqual"

private def characterDeltaAt (name : PrimName) (ws : List Val) : Option Outcome :=
  match name,ws with
  | "Character.fromInteger", [.const (.integer n)] => some (.val (match characterConvert n.toInt with
      | some c => .con "Option.Some" [.base .character] [.const (.character c)]
      | none => .con "Option.None" [.base .character] []))
  | "Character.toInteger", [.const (.character c)] => some (.val (.const (.integer (characterToInteger c))))
  | "%eq", [.const (.character a),.const (.character b)] => some (characterCompareDelta .eq a b)
  | "%ne", [.const (.character a),.const (.character b)] => some (characterCompareDelta .ne a b)
  | "%Character.less", [.const (.character a),.const (.character b)] => some (characterCompareDelta .lt a b)
  | "%Character.lessOrEqual", [.const (.character a),.const (.character b)] => some (characterCompareDelta .le a b)
  | "%Character.greater", [.const (.character a),.const (.character b)] => some (characterCompareDelta .gt a b)
  | "%Character.greaterOrEqual", [.const (.character a),.const (.character b)] => some (characterCompareDelta .ge a b)
  | _,_ => none

/-- 共通の型・行・範囲引数の検査を使う部分表。 -/
def characterDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome := scalarDelta .character characterDeltaAt name ts es rs ws

/-- 同じ Char の code は、標準応答と characterCode の観測の両方で一致する。 -/
theorem character_code (P : Program) (B : Builtins) (Ψ : StoreTy) (c : Char) (η : ObservationEnvModel) :
    characterDelta "Character.toInteger" [] [] [] [.const (.character c)] =
      some (.val (.const (.integer (characterToInteger c)))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer (characterToInteger c))) (.base .integer) ∧
    (Term.measure .characterCode (.character c)).observe η = some (.integer c.toNat) :=
  ⟨rfl,.V_Const trivial,(measure_machine_exact rfl η (.character c) rfl).1⟩

/-- 同じ二文字の六比較は、観測の比較と型付きの Boolean 応答になる。 -/
theorem character_compare (P : Program) (B : Builtins) (Ψ : StoreTy)
    (η : ObservationEnvModel) (a b : Char) (op : Comparison) :
    ∃ value, characterDelta (characterCompareName op) (comparisonTypes .character op) [] [] [.const (.character a),.const (.character b)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .character op (.character a) (.character b)).interpret η = value := by
  refine ⟨(Observation.character a).compare op (.character b),?_,.V_Const trivial,?_⟩
  · cases op <;> rfl
  · exact NumericContracts.compare_exact η (t := .character a) (u := .character b) rfl rfl rfl rfl op

/-- Bytes.fromList は同じ byte 列を保持し、toList はそのまま射影する。 -/
def bytesFromList (xs : List UInt8) : Val := .bytesV (xs.map UInt8.toNat)

theorem bytesFromList_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (xs : List UInt8) :
    HasTypeVQ P B Ψ Qempty [] [] [] (bytesFromList xs) .bytes ∧
      (xs.map UInt8.toNat).length = xs.length := by
  refine ⟨.V_Bytes ?_,by simp⟩
  intro n hn
  obtain ⟨v,_,rfl⟩ := List.mem_map.mp hn
  have := v.toNat_lt; omega

example : [-1,0,255,256].map (fun n => (byteConvert n).map UInt8.toNat) =
    [none,some 0,some 255,none] := by decide
example : [-1,0,0xd7ff,0xd800,0xdfff,0xe000,0x10ffff,0x110000].map
    (fun n => (characterConvert n).map Char.toNat) =
      [none,some 0,some 0xd7ff,none,none,some 0xe000,some 0x10ffff,none] := by decide
example (n : Int) (v : UInt8) : byteConvert n = some v ↔ (v.toNat : Int) = n := byteConvert_some n v
example (n : Int) : byteConvert n = none ↔ n < 0 ∨ 255 < n := byteConvert_none n
example (n : Int) (c : Char) : characterConvert n = some c ↔ (c.toNat : Int) = n := characterConvert_some n c
example (n : Int) : characterConvert n = none ↔ n < 0 ∨ (0xd800 ≤ n ∧ n ≤ 0xdfff) ∨ 0x110000 ≤ n := characterConvert_none n
example (P : Program) (B : Builtins) (Ψ : StoreTy) (v : UInt8) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.byte v.toNat)) (.base .byte) := (byte_result P B Ψ v).1
example (P : Program) (B : Builtins) (Ψ : StoreTy) (c : Char) (η : ObservationEnvModel) :
    (Term.measure .characterCode (.character c)).observe η = some (.integer c.toNat) := (character_code P B Ψ c η).2.2
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) (a b : Char) :
    ∃ value, HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .character .le (.character a) (.character b)).interpret η = value :=
  by
    obtain ⟨v,_,ht,hp⟩ := character_compare P B Ψ η a b .le
    exact ⟨v,ht,hp⟩
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (bytesFromList [0,255]) .bytes := (bytesFromList_typed P B Ψ [0,255]).1
example : byteDelta "Byte.shiftLeft" [] [] [] [.const (.byte 128),.const (.integer ⟨1,by decide⟩)] =
    some (.val (.const (.byte 0))) := by rfl


/-- Bytes.toList は各要素の値を保つ。 -/
def bytesToList (xs : List UInt8) : Val := .list (xs.map (fun v => .const (.byte v.toNat)))

theorem bytesToList_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (xs : List UInt8) :
    HasTypeVQ P B Ψ Qempty [] [] [] (bytesToList xs) (.list (.base .byte)) := by
  apply HasTypeVQ.V_List
  · induction xs with
    | nil => exact .nil
    | cons x xs ih => exact .cons (byte_result P B Ψ x).1 ih
  · trivial
  · trivial
  · trivial

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (bytesToList [0,255]) (.list (.base .byte)) :=
  bytesToList_typed P B Ψ [0,255]


/-- String 内の各 Character は scalar の上端を越えない。 -/
theorem string_scalar_range (s : String) (η : ObservationEnvModel) :
    (Pred.charactersIn (.string s) (Char.ofNat 0) (Char.ofNat 0x10ffff)).interpret η = true := by
  simp only [Pred.interpret,Pred.atomValue,observeAs,Term.interpret,Observation.sort,ite_true]
  apply List.all_eq_true.mpr
  intro c _
  have h := character_scalar c
  simp only [decide_eq_true_eq]
  change 0 ≤ c.toNat ∧ c.toNat ≤ 0x10ffff
  omega

example (s : String) (η : ObservationEnvModel) :
    (Pred.charactersIn (.string s) (Char.ofNat 0) (Char.ofNat 0x10ffff)).interpret η = true :=
  string_scalar_range s η

def byteCompareName : Comparison → PrimName
  | .eq => "%eq" | .ne => "%ne" | .lt => "%Byte.less" | .le => "%Byte.lessOrEqual"
  | .gt => "%Byte.greater" | .ge => "%Byte.greaterOrEqual"

/-- Byte の六比較の実応答は、同じ数の比較と Boolean の型付けを与える。 -/
theorem byte_compare (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel)
    (a b : UInt8) (op : Comparison) :
    ∃ value, byteDelta (byteCompareName op) (comparisonTypes .byte op) [] []
        [.const (.byte a.toNat),.const (.byte b.toNat)] = some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (integerComparePred op (.integer a.toNat) (.integer b.toNat)).interpret η = value := by
  have ha : a.toNat ≤ 255 := by have := a.toNat_lt; omega
  have hb : b.toNat ≤ 255 := by have := b.toNat_lt; omega
  obtain ⟨v,hv,hp⟩ := integerCompare_reply η op a.toNat b.toNat
  refine ⟨v,?_,.V_Const trivial,hp⟩
  cases op <;> simpa [byteDelta,scalarDelta,scalarArguments,scalarTypeCore,comparisonTypes,
    byteCompareName,byteDeltaAt,ha,hb] using congrArg some hv

/-- Byte の Option は二つの構成子を同じ宣言表で型付ける。 -/
theorem byteOption_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (v : Option UInt8)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    HasTypeVQ P B Ψ Qempty [] [] [] (byteOption v) (.data "Option" [.base .byte]) := by
  have h := scalarOption_typed P B Ψ .byte (fun x : UInt8 => .const (.byte x.toNat)) v
    someDecl noneDecl arity (fun x => (byte_result P B Ψ x).1)
  cases v <;> exact h

/-- Byte の fromInteger の None も正常な型付き応答である。 -/
theorem byte_fromInteger_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (n : Benitoite.Release.Integer64Value)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, byteDelta "Byte.fromInteger" [] [] [] [.const (.integer n)] = some (.val v) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [.base .byte]) :=
  ⟨_,rfl,byteOption_typed P B Ψ _ someDecl noneDecl arity⟩

/-- Character の明示変換は妥当な文字の Some と、正常な None を返す。 -/
theorem character_fromInteger_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (n : Benitoite.Release.Integer64Value)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, characterDelta "Character.fromInteger" [] [] [] [.const (.integer n)] = some (.val v) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [.base .character]) := by
  refine ⟨scalarOption .character (fun c => .const (.character c)) (characterConvert n.toInt),?_,?_⟩
  · cases h : characterConvert n.toInt <;> simp [characterDelta,scalarDelta,scalarArguments,characterDeltaAt,scalarOption,h]
  · exact scalarOption_typed P B Ψ .character _ _ someDecl noneDecl arity (fun _ => .V_Const trivial)

example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) :=
  byte_compare P B Ψ η 0 255 .lt
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) :=
  byte_compare P B Ψ η 255 255 .eq
example : byteDelta "%eq" [] [] [] [.const (.byte 7),.const (.byte 7)] = none ∧
    byteDelta "%eq" [.base .byte] [] [] [.const (.byte 7),.const (.byte 7)] =
      some (.val (.const (.boolean true))) := ⟨rfl,rfl⟩

end Benitoite.Release.Refinement.StandardScalar
