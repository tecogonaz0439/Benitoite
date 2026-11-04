import Benitoite.Release.Refinement.StandardByteCharacter
import Benitoite.Release.Refinement.CoverageRefinement
import Benitoite.Release.Refinement.CollectionInversion

/-! # 有限列の長さと標準の応答 -/
namespace Benitoite.Release.Refinement.StandardCollections
noncomputable section

/-- 数学上の個数を検査して Integer に移す。表現外は停止の応答に残す。 -/
def countReply (n : Nat) : Outcome :=
  match StandardScalar.integerConvert .integer64 n with
  | some v => .val (.const (.integer v))
  | none => .err "length does not fit Integer"

theorem countReply_normal (n : Nat) (v : Benitoite.Release.Integer64Value) :
    countReply n = .val (.const (.integer v)) ↔ v.toInt = n := by
  unfold countReply
  cases h : StandardScalar.integerConvert .integer64 n with
  | none =>
    simp only [reduceCtorEq, false_iff]
    intro eq
    have := (StandardScalar.integerConvert_some .integer64 n v).mpr eq
    rw [h] at this
    cases this
  | some w =>
    have eq := (StandardScalar.integerConvert_some .integer64 n w).mp h
    simp only [Outcome.val.injEq,Val.const.injEq,Const.integer.injEq]
    constructor
    · intro h; cases h; exact eq
    · intro h; apply Subtype.ext; exact eq.trans h.symm

theorem countReply_stop (n : Nat) :
    countReply n = .err "length does not fit Integer" ↔ Benitoite.Release.max64 < (n : Int) := by
  unfold countReply
  cases h : StandardScalar.integerConvert .integer64 n with
  | none =>
    have hn := (StandardScalar.integerConvert_none .integer64 n).mp h
    simp only [Benitoite.Interval.IntKind.min, Benitoite.Interval.IntKind.max] at hn
    simp only [Benitoite.Release.min64] at hn
    simp only [true_iff]
    omega
  | some v =>
    have eq := (StandardScalar.integerConvert_some .integer64 n v).mp h
    have bound := v.property
    change Benitoite.Release.min64 ≤ v.val ∧ v.val ≤ Benitoite.Release.max64 at bound
    change v.val = (n : Int) at eq
    simp only [reduceCtorEq, false_iff]
    omega

/-- 四つの長さの入口。List だけが一つの型引数を持つ。 -/
def lengthDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  if es.isEmpty && rs.isEmpty then
    match name,ts,ws with
    | "String.byteLength",[],[.const (.string s)] => some (countReply s.utf8ByteSize)
    | "String.characterCount",[],[.const (.string s)] => some (countReply s.toList.length)
    | "Bytes.length",[],[.bytesV bs] =>
        if bs.all (· ≤ 255) then some (countReply bs.length) else none
    | "List.length",[_],[.list xs] => some (countReply xs.length)
    | "List.isEmpty",[_],[.list xs] => some (.val (.const (.boolean xs.isEmpty)))
    | _,_,_ => none
  else none

/-- 挿入の二つの標準名は、ともに一要素を追加する。 -/
def insertDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  match ts,es,rs,ws with
  | [_],[],[],[.list xs,x] =>
      if name = "List.prepend" then some (.val (.list (x :: xs)))
      else if name = "List.append" then some (.val (.list (xs ++ [x]))) else none
  | _,_,_,_ => none

private theorem each_append {P B Ψ Q C Γ Φ a xs ys}
    (hx : HasTypeEachQ P B Ψ Q C Γ Φ xs a)
    (hy : HasTypeEachQ P B Ψ Q C Γ Φ ys a) :
    HasTypeEachQ P B Ψ Q C Γ Φ (xs ++ ys) a := by
  induction xs with
  | nil => exact hy
  | cons x xs ih =>
    cases hx with
    | cons h hs => exact .cons h (ih hs)

