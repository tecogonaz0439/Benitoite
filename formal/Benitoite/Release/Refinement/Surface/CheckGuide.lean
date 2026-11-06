import Benitoite.Release.Refinement.Surface.CheckInferFailure
import Benitoite.Release.Refinement.Surface.CheckSource

/-! 表層の検査へ渡す有限の案内。規則名は型付けの規則と一対一に対応する。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckArguments CheckSubtyping

inductive Rule where
  | E_BuilderOp
  | E_Local
  | E_Const
  | E_Fun
  | E_FunDicts
  | E_MethName
  | E_Prim
  | E_Raise
  | E_HandleFail
  | E_Op
  | E_OpDicts
  | E_ExternalName
  | E_NullCon
  | E_ConValue
  | E_Refine
  | E_Literal
  | E_NegInt
  | E_NegFloat
  | E_NegDecimal
  | E_NegInteger8
  | E_NegInteger16
  | E_NegInteger32
  | E_NegFloat32
  | E_Unit
  | E_Block
  | E_Paren
  | E_Record
  | E_RecordUpdate
  | E_RecordRefined
  | E_RecordUpdateRefined
  | E_ConCall
  | E_CallDirect
  | E_CallExternal
  | E_Call
  | E_PipeConCall
  | E_PipeConValue
  | E_PipeCallDirect
  | E_PipeCall
  | E_PipeApplyDirect
  | E_PipeApply
  | E_PartialCallDirect
  | E_PartialCall
  | E_PartialCallDirectDep
  | E_PartialCallDep
  | E_PartialCon
  | E_Binary
  | E_Neg
  | E_Not
  | E_And
  | E_Or
  | E_List
  | E_ListRefined
  | E_ListSpread
  | E_Interpolation
  | E_Lam
  | E_If
  | E_ElseIf
  | E_IfOnly
  | E_Match
  | E_ReturnTail
  | E_ReturnOther
  | E_TryResult
  | E_TryOption
  | E_TryResultDie
  | E_TryResultDieMessage
  | E_TryOptionDie
  | E_TryOptionDieMessage
  | E_With
  | E_Lazy
  | E_Handle
  | E_Resume
  | E_Sub
  | B_BuilderBind
  | B_Empty
  | B_Last
  | B_LastBind
  | B_LastDiscard
  | B_Bind
  | B_Discard
  | B_Seq
  | B_LastPat
  | B_BindPat
  | B_Sub
  | Types_nil
  | Types_cons
  | Each_nil
  | Each_cons
  | Fixed_nil
  | Fixed_expr
  | Fixed_hole
  | Arms_nil
  | Arms_plain
  | Arms_guarded
  | Clauses_nil
  | Clauses_cons
  | Spread_only
  | Spread_front
  | Spread_back
  | Spread_middle
  | Join_last
  | Join_step
  | JoinParts_empty
  | JoinParts_single
  | JoinParts_many
  | Interp_done
  | Interp_text
  | Interp_stringExpr
  | Interp_converted
  | Interp_formatted
  deriving DecidableEq

/-- 中間型・効果と、再検査する有限の証明書。型付けや含意の証明は持たない。 -/
structure Hints where
  types : List Ty := []
  typeLists : List (List Ty) := []
  effects : List Eff := []
  signatures : List Tel := []
  predicates : List Pred := []
  facts : List (List Pred) := []
  proofs : List LogicCertificate := []
  proofLists : List (List LogicCertificate) := []
  subtypes : List LeCertificate := []
  arguments : List (List ElemGuide) := []
  heads : List HeadGuide := []
  links : List (List FieldLink) := []
  ranges : List RangeExpr := []

/-- ソースを二重に保存せず、選んだ規則とその子の案内だけを保存する。 -/
inductive Guide where
  | unknown
  /-- 内部の候補の生成で得た拒否又は停止。型付けの案内としては成功しない。 -/
  | failure (failure : CheckInfer.Failure)
  | node (rule : Rule) (hints : Hints) (children : List Guide)

