import Benitoite.Release.Refinement.TermSyntax

namespace Benitoite.Release.Refinement
open Benitoite.Release.Order
private theorem natPair_eq_iff {a b c d : Nat} : natPair a b = natPair c d ↔ a = c ∧ b = d :=
  ⟨natPair_injective, fun ⟨h, h'⟩ => by cases h; cases h'; rfl⟩

/-- 有限構文の欄を区別する自然数の符号。言語の鍵の等値とは別である。 -/
class NatCode (α : Type) where
  encode : α → Nat
  injective : Function.Injective encode

def code {α : Type} [NatCode α] : α → Nat := NatCode.encode
theorem code_injective {α : Type} [NatCode α] {a b : α} (h : code a = code b) : a = b :=
  NatCode.injective h
@[simp] theorem code_eq_iff {α : Type} [NatCode α] {a b : α} : code a = code b ↔ a = b :=
  ⟨code_injective, congrArg code⟩

instance : NatCode Nat := ⟨id, fun _ _ h => h⟩
@[simp] theorem code_nat (n : Nat) : code n = n := rfl
instance : NatCode String := ⟨stringCode, fun _ _ h => stringCode_injective h⟩
instance : NatCode Char := ⟨Char.toNat, fun _ _ h => Char.toNat_inj.mp h⟩
instance : NatCode UInt32 := ⟨UInt32.toNat, fun _ _ h => UInt32.toNat_inj.mp h⟩
instance : NatCode UInt64 := ⟨UInt64.toNat, fun _ _ h => UInt64.toNat_inj.mp h⟩
instance : NatCode (Fin n) := ⟨Fin.val, fun _ _ h => Fin.ext h⟩

private def listCode {α} [NatCode α] : List α → Nat
  | [] => 0
  | a :: as => natPair (code a) (listCode as) + 1
private theorem listCode_inj {α} [NatCode α] {as bs : List α}
    (h : listCode as = listCode bs) : as = bs := by
  induction as generalizing bs with
  | nil => cases bs <;> simp_all [listCode]
  | cons a as ih =>
    cases bs with
    | nil => simp [listCode] at h
    | cons b bs =>
      have hp := natPair_injective (Nat.add_right_cancel h)
      have ha := code_injective hp.1
      have hb := ih hp.2
      cases ha; cases hb; rfl
instance {α} [NatCode α] : NatCode (List α) := ⟨listCode, fun _ _ h => listCode_inj h⟩

private def optionCode {α} [NatCode α] : Option α → Nat
  | none => 0
  | some a => code a + 1
instance {α} [NatCode α] : NatCode (Option α) where
  encode := optionCode
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [optionCode, code_eq_iff]

private def intCode : Int → Nat
  | .ofNat n => 2*n
  | .negSucc n => 2*n+1
instance : NatCode Int where
  encode := intCode
  injective := by
    intro a b h
    cases a <;> cases b <;> simp only [intCode] at h <;> first | omega | congr 1 <;> omega

instance : NatCode Scope.Domain.PathPattern := ⟨pathCode, fun _ _ h => pathCode_injective h⟩
instance : NatCode Scope.Domain.Range := ⟨rangeCode, fun _ _ h => rangeCode_injective h⟩
instance : NatCode Scope.Domain.IPAddr := ⟨ipAddrCode, fun _ _ h => ipAddrCode_injective h⟩

private def encode0 : Bool → Nat
  | .false  => natPair 0 (0)
  | .true  => natPair 1 (0)
instance : NatCode Bool where
  encode := encode0
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode0, natPair_eq_iff]

private def encode1 : Scope.Domain.Kind → Nat
  | .path  => natPair 0 (0)
  | .host  => natPair 1 (0)
  | .endpoint  => natPair 2 (0)
instance : NatCode Scope.Domain.Kind where
  encode := encode1
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode1, natPair_eq_iff]

private def encode2 : Scope.Domain.HostTarget → Nat
  | .name x0 => natPair 0 (natPair (code x0) (0))
  | .ip x0 => natPair 1 (natPair (code x0) (0))
instance : NatCode Scope.Domain.HostTarget where
  encode := encode2
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode2, natPair_eq_iff]

private def encode3 : Scope.Domain.Endpoint → Nat
  | .mk x0 x1 => natPair 0 (natPair (code x0) (natPair (code x1) (0)))
instance : NatCode Scope.Domain.Endpoint where
  encode := encode3
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode3, natPair_eq_iff]

private def encode4 : Scope.Domain.Target → Nat
  | .path x0 => natPair 0 (natPair (code x0) (0))
  | .host x0 => natPair 1 (natPair (code x0) (0))
  | .endpoint x0 => natPair 2 (natPair (code x0) (0))