theorem insert_reply {P B Ψ Q C Γ Φ a xs x}
    (annotation : Ty.Annotation P C Γ a)
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a)
    (element : HasTypeVQ P B Ψ Q C Γ Φ x a) (append : Bool) :
    ∃ ys, insertDelta (if append then "List.append" else "List.prepend") [a] [] [] [.list xs,x] =
        some (.val (.list ys)) ∧
      HasTypeVQ P B Ψ Q C Γ Φ (.list ys) (.list a) ∧ ys.length = xs.length + 1 := by
  cases append
  · exact ⟨x :: xs,rfl,.V_List (.cons element typed) annotation.wf annotation.sorted annotation.declared,by simp⟩
  · exact ⟨xs ++ [x],rfl,.V_List (each_append typed (.cons element .nil))
      annotation.wf annotation.sorted annotation.declared,by simp⟩

/-- 二列の順序を保つ連結と、同じ列の逆順。 -/
def sequenceDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  match name,ts,es,rs,ws with
  | "List.concatenate",[_],[],[],[.list xs,.list ys] => some (.val (.list (xs ++ ys)))
  | "List.reverse",[_],[],[],[.list xs] => some (.val (.list xs.reverse))
  | _,_,_,_,_ => none

theorem concatenate_reply {P B Ψ Q C Γ Φ a xs ys}
    (annotation : Ty.Annotation P C Γ a)
    (left : HasTypeEachQ P B Ψ Q C Γ Φ xs a)
    (right : HasTypeEachQ P B Ψ Q C Γ Φ ys a) :
    sequenceDelta "List.concatenate" [a] [] [] [.list xs,.list ys] =
      some (.val (.list (xs ++ ys))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.list (xs ++ ys)) (.list a) ∧
    (xs ++ ys).length = xs.length + ys.length :=
  ⟨rfl,.V_List (each_append left right) annotation.wf annotation.sorted annotation.declared,
    List.length_append⟩

theorem reverse_reply {P B Ψ Q C Γ Φ a xs}
    (annotation : Ty.Annotation P C Γ a)
    (typed : HasTypeEachQ P B Ψ Q C Γ Φ xs a) :
    sequenceDelta "List.reverse" [a] [] [] [.list xs] = some (.val (.list xs.reverse)) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.list xs.reverse) (.list a) ∧
    xs.reverse.length = xs.length := by
  have each : HasTypeEachQ P B Ψ Q C Γ Φ xs.reverse a := by
    have build : ∀ ys : List Val, (∀ v ∈ ys, HasTypeVQ P B Ψ Q C Γ Φ v a) →
        HasTypeEachQ P B Ψ Q C Γ Φ ys a := by
      intro ys
      induction ys with
      | nil => intro _; exact .nil
      | cons y ys ih => intro h; exact .cons (h y (by simp)) (ih (fun v hv => h v (by simp [hv])))
    exact build _ (fun v hv => typed.member (List.mem_reverse.mp hv))
  exact ⟨rfl,.V_List each annotation.wf annotation.sorted annotation.declared,List.length_reverse⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (.list [Val.const .unit, .const .unit]) (.list (.base .unit)) :=
  (concatenate_reply (a := .base .unit) (xs := [.const .unit]) (ys := [.const .unit]) ⟨trivial,trivial,trivial⟩
    (.cons (.V_Const trivial) .nil) (.cons (.V_Const trivial) .nil)).2.1
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (.list ([Val.const .unit].reverse)) (.list (.base .unit)) :=
  (reverse_reply (a := .base .unit) (xs := [.const .unit]) ⟨trivial,trivial,trivial⟩ (.cons (.V_Const trivial) .nil)).2.1

theorem isEmpty_reply {P B Ψ} (a : Ty) (xs : List Val) :
    lengthDelta "List.isEmpty" [a] [] [] [.list xs] = some (.val (.const (.boolean xs.isEmpty))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean xs.isEmpty)) (.base .boolean) ∧
    (xs.isEmpty = true ↔ xs.length = 0) := by
  refine ⟨rfl,.V_Const trivial,?_⟩
  cases xs <;> simp

example (P : Program) (B : Builtins) (Ψ : StoreTy) (append : Bool) :
    ∃ ys, insertDelta (if append then "List.append" else "List.prepend") [.base .unit] [] []
      [.list [],.const .unit] = some (.val (.list ys)) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.list ys) (.list (.base .unit)) ∧ ys.length = 1 :=
  insert_reply (a := .base .unit) (xs := []) (x := .const .unit)
    ⟨trivial,trivial,trivial⟩ .nil (.V_Const trivial) append
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean true)) (.base .boolean) :=
  (isEmpty_reply (.base .unit) []).2.1

