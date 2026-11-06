import Benitoite.Release.Refinement.Surface.CheckArguments

/-! 型の情報を付けたソースの注釈の有限支持。型付けの正しさはこの条件に含めない。 -/
namespace Benitoite.Release.Refinement.Surface.CheckSource
open CheckArguments

def PartsSupport (s : List Atom) : List InterpPart → Prop
  | [] => True
  | .text _ :: ps | .stringExpr :: ps => PartsSupport s ps
  | .converted a :: ps | .formatted a _ :: ps => a.Support (· ∈ s) ∧ PartsSupport s ps

mutual
  def ExprSupport (q : CheckFormation.Input) (B : Builtins) : Expr → Prop
    | .local _ | .literal _ | .negInt _ | .negFloat _ | .negDecimal _ _
    | .negInteger8 _ | .negInteger16 _ | .negInteger32 _ | .negFloat32 _ | .unit => True
    | .builderOp _ _ es k => k.contents.Support (· ∈ q.atoms) ∧ ExprsSupport q B es
    | .constE a e => a.Support (· ∈ q.atoms) ∧ ExprSupport q B e
    | e@(.funName _ _ _ _) | e@(.primName _ _ _ _) | e@(.opName _ _) | e@(.externalName _ _) => HeadInputsSupport q B e
    | e@(.funDicts _ _ _ ds _ ps _) | e@(.opDicts _ _ ds _ ps) | e@(.methName _ _ _ _ ds _ ps) =>
        HeadInputsSupport q B e ∧ DictsSupport q.atoms ds ∧ Ty.SupportList (· ∈ q.atoms) ps
    | .raise t e => t.Support (· ∈ q.atoms) ∧ e.Support (· ∈ q.atoms)
    | .handleFail e t body clause => e.Support (· ∈ q.atoms) ∧ t.Support (· ∈ q.atoms) ∧
        BlockSupport q B body ∧ BlockSupport q B clause
    | .nullCon _ ts => Ty.SupportList (· ∈ q.atoms) ts
    | .conValue _ ts _ ps => Ty.SupportList (· ∈ q.atoms) ts ∧ Ty.SupportList (· ∈ q.atoms) ps
    | .paren e | .not e | .resume _ e => ExprSupport q B e
    | .block b | .lazyE b => BlockSupport q B b
    | .conCall _ ts args | .record _ ts _ args => Ty.SupportList (· ∈ q.atoms) ts ∧ ExprsSupport q B args
    | .recordUpdate _ ts _ _ e args => Ty.SupportList (· ∈ q.atoms) ts ∧ ExprSupport q B e ∧ ExprsSupport q B args
    | .call f _ _ args => ExprSupport q B f ∧ ExprsSupport q B args
    | .pipe a b | .and a b | .or a b => ExprSupport q B a ∧ ExprSupport q B b
    | .partialCall f _ args r e => ExprSupport q B f ∧ HolesSupport q B args ∧
        r.Support (· ∈ q.atoms) ∧ e.Support (· ∈ q.atoms)
    | .partialCon _ ts args => Ty.SupportList (· ∈ q.atoms) ts ∧ HolesSupport q B args
    | .binary _ t a b => t.Support (· ∈ q.atoms) ∧ ExprSupport q B a ∧ ExprSupport q B b
    | .neg t a => t.Support (· ∈ q.atoms) ∧ ExprSupport q B a
    | .list a es => a.Support (· ∈ q.atoms) ∧ ExprsSupport q B es
    | .listSpread a f before spread after => a.Support (· ∈ q.atoms) ∧ ExprSupport q B f ∧
        ExprsSupport q B before ∧ ExprSupport q B spread ∧ ExprsSupport q B after
    | .interpolation parts es fs => PartsSupport q.atoms parts ∧ ExprsSupport q B es ∧ ExprsSupport q B fs
    | .lam _ ps r e b => Ty.SupportList (· ∈ q.atoms) ps ∧ r.Support (· ∈ q.atoms) ∧
        e.Support (· ∈ q.atoms) ∧ BlockSupport q B b
    | .ite c y n => ExprSupport q B c ∧ BlockSupport q B y ∧ BlockSupport q B n
    | .elseIf c y n => ExprSupport q B c ∧ BlockSupport q B y ∧ ExprSupport q B n
    | .ifOnly c y => ExprSupport q B c ∧ BlockSupport q B y
    | .matchE b e arms => b.Support (· ∈ q.atoms) ∧ ExprSupport q B e ∧ ArmsSupport q B arms
    | .returnE t e => t.Support (· ∈ q.atoms) ∧ ExprSupport q B e
    | .tryResult ts _ _ e | .tryOption ts _ _ e => Ty.SupportList (· ∈ q.atoms) ts ∧ ExprSupport q B e
    | .tryResultDie t _ _ d _ _ e m => t.Support (· ∈ q.atoms) ∧ DictSupport q.atoms d ∧
        ExprSupport q B e ∧ MessageSupport q B m
    | .tryOptionDie t _ _ _ e m => t.Support (· ∈ q.atoms) ∧ ExprSupport q B e ∧ MessageSupport q B m
    | .withE _ e b => ExprSupport q B e ∧ BlockSupport q B b
    | .handleE b cs => BlockSupport q B b ∧ ClausesSupport q B cs
  def ExprsSupport (q : CheckFormation.Input) (B : Builtins) : Exprs → Prop
    | .nil => True
    | .cons e es => ExprSupport q B e ∧ ExprsSupport q B es
  def MessageSupport (q : CheckFormation.Input) (B : Builtins) : Option Expr → Prop
    | none => True
    | some e => ExprSupport q B e
  def HolesSupport (q : CheckFormation.Input) (B : Builtins) : HoleArgs → Prop
    | .nil => True
    | .expr _ _ e args => ExprSupport q B e ∧ HolesSupport q B args
    | .hole _ _ t args => t.Support (· ∈ q.atoms) ∧ HolesSupport q B args
  def ArmsSupport (q : CheckFormation.Input) (B : Builtins) : Arms → Prop
    | .nil => True
    | .cons _ g b rest => MessageSupport q B g ∧ BlockSupport q B b ∧ ArmsSupport q B rest
  def ClausesSupport (q : CheckFormation.Input) (B : Builtins) : Clauses → Prop
    | .nil => True
    | .cons _ _ _ body rest _ => BlockSupport q B body ∧ ClausesSupport q B rest
  def BlockSupport (q : CheckFormation.Input) (B : Builtins) : Block → Prop
    | .empty => True
    | .builderBind k rest => k.contents.Support (· ∈ q.atoms) ∧ BlockSupport q B rest
    | .last e | .lastDiscard e => ExprSupport q B e
    | .lastBind _ t e | .lastPat _ _ t e => t.Support (· ∈ q.atoms) ∧ ExprSupport q B e
    | .bind _ t e rest | .bindPat _ _ t e rest => t.Support (· ∈ q.atoms) ∧
        ExprSupport q B e ∧ BlockSupport q B rest
    | .discard e rest | .seq e rest => ExprSupport q B e ∧ BlockSupport q B rest