instance : NatCode Scope.Domain.Target where
  encode := encode4
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode4, natPair_eq_iff]

private def encode5 : PathBase → Nat
  | .root  => natPair 0 (0)
  | .cwd  => natPair 1 (0)
  | .home  => natPair 2 (0)
  | .work  => natPair 3 (0)
  | .tmp  => natPair 4 (0)
instance : NatCode PathBase where
  encode := encode5
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode5, natPair_eq_iff]

private def encode6 : PathEnv → Nat
  | .mk x0 x1 x2 x3 x4 x5 => natPair 0 (natPair (code x0) (natPair (code x1) (natPair (code x2) (natPair (code x3) (natPair (code x4) (natPair (code x5) (0)))))))
instance : NatCode PathEnv where
  encode := encode6
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode6, natPair_eq_iff]

private def encode7 : RangeExpr → Nat
  | .absolute x0 => natPair 0 (natPair (code x0) (0))
  | .based x0 x1 => natPair 1 (natPair (code x0) (natPair (code x1) (0)))
  | .secrets  => natPair 2 (0)
instance : NatCode RangeExpr where
  encode := encode7
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode7, natPair_eq_iff]

private def encode8 : RangeIx → Nat
  | .fixed x0 => natPair 0 (natPair (code x0) (0))
  | .rvar x0 => natPair 1 (natPair (code x0) (0))
instance : NatCode RangeIx where
  encode := encode8
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode8, natPair_eq_iff]

private def encode9 : «Sort» → Nat
  | .integer  => natPair 0 (0)
  | .character  => natPair 1 (0)
  | .float64  => natPair 2 (0)
  | .float32  => natPair 3 (0)
  | .decimal  => natPair 4 (0)
  | .boolean  => natPair 5 (0)
  | .unit  => natPair 6 (0)
  | .string  => natPair 7 (0)
  | .list  => natPair 8 (0)
  | .bytes  => natPair 9 (0)
  | .map  => natPair 10 (0)
  | .set  => natPair 11 (0)
  | .data  => natPair 12 (0)
  | .target x0 => natPair 13 (natPair (code x0) (0))
instance : NatCode «Sort» where
  encode := encode9
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode9, natPair_eq_iff]

private def encode10 : FieldRef → Nat
  | .mk x0 x1 x2 x3 => natPair 0 (natPair (code x0) (natPair (code x1) (natPair (code x2) (natPair (code x3) (0)))))
instance : NatCode FieldRef where
  encode := encode10
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode10, natPair_eq_iff]

private def encode11 : Measure → Nat
  | .stringBytes  => natPair 0 (0)
  | .stringCharacters  => natPair 1 (0)
  | .listLength  => natPair 2 (0)
  | .bytesLength  => natPair 3 (0)
  | .mapSize  => natPair 4 (0)
  | .setSize  => natPair 5 (0)
  | .characterCode  => natPair 6 (0)
instance : NatCode Measure where
  encode := encode11
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode11, natPair_eq_iff]

private def encode12 : Comparison → Nat
  | .eq  => natPair 0 (0)
  | .ne  => natPair 1 (0)
  | .lt  => natPair 2 (0)
  | .le  => natPair 3 (0)
  | .gt  => natPair 4 (0)
  | .ge  => natPair 5 (0)
instance : NatCode Comparison where
  encode := encode12
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode12, natPair_eq_iff]

private def encode13 : FloatWidth → Nat
  | .binary32  => natPair 0 (0)
  | .binary64  => natPair 1 (0)
instance : NatCode FloatWidth where
  encode := encode13
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode13, natPair_eq_iff]

private def encode14 : FloatClass → Nat
  | .finite  => natPair 0 (0)
  | .nan  => natPair 1 (0)
  | .positiveInfinity  => natPair 2 (0)
  | .negativeInfinity  => natPair 3 (0)
  | .positiveZero  => natPair 4 (0)
  | .negativeZero  => natPair 5 (0)
instance : NatCode FloatClass where
  encode := encode14
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [encode14, natPair_eq_iff]

instance : NatCode ExternalId := ⟨fun x => match x with | .mk n => n, by intro a b h; cases a; cases b; cases h; rfl⟩

private def atomCode : Atom → Nat
  | .name l ix => natPair 0 (natPair (code l) (code ix))
  | .rho i => natPair 1 i
instance : NatCode Atom where
  encode := atomCode
  injective := by
    intro a b h
    cases a <;> cases b <;> simp_all [atomCode, natPair_eq_iff]


end Benitoite.Release.Refinement