/-- 正常な個数に非負の篩を導入する。整数の上限は元の定数の型域から得る。 -/
theorem countReply_typed {P B Ψ} (n : Nat) (v : Benitoite.Release.Integer64Value)
    (normal : countReply n = .val (.const (.integer v))) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer v))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) := by
  have eq := (countReply_normal n v).mp normal
  have nonnegative : 0 ≤ v.toInt := by omega
  have base : HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer v)) (.base .integer) :=
    .V_Const trivial
  apply HasTypeVQ.V_Refine base (sort := .integer) rfl rfl
  · exact ⟨⟨trivial,rfl⟩,⟨⟨.base .integer,rfl,by trivial⟩,⟨.base .integer,rfl,rfl⟩⟩⟩
  · simp [Pred.WF,Pred.VarsIn,Term.VarsIn]
  · exact .integer_le nonnegative
  · trivial
  · exact ⟨trivial, ⟨.base .integer,rfl,by trivial⟩⟩

/-- 同じ標準応答、長さの篩、実 measure の観測を一緒に返す。 -/
theorem length_reply {P B Ψ} (name : PrimName) (ts : List Ty) (input : Val)
    (m : Measure) (o : Observation) (n : Nat) (t : Term)
    (η : ObservationEnvModel) (v : Benitoite.Release.Integer64Value)
    (delta : lengthDelta name ts [] [] [input] = some (countReply n))
    (normal : countReply n = .val (.const (.integer v)))
    (term : input.toTerm? = some t) (observed : t.observe η = some o)
    (measure : Observation.measure m o = some (.integer n)) :
    lengthDelta name ts [] [] [input] = some (.val (.const (.integer v))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer v))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    input.toTerm? = some t ∧
    (Term.measure m t).observe η = some (.integer v.toInt) ∧ 0 ≤ v.toInt := by
  have eq := (countReply_normal n v).mp normal
  exact ⟨normal ▸ delta,countReply_typed n v normal,term,
    eq ▸ (measure_machine_exact measure η t observed).1,by omega⟩

/-- 観測できない要素も外側の長さに含める。 -/
theorem list_length (a : Ty) (xs : List Val) (η : ObservationEnvModel) :
    lengthDelta "List.length" [a] [] [] [.list xs] = some (countReply xs.length) ∧
    (Term.measure .listLength (.listValue (Val.toTermSlots xs))).observe η =
      some (.integer xs.length) := by
  refine ⟨rfl,?_⟩
  simp [Term.observe,Observation.measure,observeSlots_length]

theorem bytes_length (bs : List Nat) (valid : bs.all (· ≤ 255) = true)
    (η : ObservationEnvModel) :
    lengthDelta "Bytes.length" [] [] [] [.bytesV bs] = some (countReply bs.length) ∧
    (Term.measure .bytesLength (.bytesValue bs)).observe η = some (.integer bs.length) := by
  simp [lengthDelta,Term.observe,Observation.measure,valid]

/-- UTF-8 の byte 数と文字の数をそれぞれの標準名へ渡す。 -/
theorem string_lengths (s : String) (η : ObservationEnvModel) :
    lengthDelta "String.byteLength" [] [] [] [.const (.string s)] = some (countReply s.utf8ByteSize) ∧
    lengthDelta "String.characterCount" [] [] [] [.const (.string s)] = some (countReply s.toList.length) ∧
    (Term.measure .stringBytes (.string s)).observe η = some (.integer s.utf8ByteSize) ∧
    (Term.measure .stringCharacters (.string s)).observe η = some (.integer s.toList.length) :=
  ⟨rfl,rfl,rfl,rfl⟩

theorem string_length_reply {P B Ψ} (s : String) (characters : Bool)
    (v : Benitoite.Release.Integer64Value)
    (normal : countReply (if characters then s.toList.length else s.utf8ByteSize) =
      .val (.const (.integer v))) (η : ObservationEnvModel) :
    lengthDelta (if characters then "String.characterCount" else "String.byteLength") [] [] []
      [.const (.string s)] = some (.val (.const (.integer v))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer v))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure (if characters then .stringCharacters else .stringBytes) (.string s)).observe η =
      some (.integer v.toInt) := by
  cases characters with
  | false =>
    obtain ⟨hd,ht,_,hm,_⟩ := length_reply (P := P) (B := B) (Ψ := Ψ)
      "String.byteLength" [] (.const (.string s)) .stringBytes (.string s) s.utf8ByteSize
      (.string s) η v rfl normal rfl rfl rfl
    exact ⟨hd,ht,hm⟩
  | true =>
    obtain ⟨hd,ht,_,hm,_⟩ := length_reply (P := P) (B := B) (Ψ := Ψ)
      "String.characterCount" [] (.const (.string s)) .stringCharacters (.string s) s.toList.length
      (.string s) η v rfl normal rfl rfl rfl
    exact ⟨hd,ht,hm⟩