end


mutual
  private theorem exprSupport_transport {q : CheckFormation.Input} {B ks e} :
      ExprSupport {q with rangeKinds := ks} B e ↔ ExprSupport q B e := by
    cases e <;> simp only [ExprSupport, HeadInputsSupport, exprSupport_transport, exprsSupport_transport, messageSupport_transport, holesSupport_transport, armsSupport_transport, clausesSupport_transport, blockSupport_transport]
  private theorem exprsSupport_transport {q : CheckFormation.Input} {B ks es} :
      ExprsSupport {q with rangeKinds := ks} B es ↔ ExprsSupport q B es := by
    cases es <;> simp only [ExprsSupport, exprSupport_transport, exprsSupport_transport]
  private theorem messageSupport_transport {q : CheckFormation.Input} {B ks m} :
      MessageSupport {q with rangeKinds := ks} B m ↔ MessageSupport q B m := by
    cases m <;> simp only [MessageSupport, exprSupport_transport]
  private theorem holesSupport_transport {q : CheckFormation.Input} {B ks args} :
      HolesSupport {q with rangeKinds := ks} B args ↔ HolesSupport q B args := by
    cases args <;> simp only [HolesSupport, exprSupport_transport, holesSupport_transport]
  private theorem armsSupport_transport {q : CheckFormation.Input} {B ks arms} :
      ArmsSupport {q with rangeKinds := ks} B arms ↔ ArmsSupport q B arms := by
    cases arms <;> simp only [ArmsSupport, messageSupport_transport, blockSupport_transport, armsSupport_transport]
  private theorem clausesSupport_transport {q : CheckFormation.Input} {B ks clauses} :
      ClausesSupport {q with rangeKinds := ks} B clauses ↔ ClausesSupport q B clauses := by
    cases clauses <;> simp only [ClausesSupport, blockSupport_transport, clausesSupport_transport]
  private theorem blockSupport_transport {q : CheckFormation.Input} {B ks b} :
      BlockSupport {q with rangeKinds := ks} B b ↔ BlockSupport q B b := by
    cases b <;> simp only [BlockSupport, exprSupport_transport, blockSupport_transport]
end

/-- 範囲の種類の一覧の更新は、ソースの原子の有限支持を変えない。 -/
theorem blockSupport_rangeKinds {q : CheckFormation.Input} {B ks b} :
    BlockSupport {q with rangeKinds := ks} B b ↔ BlockSupport q B b :=
  blockSupport_transport

end Benitoite.Release.Refinement.Surface.CheckSource
