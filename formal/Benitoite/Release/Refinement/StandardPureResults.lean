import Benitoite.Release.Refinement.StandardFloatMathResponse
import Benitoite.Release.Refinement.StandardDecimalResponse

/-! # 純粋応答の有限な結果の構成 -/
namespace Benitoite.Release.Refinement.StandardPureResults
open Benitoite.Interval StandardScalar StandardCollections
noncomputable section

private def splitChars (first : Char) (tail : List Char) (acc : List Char) :
 List Char → List (List Char)
 | [] => [acc.reverse]
 | c::cs =>
   if c==first && tail.isPrefixOf cs then
    acc.reverse :: splitChars first tail [] (cs.drop tail.length)
   else splitChars first tail (c::acc) cs
termination_by source => source.length
decreasing_by all_goals simp_wf <;> omega

/-- 元の文字列を左から非重複で分割し、末尾の空片を保持する。 -/
def stringParts (s separator : String) : List String :=
 match separator.toList with
 | [] => [s]
 | first::tail => (splitChars first tail [] s.toList).map String.ofList

example : stringParts "a\n" "\n" = ["a",""] := by decide +kernel


private def constructors : List (ConName × ConDecl) :=
 [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),
  ("ByteOrder.BigEndian",⟨"ByteOrder",0,[]⟩),("ByteOrder.LittleEndian",⟨"ByteOrder",0,[]⟩)]
def program : Program where
 defs := fun _ => none
 cons := fun c => constructors.lookup c
 ops := fun _ => none
 effects := fun _ => none
 classes := fun _ => none
 impls := fun _ => none
private theorem cons_mem {c cd} (h : program.cons c=some cd) : (c,cd)∈constructors := by
 obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp h
 rw [eq]
 exact List.mem_append_right _ (List.mem_cons_self ..)

theorem option_arity : program.DataArity "Option" 1 := by
 refine ⟨⟨"Option.Some",_,rfl,rfl⟩,?_⟩
 intro c cd h owner
 have mem := cons_mem h
 simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
 rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all