def Hints.ty (h : Hints) (i : Nat) : Ty := (h.types[i]?).getD (.base .unit)
def Hints.tys (h : Hints) (i : Nat) : List Ty := (h.typeLists[i]?).getD []
def Hints.eff (h : Hints) (i : Nat) : Eff := (h.effects[i]?).getD Eff.empty
def Hints.tel (h : Hints) (i : Nat) : Tel := (h.signatures[i]?).getD (.done (.base .unit) Eff.empty)
def Hints.pred (h : Hints) (i : Nat) : Pred := (h.predicates[i]?).getD .truth
def Hints.factsAt (h : Hints) (i : Nat) : List Pred := (h.facts[i]?).getD []
def Hints.proof (h : Hints) (i : Nat) : LogicCertificate := (h.proofs[i]?).getD ⟨.use 0, [], none⟩
def Hints.proofsAt (h : Hints) (i : Nat) : List LogicCertificate := (h.proofLists[i]?).getD []
def Hints.le (h : Hints) (i : Nat) : LeCertificate := (h.subtypes[i]?).getD (.refl (.base .unit))
def Hints.args (h : Hints) (i : Nat) : List ElemGuide := (h.arguments[i]?).getD []
def Hints.head (h : Hints) (i : Nat) : HeadGuide := (h.heads[i]?).getD .plain
def Hints.fieldLinks (h : Hints) (i : Nat) : List FieldLink := (h.links[i]?).getD []
def Hints.range (h : Hints) (i : Nat) : RangeExpr := (h.ranges[i]?).getD (.absolute .top)

structure Hints.Support (s : List Atom) (h : Hints) : Prop where
  types : Ty.SupportList (· ∈ s) h.types
  typeLists : ∀ ts ∈ h.typeLists, Ty.SupportList (· ∈ s) ts
  effects : ∀ e ∈ h.effects, e.Support (· ∈ s)
  signatures : ∀ t ∈ h.signatures, t.Support (· ∈ s)
  subtypes : ∀ c ∈ h.subtypes, c.Supported s
  arguments : ∀ gs ∈ h.arguments, ElemGuidesSupport s gs
  heads : ∀ g ∈ h.heads, g.Support s

mutual
  def Guide.Support (s : List Atom) : Guide → Prop
    | .unknown | .failure _ => True
    | .node _ h children => h.Support s ∧ GuidesSupport s children
  def GuidesSupport (s : List Atom) : List Guide → Prop
    | [] => True
    | g :: gs => g.Support s ∧ GuidesSupport s gs
end

theorem getD_property {α : Type} {P : α → Prop} {xs : List α} {fallback : α}
    (hx : ∀ x ∈ xs, P x) (hd : P fallback) (i : Nat) : P ((xs[i]?).getD fallback) := by
  cases hi : xs[i]? with
  | none => exact hd
  | some x => exact hx x (List.mem_of_getElem? hi)

theorem Hints.Support.ty {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : (h.ty i).Support (· ∈ s) :=
  getD_property (fallback := Ty.base .unit) (Ty.SupportList.iff.mp hh.types) trivial i

theorem Hints.Support.tys {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : Ty.SupportList (· ∈ s) (h.tys i) :=
  getD_property (fallback := ([] : List Ty)) hh.typeLists trivial i

theorem Hints.Support.eff {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : (h.eff i).Support (· ∈ s) :=
  getD_property (fallback := Eff.empty) hh.effects ⟨(by intro a ha; cases ha), trivial⟩ i

theorem Hints.Support.tel {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : (h.tel i).Support (· ∈ s) :=
  getD_property (fallback := Tel.done (.base .unit) Eff.empty) hh.signatures ⟨trivial, ⟨(by intro a ha; cases ha), trivial⟩⟩ i

theorem Hints.Support.le {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : (h.le i).Supported s :=
  getD_property (fallback := LeCertificate.refl (.base .unit)) hh.subtypes ⟨trivial, trivial, trivial⟩ i

theorem Hints.Support.args {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : ElemGuidesSupport s (h.args i) :=
  getD_property (fallback := ([] : List ElemGuide)) hh.arguments trivial i

theorem Hints.Support.head {s : List Atom} {h : Hints} (hh : h.Support s) (i : Nat) : (h.head i).Support s :=
  getD_property (fallback := HeadGuide.plain) hh.heads trivial i

end Benitoite.Release.Refinement.Surface.Check