theorem list_length_reply {P B Ψ} (a : Ty) (xs : List Val)
    (v : Benitoite.Release.Integer64Value)
    (normal : countReply xs.length = .val (.const (.integer v))) (η : ObservationEnvModel) :
    lengthDelta "List.length" [a] [] [] [.list xs] = some (.val (.const (.integer v))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer v))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure .listLength (.listValue (Val.toTermSlots xs))).observe η = some (.integer v.toInt) := by
  have eq := (countReply_normal _ v).mp normal
  exact ⟨normal ▸ (list_length a xs η).1,countReply_typed _ v normal,
    eq ▸ (list_length a xs η).2⟩

theorem bytes_length_reply {P B Ψ} (bs : List Nat) (valid : bs.all (· ≤ 255) = true)
    (v : Benitoite.Release.Integer64Value)
    (normal : countReply bs.length = .val (.const (.integer v))) (η : ObservationEnvModel) :
    lengthDelta "Bytes.length" [] [] [] [.bytesV bs] = some (.val (.const (.integer v))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer v))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Term.measure .bytesLength (.bytesValue bs)).observe η = some (.integer v.toInt) := by
  have eq := (countReply_normal _ v).mp normal
  exact ⟨normal ▸ (bytes_length bs valid η).1,countReply_typed _ v normal,
    eq ▸ (bytes_length bs valid η).2⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨1,by decide⟩))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) :=
  (string_length_reply "é" true _ rfl η).2.1
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨1,by decide⟩))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) :=
  (list_length_reply (.fn [] [] (.base .unit) Eff.empty) [.lam [] [] (.ret (.const .unit))] _ rfl η).2.1
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨2,by decide⟩))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) :=
  (bytes_length_reply [0,255] (by decide) _ rfl η).2.1

example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) :
    lengthDelta "String.byteLength" [] [] [] [.const (.string "é")] =
      some (.val (.const (.integer ⟨2,by decide⟩))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨2,by decide⟩))
      (.refined (.base .integer) (.le (.integer 0) (.var 0))) ∧
    (Val.const (.string "é")).toTerm? = some (.string "é") ∧
    (Term.measure .stringBytes (.string "é")).observe η = some (.integer 2) ∧ (0 : Int) ≤ 2 :=
  length_reply "String.byteLength" [] _ .stringBytes (.string "é") 2 (.string "é") η _
    rfl rfl rfl rfl rfl

example : lengthDelta "String.characterCount" [] [] [] [.const (.string "é")] =
    some (.val (.const (.integer ⟨1,by decide⟩))) ∧
    lengthDelta "List.length" [] [] [] [.list []] = none ∧
    lengthDelta "Bytes.length" [] [] [] [.bytesV [256]] = none ∧
    countReply 9223372036854775808 = .err "length does not fit Integer" := by
  constructor
  · rfl
  · constructor
    · rfl
    · constructor <;> rfl

example (xs : List Val) (η : ObservationEnvModel) :
    (Term.measure .listLength (.listValue (Val.toTermSlots xs))).observe η =
      some (.integer xs.length) := (list_length (.base .unit) xs η).2
example (η : ObservationEnvModel) :
    (Term.measure .bytesLength (.bytesValue [0,255])).observe η = some (.integer 2) :=
  (bytes_length [0,255] (by decide) η).2
example (η : ObservationEnvModel) :
    (Term.measure .stringCharacters (.string "é")).observe η = some (.integer 1) :=
  (string_lengths "é" η).2.2.2
example : countReply 9223372036854775808 = .err "length does not fit Integer" :=
  (countReply_stop _).mpr (by decide)

end
end Benitoite.Release.Refinement.StandardCollections