theorem byteOrder_arity : program.DataArity "ByteOrder" 0 := by
 refine ⟨⟨"ByteOrder.BigEndian",_,rfl,rfl⟩,?_⟩
 intro c cd h owner
 have mem := cons_mem h
 simp only [constructors,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
 rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all

/-- 同じ宣言表からByteOrderの両正常値を構成する。 -/
theorem byteOrder_typed (B : Builtins) (Ψ : StoreTy) (big : Bool) :
 HasTypeVQ program B Ψ Qempty [] [] []
  (.con (if big then "ByteOrder.BigEndian" else "ByteOrder.LittleEndian") [] []) (.data "ByteOrder" []) := by
 have kinds : TypeArgsKinded program [] [] [] := ⟨rfl,by intro i a k h; cases h⟩
 have annotation : Ty.Annotation program [] [] (.data "ByteOrder" []) :=
  ⟨trivial,trivial,⟨⟨0,byteOrder_arity,rfl⟩,trivial⟩⟩
 cases big
 all_goals refine HasTypeVQ.V_Con (cd := ⟨"ByteOrder",0,[]⟩) rfl rfl kinds ?_ .nil annotation
 all_goals intro t ht; cases ht
example (B : Builtins) (Ψ : StoreTy) :
 HasTypeVQ program B Ψ Qempty [] [] [] (.con "ByteOrder.BigEndian" [] []) (.data "ByteOrder" []) :=
 byteOrder_typed B Ψ true

inductive Kind where
 | string | boolean | integer | character | byte | bytes | float32 | float64 | decimal
 | list (element : Kind)
 | option (element : Kind)
 deriving DecidableEq

def Kind.type : Kind → Ty
 | .string => .base .string | .boolean => .base .boolean | .integer => .base .integer
 | .character => .base .character | .byte => .base .byte | .bytes => .bytes
 | .float32 => .base .float32 | .float64 => .base .float | .decimal => .base .decimal
 | .list k => .list k.type | .option k => .data "Option" [k.type]

def Kind.Payload : Kind → Type
 | .string => String | .boolean => Bool | .integer => Integer64Value | .character => Char
 | .byte => UInt8 | .bytes => List UInt8 | .float32 => UInt32 | .float64 => UInt64
 | .decimal => {v : Int × Nat // decimalRepresentable v.1 v.2}
 | .list k => List k.Payload | .option k => Option k.Payload

def Kind.encode : (k : Kind) → k.Payload → Val
 | .string,s => .const (.string s) | .boolean,b => .const (.boolean b)
 | .integer,n => .const (.integer n) | .character,c => .const (.character c)
 | .byte,b => .const (.byte b.toNat) | .bytes,bs => bytesFromList bs
 | .float32,bits => .const (.float32 bits) | .float64,bits => .const (.float64 bits)
 | .decimal,v => .const (.decimal v.val.1 v.val.2)
 | .list k,xs => .list (xs.map k.encode)
 | .option k,none => .con "Option.None" [k.type] []
 | .option k,some x => .con "Option.Some" [k.type] [k.encode x]

theorem Kind.normal (k : Kind) : k.type.norm=k.type := by
 induction k with
 | list k ih => simp [Kind.type,Ty.norm,ih]
 | option k ih => simp [Kind.type,Ty.norm,Ty.normTys,ih]
 | _ => rfl

theorem Kind.ordinary (k : Kind) : Ordinary k.type := by
 cases k <;> intro b t e h <;> cases h

theorem Kind.formed {P} (arity : P.DataArity "Option" 1) (k : Kind) :
 Ty.Annotation P [] [] k.type ∧ Ty.HasKind P [] k.type .value := by
 induction k with
 | list k ih =>
  refine ⟨⟨?_,?_,?_⟩,?_⟩
  · exact ih.1.wf
  · exact ih.1.sorted
  · exact ih.1.declared
  · exact ih.2
 | option k ih =>
  refine ⟨⟨?_,?_,?_⟩,?_⟩
  · exact ⟨ih.1.wf,trivial⟩
  · exact ⟨ih.1.sorted,trivial⟩
  · exact ⟨⟨1,arity,rfl⟩,ih.1.declared,trivial⟩
  · simp only [Kind.type,Ty.HasKind,kindsList]
    exact ⟨TyCon.arity_data arity,ih.2,trivial⟩
 | _ => exact ⟨⟨trivial,trivial,trivial⟩,trivial⟩

private theorem one_kinded {P} (arity : P.DataArity "Option" 1) (k : Kind) :
 TypeArgsKinded P [] [k.type] [.value] := by
 refine ⟨rfl,?_⟩
 rintro (_|i) t j ht hj
 · cases Option.some.inj ht
   cases Option.some.inj hj
   exact ⟨(k.formed arity).2,fun _ => k.ordinary⟩
 · simp at ht

theorem Kind.typed {P B Ψ} (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩) (arity : P.DataArity "Option" 1)
 (k : Kind) (value : k.Payload) :
 HasTypeVQ P B Ψ Qempty [] [] [] (k.encode value) k.type := by
 induction k with
 | list k ih =>
  apply HasTypeVQ.V_List _ (k.formed arity).1.wf (k.formed arity).1.sorted (k.formed arity).1.declared
  induction value with
  | nil => exact .nil
  | cons x xs tail => exact .cons (ih x) tail
 | option k ih =>
  have ann := (Kind.option k).formed arity |>.1
  cases value with
  | none => exact .V_Con noneDecl rfl (one_kinded arity k) (by simp) .nil ann
  | some x =>
   apply HasTypeVQ.V_Con someDecl rfl (one_kinded arity k) ?_ ?_ ann
   · intro t ht; simp only [List.mem_singleton] at ht; subst t; exact Nat.zero_lt_succ 0
   · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,k.normal]
       using (HasTypeVsQ.cons (ih x) HasTypeVsQ.nil)
 | byte =>
  apply HasTypeVQ.V_Const
  have h := value.toNat_lt
  change value.toNat ≤ 255
  omega
 | bytes => exact (bytesFromList_typed P B Ψ value).1
 | decimal => exact .V_Const value.property
 | _ => exact .V_Const trivial

theorem Kind.ground (k : Kind) (value : k.Payload) : (k.encode value).Ground := by
 induction k with
 | list k ih =>
  change Val.ClosedList 0 0 (value.map k.encode)
  induction value with
  | nil => trivial
  | cons x xs tail => exact ⟨ih x,tail⟩
 | option k ih =>
  cases value with
  | none =>
   refine ⟨?_,trivial⟩
   intro a ha; cases List.mem_singleton.mp ha
   exact (k.formed (P := StandardCollectionModel.program) StandardConversionResponse.option_arity).1.wf
  | some x =>
   refine ⟨?_,ih x,trivial⟩
   intro a ha; cases List.mem_singleton.mp ha
   exact (k.formed (P := StandardCollectionModel.program) StandardConversionResponse.option_arity).1.wf
 | _ => trivial

theorem Kind.adequate (σ : PathEnv) (k : Kind) (value : k.Payload) :
 (k.encode value).Adequate σ := by
 induction k with
 | list k ih =>
  change adequateVals σ (value.map k.encode)
  induction value with
  | nil => trivial
  | cons x xs tail => exact ⟨ih x,tail⟩
 | option k ih =>
  cases value with
  | none => trivial
  | some x => exact ⟨ih x,trivial⟩
 | _ => trivial

def reply (k : Kind) : Except String k.Payload → Outcome
 | .error message => .err message
 | .ok value => .val (k.encode value)

theorem reply_safe {P B Ψ} (someDecl : P.cons "Option.Some"=some ⟨"Option",1,[.tvar 0]⟩)
 (noneDecl : P.cons "Option.None"=some ⟨"Option",1,[]⟩) (arity : P.DataArity "Option" 1)
 (k : Kind) (value : Except String k.Payload) (ws : List Val) :
 Outcome.Typed P B Ψ (reply k value) k.type ∧ AdequateResult ws (reply k value) ∧
 (∀ i, reply k value≠.exit i) := by
 cases value with
 | error message => exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp [reply]⟩
 | ok value => exact ⟨⟨k.typed someDecl noneDecl arity value,k.ground value⟩,
    by intro σ _ _; exact k.adequate σ value,by intro i; simp [reply]⟩
end
end Benitoite.Release.Refinement.StandardPureResults

