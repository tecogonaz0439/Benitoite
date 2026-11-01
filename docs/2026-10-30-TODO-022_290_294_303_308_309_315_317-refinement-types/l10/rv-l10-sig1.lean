import Benitoite
open Benitoite

namespace RVL10
namespace S
open Benitoite.Release.Refinement
mutual
  def Ty.Support (p : Atom → Prop) : Ty → Prop
    | .data _ ts | .tapp _ ts | .external _ ts => Ty.SupportList p ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t | .refined t _ => Ty.Support p t
    | .fn _ ps r e => Ty.SupportList p ps ∧ Ty.Support p r ∧ Eff.Support p e
    | .cont a b e => Ty.Support p a ∧ Ty.Support p b ∧ Eff.Support p e
    | .map a b => Ty.Support p a ∧ Ty.Support p b
    | .dependentFn t => Tel.Support p t
    | _ => True
  def Ty.SupportList (p : Atom → Prop) : List Ty → Prop
    | [] => True
    | t :: ts => Ty.Support p t ∧ Ty.SupportList p ts
  def Eff.Support (p : Atom → Prop) : Eff → Prop
    | .mk f fs => (∀ a, f a = true → p a) ∧ Ty.SupportList p fs
  def Tel.Support (p : Atom → Prop) : Tel → Prop
    | .done r e => Ty.Support p r ∧ Eff.Support p e
    | .param _ a t => Ty.Support p a ∧ Tel.Support p t
end
#check @Ty.Support
end S

namespace E
open Benitoite.Release.Refinement
variable {P : Program} {B : Builtins}

theorem embed_const {Ψ Q C Γ Φ} (c : Benitoite.Release.Const)
    (hc : ConstOK B (embedConst c)) :
    HasTypeVQ P B Ψ Q C Γ Φ (.const (embedConst c)) (embedTy c.type) := by
  rw [← Const.type_embed]; exact .V_Const hc
theorem embed_bytes {Ψ Q C Γ Φ} (bs : List Nat)
    (hb : ∀ b ∈ bs, b ≤ 255) :
    HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) .bytes := .V_Bytes hb
theorem embed_checked {Ψ Q C Γ Φ o k range target}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checked target)
      (.scoped o k (.fixed (.absolute range))) := .V_Checked hk hc hm
theorem embed_checkedRequest {Ψ Q C Γ Φ o range target req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (ht : HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] (embedVal req) T.norm)
    (hg : groundVal (embedVal req) = true)
    (he : (embedVal req).reqTarget = some target)
    (hm : Scope.Domain.Range.MemK .endpoint range target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target (embedVal req))
      (.scoped o .endpoint (.fixed (.absolute range))) :=
  .V_CheckedRequest hk hc ht hg he hm

theorem embed_normal_eq_iff (a b : Benitoite.Release.Ty) :
    (embedTy a).norm = (embedTy b).norm ↔ a.norm = b.norm := by
  constructor
  · intro h
    exact embedTy_injective (by simpa only [embedTy_norm] using h)
  · intro h
    rw [← embedTy_norm, ← embedTy_norm, h]

-- E のL20/L70 の予定の署名の型
#check @embedStoreTy
def embedLocalCtx (L : Benitoite.Release.LocalCtx) : LocalCtx := L.map (Option.map embedBuilderKind)
example (P0 : Benitoite.Release.Program) (B0 : Benitoite.Release.Builtins) (K : Program) (Ψ Q C Γ v a)
  (h : Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a) :
  HasTypeVQ K B (embedStoreTy Ψ) Q C (Γ.map (Option.map embedTy)) [] (embedVal v) (embedTy a) := by
  sorry
example (P0 : Benitoite.Release.Program) (B0 : Benitoite.Release.Builtins) (K : Program) (Ψ Q C Γ R m a e L)
  (h : Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L) :
  HasTypeCQ K B (embedStoreTy Ψ) Q C (Γ.map (Option.map embedTy)) [] (R.map embedTy)
    (embedComp m) (embedTy a) (embedEff e) (embedLocalCtx L) := by
  sorry
