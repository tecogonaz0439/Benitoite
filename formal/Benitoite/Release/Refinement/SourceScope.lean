import Benitoite.Release.Refinement.Admissible
import Benitoite.Release.Refinement.Source

/-! # ソースの四名前空間の上限（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/- Eff.WF は Fail の型だけを読むため、効果原子の範囲添字を別に検査する。 -/
mutual
  def Ty.RangesScoped (nr : Nat) : Ty → Prop
    | .opaque _ ix | .scoped _ _ ix => ix.WF nr
    | .data _ as | .tapp _ as | .external _ as => rangesScopedTypes nr as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => a.RangesScoped nr
    | .map a b => a.RangesScoped nr ∧ b.RangesScoped nr
    | .fn _ ps r e => rangesScopedTypes nr ps ∧ r.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .cont a b e => a.RangesScoped nr ∧ b.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .dependentFn t => t.RangesScoped nr
    | _ => True
  def Tel.RangesScoped (nr : Nat) : Tel → Prop
    | .done a e => a.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .param _ a t => a.RangesScoped nr ∧ t.RangesScoped nr
  def Eff.RangesScoped (nr : Nat) : Eff → Prop
    | .mk atoms fs => (∀ name ix, atoms (.name name ix) = true → ix.WF nr) ∧ rangesScopedTypes nr fs
  def rangesScopedTypes (nr : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.RangesScoped nr ∧ rangesScopedTypes nr as
end

/-- 四名前空間のうち、型注釈に現れる範囲・型・値と、行変数の上限。 -/
def Ty.SourceScoped (nr nt ne nv : Nat) (a : Ty) : Prop :=
  a.WF nr nt nv ∧ a.RowsIn (· < ne) ∧ a.RangesScoped nr

def Eff.SourceScoped (nr nt ne nv : Nat) (e : Eff) : Prop :=
  e.WF nr nt nv ∧ e.RowsIn (· < ne) ∧ Eff.RangesScoped nr e

def BuilderKind.SourceScoped (nr nt ne nv : Nat) : BuilderKind → Prop
  | .list a => a.SourceScoped nr nt ne nv
  | .string | .bytes => True

mutual
  /-- ソースの値構文だけを受け入れ、束縛位置で各名前空間の深さを増やす。 -/
  def Val.SourceScoped (nr nt ne nv : Nat) : Val → Prop
    | .var i => i < nv
    | .const _ | .bytesV _ => True
    | .fnRef _ ts es => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es
    | .prim _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ r ∈ rs, r.WF ∧ r.Canonical)
    | .lam ns ps body => NamesWF ns ps ∧ scopedTypes nr nt ne nv ps ∧
        body.SourceScoped nr nt ne (nv + ps.length)
    | .dependentLam t body => (Ty.dependentFn t).SourceScoped nr nt ne nv ∧
        body.SourceScoped nr nt ne (nv + telBinders t)
    | .con _ ts vs | .dict _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .list vs | .setV vs => scopedValues nr nt ne nv vs
    | .op _ ts | .externalRef _ ts => scopedTypes nr nt ne nv ts
    | .raise a e => a.SourceScoped nr nt ne nv ∧ e.SourceScoped nr nt ne nv
    | .mapV ks vs => scopedValues nr nt ne nv ks ∧ scopedValues nr nt ne nv vs
    | .super v _ => v.SourceScoped nr nt ne nv
    | .scopePattern r => r.WF ∧ r.Canonical
    | .closure _ _ | .loc _ | .externalHandle _ _ | .pathBases _ |
        .checkedAt _ _ _ _ | .atError _ | .checked _ | .checkedRequest _ _ => False
  def scopedValues (nr nt ne nv : Nat) : List Val → Prop
    | [] => True
    | v :: vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
  def Comp.SourceScoped (nr nt ne nv : Nat) : Comp → Prop
    | .builderLet k m => k.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne (nv+1)
    | .builderOp k _ r vs => k.SourceScoped nr nt ne nv ∧
        (match r with | .bound i => i < nv | .loc _ => False) ∧ scopedValues nr nt ne nv vs
    | .ret v | .escape v => v.SourceScoped nr nt ne nv
    | .letIn m n => m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne (nv+1)
    | .app v vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
    | .ite v m n => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne nv
    | .match v arms => v.SourceScoped nr nt ne nv ∧ scopedArms nr nt ne nv arms
    | .lazyC m => m.SourceScoped nr nt ne nv
    | .use v m => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv
    | .handle m cs => m.SourceScoped nr nt ne nv ∧ scopedClauses nr nt ne nv cs
    | .resume k v => k.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .externalCall _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .issuePathBases _ => False
    | .checkAt _ _ sh bs p v ix => sh.errorType.SourceScoped nr nt ne nv ∧ ix.WF nr ∧
        (match bs with | none => True | some b => b.SourceScoped nr nt ne nv) ∧
        p.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .meth d _ ts es vs => d.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv ts ∧
        scopedRows nr nt ne nv es ∧ scopedValues nr nt ne nv vs
  def scopedArms (nr nt ne nv : Nat) : List Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True | some g => g.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts)) ∧
        body.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts) ∧ scopedArms nr nt ne nv arms
  def scopedClauses (nr nt ne nv : Nat) : List Clause → Prop
    | [] => True
    | .mk _ arity k body :: cs => body.SourceScoped nr (nt+k) ne (nv+arity+1) ∧ scopedClauses nr nt ne nv cs
    | .fail e body :: cs => e.SourceScoped nr nt ne nv ∧
        body.SourceScoped nr (nt+1) ne (nv+2) ∧ scopedClauses nr nt ne nv cs
  def scopedTypes (nr nt ne nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv as
  def scopedRows (nr nt ne nv : Nat) : List Eff → Prop
    | [] => True
    | e :: es => e.SourceScoped nr nt ne nv ∧ scopedRows nr nt ne nv es
end

/-- WF は依存列内の深さを増やし、Annotation は参照順序・sort・宣言を同時に読む。 -/
def SignatureScoped (P : Program) (C : TypeCtx) (ne : Nat) (t : Tel) : Prop :=
  (Ty.dependentFn t).SourceScoped 0 C.length ne 0 ∧ t.RowsIn (· < ne) ∧
    Ty.HasKind P (TypeCtx.kinds C) (.dependentFn t) .value ∧ Ty.Annotation P C [] (.dependentFn t)

end
end Benitoite.Release.Refinement