example (P0 : Benitoite.Release.Program) (B0 : Benitoite.Release.Builtins) (K : Program) (σ s ev s')
  (h : Benitoite.Release.Step P0 B0 s ev s') : Step K B σ (embedState s) (ev.map embedEvent) (embedState s') := by
  sorry
example (P0 : Benitoite.Release.Program) (B0 : Benitoite.Release.Builtins) (K : Program) (σ Eb s)
  (h : Benitoite.Release.StateTyE P0 B0 Eb s) : StateTyE K B σ (embedEff Eb) (embedState s) := by
  sorry
end E

namespace EncA
open Benitoite.Release.Refinement
def finiteEncodeAtoms (s : List Atom) (f : Atom → Bool) :
    Benitoite.Release.Atom → Bool := fun old =>
  s.any (fun a => decide (old = Benitoite.Release.Atom.rho a.code) && f a)
theorem finiteEncodeAtoms_eq (s : List Atom) (f : Atom → Bool)
    (hf : ∀ a, f a = true → a ∈ s) : finiteEncodeAtoms s f = encodeAtoms f := by
  funext old
  cases old with
  | name l ix => simp [finiteEncodeAtoms, encodeAtoms]
  | rho n =>
    by_cases h : ∃ a : Atom, a.code = n
    · obtain ⟨a, rfl⟩ := h
      rw [encodeAtoms_at]
      cases hfa : f a with
      | true => simp [finiteEncodeAtoms]; exact ⟨a, hf a hfa, rfl, hfa⟩
      | false =>
        simp [finiteEncodeAtoms]
        intro b _ hc
        have := Atom.code_injective hc
        subst this; simpa using hfa
    · have : encodeAtoms f (.rho n) = false := by
        classical
        simp only [encodeAtoms, h, dif_neg, not_false_eq_true]
      rw [this]
      simp only [finiteEncodeAtoms, List.any_eq_false]
      intro a _ 
      simp
      intro hn
      exact absurd ⟨a, hn.symm⟩ h
end EncA

namespace A
open Benitoite.Interval
def possible : Shared.ValueApprox → Bool
  | .bottom => false
  | .integer _ .bottom => false
  | .integer _ (.closed _ _ _) => true
  | .boolean f t => f || t
  | .unknown => true
theorem possible_iff (a : Shared.ValueApprox) : possible a = true ↔ ∃ v, a.Mem v := by
  cases a with
  | bottom => simp [possible, Shared.ValueApprox.Mem]
  | unknown => simp [possible]; exact ⟨.other, trivial⟩
  | integer k i =>
    cases i with
    | bottom =>
      simp only [possible, Bool.false_eq_true, false_iff]
      rintro ⟨v, hv⟩
      cases v <;> simp [Shared.ValueApprox.Mem, Interval.Mem, Mem] at hv
    | closed l h v =>
      simp only [possible, true_iff]
      exact ⟨.integer k ⟨l, by omega, by omega⟩, rfl, by simp [IntegerValue.toInt, Mem]; omega⟩
  | boolean f t =>
    cases f <;> cases t <;> simp [possible, Shared.ValueApprox.Mem]
    all_goals sorry

def baseToShared (type : Release.Ty) (b : BaseApprox) : Shared.ValueApprox :=
  match IntKind.ofType type with
  | some k => .integer k (b.rangeKind k)
  | none => match type with
    | .base .boolean => .boolean b.boolean.1 b.boolean.2
    | _ => .unknown
def BudgetAnalysis.Report.sharedFlow (r : BudgetAnalysis.Report) (type : Benitoite.Release.Ty)
    (returned : Shared.ValueApprox) : Shared.FlowApprox :=
  ⟨baseToShared type r.approx, returned, r.approx.mayFail⟩
theorem normalToShared_iff {type : Benitoite.Release.Ty}
    {range : NormalRange type} {value : ConcreteValue} (typed : value.type = type) :
    (normalToShared type range).Mem value.toApprox ↔ NormalMem type range value := by
  refine ⟨?_, normalToShared_mem⟩
  subst typed
  cases value <;> simp_all [NormalMem, NormalContains, normalToShared, ConcreteValue.type, ConcreteValue.toApprox, Shared.ValueApprox.Mem, NormalRange]
  all_goals sorry
end A
end RVL10
